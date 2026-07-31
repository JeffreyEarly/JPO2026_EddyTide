function EddyTidePseudoTopographicSuiteWorker
% Run or preflight one job in the pseudo-topographic simulation campaign.
%
% This function is an implementation detail of
% `run-pseudo-topographic-suite.sh`. The scheduler supplies configuration
% through `PSEUDOTOPO_*` environment variables so detached MATLAB processes
% do not depend on computer-specific paths embedded in command strings.

scriptDirectory = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(scriptDirectory));
figureDirectory = fullfile(repositoryRoot,"figure-scripts");
addpath(scriptDirectory)
addpath(figureDirectory)

action = environmentString("PSEUDOTOPO_ACTION");
switch action
    case "preflight"
        runPreflight(repositoryRoot)
    case "run"
        runJob(repositoryRoot)
    otherwise
        error("EddyTidePseudoTopographicSuiteWorker:UnknownAction", "PSEUDOTOPO_ACTION must be 'preflight' or 'run'.")
end
end

function runPreflight(repositoryRoot)
requiredFunctions = ["EddyTidePseudoTopographicSimulationMinimal" "EddyTidePseudoTopographicQuicklook" ...
    "EddyTidePseudoTopographicEnergyDiagnostics" "EddyTidePseudoTopographicEnergyComparison"];
for functionName = requiredFunctions
    if exist(functionName,"file") ~= 2
        error("EddyTidePseudoTopographicSuiteWorker:MissingFunction", "Required function '%s' is not on the MATLAB path.",functionName)
    end
end
if exist("WVPseudoTopographicWaveGeneration","class") ~= 8
    error("EddyTidePseudoTopographicSuiteWorker:MissingWaveVortexModel", "WaveVortexModel 4.2.0 or newer, including WVPseudoTopographicWaveGeneration, is required.")
end
if exist("WVDiagnostics","class") ~= 8
    error("EddyTidePseudoTopographicSuiteWorker:MissingDiagnostics", "WaveVortexModelDiagnostics 1.0.7 or newer is required.")
end

modelVersion = packageVersionForClass("WVTransform");
diagnosticsVersion = string(WVDiagnostics.version());
requireMinimumVersion(modelVersion,"4.2.0","WaveVortexModel")
requireMinimumVersion(diagnosticsVersion,"1.0.7","WaveVortexModelDiagnostics")

outputDirectory = environmentString("PSEUDOTOPO_OUTPUT_DIRECTORY");
if ~isfolder(outputDirectory)
    mkdir(outputDirectory)
end
fprintf("Pseudo-topographic campaign preflight passed.\n")
fprintf("Repository: %s\n",repositoryRoot)
fprintf("MATLAB: %s\n",version)
fprintf("WaveVortexModel: %s\n",modelVersion)
fprintf("WaveVortexModelDiagnostics: %s\n",diagnosticsVersion)
fprintf("Output directory: %s\n",outputDirectory)
end

function runJob(repositoryRoot)
configuration = readConfiguration();
if startsWith(configuration.jobID,"pair-")
    runPairAnalysis(configuration)
elseif startsWith(configuration.jobID,"single-")
    runStandaloneAnalysis(configuration)
else
    runSimulationCase(repositoryRoot,configuration)
end
end

function runSimulationCase(repositoryRoot,configuration)
caseConfiguration = configurationForCase(configuration.jobID);
caseDirectory = fullfile(configuration.suiteRoot,"cases",configuration.jobID);
if ~isfolder(caseDirectory)
    mkdir(caseDirectory)
end

failurePath = fullfile(caseDirectory,"failed.txt");
archiveExistingFailure(failurePath,caseDirectory)
writeCaseManifest(caseDirectory,repositoryRoot,configuration,caseConfiguration)

stage = "simulation";
writeStage(caseDirectory,stage)
try
    simulationMarker = fullfile(caseDirectory,"simulation-complete.txt");
    if isfile(simulationMarker)
        modelFile = markerValue(simulationMarker,"model_file");
        if ~isfile(modelFile)
            error("EddyTidePseudoTopographicSuiteWorker:MissingCompletedModel", "The simulation marker refers to missing model output '%s'.",modelFile)
        end
        fprintf("[%s] Reusing completed simulation %s.\n",localTimestamp(),modelFile)
    else
        modelFile = runSimulation(configuration,caseConfiguration);
        validateModelOutput(modelFile,configuration,caseConfiguration)
        writeMarker(simulationMarker,[
            "case_id="+configuration.jobID
            "model_file="+modelFile
            "records="+expectedRecordCount(configuration)
            "final_day="+configuration.targetDay
            "completed_at="+localTimestamp()
            ])
    end

    stage = "quicklook";
    writeStage(caseDirectory,stage)
    quicklookMarker = fullfile(caseDirectory,"quicklook-complete.txt");
    if ~isfile(quicklookMarker)
        [figures,quicklook] = EddyTidePseudoTopographicQuicklook(modelFile,iTime=Inf,figureVisible="off", ...
            shouldExport=true,shouldOverwriteExisting=true);
        close(figures)
        writeMarker(quicklookMarker,[
            "case_id="+configuration.jobID
            "model_file="+modelFile
            "quicklook_state="+quicklook.figurePaths(1)
            "quicklook_spectra="+quicklook.figurePaths(2)
            "completed_at="+localTimestamp()
            ])
    end

    writeStage(caseDirectory,"complete")
    fprintf("[%s] Simulation job %s completed successfully.\n",localTimestamp(),configuration.jobID)
catch exception
    writeFailure(failurePath,configuration.jobID,stage,exception)
    writeStage(caseDirectory,"failed")
    fprintf(2,"%s\n",getReport(exception,"extended"))
    rethrow(exception)
end
end

function runStandaloneAnalysis(configuration)
caseID = extractAfter(configuration.jobID,"single-");
caseConfiguration = configurationForCase(caseID);
analysisDirectory = fullfile(configuration.suiteRoot,"analysis",configuration.jobID);
if ~isfolder(analysisDirectory)
    mkdir(analysisDirectory)
end
failurePath = fullfile(analysisDirectory,"failed.txt");
archiveExistingFailure(failurePath,analysisDirectory)
writeStage(analysisDirectory,"analysis")
try
    modelFile = completedModelFile(configuration.suiteRoot,caseID);
    if caseConfiguration.initialCondition == "eddy"
        energyScale = "normalized";
    else
        energyScale = "absolute";
    end
    [figureHandle,energy,diagnosticsFile] = EddyTidePseudoTopographicEnergyDiagnostics(modelFile, ...
        diagnosticsStride=4,shouldUpdateDiagnostics=true,energyScale=energyScale,figureVisible="off", ...
        shouldExport=true,shouldOverwriteExisting=true);
    close(figureHandle)
    validateAnalysisTimes(energy,configuration)
    confirmReadWriteReopen(modelFile)
    confirmReadWriteReopen(diagnosticsFile)
    writeMarker(fullfile(analysisDirectory,"analysis-complete.txt"),[
        "job_id="+configuration.jobID
        "model_file="+modelFile
        "diagnostics_file="+diagnosticsFile
        "energy_figure="+energy.figurePath
        "energy_scale="+energyScale
        "completed_at="+localTimestamp()
        ])
    writeStage(analysisDirectory,"complete")
catch exception
    writeFailure(failurePath,configuration.jobID,"analysis",exception)
    writeStage(analysisDirectory,"failed")
    fprintf(2,"%s\n",getReport(exception,"extended"))
    rethrow(exception)
end
end

function runPairAnalysis(configuration)
pairID = extractAfter(configuration.jobID,"pair-");
tokens = split(pairID,"-");
if numel(tokens) ~= 2 || ~ismember(tokens(1),["hiron" "shakespeare"]) || ~ismember(tokens(2),["strong" "moderate" "weak"])
    error("EddyTidePseudoTopographicSuiteWorker:UnknownPair", "Unknown paired-analysis job '%s'.",configuration.jobID)
end
eddyCaseID = pairID+"-eddy";
controlCaseID = pairID+"-control";
analysisDirectory = fullfile(configuration.suiteRoot,"analysis",configuration.jobID);
if ~isfolder(analysisDirectory)
    mkdir(analysisDirectory)
end
failurePath = fullfile(analysisDirectory,"failed.txt");
archiveExistingFailure(failurePath,analysisDirectory)
writeStage(analysisDirectory,"analysis")
try
    eddyFile = completedModelFile(configuration.suiteRoot,eddyCaseID);
    controlFile = completedModelFile(configuration.suiteRoot,controlCaseID);
    validateMatchingPair(eddyFile,controlFile,configuration)
    exportPrefix = "eddy-tide-pseudo-topographic-"+pairID;
    [figureHandle,comparison,diagnosticsFiles] = EddyTidePseudoTopographicEnergyComparison(eddyFile,controlFile, ...
        diagnosticsStride=4,figureVisible="off",shouldExport=true,exportDirectory=configuration.outputDirectory, ...
        exportPrefix=exportPrefix,shouldOverwriteExisting=true);
    close(figureHandle)
    validateAnalysisTimes(comparison.eddy,configuration)
    validateAnalysisTimes(comparison.control,configuration)
    confirmReadWriteReopen(eddyFile)
    confirmReadWriteReopen(controlFile)
    confirmReadWriteReopen(diagnosticsFiles.eddy)
    confirmReadWriteReopen(diagnosticsFiles.control)
    writeMarker(fullfile(analysisDirectory,"analysis-complete.txt"),[
        "job_id="+configuration.jobID
        "eddy_file="+eddyFile
        "control_file="+controlFile
        "eddy_diagnostics="+diagnosticsFiles.eddy
        "control_diagnostics="+diagnosticsFiles.control
        "energy_figure="+comparison.figurePath
        "normalization="+compose("%.17g",comparison.normalization)
        "completed_at="+localTimestamp()
        ])
    writeStage(analysisDirectory,"complete")
catch exception
    writeFailure(failurePath,configuration.jobID,"analysis",exception)
    writeStage(analysisDirectory,"failed")
    fprintf(2,"%s\n",getReport(exception,"extended"))
    rethrow(exception)
end
end

function configuration = readConfiguration()
configuration = struct;
configuration.jobID = environmentString("PSEUDOTOPO_JOB_ID");
configuration.suiteRoot = environmentString("PSEUDOTOPO_SUITE_ROOT");
configuration.outputDirectory = environmentString("PSEUDOTOPO_OUTPUT_DIRECTORY");
configuration.Nxy = environmentNumber("PSEUDOTOPO_NXY",mustBeInteger=true,mustBePositive=true);
configuration.targetDay = environmentNumber("PSEUDOTOPO_TARGET_DAY",mustBePositive=true);
configuration.outputInterval = environmentNumber("PSEUDOTOPO_OUTPUT_INTERVAL",mustBePositive=true);
configuration.minimumTopographicWavelength = 1e3*environmentNumber("PSEUDOTOPO_MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM",mustBePositive=true);
numberOfIntervals = configuration.targetDay*86400/configuration.outputInterval;
if abs(numberOfIntervals-round(numberOfIntervals)) > 100*eps(max(1,numberOfIntervals))
    error("EddyTidePseudoTopographicSuiteWorker:IncommensurateTargetTime", "The target day must be an integer multiple of the output interval.")
end
end

function caseConfiguration = configurationForCase(caseID)
tokens = split(caseID,"-");
if numel(tokens) ~= 3 || ~ismember(tokens(1),["hiron" "shakespeare"]) || ...
        ~ismember(tokens(2),["strong" "moderate" "weak"]) || ~ismember(tokens(3),["eddy" "control"])
    error("EddyTidePseudoTopographicSuiteWorker:UnknownCase", "Unknown campaign case '%s'.",caseID)
end
caseConfiguration = struct(suite=tokens(1),forcingRegime=tokens(2),initialCondition=tokens(3));
caseConfiguration.includeEddy = caseConfiguration.initialCondition == "eddy";
switch caseConfiguration.forcingRegime
    case "strong"
        caseConfiguration.barotropicCurrentSpeed = 0.05/sqrt(10);
    case "moderate"
        caseConfiguration.barotropicCurrentSpeed = 0.05/sqrt(40);
    case "weak"
        caseConfiguration.barotropicCurrentSpeed = 0.05/sqrt(160);
end
end

function modelFile = runSimulation(configuration,caseConfiguration)
fprintf("[%s] Starting campaign case %s through day %g.\n",localTimestamp(),configuration.jobID,configuration.targetDay)
if caseConfiguration.suite == "hiron"
    [model,~,modelFile] = EddyTidePseudoTopographicSimulationMinimal(Nxy=configuration.Nxy, ...
        includeEddy=caseConfiguration.includeEddy,maxT=configuration.targetDay*86400, ...
        outputInterval=configuration.outputInterval,outputDirectory=configuration.outputDirectory, ...
        shouldOverwriteExisting=false,minimumTopographicWavelength=configuration.minimumTopographicWavelength, ...
        forcingRegime=caseConfiguration.forcingRegime,domainSizeTidalWavelengths=4);
else
    [model,~,modelFile] = EddyTidePseudoTopographicSimulationMinimal(Nxy=configuration.Nxy, ...
        includeEddy=caseConfiguration.includeEddy,maxT=configuration.targetDay*86400, ...
        outputInterval=configuration.outputInterval,outputDirectory=configuration.outputDirectory, ...
        shouldOverwriteExisting=false,minimumTopographicWavelength=configuration.minimumTopographicWavelength, ...
        forcingRegime=caseConfiguration.forcingRegime,Lxy=500e3);
end
model.closeNetCDFFile();
clear model
modelFile = string(modelFile);
end

function validateModelOutput(modelFile,configuration,caseConfiguration)
numberOfRecords = expectedRecordCount(configuration);
expectedTime = (0:numberOfRecords-1).'*configuration.outputInterval;
[wvt,ncfile] = WVTransform.waveVortexTransformFromFile(char(modelFile),iTime=numberOfRecords,shouldReadOnly=true);
fileCleanup = onCleanup(@()ncfile.close());
savedTime = reshape(ncfile.readVariables("wave-vortex/t"),[],1);
if ~isequal(savedTime,expectedTime)
    error("EddyTidePseudoTopographicSuiteWorker:InvalidSavedTimes", "Model output must contain exactly %d records from day zero through day %g.",numberOfRecords,configuration.targetDay)
end

expectedLxy = expectedDomainWidth(caseConfiguration.suite);
N0 = sqrt(2e-5);
N2 = @(z)N0*N0*ones(size(z));
expectedNz = WVStratification.verticalResolutionForHorizontalResolution(expectedLxy,2000,configuration.Nxy,N2=N2,latitude=45);
domainTolerance = 100*eps(expectedLxy);
if wvt.Nx ~= configuration.Nxy || wvt.Ny ~= configuration.Nxy || wvt.Nz ~= expectedNz || abs(wvt.Lx-expectedLxy) > domainTolerance || abs(wvt.Ly-expectedLxy) > domainTolerance
    error("EddyTidePseudoTopographicSuiteWorker:ConfigurationMismatch", "The saved domain or resolution does not match the requested campaign case.")
end
if any(~isfinite([wvt.Ap(:); wvt.Am(:); wvt.A0(:)]))
    error("EddyTidePseudoTopographicSuiteWorker:NonfiniteCoefficients", "Final model coefficients must be finite.")
end

generation = pseudoTopographicGeneration(wvt);
M2Period = 12.420602*3600;
if generation.darwinSymbol ~= "M2" || abs(generation.frequency-2*pi/M2Period) > 100*eps(2*pi/M2Period) || ...
        abs(generation.rampDuration-M2Period) > 100*eps(M2Period) || generation.startTime ~= 0 || ...
        ~generation.shouldAvoidAdaptiveDamping || ~isinf(generation.maximumForcedHorizontalWavenumber) || ...
        ~isinf(generation.maximumForcedVerticalMode)
    error("EddyTidePseudoTopographicSuiteWorker:ForcingConfigurationMismatch", "The saved pseudo-topographic forcing options do not match the campaign configuration.")
end
expectedVelocity = [caseConfiguration.barotropicCurrentSpeed; 0];
if any(abs(generation.barotropicVelocityAmplitude-expectedVelocity) > 100*eps(max(1,max(abs(expectedVelocity)))))
    error("EddyTidePseudoTopographicSuiteWorker:ForcingAmplitudeMismatch", "The saved barotropic-current amplitude does not match the requested forcing regime.")
end
if nnz(arrayfun(@(forcing)isa(forcing,"WVAdaptiveDamping"),wvt.forcing)) ~= 1
    error("EddyTidePseudoTopographicSuiteWorker:AdaptiveDampingMismatch", "The model must contain exactly one WVAdaptiveDamping closure.")
end

[~,expectedTopography] = WVPseudoTopographicWaveGeneration.goffAbyssalHillTopography(wvt,rmsHeight=100, ...
    cornerWavenumber=1e-4,minimumWavelength=configuration.minimumTopographicWavelength,randomSeed=2023);
terrainTolerance = 100*eps(max(1,max(abs(expectedTopography),[],"all")));
if any(abs(generation.topographicHeight-expectedTopography) > terrainTolerance,"all")
    error("EddyTidePseudoTopographicSuiteWorker:TerrainMismatch", "The saved terrain does not match the deterministic campaign realization.")
end

expectedCaseToken = "-"+caseConfiguration.initialCondition+"-";
if ~contains(modelFile,expectedCaseToken)
    error("EddyTidePseudoTopographicSuiteWorker:InitialConditionMismatch", "The model filename does not identify the requested initial condition.")
end

clear fileCleanup
confirmReadWriteReopen(modelFile)
fprintf("[%s] Validated %d model records through day %g.\n",localTimestamp(),numberOfRecords,configuration.targetDay)
end

function validateMatchingPair(eddyFile,controlFile,configuration)
numberOfRecords = expectedRecordCount(configuration);
[eddy,ncEddy] = WVTransform.waveVortexTransformFromFile(char(eddyFile),iTime=numberOfRecords,shouldReadOnly=true);
eddyCleanup = onCleanup(@()ncEddy.close());
[control,ncControl] = WVTransform.waveVortexTransformFromFile(char(controlFile),iTime=numberOfRecords,shouldReadOnly=true);
controlCleanup = onCleanup(@()ncControl.close());
eddyTime = reshape(ncEddy.readVariables("wave-vortex/t"),[],1);
controlTime = reshape(ncControl.readVariables("wave-vortex/t"),[],1);
if ~isequal(eddyTime,controlTime) || ~isequal([eddy.Lx eddy.Ly eddy.Lz eddy.Nx eddy.Ny eddy.Nz],[control.Lx control.Ly control.Lz control.Nx control.Ny control.Nz])
    error("EddyTidePseudoTopographicSuiteWorker:PairConfigurationMismatch", "Paired eddy and control files must have identical domains, resolutions, and saved times.")
end
eddyGeneration = pseudoTopographicGeneration(eddy);
controlGeneration = pseudoTopographicGeneration(control);
if ~isequal(eddyGeneration.topographicHeight,controlGeneration.topographicHeight) || ...
        ~isequal(eddyGeneration.barotropicVelocityAmplitude,controlGeneration.barotropicVelocityAmplitude) || ...
        eddyGeneration.frequency ~= controlGeneration.frequency
    error("EddyTidePseudoTopographicSuiteWorker:PairForcingMismatch", "Paired eddy and control files must have identical terrain and forcing.")
end
clear controlCleanup eddyCleanup
end

function validateAnalysisTimes(energy,configuration)
if energy.time(end) ~= configuration.targetDay*86400 || energy.waveSpeedTime(end) ~= configuration.targetDay*86400 || numel(energy.waveSpeedTime) ~= expectedRecordCount(configuration)
    error("EddyTidePseudoTopographicSuiteWorker:IncompleteAnalysis", "Final diagnostics and wave-speed history must extend through the requested target day.")
end
end

function modelFile = completedModelFile(suiteRoot,caseID)
markerPath = fullfile(suiteRoot,"cases",caseID,"simulation-complete.txt");
if ~isfile(markerPath)
    error("EddyTidePseudoTopographicSuiteWorker:MissingSimulationMarker", "Simulation marker is missing for case '%s'.",caseID)
end
modelFile = markerValue(markerPath,"model_file");
if ~isfile(modelFile)
    error("EddyTidePseudoTopographicSuiteWorker:MissingCompletedModel", "Completed model output '%s' is missing.",modelFile)
end
end

function generation = pseudoTopographicGeneration(wvt)
generators = arrayfun(@(forcing)isa(forcing,"WVPseudoTopographicWaveGeneration"),wvt.forcing);
if nnz(generators) ~= 1
    error("EddyTidePseudoTopographicSuiteWorker:GeneratorMismatch", "The model must contain exactly one WVPseudoTopographicWaveGeneration forcing.")
end
generation = wvt.forcing(find(generators,1));
end

function Lxy = expectedDomainWidth(suite)
if suite == "shakespeare"
    Lxy = 500e3;
    return
end
N0 = sqrt(2e-5);
M2Period = 12.420602*3600;
N2 = @(z)N0*N0*ones(size(z));
internalModes = InternalModesWKBSpectral(N2=N2,zIn=[-2000 0],latitude=45);
[~,~,~,kM2] = internalModes.modesAtFrequency(2*pi/M2Period);
Lxy = 4*2*pi/kM2(1);
end

function count = expectedRecordCount(configuration)
count = round(configuration.targetDay*86400/configuration.outputInterval)+1;
end

function confirmReadWriteReopen(path)
file = NetCDFFile(char(path),shouldReadOnly=false);
file.close();
end

function writeCaseManifest(caseDirectory,repositoryRoot,configuration,caseConfiguration)
[commit,dirty] = repositoryState(repositoryRoot);
manifestPath = fullfile(caseDirectory,"case-manifest.txt");
writeMarker(manifestPath,[
    "case_id="+configuration.jobID
    "suite="+caseConfiguration.suite
    "forcing_regime="+caseConfiguration.forcingRegime
    "initial_condition="+caseConfiguration.initialCondition
    "include_eddy="+caseConfiguration.includeEddy
    "barotropic_current_speed_m_s="+compose("%.17g",caseConfiguration.barotropicCurrentSpeed)
    "domain_width_m="+compose("%.17g",expectedDomainWidth(caseConfiguration.suite))
    "domain_definition="+domainDefinition(caseConfiguration.suite)
    "Nxy="+configuration.Nxy
    "target_day="+configuration.targetDay
    "output_interval_seconds="+configuration.outputInterval
    "terrain_rms_height_m=100"
    "terrain_corner_wavenumber_rad_m=0.0001"
    "minimum_topographic_wavelength_m="+configuration.minimumTopographicWavelength
    "terrain_random_seed=2023"
    "tidal_constituent=M2"
    "adaptive_damping=true"
    "antialiasing=true"
    "avoid_adaptive_damping=true"
    "output_directory="+configuration.outputDirectory
    "repository_commit="+commit
    "repository_dirty="+dirty
    "matlab_version="+string(version)
    "wave_vortex_model_version="+packageVersionForClass("WVTransform")
    "wave_vortex_model_diagnostics_version="+string(WVDiagnostics.version())
    "process_id="+feature("getpid")
    "started_at="+localTimestamp()
    ])
end

function definition = domainDefinition(suite)
if suite == "hiron"
    definition = "four mode-one M2 wavelengths";
else
    definition = "fixed 500 km Shakespeare width";
end
end

function [commit,dirty] = repositoryState(repositoryRoot)
[commitStatus,commitOutput] = system(sprintf('git -C "%s" rev-parse HEAD',repositoryRoot));
if commitStatus == 0
    commit = strip(string(commitOutput));
else
    commit = "unknown";
end
[dirtyStatus,dirtyOutput] = system(sprintf('git -C "%s" status --porcelain',repositoryRoot));
dirty = dirtyStatus ~= 0 || strlength(strip(string(dirtyOutput))) > 0;
end

function versionString = packageVersionForClass(className)
classPath = string(which(className));
if strlength(classPath) == 0
    error("EddyTidePseudoTopographicSuiteWorker:MissingClass", "Required class '%s' is not on the MATLAB path.",className)
end
packageRoot = string(fileparts(fileparts(classPath)));
manifestPath = fullfile(packageRoot,"resources","mpackage.json");
if ~isfile(manifestPath)
    error("EddyTidePseudoTopographicSuiteWorker:MissingPackageManifest", "Package manifest not found at '%s'.",manifestPath)
end
manifest = jsondecode(fileread(manifestPath));
versionString = string(manifest.version);
end

function requireMinimumVersion(installedVersion,minimumVersion,packageName)
installed = sscanf(char(installedVersion),"%d.%d.%d");
minimum = sscanf(char(minimumVersion),"%d.%d.%d");
if numel(installed) ~= 3 || numel(minimum) ~= 3
    error("EddyTidePseudoTopographicSuiteWorker:InvalidPackageVersion", "%s versions must use major.minor.patch notation.",packageName)
end
difference = installed(:)-minimum(:);
firstDifference = find(difference ~= 0,1);
if ~isempty(firstDifference) && difference(firstDifference) < 0
    error("EddyTidePseudoTopographicSuiteWorker:PackageTooOld", "%s %s or newer is required; found %s.",packageName,minimumVersion,installedVersion)
end
end

function value = environmentString(name)
value = string(getenv(name));
if strlength(value) == 0
    error("EddyTidePseudoTopographicSuiteWorker:MissingEnvironment", "Required environment variable %s is not set.",name)
end
end

function value = environmentNumber(name,options)
arguments
    name (1,1) string
    options.mustBeInteger (1,1) logical = false
    options.mustBePositive (1,1) logical = false
end
textValue = environmentString(name);
value = str2double(textValue);
if ~isfinite(value) || (options.mustBeInteger && value ~= fix(value)) || (options.mustBePositive && value <= 0)
    error("EddyTidePseudoTopographicSuiteWorker:InvalidEnvironmentNumber", "Environment variable %s has invalid numeric value '%s'.",name,textValue)
end
end

function archiveExistingFailure(failurePath,directory)
if ~isfile(failurePath)
    return
end
timestamp = string(datetime("now","TimeZone","local","Format","yyyyMMdd-HHmmss"));
movefile(failurePath,fullfile(directory,"failed-"+timestamp+".txt"),"f")
end

function writeFailure(path,jobID,stage,exception)
writeMarker(path,[
    "job_id="+jobID
    "stage="+stage
    "failed_at="+localTimestamp()
    "identifier="+string(exception.identifier)
    "message="+replace(string(exception.message),newline," ")
    ])
end

function writeStage(directory,stage)
writeMarker(fullfile(directory,"stage.txt"),[
    "stage="+stage
    "updated_at="+localTimestamp()
    ])
end

function value = markerValue(markerPath,key)
lines = readlines(markerPath);
prefix = key+"=";
matches = startsWith(lines,prefix);
if nnz(matches) ~= 1
    error("EddyTidePseudoTopographicSuiteWorker:InvalidMarker", "Marker '%s' must contain exactly one '%s' entry.",markerPath,key)
end
value = extractAfter(lines(matches),strlength(prefix));
end

function writeMarker(path,lines)
temporaryPath = path+".tmp-"+feature("getpid");
writelines(lines,temporaryPath)
movefile(temporaryPath,path,"f")
end

function timestamp = localTimestamp()
timestamp = string(datetime("now","TimeZone","local","Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
end
