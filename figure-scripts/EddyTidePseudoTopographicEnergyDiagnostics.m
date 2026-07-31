function [figureHandle,energy,diagnosticsFile] = EddyTidePseudoTopographicEnergyDiagnostics(modelFile,options)
% Plot wave and geostrophic energy using WaveVortexModelDiagnostics.
%
% Missing diagnostics are created and stale diagnostics are extended by
% default. Wave energy uses `EnergyReservoir.wave`, which is the combined
% internal-gravity-wave and inertial-oscillation reservoir
% $$E_{\mathrm{wave}}=E_w+E_{io}$$. Energies are plotted in absolute SI
% units without normalization. The simulation writer must be closed before
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
% - Parameter options.figureVisible: figure visibility, `"on"` or `"off"`
% - Parameter options.shouldExport: whether to export the provisional PNG figure
% - Parameter options.exportDirectory: export directory, default beside `modelFile`
% - Parameter options.exportPrefix: export filename prefix, default model filename
% - Parameter options.exportResolution: PNG resolution in dots per inch
% - Parameter options.shouldOverwriteExisting: whether an existing PNG file may be replaced
% - Returns figureHandle: two-panel energy figure
% - Returns energy: time, plotted reservoirs, quadratic total, and exact total energy
% - Returns diagnosticsFile: diagnostics NetCDF path
arguments (Input)
    modelFile (1,1) string {mustBeFile}
    options.diagnosticsFile (1,1) string = ""
    options.diagnosticsStride (1,1) double {mustBeInteger,mustBePositive} = 1
    options.shouldUpdateDiagnostics (1,1) logical = true
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

reservoirNames = [EnergyReservoir.wave EnergyReservoir.geostrophic ...
    EnergyReservoir.geostrophic_kinetic EnergyReservoir.geostrophic_potential EnergyReservoir.total];
[reservoirs,time] = diagnostics.quadraticEnergyOverTime(energyReservoirs=reservoirNames);
[exactTotal,exactTime] = diagnostics.exactEnergyOverTime;
time = reshape(time,[],1);
exactTime = reshape(exactTime,[],1);
if ~isequal(time,exactTime)
    error("EddyTidePseudoTopographicEnergyDiagnostics:DiagnosticsTimeMismatch", "Quadratic and exact energy diagnostics must use identical saved times.")
end
if isempty(time) || time(end) ~= diagnostics.t_wv(end)
    error("EddyTidePseudoTopographicEnergyDiagnostics:StaleDiagnostics", "Diagnostics must extend through the final model-output time.")
end

energy = struct(time=time,timeDays=time/86400,wave=reshape(reservoirs(1).energy,[],1), ...
    geostrophic=reshape(reservoirs(2).energy,[],1), ...
    geostrophicKinetic=reshape(reservoirs(3).energy,[],1), ...
    geostrophicPotential=reshape(reservoirs(4).energy,[],1), ...
    quadraticTotal=reshape(reservoirs(5).energy,[],1),exactTotal=reshape(exactTotal,[],1), ...
    units="m^3 s^{-2}",waveDefinition="E_w + E_io",figurePath="");
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
series = [energy.wave energy.geostrophic energy.geostrophicKinetic ...
    energy.geostrophicPotential energy.quadraticTotal energy.exactTotal];
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
end

function figureHandle = createEnergyFigure(energy,visibility)
figureHandle = figure(Name="Pseudo-topographic energy diagnostics",Color="w",Visible=visibility,Position=[100 100 1000 780]);
layout = tiledlayout(figureHandle,2,1,TileSpacing="compact",Padding="compact");

axesHandle = nexttile(layout,1);
if any([energy.wave; energy.geostrophic] > 0)
    plotFunction = @semilogy;
    panelTitle = "Wave and geostrophic reservoirs (log scale)";
else
    plotFunction = @plot;
    panelTitle = "Wave and geostrophic reservoirs";
end
plotFunction(axesHandle,energy.timeDays,energy.wave,LineWidth=2,DisplayName="wave, E_w + E_{io}")
hold(axesHandle,"on")
plotFunction(axesHandle,energy.timeDays,energy.geostrophic,LineWidth=2,DisplayName="geostrophic, E_g")
grid(axesHandle,"on")
xlim(axesHandle,timeLimits(energy.timeDays))
ylabel(axesHandle,"energy (m^3 s^{-2})")
title(axesHandle,panelTitle)
legend(axesHandle,Location="best")

axesHandle = nexttile(layout,2);
plot(axesHandle,energy.timeDays,energy.geostrophicKinetic,LineWidth=2,DisplayName="geostrophic kinetic, KE_g")
hold(axesHandle,"on")
plot(axesHandle,energy.timeDays,energy.geostrophicPotential,LineWidth=2,DisplayName="geostrophic potential, PE_g")
grid(axesHandle,"on")
xlim(axesHandle,timeLimits(energy.timeDays))
xlabel(axesHandle,"time (days)")
ylabel(axesHandle,"energy (m^3 s^{-2})")
title(axesHandle,"Geostrophic partition")
legend(axesHandle,Location="best")

title(layout,"Pseudo-topographic energy evolution")
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
