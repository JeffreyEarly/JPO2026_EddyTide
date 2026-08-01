function [figureHandle,flux,diagnosticsFiles] = EddyTidePseudoTopographicDomainFluxComparison(hironEddyFile,hironControlFile,shakespeareEddyFile,shakespeareControlFile,options)
% Compare pseudo-topographic energy input between Hiron and Shakespeare domains.
%
% The temporal panels show exact, depth-integrated, horizontally averaged
% pseudo-topographic pressure work and adaptive-damping work. The spectral
% panels use the controls to isolate domain resonance and convert radial-bin
% power to power per logarithmic wavenumber interval before comparing the
% two domains. No energy series is normalized by the initial eddy.
%
% ```matlab
% [fig,flux,diagnosticsFiles] = EddyTidePseudoTopographicDomainFluxComparison(hironEddyFile,hironControlFile,shakespeareEddyFile,shakespeareControlFile);
% ```
%
% - Topic: Provisional figures
% - Declaration: [figureHandle,flux,diagnosticsFiles] = EddyTidePseudoTopographicDomainFluxComparison(hironEddyFile,hironControlFile,shakespeareEddyFile,shakespeareControlFile,options)
% - Parameter hironEddyFile: Hiron-domain model output initialized with an eddy
% - Parameter hironControlFile: matching Hiron-domain model output without an eddy
% - Parameter shakespeareEddyFile: Shakespeare-domain model output initialized with an eddy
% - Parameter shakespeareControlFile: matching Shakespeare-domain model output without an eddy
% - Parameter options.diagnosticsStride: model-output stride used to create or update diagnostics
% - Parameter options.shouldUpdateDiagnostics: whether missing or stale diagnostics may be created or extended
% - Parameter options.smoothingWindowDays: centered moving-mean width for plotted power histories
% - Parameter options.spectralAveragingWindowDays: final-time window used for the control spectra
% - Parameter options.referenceDensity: density used to convert specific work to energy per horizontal area
% - Parameter options.budgetClosureTolerance: maximum relative exact-energy budget residual
% - Parameter options.figureVisible: figure visibility, `"on"` or `"off"`
% - Parameter options.shouldExport: whether to export the PNG figure
% - Parameter options.exportDirectory: export directory, default beside `hironEddyFile`
% - Parameter options.exportPrefix: PNG filename without extension, default derived from forcing and final day
% - Parameter options.exportResolution: PNG resolution in dots per inch
% - Parameter options.shouldOverwriteExisting: whether an existing PNG may be replaced
% - Returns figureHandle: Hiron-Shakespeare forcing-flux comparison figure
% - Returns flux: raw and plotted flux histories, budgets, spectra, resonance locations, and metrics
% - Returns diagnosticsFiles: paths to all four companion diagnostics files
arguments (Input)
    hironEddyFile (1,1) string {mustBeFile}
    hironControlFile (1,1) string {mustBeFile}
    shakespeareEddyFile (1,1) string {mustBeFile}
    shakespeareControlFile (1,1) string {mustBeFile}
    options.diagnosticsStride (1,1) double {mustBeInteger,mustBePositive} = 4
    options.shouldUpdateDiagnostics (1,1) logical = true
    options.smoothingWindowDays (1,1) double {mustBePositive,mustBeFinite} = 30
    options.spectralAveragingWindowDays (1,1) double {mustBePositive,mustBeFinite} = 100
    options.referenceDensity (1,1) double {mustBePositive,mustBeFinite} = 1025
    options.budgetClosureTolerance (1,1) double {mustBePositive,mustBeFinite} = 0.02
    options.figureVisible (1,1) string {mustBeMember(options.figureVisible,["on" "off"])} = "on"
    options.shouldExport (1,1) logical = true
    options.exportDirectory (1,1) string = ""
    options.exportPrefix (1,1) string = ""
    options.exportResolution (1,1) double {mustBeInteger,mustBePositive} = 300
    options.shouldOverwriteExisting (1,1) logical = false
end
arguments (Output)
    figureHandle matlab.ui.Figure
    flux (1,1) struct
    diagnosticsFiles (1,1) struct
end

requireDiagnosticsVersion("1.0.7")
diagnosticsFiles = struct;
[hironEddy,diagnosticsFiles.hironEddy] = diagnosticsForSimulation(hironEddyFile,options);
[hironControl,diagnosticsFiles.hironControl] = diagnosticsForSimulation(hironControlFile,options);
[shakespeareEddy,diagnosticsFiles.shakespeareEddy] = diagnosticsForSimulation(shakespeareEddyFile,options);
[shakespeareControl,diagnosticsFiles.shakespeareControl] = diagnosticsForSimulation(shakespeareControlFile,options);

validateComparison(hironEddy,hironControl,shakespeareEddy,shakespeareControl,options.budgetClosureTolerance)
hironEddy = addPlotSeries(hironEddy,options);
hironControl = addPlotSeries(hironControl,options);
shakespeareEddy = addPlotSeries(shakespeareEddy,options);
shakespeareControl = addPlotSeries(shakespeareControl,options);

hironSpectrum = controlSpectrum(hironControl,options);
shakespeareSpectrum = controlSpectrum(shakespeareControl,options);
validateSpectralComparison(hironSpectrum,shakespeareSpectrum)

flux = struct;
flux.hiron = struct(eddy=hironEddy,control=hironControl);
flux.shakespeare = struct(eddy=shakespeareEddy,control=shakespeareControl);
flux.spectra = struct(hironControl=hironSpectrum,shakespeareControl=shakespeareSpectrum);
flux.metrics = comparisonMetrics(flux);
flux.referenceDensity = options.referenceDensity;
flux.powerUnits = "mW m^-2";
flux.cumulativeWorkUnits = "kJ m^-2";
flux.spectralUnits = "mW m^-2 per d ln(k)";
flux.smoothingWindowDays = options.smoothingWindowDays;
flux.spectralAveragingWindowDays = options.spectralAveragingWindowDays;
flux.figurePath = "";

[exportDirectory,exportPrefix] = resolvedExportLocation(hironEddyFile,hironEddy,options.exportDirectory,options.exportPrefix);
figurePath = fullfile(exportDirectory,exportPrefix+".png");
if options.shouldExport
    validateExportPath(figurePath,options.shouldOverwriteExisting)
end
figureHandle = createFluxFigure(flux,options.figureVisible);
if options.shouldExport
    exportgraphics(figureHandle,figurePath,Resolution=options.exportResolution)
    flux.figurePath = figurePath;
end
end

function requireDiagnosticsVersion(minimumVersion)
if exist("WVDiagnostics","class") ~= 8
    error("EddyTidePseudoTopographicDomainFluxComparison:WVDiagnosticsNotFound", "WaveVortexModelDiagnostics 1.0.7 or newer is required.")
end
installedVersion = string(WVDiagnostics.version());
if compareVersions(installedVersion,minimumVersion) < 0
    error("EddyTidePseudoTopographicDomainFluxComparison:WVDiagnosticsTooOld", "WaveVortexModelDiagnostics %s is installed, but version %s or newer is required.",installedVersion,minimumVersion)
end
end

function comparison = compareVersions(leftVersion,rightVersion)
left = sscanf(char(leftVersion),"%d.%d.%d");
right = sscanf(char(rightVersion),"%d.%d.%d");
if numel(left) ~= 3 || numel(right) ~= 3
    error("EddyTidePseudoTopographicDomainFluxComparison:InvalidDiagnosticsVersion", "WVDiagnostics versions must use major.minor.patch notation.")
end
difference = left(:)-right(:);
firstDifference = find(difference ~= 0,1);
if isempty(firstDifference)
    comparison = 0;
else
    comparison = sign(difference(firstDifference));
end
end

function [result,diagnosticsFile] = diagnosticsForSimulation(modelFile,options)
diagnostics = WVDiagnostics(char(modelFile));
cleanup = onCleanup(@()diagnostics.close());
updateDiagnostics(diagnostics,options.diagnosticsStride,options.shouldUpdateDiagnostics)
generation = pseudoTopographicGeneration(diagnostics.wvt);

[exactFluxes,time] = diagnostics.exactEnergyFluxesOverTime;
spectralFluxes = diagnostics.exactEnergyFluxes;
[exactEnergy,energyTime] = diagnostics.exactEnergyOverTime;
time = reshape(time,[],1);
energyTime = reshape(energyTime,[],1);
if ~isequal(time,energyTime) || isempty(time) || time(end) ~= diagnostics.t_wv(end)
    error("EddyTidePseudoTopographicDomainFluxComparison:DiagnosticsTimeMismatch", "Exact energy and forcing diagnostics must share a time axis that reaches the final model time.")
end

generationIndex = forcingIndex(exactFluxes,"pseudo_topographic_wave_generation");
dampingIndex = forcingIndex(exactFluxes,"adaptive_damping");
spectralGenerationIndex = forcingIndex(spectralFluxes,"pseudo_topographic_wave_generation");
generationPower = reshape(real(exactFluxes(generationIndex).te),[],1);
dampingPower = reshape(real(exactFluxes(dampingIndex).te),[],1);
allForcingPower = zeros(size(time));
grossForcingWork = 0;
for iFlux = 1:numel(exactFluxes)
    rate = reshape(real(exactFluxes(iFlux).te),[],1);
    if numel(rate) ~= numel(time) || any(~isfinite(rate))
        error("EddyTidePseudoTopographicDomainFluxComparison:InvalidFluxSeries", "Every exact forcing-flux history must be finite and match the diagnostics time axis.")
    end
    exactFluxes(iFlux).te = rate;
    allForcingPower = allForcingPower+rate;
    grossForcingWork = grossForcingWork+trapz(time,abs(rate));
end
exactEnergy = reshape(real(exactEnergy),[],1);
observedEnergyChange = exactEnergy(end)-exactEnergy(1);
integratedForcingWork = trapz(time,allForcingPower);
closureResidual = integratedForcingWork-observedEnergyChange;
closureScale = max([abs(observedEnergyChange) grossForcingWork eps]);
closure = struct(observedEnergyChange=observedEnergyChange,integratedForcingWork=integratedForcingWork, ...
    residual=closureResidual,relativeResidual=abs(closureResidual)/closureScale,grossForcingWork=grossForcingWork);

[verticalMode,kRadial,omega] = diagnostics.diagfile.readVariables("j","kRadial","omega_jk");
result = struct(modelFile=modelFile,diagnosticsFile=string(diagnostics.diagpath),time=time,timeDays=time/86400, ...
    generationPower=generationPower,dampingPower=dampingPower,allForcingPower=allForcingPower, ...
    cumulativeGeneration=cumtrapz(time,generationPower),cumulativeDamping=cumtrapz(time,dampingPower), ...
    cumulativeAllForcing=cumtrapz(time,allForcingPower),exactEnergy=exactEnergy,forcingFluxes=exactFluxes, ...
    generationFluxByMode=real(spectralFluxes(spectralGenerationIndex).te),verticalMode=reshape(verticalMode,[],1), ...
    kRadial=reshape(kRadial,[],1),omega=real(omega),closure=closure,frequency=generation.frequency, ...
    barotropicVelocityAmplitude=generation.barotropicVelocityAmplitude,rampDuration=generation.rampDuration, ...
    startTime=generation.startTime,Lx=diagnostics.wvt.Lx,Ly=diagnostics.wvt.Ly,Lz=diagnostics.wvt.Lz, ...
    Nx=diagnostics.wvt.Nx,Ny=diagnostics.wvt.Ny,Nz=diagnostics.wvt.Nz, ...
    diagnosticsInterval=median(diff(time)));
diagnosticsFile = string(diagnostics.diagpath);
validateSimulationResult(result)
clear cleanup
end

function updateDiagnostics(diagnostics,diagnosticsStride,shouldUpdate)
diagnosticsExists = isfile(diagnostics.diagpath);
if ~diagnosticsExists
    if ~shouldUpdate
        error("EddyTidePseudoTopographicDomainFluxComparison:DiagnosticsNotFound", "The diagnostics file '%s' does not exist and shouldUpdateDiagnostics is false.",diagnostics.diagpath)
    end
    diagnostics.createDiagnosticsFile(stride=diagnosticsStride);
    return
end
diagnosticTime = reshape(diagnostics.t_diag,[],1);
modelTime = reshape(diagnostics.t_wv,[],1);
if isempty(diagnosticTime) || diagnosticTime(end) < modelTime(end)
    if ~shouldUpdate
        error("EddyTidePseudoTopographicDomainFluxComparison:StaleDiagnostics", "The diagnostics file '%s' does not reach the final model time.",diagnostics.diagpath)
    end
    if numel(diagnosticTime) < 2
        error("EddyTidePseudoTopographicDomainFluxComparison:IncompleteDiagnostics", "The existing diagnostics file has fewer than two records and cannot be appended safely.")
    end
    diagnostics.createDiagnosticsFile(stride=diagnosticsStride);
elseif diagnosticTime(end) > modelTime(end)
    error("EddyTidePseudoTopographicDomainFluxComparison:DiagnosticsBeyondModel", "The diagnostics file extends beyond the model output.")
end
end

function generation = pseudoTopographicGeneration(wvt)
matches = false(size(wvt.forcing));
for iForcing = 1:numel(wvt.forcing)
    matches(iForcing) = isa(wvt.forcing(iForcing),"WVPseudoTopographicWaveGeneration");
end
if nnz(matches) ~= 1
    error("EddyTidePseudoTopographicDomainFluxComparison:InvalidPseudoTopographicForcing", "Every model must contain exactly one WVPseudoTopographicWaveGeneration object.")
end
generation = wvt.forcing(matches);
end

function index = forcingIndex(fluxes,name)
indices = find(string({fluxes.name}) == name);
if numel(indices) ~= 1
    error("EddyTidePseudoTopographicDomainFluxComparison:MissingForcingFlux", "Diagnostics must contain exactly one '%s' exact energy flux.",name)
end
index = indices;
end

function validateSimulationResult(result)
series = [result.time result.generationPower result.dampingPower result.allForcingPower result.exactEnergy];
if size(series,1) < 2 || any(~isfinite(series),"all") || any(diff(result.time) <= 0)
    error("EddyTidePseudoTopographicDomainFluxComparison:InvalidSimulationData", "Times, energies, and fluxes must be finite, nonempty, and strictly increasing.")
end
if size(result.generationFluxByMode,3) ~= numel(result.time) || size(result.generationFluxByMode,1) ~= numel(result.verticalMode) || size(result.generationFluxByMode,2) ~= numel(result.kRadial)
    error("EddyTidePseudoTopographicDomainFluxComparison:InvalidSpectralShape", "The generation spectrum must have dimensions [j kRadial t].")
end
spectralPower = reshape(sum(sum(result.generationFluxByMode,1),2),[],1);
tolerance = 1e3*eps(max(1,max(abs(result.generationPower))));
if max(abs(spectralPower-result.generationPower)) > tolerance
    error("EddyTidePseudoTopographicDomainFluxComparison:FluxReductionMismatch", "The forcing-flux time series must equal the sum of its modal spectrum.")
end
end

function validateComparison(hironEddy,hironControl,shakespeareEddy,shakespeareControl,closureTolerance)
cases = {hironEddy,hironControl,shakespeareEddy,shakespeareControl};
referenceTime = hironEddy.time;
for iCase = 1:numel(cases)
    value = cases{iCase};
    if ~isequal(value.time,referenceTime)
        error("EddyTidePseudoTopographicDomainFluxComparison:TimeMismatch", "All four diagnostics files must use identical saved times.")
    end
    if value.closure.relativeResidual > closureTolerance
        error("EddyTidePseudoTopographicDomainFluxComparison:BudgetClosureFailure", "The exact-energy budget for '%s' has relative residual %.4g, exceeding %.4g.",value.modelFile,value.closure.relativeResidual,closureTolerance)
    end
    dampingTolerance = 1e3*eps(max([1 abs(value.cumulativeGeneration(end))]));
    if value.cumulativeDamping(end) > dampingTolerance
        error("EddyTidePseudoTopographicDomainFluxComparison:PositiveCumulativeDamping", "Cumulative adaptive-damping work must be non-positive within numerical tolerance.")
    end
end
validatePair(hironEddy,hironControl,"Hiron")
validatePair(shakespeareEddy,shakespeareControl,"Shakespeare")
if hironEddy.Lx <= shakespeareEddy.Lx
    error("EddyTidePseudoTopographicDomainFluxComparison:DomainOrder", "The Hiron domain must be wider than the Shakespeare domain.")
end
validateSameForcing(hironEddy,shakespeareEddy)
end

function validatePair(eddy,control,pairName)
geometry = [eddy.Lx eddy.Ly eddy.Lz eddy.Nx eddy.Ny eddy.Nz];
controlGeometry = [control.Lx control.Ly control.Lz control.Nx control.Ny control.Nz];
if ~isequal(geometry,controlGeometry)
    error("EddyTidePseudoTopographicDomainFluxComparison:PairGeometryMismatch", "%s eddy and control geometry must match exactly.",pairName)
end
validateSameForcing(eddy,control)
end

function validateSameForcing(left,right)
scale = max([1 abs(left.frequency) abs(right.frequency)]);
if abs(left.frequency-right.frequency) > 1e3*eps(scale) || ...
        ~isequal(left.barotropicVelocityAmplitude,right.barotropicVelocityAmplitude) || ...
        left.rampDuration ~= right.rampDuration || left.startTime ~= right.startTime || ...
        left.Nx ~= right.Nx || left.Ny ~= right.Ny
    error("EddyTidePseudoTopographicDomainFluxComparison:ForcingMismatch", "Frequency, current amplitude, ramp, start time, and horizontal resolution must match across compared simulations.")
end
end

function result = addPlotSeries(result,options)
timeStep = median(diff(result.time));
windowRecords = max(1,round(options.smoothingWindowDays*86400/timeStep));
if mod(windowRecords,2) == 0
    windowRecords = windowRecords+1;
end
result.smoothedGenerationPower = movmean(result.generationPower,windowRecords,Endpoints="shrink");
result.smoothedDampingPower = movmean(result.dampingPower,windowRecords,Endpoints="shrink");
result.powerMilliwattsPerSquareMeter = options.referenceDensity*1e3*result.generationPower;
result.smoothedPowerMilliwattsPerSquareMeter = options.referenceDensity*1e3*result.smoothedGenerationPower;
result.cumulativeGenerationKilojoulesPerSquareMeter = options.referenceDensity*result.cumulativeGeneration/1e3;
result.cumulativeDampingKilojoulesPerSquareMeter = options.referenceDensity*result.cumulativeDamping/1e3;
result.finalNetWorkKilojoulesPerSquareMeter = options.referenceDensity*(result.cumulativeGeneration(end)+result.cumulativeDamping(end))/1e3;
result.smoothingWindowRecords = windowRecords;
end

function spectrum = controlSpectrum(control,options)
windowStart = max(control.time(1),control.time(end)-options.spectralAveragingWindowDays*86400);
timeIndices = find(control.time >= windowStart);
rawPerBin = mean(control.generationFluxByMode(:,:,timeIndices),3);
[positiveIndices,deltaLogK] = logarithmicBinWidths(control.kRadial);
zeroPower = sum(rawPerBin(:,setdiff(1:numel(control.kRadial),positiveIndices)),"all");
totalPower = mean(control.generationPower(timeIndices));
zeroTolerance = 1e3*eps(max(1,abs(totalPower)));
if abs(zeroPower) > zeroTolerance
    error("EddyTidePseudoTopographicDomainFluxComparison:NonzeroZeroWavenumberFlux", "Non-positive radial-wavenumber bins contain non-negligible generation work.")
end
rawPositive = rawPerBin(:,positiveIndices);
powerPerLogK = rawPositive./reshape(deltaLogK,1,[]);
integratedPower = sum(powerPerLogK.*reshape(deltaLogK,1,[]),"all");
integrationTolerance = 1e3*eps(max(1,abs(totalPower)));
if abs(integratedPower-totalPower) > integrationTolerance
    error("EddyTidePseudoTopographicDomainFluxComparison:SpectralIntegrationMismatch", "The logarithmic-wavenumber spectrum must integrate to the final-window mean generation power.")
end
k = control.kRadial(positiveIndices);
omega = control.omega(:,positiveIndices);
spectrum = struct(timeIndices=timeIndices,timeWindowDays=[control.time(timeIndices(1)) control.time(timeIndices(end))]/86400, ...
    verticalMode=control.verticalMode,kRadial=k,horizontalWavelength=2*pi./k,omega=omega, ...
    rawPowerPerBin=rawPositive,deltaLogK=deltaLogK,powerPerLogK=powerPerLogK, ...
    powerPerLogKMilliwattsPerSquareMeter=options.referenceDensity*1e3*powerPerLogK, ...
    integratedPower=integratedPower,meanTimeSeriesPower=totalPower,zeroWavenumberPower=zeroPower, ...
    resonanceWavelength=resonanceWavelength(k,omega,control.frequency),frequency=control.frequency);
end

function [positiveIndices,deltaLogK] = logarithmicBinWidths(kRadial)
kRadial = reshape(kRadial,[],1);
positiveIndices = find(kRadial > 0 & isfinite(kRadial));
if numel(positiveIndices) < 2 || any(diff(kRadial(positiveIndices)) <= 0)
    error("EddyTidePseudoTopographicDomainFluxComparison:InvalidRadialAxis", "The radial-wavenumber axis must contain at least two strictly increasing positive values.")
end
lowerEdge = zeros(size(positiveIndices));
upperEdge = zeros(size(positiveIndices));
for iBin = 1:numel(positiveIndices)
    index = positiveIndices(iBin);
    if index > 1
        lowerEdge(iBin) = (kRadial(index-1)+kRadial(index))/2;
    else
        lowerEdge(iBin) = kRadial(index)/2;
    end
    if index < numel(kRadial)
        upperEdge(iBin) = (kRadial(index)+kRadial(index+1))/2;
    else
        upperEdge(iBin) = kRadial(index)+(kRadial(index)-kRadial(index-1))/2;
    end
end
if any(lowerEdge <= 0) || any(upperEdge <= lowerEdge)
    error("EddyTidePseudoTopographicDomainFluxComparison:InvalidRadialBinEdges", "Radial-bin edges must be finite, positive, and ordered.")
end
deltaLogK = log(upperEdge./lowerEdge);
end

function wavelength = resonanceWavelength(kRadial,omega,frequency)
wavelength = NaN(size(omega,1),1);
for iMode = 1:size(omega,1)
    valid = isfinite(omega(iMode,:)) & isfinite(kRadial.') & omega(iMode,:) > 0;
    modeOmega = omega(iMode,valid);
    modeK = kRadial(valid);
    [modeOmega,uniqueIndices] = unique(modeOmega,"sorted");
    modeK = modeK(uniqueIndices);
    if numel(modeOmega) >= 2 && frequency >= modeOmega(1) && frequency <= modeOmega(end)
        resonantK = interp1(modeOmega,modeK,frequency,"linear");
        wavelength(iMode) = 2*pi/resonantK;
    end
end
end

function validateSpectralComparison(hironSpectrum,shakespeareSpectrum)
values = [hironSpectrum.powerPerLogK(:); shakespeareSpectrum.powerPerLogK(:); ...
    hironSpectrum.resonanceWavelength(:); shakespeareSpectrum.resonanceWavelength(:)];
if any(~isfinite(values(~isnan(values))))
    error("EddyTidePseudoTopographicDomainFluxComparison:NonfiniteSpectrum", "Spectral power and finite resonance locations must contain finite values.")
end
end

function metrics = comparisonMetrics(flux)
metrics = struct;
for initialCondition = ["eddy" "control"]
    hiron = flux.hiron.(initialCondition);
    shakespeare = flux.shakespeare.(initialCondition);
    metrics.(initialCondition) = struct( ...
        hironCumulativeGeneration=hiron.cumulativeGeneration(end), ...
        shakespeareCumulativeGeneration=shakespeare.cumulativeGeneration(end), ...
        cumulativeGenerationRatio=hiron.cumulativeGeneration(end)/shakespeare.cumulativeGeneration(end), ...
        hironCumulativeDamping=hiron.cumulativeDamping(end), ...
        shakespeareCumulativeDamping=shakespeare.cumulativeDamping(end), ...
        hironDampedFraction=-hiron.cumulativeDamping(end)/hiron.cumulativeGeneration(end), ...
        shakespeareDampedFraction=-shakespeare.cumulativeDamping(end)/shakespeare.cumulativeGeneration(end));
end
end

function figureHandle = createFluxFigure(flux,visibility)
figureHandle = figure(Name="Hiron-Shakespeare forcing-flux comparison",Color="w",Visible=visibility,Position=[100 100 1120 1020]);
layout = tiledlayout(figureHandle,3,2,TileSpacing="compact",Padding="compact");
colors = struct(hiron=[0 0.4470 0.7410],shakespeare=[0.8500 0.3250 0.0980]);

powerAxes = nexttile(layout,1,[1 2]);
plotPowerHistory(powerAxes,flux,colors)
title(powerAxes,"(a) Exact pseudo-topographic pressure work")
ylabel(powerAxes,"generation power (mW m^{-2})")
powerAxes.XTickLabel = [];

workAxes = nexttile(layout,3,[1 2]);
plotCumulativeWork(workAxes,flux,colors)
title(workAxes,"(b) Cumulative generation and adaptive-damping work")
xlabel(workAxes,"Time (days)")
ylabel(workAxes,"cumulative work (kJ m^{-2})")

hironAxes = nexttile(layout,5);
shakespeareAxes = nexttile(layout,6);
[colorScale,colorTicks,colorTickLabels] = plotSpectra(hironAxes,shakespeareAxes,flux.spectra);
title(hironAxes,compose("(c) Hiron control, days %.0f-%.0f",flux.spectra.hironControl.timeWindowDays))
title(shakespeareAxes,compose("(d) Shakespeare control, days %.0f-%.0f",flux.spectra.shakespeareControl.timeWindowDays))
ylabel(hironAxes,"vertical mode j")
xlabel(hironAxes,"horizontal wavelength (km)")
xlabel(shakespeareAxes,"horizontal wavelength (km)")
shakespeareAxes.YTickLabel = [];
colorbarHandle = colorbar(shakespeareAxes);
colorbarHandle.Ticks = colorTicks;
colorbarHandle.TickLabels = colorTickLabels;
colorbarHandle.Label.String = "generation dP/dln(k) (mW m^{-2})";
clim(hironAxes,colorScale)
clim(shakespeareAxes,colorScale)
colormap(figureHandle,divergingColormap(257))
end

function plotPowerHistory(axesHandle,flux,colors)
hold(axesHandle,"on")
plotPowerCase(axesHandle,flux.hiron.eddy,colors.hiron,"-",false);
plotPowerCase(axesHandle,flux.hiron.control,colors.hiron,"--",false);
plotPowerCase(axesHandle,flux.shakespeare.eddy,colors.shakespeare,"-",false);
plotPowerCase(axesHandle,flux.shakespeare.control,colors.shakespeare,"--",false);
handles = gobjects(4,1);
handles(1) = plotPowerCase(axesHandle,flux.hiron.eddy,colors.hiron,"-",true);
handles(2) = plotPowerCase(axesHandle,flux.hiron.control,colors.hiron,"--",true);
handles(3) = plotPowerCase(axesHandle,flux.shakespeare.eddy,colors.shakespeare,"-",true);
handles(4) = plotPowerCase(axesHandle,flux.shakespeare.control,colors.shakespeare,"--",true);
hold(axesHandle,"off")
xlim(axesHandle,[flux.hiron.eddy.timeDays(1) flux.hiron.eddy.timeDays(end)])
yline(axesHandle,0,Color=0.7*[1 1 1],HandleVisibility="off")
legend(axesHandle,handles,{"Hiron eddy","Hiron control","Shakespeare eddy","Shakespeare control"},Location="northwest",NumColumns=2)
box(axesHandle,"on")
end

function handle = plotPowerCase(axesHandle,value,color,lineStyle,isSmoothed)
if isSmoothed
    series = value.smoothedPowerMilliwattsPerSquareMeter;
    handle = plot(axesHandle,value.timeDays,series,Color=color,LineStyle=lineStyle,LineWidth=2);
else
    series = value.powerMilliwattsPerSquareMeter;
    lightColor = 0.72*[1 1 1]+0.28*color;
    handle = plot(axesHandle,value.timeDays,series,Color=lightColor,LineStyle=lineStyle,LineWidth=0.6,HandleVisibility="off");
end
end

function plotCumulativeWork(axesHandle,flux,colors)
hold(axesHandle,"on")
plotWorkCase(axesHandle,flux.hiron.eddy,colors.hiron,"-")
plotWorkCase(axesHandle,flux.hiron.control,colors.hiron,"--")
plotWorkCase(axesHandle,flux.shakespeare.eddy,colors.shakespeare,"-")
plotWorkCase(axesHandle,flux.shakespeare.control,colors.shakespeare,"--")
hold(axesHandle,"off")
yline(axesHandle,0,Color=0.7*[1 1 1],HandleVisibility="off")
xlim(axesHandle,[flux.hiron.eddy.timeDays(1) flux.hiron.eddy.timeDays(end)])
box(axesHandle,"on")
text(axesHandle,0.01,0.94,"positive: generation; negative: adaptive damping; diamonds: net",Units="normalized",VerticalAlignment="top",Color=0.25*[1 1 1])
end

function plotWorkCase(axesHandle,value,color,lineStyle)
plot(axesHandle,value.timeDays,value.cumulativeGenerationKilojoulesPerSquareMeter,Color=color,LineStyle=lineStyle,LineWidth=2,HandleVisibility="off")
plot(axesHandle,value.timeDays,value.cumulativeDampingKilojoulesPerSquareMeter,Color=color,LineStyle=lineStyle,LineWidth=1.4,HandleVisibility="off")
plot(axesHandle,value.timeDays(end),value.finalNetWorkKilojoulesPerSquareMeter,Marker="d",MarkerSize=7,MarkerFaceColor=color,MarkerEdgeColor=color,HandleVisibility="off")
end

function [colorScale,colorTicks,colorTickLabels] = plotSpectra(hironAxes,shakespeareAxes,spectra)
hironValues = spectra.hironControl.powerPerLogKMilliwattsPerSquareMeter;
shakespeareValues = spectra.shakespeareControl.powerPerLogKMilliwattsPerSquareMeter;
maximumMagnitude = max(abs([hironValues(:); shakespeareValues(:)]));
if ~isfinite(maximumMagnitude) || maximumMagnitude <= 0
    error("EddyTidePseudoTopographicDomainFluxComparison:EmptySpectrum", "At least one control generation spectrum must contain nonzero finite power.")
end
transition = maximumMagnitude*1e-3;
transformedHiron = asinh(hironValues/transition);
transformedShakespeare = asinh(shakespeareValues/transition);
limit = max(abs([transformedHiron(:); transformedShakespeare(:)]));
colorScale = [-limit limit];
[colorTicks,colorTickLabels] = signedLogTicks(maximumMagnitude,transition);

allWavelengths = [spectra.hironControl.horizontalWavelength; spectra.shakespeareControl.horizontalWavelength]/1e3;
allModes = [spectra.hironControl.verticalMode; spectra.shakespeareControl.verticalMode];
plotSpectrum(hironAxes,spectra.hironControl,transformedHiron)
plotSpectrum(shakespeareAxes,spectra.shakespeareControl,transformedShakespeare)
for axesHandle = [hironAxes shakespeareAxes]
    set(axesHandle,XScale="log",XDir="reverse",YDir="normal")
    xlim(axesHandle,[min(allWavelengths) max(allWavelengths)])
    ylim(axesHandle,[min(allModes)-0.5 max(allModes)+0.5])
    box(axesHandle,"on")
end
end

function plotSpectrum(axesHandle,spectrum,transformedValues)
wavelength = spectrum.horizontalWavelength/1e3;
[X,Y] = meshgrid(wavelength,spectrum.verticalMode);
surface(axesHandle,X,Y,zeros(size(transformedValues)),transformedValues,EdgeColor="none",FaceColor="flat")
view(axesHandle,2)
hold(axesHandle,"on")
valid = isfinite(spectrum.resonanceWavelength);
plot(axesHandle,spectrum.resonanceWavelength(valid)/1e3,spectrum.verticalMode(valid),"k-o",LineWidth=1.4,MarkerSize=3,MarkerFaceColor="w")
hold(axesHandle,"off")
end

function [ticks,labels] = signedLogTicks(maximumMagnitude,transition)
minimumExponent = floor(log10(transition));
maximumExponent = ceil(log10(maximumMagnitude));
positiveValues = 10.^(minimumExponent:maximumExponent);
positiveValues = positiveValues(positiveValues <= 1.05*maximumMagnitude & positiveValues >= transition);
if isempty(positiveValues)
    positiveValues = maximumMagnitude;
end
ticks = [-fliplr(asinh(positiveValues/transition)) 0 asinh(positiveValues/transition)];
negativeLabels = "-"+compose("%.1g",fliplr(positiveValues));
positiveLabels = compose("%.1g",positiveValues);
labels = [negativeLabels "0" positiveLabels];
end

function map = divergingColormap(numberOfColors)
anchors = [0.230 0.299 0.754; 0.706 0.016 0.150];
half = floor(numberOfColors/2);
left = [linspace(anchors(1,1),1,half+1).' linspace(anchors(1,2),1,half+1).' linspace(anchors(1,3),1,half+1).'];
rightCount = numberOfColors-half;
right = [linspace(1,anchors(2,1),rightCount).' linspace(1,anchors(2,2),rightCount).' linspace(1,anchors(2,3),rightCount).'];
map = [left(1:end-1,:); right];
end

function [exportDirectory,exportPrefix] = resolvedExportLocation(modelFile,simulation,exportDirectory,exportPrefix)
if strlength(exportDirectory) == 0
    exportDirectory = string(fileparts(modelFile));
end
if strlength(exportPrefix) == 0
    exportPrefix = "eddy-tide-pseudo-topographic-"+forcingLabel(simulation.barotropicVelocityAmplitude)+ ...
        "-domain-flux-comparison-day"+replace(compose("%.15g",simulation.timeDays(end)),".","p");
end
end

function label = forcingLabel(amplitude)
speed = norm(amplitude);
reference = [0.05/sqrt(10) 0.05/sqrt(40) 0.05/sqrt(160)];
labels = ["strong" "moderate" "weak"];
[difference,index] = min(abs(reference-speed));
if difference <= 1e3*eps(max([1 speed reference(index)]))
    label = labels(index);
else
    label = "custom";
end
end

function validateExportPath(path,shouldOverwriteExisting)
directory = fileparts(path);
if strlength(directory) > 0 && ~isfolder(directory)
    mkdir(directory)
end
if isfile(path) && ~shouldOverwriteExisting
    error("EddyTidePseudoTopographicDomainFluxComparison:ExportFileExists", "The figure '%s' already exists. Set shouldOverwriteExisting=true to replace it.",path)
end
end
