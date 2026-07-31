function [figureHandle,energy,diagnosticsFile] = EddyTidePseudoTopographicEnergyDiagnostics(modelFile,options)
% Plot wave and geostrophic energy using WaveVortexModelDiagnostics.
%
% Missing diagnostics are created and stale diagnostics are extended by
% default. The figure follows the normalized-energy panel of manuscript
% Figure 4: total quadratic energy, internal-gravity-wave energy,
% geostrophic energy, geostrophic kinetic energy, and geostrophic potential
% energy are normalized by the initial total quadratic energy. Set
% `energyScale="absolute"` for a zero-energy control calculation. The returned
% `energy.wave` remains the combined internal-gravity-wave and
% inertial-oscillation reservoir $$E_w+E_{io}$$. A second panel shows the
% domain-maximum horizontal wave speed at every saved model time, regardless
% of the diagnostics stride. The simulation writer must be closed before
% calling this function.
%
% ```matlab
% [fig,energy,diagnosticsFile] = EddyTidePseudoTopographicEnergyDiagnostics(modelFile);
% ```
%
% - Topic: Provisional figures
% - Declaration: [figureHandle,energy,diagnosticsFile] = EddyTidePseudoTopographicEnergyDiagnostics(modelFile,options)
% - Parameter modelFile: restartable pseudo-topographic WVModel NetCDF output path
% - Parameter options.diagnosticsFile: diagnostics path, default standard companion filename
% - Parameter options.diagnosticsStride: model-output stride used to create new diagnostics
% - Parameter options.shouldUpdateDiagnostics: whether missing or stale diagnostics may be created or extended
% - Parameter options.energyScale: `"normalized"` for Figure-4 scaling or `"absolute"` for SI energy units
% - Parameter options.figureVisible: figure visibility, `"on"` or `"off"`
% - Parameter options.shouldExport: whether to export the provisional PNG figure
% - Parameter options.exportDirectory: export directory, default beside `modelFile`
% - Parameter options.exportPrefix: export filename prefix, default model filename
% - Parameter options.exportResolution: PNG resolution in dots per inch
% - Parameter options.shouldOverwriteExisting: whether an existing PNG file may be replaced
% - Returns figureHandle: normalized energy-evolution figure
% - Returns energy: time, raw and normalized reservoirs, quadratic total, and exact total energy
% - Returns diagnosticsFile: diagnostics NetCDF path
arguments (Input)
    modelFile (1,1) string {mustBeFile}
    options.diagnosticsFile (1,1) string = ""
    options.diagnosticsStride (1,1) double {mustBeInteger,mustBePositive} = 1
    options.shouldUpdateDiagnostics (1,1) logical = true
    options.energyScale (1,1) string {mustBeMember(options.energyScale,["normalized" "absolute"])} = "normalized"
    options.figureVisible (1,1) string {mustBeMember(options.figureVisible,["on" "off"])} = "on"
    options.shouldExport (1,1) logical = true
    options.exportDirectory (1,1) string = ""
    options.exportPrefix (1,1) string = ""
    options.exportResolution (1,1) double {mustBeInteger,mustBePositive} = 300
    options.shouldOverwriteExisting (1,1) logical = false
end
arguments (Output)
    figureHandle matlab.ui.Figure
    energy (1,1) struct
    diagnosticsFile (1,1) string
end

requireDiagnosticsVersion("1.0.7")
[exportDirectory,exportPrefix] = resolvedExportLocation(modelFile,options.exportDirectory,options.exportPrefix);
figurePath = fullfile(exportDirectory,exportPrefix+"-diagnostic-energy.png");
if options.shouldExport
    validateExportPath(figurePath,options.shouldOverwriteExisting)
end

if strlength(options.diagnosticsFile) == 0
    diagnostics = WVDiagnostics(char(modelFile));
else
    diagnostics = WVDiagnostics(char(modelFile),diagnosticsFilePath=char(options.diagnosticsFile));
end
diagnosticsCleanup = onCleanup(@()diagnostics.close());
diagnosticsFile = string(diagnostics.diagpath);
validatePseudoTopographicForcing(diagnostics.wvt)
updateDiagnostics(diagnostics,options.diagnosticsStride,options.shouldUpdateDiagnostics)

reservoirNames = [EnergyReservoir.igw EnergyReservoir.io EnergyReservoir.wave ...
    EnergyReservoir.geostrophic EnergyReservoir.geostrophic_kinetic ...
    EnergyReservoir.geostrophic_potential EnergyReservoir.total];
[reservoirs,time] = diagnostics.quadraticEnergyOverTime(energyReservoirs=reservoirNames);
[exactTotal,exactTime] = diagnostics.exactEnergyOverTime;
[waveSpeedTime,maximumHorizontalWaveSpeed] = maximumHorizontalWaveSpeedOverTime(diagnostics);
time = reshape(time,[],1);
exactTime = reshape(exactTime,[],1);
if ~isequal(time,exactTime)
    error("EddyTidePseudoTopographicEnergyDiagnostics:DiagnosticsTimeMismatch", "Quadratic and exact energy diagnostics must use identical saved times.")
end
if isempty(time) || time(end) ~= diagnostics.t_wv(end)
    error("EddyTidePseudoTopographicEnergyDiagnostics:StaleDiagnostics", "Diagnostics must extend through the final model-output time.")
end

energy = struct(time=time,timeDays=time/86400,internalGravityWave=reshape(reservoirs(1).energy,[],1), ...
    inertialOscillation=reshape(reservoirs(2).energy,[],1),wave=reshape(reservoirs(3).energy,[],1), ...
    geostrophic=reshape(reservoirs(4).energy,[],1), ...
    geostrophicKinetic=reshape(reservoirs(5).energy,[],1), ...
    geostrophicPotential=reshape(reservoirs(6).energy,[],1), ...
    quadraticTotal=reshape(reservoirs(7).energy,[],1),exactTotal=reshape(exactTotal,[],1), ...
    units="m^3 s^{-2}",waveDefinition="E_w + E_io",internalGravityWaveDefinition="E_w", ...
    normalizationDefinition="initial quadratic total energy",energyScale=options.energyScale,waveSpeedTime=waveSpeedTime, ...
    waveSpeedTimeDays=waveSpeedTime/86400,maximumHorizontalWaveSpeed=maximumHorizontalWaveSpeed, ...
    waveSpeedUnits="m s^-1",figurePath="");
if options.energyScale == "normalized"
    energy.normalization = energy.quadraticTotal(1);
    energy.normalized = normalizedEnergy(energy);
else
    energy.normalization = NaN;
    energy.normalized = struct;
end
validateEnergy(energy)

figureHandle = createEnergyFigure(energy,options.figureVisible);
if options.shouldExport
    exportgraphics(figureHandle,figurePath,Resolution=options.exportResolution)
    energy.figurePath = figurePath;
end
clear diagnosticsCleanup
end

function requireDiagnosticsVersion(minimumVersion)
if exist("WVDiagnostics","class") ~= 8 || exist("EnergyReservoir","class") ~= 8
    error("EddyTidePseudoTopographicEnergyDiagnostics:WVDiagnosticsNotFound", "WaveVortexModelDiagnostics 1.0.7 or newer is required.")
end
installedVersion = string(WVDiagnostics.version());
if compareVersions(installedVersion,minimumVersion) < 0
    error("EddyTidePseudoTopographicEnergyDiagnostics:WVDiagnosticsTooOld", "WaveVortexModelDiagnostics %s is installed, but version %s or newer is required.",installedVersion,minimumVersion)
end
end

function comparison = compareVersions(leftVersion,rightVersion)
left = sscanf(char(leftVersion),"%d.%d.%d");
right = sscanf(char(rightVersion),"%d.%d.%d");
if numel(left) ~= 3 || numel(right) ~= 3
    error("EddyTidePseudoTopographicEnergyDiagnostics:InvalidDiagnosticsVersion", "WVDiagnostics versions must use major.minor.patch notation.")
end
difference = left(:)-right(:);
firstDifference = find(difference ~= 0,1);
if isempty(firstDifference)
    comparison = 0;
else
    comparison = sign(difference(firstDifference));
end
end

function updateDiagnostics(diagnostics,diagnosticsStride,shouldUpdate)
diagnosticsExists = isfile(diagnostics.diagpath);
if ~diagnosticsExists
    if ~shouldUpdate
        error("EddyTidePseudoTopographicEnergyDiagnostics:DiagnosticsNotFound", "The diagnostics file '%s' does not exist and shouldUpdateDiagnostics is false.",diagnostics.diagpath)
    end
    diagnostics.createDiagnosticsFile(stride=diagnosticsStride);
    return
end

diagnosticTime = reshape(diagnostics.t_diag,[],1);
modelTime = reshape(diagnostics.t_wv,[],1);
if isempty(diagnosticTime) || diagnosticTime(end) < modelTime(end)
    if ~shouldUpdate
        error("EddyTidePseudoTopographicEnergyDiagnostics:StaleDiagnostics", "The diagnostics file '%s' does not reach the final model time and shouldUpdateDiagnostics is false.",diagnostics.diagpath)
    end
    if numel(diagnosticTime) < 2
        error("EddyTidePseudoTopographicEnergyDiagnostics:IncompleteDiagnostics", "The existing diagnostics file '%s' has fewer than two records and cannot be appended safely.",diagnostics.diagpath)
    end
    diagnostics.createDiagnosticsFile(stride=diagnosticsStride);
elseif diagnosticTime(end) > modelTime(end)
    error("EddyTidePseudoTopographicEnergyDiagnostics:DiagnosticsBeyondModel", "The diagnostics file extends beyond the model output.")
end
end

function validatePseudoTopographicForcing(wvt)
numberOfGenerators = 0;
for iForcing = 1:numel(wvt.forcing)
    candidate = wvt.forcing(iForcing);
    if isa(candidate,"WVPseudoTopographicWaveGeneration")
        numberOfGenerators = numberOfGenerators+1;
        generation = candidate;
    end
end
if numberOfGenerators ~= 1
    error("EddyTidePseudoTopographicEnergyDiagnostics:InvalidPseudoTopographicForcing", "The model must contain exactly one WVPseudoTopographicWaveGeneration object.")
end
if ~isfinite(generation.frequency) || generation.frequency <= 0 || ...
        any(~isfinite(generation.barotropicVelocityAmplitude),"all") || ...
        any(~isfinite(generation.topographicHeight),"all")
    error("EddyTidePseudoTopographicEnergyDiagnostics:InvalidForcingMetadata", "The pseudo-topographic terrain, frequency, and velocity amplitude must be finite, with positive frequency.")
end
end

function validateEnergy(energy)
numberOfTimes = numel(energy.time);
series = [energy.internalGravityWave energy.inertialOscillation energy.wave ...
    energy.geostrophic energy.geostrophicKinetic energy.geostrophicPotential ...
    energy.quadraticTotal energy.exactTotal];
if size(series,1) ~= numberOfTimes || any(~isfinite([energy.time; series(:)]))
    error("EddyTidePseudoTopographicEnergyDiagnostics:NonfiniteEnergy", "All energy series must match the time axis and contain finite values.")
end
if any(diff(energy.time) <= 0)
    error("EddyTidePseudoTopographicEnergyDiagnostics:InvalidSavedTimes", "Diagnostics times must be strictly increasing.")
end
tolerance = 100*eps(max(1,max(abs(energy.geostrophic))));
if any(abs(energy.geostrophic-energy.geostrophicKinetic-energy.geostrophicPotential) > tolerance)
    error("EddyTidePseudoTopographicEnergyDiagnostics:GeostrophicPartitionMismatch", "Geostrophic energy must equal geostrophic kinetic plus geostrophic potential energy.")
end
waveTolerance = 100*eps(max(1,max(abs(energy.wave))));
if any(abs(energy.wave-energy.internalGravityWave-energy.inertialOscillation) > waveTolerance)
    error("EddyTidePseudoTopographicEnergyDiagnostics:WavePartitionMismatch", "Combined wave energy must equal internal-gravity-wave plus inertial-oscillation energy.")
end
if energy.energyScale == "normalized"
    if ~isfinite(energy.normalization) || energy.normalization <= 0
        error("EddyTidePseudoTopographicEnergyDiagnostics:InvalidNormalization", "The initial total quadratic energy must be finite and positive.")
    end
    normalizedSeries = [energy.normalized.quadraticTotal energy.normalized.internalGravityWave ...
        energy.normalized.geostrophic energy.normalized.geostrophicKinetic ...
        energy.normalized.geostrophicPotential];
    if any(~isfinite(normalizedSeries),"all") || abs(energy.normalized.quadraticTotal(1)-1) > 100*eps
        error("EddyTidePseudoTopographicEnergyDiagnostics:InvalidNormalizedEnergy", "Normalized energy series must be finite and the initial normalized total must equal one.")
    end
end
if numel(energy.waveSpeedTime) ~= numel(energy.maximumHorizontalWaveSpeed) || ...
        isempty(energy.waveSpeedTime) || any(~isfinite([energy.waveSpeedTime; energy.maximumHorizontalWaveSpeed]))
    error("EddyTidePseudoTopographicEnergyDiagnostics:InvalidWaveSpeed", "The wave-speed history must match the model time axis and contain finite values.")
end
if any(diff(energy.waveSpeedTime) <= 0) || any(energy.maximumHorizontalWaveSpeed < 0)
    error("EddyTidePseudoTopographicEnergyDiagnostics:InvalidWaveSpeed", "Wave-speed times must increase strictly and maximum speeds must be nonnegative.")
end
if energy.waveSpeedTime(1) ~= energy.time(1) || energy.waveSpeedTime(end) ~= energy.time(end)
    error("EddyTidePseudoTopographicEnergyDiagnostics:WaveSpeedTimeMismatch", "Wave-speed and energy histories must have identical start and end times.")
end
end

function [time,maximumHorizontalWaveSpeed] = maximumHorizontalWaveSpeedOverTime(diagnostics)
time = reshape(diagnostics.t_wv,[],1);
if isempty(time) || any(~isfinite(time)) || any(diff(time) <= 0)
    error("EddyTidePseudoTopographicEnergyDiagnostics:InvalidModelTimes", "Saved model times must be finite and strictly increasing.")
end

originalTimeIndex = diagnostics.iTime;
timeCleanup = onCleanup(@()restoreDiagnosticsTimeIndex(diagnostics,originalTimeIndex));
maximumHorizontalWaveSpeed = zeros(size(time));
for iTime = 1:numel(time)
    diagnostics.iTime = iTime;
    wvt = diagnostics.wvt;
    waveU = wvt.transformToSpatialDomainWithF(Apm=wvt.UAp.*wvt.Apt+wvt.UAm.*wvt.Amt);
    waveV = wvt.transformToSpatialDomainWithF(Apm=wvt.VAp.*wvt.Apt+wvt.VAm.*wvt.Amt);
    maximumHorizontalWaveSpeed(iTime) = max(hypot(waveU,waveV),[],"all");
end
diagnostics.iTime = originalTimeIndex;
clear timeCleanup
end

function restoreDiagnosticsTimeIndex(diagnostics,iTime)
diagnostics.iTime = iTime;
end

function normalized = normalizedEnergy(energy)
normalization = energy.quadraticTotal(1);
normalized = struct(quadraticTotal=energy.quadraticTotal/normalization, ...
    internalGravityWave=energy.internalGravityWave/normalization, ...
    geostrophic=energy.geostrophic/normalization, ...
    geostrophicKinetic=energy.geostrophicKinetic/normalization, ...
    geostrophicPotential=energy.geostrophicPotential/normalization);
end

function figureHandle = createEnergyFigure(energy,visibility)
figureHandle = figure(Name="Pseudo-topographic energy diagnostics",Color="w",Visible=visibility,Position=[100 100 900 850]);
layout = tiledlayout(figureHandle,2,1,TileSpacing="compact",Padding="compact");
energyAxes = nexttile(layout,1);
colors = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250; 0.4940 0.1840 0.5560; 0.4660 0.6740 0.1880];
if energy.energyScale == "normalized"
    series = [energy.normalized.quadraticTotal energy.normalized.internalGravityWave ...
        energy.normalized.geostrophic energy.normalized.geostrophicKinetic ...
        energy.normalized.geostrophicPotential];
    energyLabel = "Normalized Energy";
else
    series = [energy.quadraticTotal energy.internalGravityWave energy.geostrophic ...
        energy.geostrophicKinetic energy.geostrophicPotential];
    energyLabel = "Energy (m^3 s^{-2})";
end
lineHandles = plot(energyAxes,energy.timeDays,series,LineWidth=2);
for iLine = 1:numel(lineHandles)
    lineHandles(iLine).Color = colors(iLine,:);
end
xlim(energyAxes,timeLimits(energy.timeDays))
ylim(energyAxes,energyLimits(series,energy.energyScale))
ylabel(energyAxes,energyLabel)
energyAxes.XTickLabel = [];
legend(energyAxes,lineHandles,{"Total Energy $\mathcal{E}$","Wave Energy $\mathcal{E}_w$", ...
    "Geostrophic Energy $\mathcal{E}_g$","Geostrophic Kinetic $\mathcal{K}_g$", ...
    "Geostrophic Potential $\mathcal{P}_g$"},Location="northwest",NumColumns=2,Interpreter="latex")

speedAxes = nexttile(layout,2);
plot(speedAxes,energy.waveSpeedTimeDays,100*energy.maximumHorizontalWaveSpeed,LineWidth=2,Color=colors(1,:))
xlim(speedAxes,timeLimits(energy.waveSpeedTimeDays))
ylim(speedAxes,waveSpeedLimits(100*energy.maximumHorizontalWaveSpeed))
xlabel(speedAxes,"Time (days)")
ylabel(speedAxes,"maximum horizontal wave speed (cm s^{-1})")
title(speedAxes,"Domain-maximum horizontal wave velocity")
linkaxes([energyAxes speedAxes],"x")
end

function limits = energyLimits(series,energyScale)
maximumEnergy = max(series,[],"all");
if energyScale == "normalized"
    upperLimit = max(1,ceil(2*1.05*maximumEnergy)/2);
else
    upperLimit = max(eps,1.05*maximumEnergy);
end
limits = [0 upperLimit];
end

function limits = waveSpeedLimits(maximumHorizontalWaveSpeedCentimeters)
upperLimit = max(1,ceil(1.05*max(maximumHorizontalWaveSpeedCentimeters)));
limits = [0 upperLimit];
end

function limits = timeLimits(timeDays)
limits = [timeDays(1) timeDays(end)];
if limits(1) == limits(2)
    halfWidth = max(0.5,abs(limits(1))*0.01);
    limits = limits+[-halfWidth halfWidth];
end
end

function [exportDirectory,exportPrefix] = resolvedExportLocation(modelFile,exportDirectory,exportPrefix)
[modelDirectory,modelName,~] = fileparts(modelFile);
if strlength(exportDirectory) == 0
    exportDirectory = string(modelDirectory);
end
if strlength(exportPrefix) == 0
    exportPrefix = string(modelName);
end
end

function validateExportPath(path,shouldOverwriteExisting)
directory = fileparts(path);
if strlength(directory) > 0 && ~isfolder(directory)
    mkdir(directory)
end
if isfile(path) && ~shouldOverwriteExisting
    error("EddyTidePseudoTopographicEnergyDiagnostics:ExportFileExists", "The figure '%s' already exists. Set shouldOverwriteExisting=true to replace it.",path)
end
end
