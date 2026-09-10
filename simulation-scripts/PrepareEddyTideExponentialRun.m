function [requestPath,modelPath,provenance] = PrepareEddyTideExponentialRun(options)
% Prepare the exponential eddy-tide case for standalone C++ integration.
%
% Run in a fresh MATLAB session. This function selects the pinned v4 source
% and OceanKit dependency snapshots for this session without saving the path.
% It initializes the unforced beam and eddy, writes a closed restart file,
% and generates a portable request. It does not integrate the model.
%
% The profile is N2(z) = (3*2*pi/3600)^2 * exp(2*z/1300), on [-4000,0] m.
% The domain spans four mode-one M2 wavelengths. Vertical resolution follows
% WVStratification.verticalResolutionForHorizontalResolution.
%
% Existing output is preserved. A matching prepared run can be extended by
% supplying a later maxT; mismatched science or execution provenance fails.
%
% - Declaration: [requestPath,modelPath,provenance] = PrepareEddyTideExponentialRun(options)
% - Parameter Nxy: horizontal resolution, default 256
% - Parameter maxT: final time in seconds, default 600*86400; a multiple of six hours
% - Parameter outputDirectory: run folder, default model-output/exponential-Nxy256-depth4000-shift0
% - Parameter modelSource: pinned WaveVortexModel checkout, default repository .dependencies/wave-vortex-model
% - Returns requestPath: portable run-request JSON path
% - Returns modelPath: restart-capable NetCDF path
% - Returns provenance: recorded configuration, environment, and initialization measurements
arguments (Input)
    options.Nxy (1,1) double {mustBeInteger,mustBePositive} = 256
    options.maxT (1,1) double {mustBeFinite,mustBePositive} = 600*86400
    options.outputDirectory (1,1) string = ""
    options.modelSource (1,1) string = ""
end
arguments (Output)
    requestPath (1,1) string
    modelPath (1,1) string
    provenance (1,1) struct
end

scriptFolder = string(fileparts(mfilename("fullpath")));
repoRoot = string(fileparts(scriptFolder));
workspaceRoot = string(fileparts(repoRoot));
if options.modelSource == ""
    options.modelSource = fullfile(repoRoot,".dependencies/wave-vortex-model");
end
if options.outputDirectory == ""
    options.outputDirectory = fullfile(repoRoot,"model-output",sprintf("exponential-Nxy%d-depth4000-shift0",options.Nxy));
end
outputDirectory = string(java.io.File(options.outputDirectory).getCanonicalPath());
if isfolder(fullfile(outputDirectory,".run.lock"))
    error("JPO2026:ActiveRun","The run folder is locked. Stop the runner before preparing or inspecting its NetCDF file.");
end
outputInterval = 86400/4;
if mod(options.maxT,outputInterval) ~= 0
    error("JPO2026:FinalTime","maxT must be a multiple of the six-hour output interval.");
end
environment = configureEnvironment(workspaceRoot,scriptFolder,options.modelSource);
configuration = struct("schemaVersion",1,"Nxy",options.Nxy,"Lz",4000,"N0",3*2*pi/3600,"stratificationScale",1300,"latitude",45,"M2Period",12.420602*3600,"domainWavelengths",4,"u0Wave",0.05,"eddySpeed",0.10,"eddyHorizontalScale",80e3,"eddyVerticalScale",300,"beamTaperScale",500,"tideBeamShiftFraction",0,"isForced",false,"outputInterval",outputInterval);
modelPath = fullfile(outputDirectory,"eddy-tide-exponential.nc");
requestPath = fullfile(outputDirectory,"run.json");
provenancePath = fullfile(outputDirectory,"provenance.json");
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

if isfile(modelPath)
    if ~isfile(provenancePath)
        error("JPO2026:MissingProvenance","Existing model output has no provenance.json; it will not be overwritten.");
    end
    provenance = jsondecode(fileread(provenancePath));
    storedConfiguration = jsondecode(ncreadatt(modelPath,"/","eddyTideExponentialConfiguration"));
    if ~isequaln(provenance.configuration,configuration) || ~isequaln(storedConfiguration,configuration) || ~strcmp(jsonencode(provenance.environment),jsonencode(environment))
        error("JPO2026:RunMismatch","Existing output differs from the requested scientific configuration or pinned environment.");
    end
    model = WVModel.modelFromFile(modelPath);
    closeModel = onCleanup(@()model.closeNetCDFFile());
    validateTransform(model.wvt,configuration);
    if model.t >= options.maxT
        error("JPO2026:RunAlreadyComplete","Existing output has reached day %.6g; maxT must be later.",model.t/86400);
    end
    fprintf("Resuming matching output at day %.6g.\n",model.t/86400);
    clear closeModel model
else
    if isfile(provenancePath)
        error("JPO2026:MissingModel","provenance.json exists without its model file; use a new run directory.");
    end
    N0 = configuration.N0;
    Lz = configuration.Lz;
    stratificationScale = configuration.stratificationScale;
    N2 = @(z) N0^2*exp(2*z/stratificationScale);
    im = InternalModesWKBSpectral(N2=N2,zIn=[-Lz 0],latitude=configuration.latitude);
    [~,~,~,kSD] = im.ModesAtFrequency(2*pi/configuration.M2Period);
    Lsd = 2*pi/kSD(1);
    Lxy = configuration.domainWavelengths*Lsd;
    Nz = WVStratification.verticalResolutionForHorizontalResolution(Lxy,Lz,options.Nxy,N2Function=N2,latitude=configuration.latitude);
    wvt = WVTransformHydrostatic([Lxy Lxy Lz],[options.Nxy options.Nxy Nz],N2Function=N2,latitude=configuration.latitude);
    wvt.addForcing(WVAdaptiveDamping(wvt));
    damping = wvt.forcingWithName("adaptive damping");

    % Match the minimal simulation's discrete M2 beam and bottom taper.
    maskApSD = false(wvt.spectralMatrixSize);
    for iJ = 1:max(wvt.j)
        indices = find(wvt.L == 0 & wvt.j == iJ & wvt.Kh < damping.k_damp & wvt.J < damping.j_damp);
        if isempty(indices), continue; end
        [~,closest] = min(abs(wvt.Omega(indices)-2*pi/configuration.M2Period));
        maskApSD(indices(closest)) = true;
    end
    wvt.removeAll;
    L = configuration.beamTaperScale;
    taper = 0.10*(1-2*((wvt.z+Lz)/L).^2).*exp(-((wvt.z+Lz)/L).^2);
    taperJ = wvt.FMatrix*taper;
    for iJ = 1:max(wvt.j)
        wvt.Ap(maskApSD & wvt.J == iJ) = taperJ(iJ);
    end
    if ~isfinite(wvt.uvMax) || wvt.uvMax <= 0
        error("JPO2026:EmptyBeam","The resolved grid cannot initialize the requested M2 beam.");
    end
    wvt.Ap = configuration.u0Wave*wvt.Ap/wvt.uvMax;
    waveMaximum = wvt.uvMax;
    assert(abs(waveMaximum-configuration.u0Wave) < 1e-12,"Beam normalization failed.");

    x0 = Lxy/2; y0 = Lxy/2;
    Le = configuration.eddyHorizontalScale;
    He = configuration.eddyVerticalScale;
    U = configuration.eddySpeed;
    H = @(z) exp(-(z/He/sqrt(2)).^2);
    F = @(x,y) exp(-((x-x0)/Le).^2-((y-y0)/Le).^2);
    psi = @(x,y,z) U*(Le/sqrt(2))*exp(1/2)*H(z).*(F(x,y)-(pi*Le*Le/(wvt.Lx*wvt.Ly)));
    wvt.addGeostrophicStreamfunction(psi);
    wvt.A0(wvt.Kh > damping.k_damp) = 0;
    validateTransform(wvt,configuration);

    model = WVModel(wvt);
    closeModel = onCleanup(@()model.closeNetCDFFile());
    output = model.createNetCDFFileForModelOutput(modelPath,outputInterval=outputInterval,shouldOverwriteExisting=false);
    output.outputTimesForIntegrationPeriod(0,options.maxT);
    output.writeTimeStepToOutputFile(0);
    clear closeModel
    ncwriteatt(modelPath,"/","eddyTideExponentialConfiguration",jsonencode(configuration));

    resolved = struct("Lxy",Lxy,"M2Wavelength",Lsd,"Nz",wvt.Nz,"Nj",wvt.Nj,"Nkl",wvt.Nkl,"initialWaveMaximum",waveMaximum,"coefficientBytesPerRecord",3*16*numel(wvt.Ap));
    provenance = struct("configuration",configuration,"environment",environment,"resolved",resolved,"createdAt",string(datetime("now",TimeZone="UTC")),"preparationSHA256",fileSHA256(mfilename("fullpath")+".m"));
    writeJSON(provenancePath,provenance);
    fprintf("Initialized %d x %d x %d, %d retained modes, Lxy=%.6f km.\n",options.Nxy,options.Nxy,wvt.Nz,wvt.Nj,Lxy/1e3);
end

WVModel.writePortableRunRequest(requestPath,modelPath,finalTime=options.maxT);
fprintf("Prepared C++ ode78 continuation to day %.6g; estimated coefficient output %.3f GiB.\n",options.maxT/86400,(1+options.maxT/outputInterval)*provenance.resolved.coefficientBytesPerRecord/2^30);
fprintf("Request: %s\n",requestPath);
end

function environment = configureEnvironment(workspaceRoot,scriptFolder,modelSource)
expectedCommit = "a74ed4e61bc1bc57f731c999d7d404f8732f8679";
modelSource = string(java.io.File(modelSource).getCanonicalPath());
[status,commit] = system("git -C "+shellQuote(modelSource)+" rev-parse HEAD");
if status ~= 0 || string(strtrim(commit)) ~= expectedCommit
    error("JPO2026:ModelRevision","modelSource must be WaveVortexModel commit %s.",expectedCommit);
end
[status,changes] = system("git -C "+shellQuote(modelSource)+" status --porcelain --untracked-files=no");
if status ~= 0 || strlength(strtrim(changes)) ~= 0
    error("JPO2026:ModifiedModel","The pinned model source has tracked changes.");
end
runner = fullfile(modelSource,".compiled-backend-cache/runtime-build/wave-vortex-run");
if ~isfile(runner)
    error("JPO2026:MissingRunner","Build the native runner first: %s",fullfile(modelSource,"PortableRuntime/buildWaveVortexRun.sh"));
end
snapshots = ["SplineCore-2.2.0","NetCDF-1.0.2","ClassAnnotations-1.2.1","InternalModes-1.3.0","chebfun-5.7.0"];
roots = [fullfile(workspaceRoot,"OceanKit",snapshots),modelSource];
restoredefaultpath;
for root = roots
    manifestPath = fullfile(root,"resources/mpackage.json");
    if ~isfile(manifestPath)
        error("JPO2026:MissingDependency","Missing dependency manifest: %s",manifestPath);
    end
    manifest = jsondecode(fileread(manifestPath));
    addpath(root,"-begin");
    for iFolder = 1:numel(manifest.folders)
        addpath(fullfile(root,manifest.folders(iFolder).path),"-begin");
    end
end
addpath(scriptFolder,"-begin");
assert(string(which("WVModel")) == fullfile(modelSource,"@WVModel/WVModel.m"),"The pinned WVModel is not active; use a fresh MATLAB session.");
environment = struct("modelSource",modelSource,"modelCommit",expectedCommit,"runner",runner,"runnerSHA256",fileSHA256(runner),"dependencySnapshots",snapshots(:),"matlabVersion",string(version),"architecture",string(computer("arch")));
end

function validateTransform(wvt,c)
assert(isa(wvt,"WVTransformHydrostatic"),"Expected a hydrostatic transform.");
assert(wvt.Nx == c.Nxy && wvt.Ny == c.Nxy && wvt.Lz == c.Lz,"Unexpected grid or depth.");
expectedN2 = c.N0^2*exp(2*wvt.z/c.stratificationScale);
assert(max(abs(wvt.N2-expectedN2)) < 1e-12*max(expectedN2),"Unexpected stratification.");
assert(all(isfinite(wvt.Ap),"all") && all(isfinite(wvt.Am),"all") && all(isfinite(wvt.A0),"all"),"Nonfinite initial or restored coefficients.");
end

function digest = fileSHA256(path)
[status,result] = system("shasum -a 256 "+shellQuote(path));
assert(status == 0,"Unable to hash provenance input.");
digest = string(extractBefore(result,65));
end

function quoted = shellQuote(value)
quoted = "'"+replace(string(value),"'","'"+string(char(34))+"'"+string(char(34))+"'")+"'";
end

function writeJSON(path,value)
fid = fopen(path,"w");
if fid < 0, error("JPO2026:ProvenanceWrite","Cannot write %s.",path); end
closeFile = onCleanup(@()fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
