function [figureHandle,comparison,diagnosticsFiles] = EddyTidePseudoTopographicEnergyComparison(eddyFile,controlFile,options)
% Compare pseudo-topographic eddy and control energy histories.
%
% Both calculations use the initial quadratic total energy of the eddy run
% as their common normalization. Constituent colors follow the normalized
% energy panel of manuscript Figure 4; solid curves show the initial-eddy
% calculation and dashed curves show the control.
%
% ```matlab
% [fig,comparison,diagnosticsFiles] = EddyTidePseudoTopographicEnergyComparison(eddyFile,controlFile);
% ```
%
% - Topic: Provisional figures
% - Declaration: [figureHandle,comparison,diagnosticsFiles] = EddyTidePseudoTopographicEnergyComparison(eddyFile,controlFile,options)
% - Parameter eddyFile: restartable pseudo-topographic model output initialized with an eddy
% - Parameter controlFile: matching restartable pseudo-topographic model output initialized without an eddy
% - Parameter options.diagnosticsStride: model-output stride used to create or update diagnostics
% - Parameter options.figureVisible: figure visibility, `"on"` or `"off"`
% - Parameter options.shouldExport: whether to export the comparison PNG
% - Parameter options.exportDirectory: export directory, default beside `eddyFile`
% - Parameter options.exportPrefix: export filename prefix, default derived from `eddyFile`
% - Parameter options.exportResolution: PNG resolution in dots per inch
% - Parameter options.shouldOverwriteExisting: whether an existing PNG may be replaced
% - Returns figureHandle: paired normalized-energy and wave-speed figure
% - Returns comparison: raw and commonly normalized eddy and control series
% - Returns diagnosticsFiles: eddy and control diagnostics paths
arguments (Input)
    eddyFile (1,1) string {mustBeFile}
    controlFile (1,1) string {mustBeFile}
    options.diagnosticsStride (1,1) double {mustBeInteger,mustBePositive} = 4
    options.figureVisible (1,1) string {mustBeMember(options.figureVisible,["on" "off"])} = "on"
    options.shouldExport (1,1) logical = true
    options.exportDirectory (1,1) string = ""
    options.exportPrefix (1,1) string = ""
    options.exportResolution (1,1) double {mustBeInteger,mustBePositive} = 300
    options.shouldOverwriteExisting (1,1) logical = false
end
arguments (Output)
    figureHandle matlab.ui.Figure
    comparison (1,1) struct
    diagnosticsFiles (1,1) struct
end

[eddyFigure,eddy,eddyDiagnostics] = EddyTidePseudoTopographicEnergyDiagnostics(eddyFile, ...
    diagnosticsStride=options.diagnosticsStride,shouldUpdateDiagnostics=true,energyScale="normalized", ...
    figureVisible="off",shouldExport=false);
close(eddyFigure)
[controlFigure,control,controlDiagnostics] = EddyTidePseudoTopographicEnergyDiagnostics(controlFile, ...
    diagnosticsStride=options.diagnosticsStride,shouldUpdateDiagnostics=true,energyScale="absolute", ...
    figureVisible="off",shouldExport=false);
close(controlFigure)

validatePair(eddy,control)
normalization = eddy.quadraticTotal(1);
comparison = struct(eddy=eddy,control=control,normalization=normalization, ...
    normalizationDefinition="initial eddy quadratic total energy", ...
    eddyNormalized=normalizedSeries(eddy,normalization), ...
    controlNormalized=normalizedSeries(control,normalization),figurePath="");
diagnosticsFiles = struct(eddy=string(eddyDiagnostics),control=string(controlDiagnostics));

figureHandle = createComparisonFigure(comparison,options.figureVisible);
if options.shouldExport
    figurePath = resolvedExportPath(eddyFile,options.exportDirectory,options.exportPrefix);
    validateExportPath(figurePath,options.shouldOverwriteExisting)
    exportgraphics(figureHandle,figurePath,Resolution=options.exportResolution)
    comparison.figurePath = figurePath;
end
end

function validatePair(eddy,control)
if ~isequal(eddy.time,control.time) || ~isequal(eddy.waveSpeedTime,control.waveSpeedTime)
    error("EddyTidePseudoTopographicEnergyComparison:TimeMismatch", "Eddy and control diagnostics must use identical energy and model time axes.")
end
normalization = eddy.quadraticTotal(1);
if ~isfinite(normalization) || normalization <= 0
    error("EddyTidePseudoTopographicEnergyComparison:InvalidNormalization", "The initial eddy quadratic total energy must be finite and positive.")
end
controlTolerance = 100*eps(max(1,max(abs(control.quadraticTotal))));
if abs(control.quadraticTotal(1)) > controlTolerance
    error("EddyTidePseudoTopographicEnergyComparison:NonzeroControlInitialEnergy", "The control must begin with zero quadratic total energy within numerical precision.")
end
values = [energyValues(eddy); energyValues(control)];
if any(~isfinite(values))
    error("EddyTidePseudoTopographicEnergyComparison:NonfiniteData", "All paired energy and wave-speed series must be finite.")
end
end

function values = energyValues(energy)
values = [energy.quadraticTotal(:); energy.internalGravityWave(:); energy.geostrophic(:); ...
    energy.geostrophicKinetic(:); energy.geostrophicPotential(:); ...
    energy.maximumHorizontalWaveSpeed(:)];
end

function normalized = normalizedSeries(energy,normalization)
normalized = struct(quadraticTotal=energy.quadraticTotal/normalization, ...
    internalGravityWave=energy.internalGravityWave/normalization, ...
    geostrophic=energy.geostrophic/normalization, ...
    geostrophicKinetic=energy.geostrophicKinetic/normalization, ...
    geostrophicPotential=energy.geostrophicPotential/normalization);
end

function figureHandle = createComparisonFigure(comparison,visibility)
figureHandle = figure(Name="Pseudo-topographic eddy-control comparison",Color="w",Visible=visibility,Position=[100 100 980 850]);
layout = tiledlayout(figureHandle,2,1,TileSpacing="compact",Padding="compact");
colors = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250; 0.4940 0.1840 0.5560; 0.4660 0.6740 0.1880];

energyAxes = nexttile(layout,1);
eddySeries = seriesMatrix(comparison.eddyNormalized);
controlSeries = seriesMatrix(comparison.controlNormalized);
hold(energyAxes,"on")
eddyLines = plot(energyAxes,comparison.eddy.timeDays,eddySeries,LineWidth=2,LineStyle="-");
controlLines = plot(energyAxes,comparison.control.timeDays,controlSeries,LineWidth=2,LineStyle="--");
for iLine = 1:numel(eddyLines)
    eddyLines(iLine).Color = colors(iLine,:);
    controlLines(iLine).Color = colors(iLine,:);
end
eddyKey = plot(energyAxes,NaN,NaN,Color=[0.15 0.15 0.15],LineWidth=2,LineStyle="-");
controlKey = plot(energyAxes,NaN,NaN,Color=[0.15 0.15 0.15],LineWidth=2,LineStyle="--");
hold(energyAxes,"off")
xlim(energyAxes,timeLimits(comparison.eddy.timeDays))
ylim(energyAxes,normalizedEnergyLimits([eddySeries controlSeries]))
ylabel(energyAxes,"Normalized Energy")
energyAxes.XTickLabel = [];
legend(energyAxes,[eddyLines(:); eddyKey; controlKey], ...
    {"Total Energy $\mathcal{E}$","Wave Energy $\mathcal{E}_w$", ...
    "Geostrophic Energy $\mathcal{E}_g$","Geostrophic Kinetic $\mathcal{K}_g$", ...
    "Geostrophic Potential $\mathcal{P}_g$","Initial eddy","Control"}, ...
    Location="northwest",NumColumns=2,Interpreter="latex")

speedAxes = nexttile(layout,2);
plot(speedAxes,comparison.eddy.waveSpeedTimeDays,100*comparison.eddy.maximumHorizontalWaveSpeed, ...
    LineWidth=2,Color=colors(1,:),LineStyle="-")
hold(speedAxes,"on")
plot(speedAxes,comparison.control.waveSpeedTimeDays,100*comparison.control.maximumHorizontalWaveSpeed, ...
    LineWidth=2,Color=colors(1,:),LineStyle="--")
hold(speedAxes,"off")
xlim(speedAxes,timeLimits(comparison.eddy.waveSpeedTimeDays))
maximumSpeed = 100*max([comparison.eddy.maximumHorizontalWaveSpeed; comparison.control.maximumHorizontalWaveSpeed]);
ylim(speedAxes,[0 max(1,ceil(1.05*maximumSpeed))])
xlabel(speedAxes,"Time (days)")
ylabel(speedAxes,"maximum horizontal wave speed (cm s^{-1})")
title(speedAxes,"Domain-maximum horizontal wave velocity")
legend(speedAxes,{"Initial eddy","Control"},Location="northwest")
linkaxes([energyAxes speedAxes],"x")
end

function series = seriesMatrix(normalized)
series = [normalized.quadraticTotal normalized.internalGravityWave normalized.geostrophic ...
    normalized.geostrophicKinetic normalized.geostrophicPotential];
end

function limits = normalizedEnergyLimits(series)
upperLimit = max(1,ceil(2*1.05*max(series,[],"all"))/2);
limits = [0 upperLimit];
end

function limits = timeLimits(timeDays)
limits = [timeDays(1) timeDays(end)];
if limits(1) == limits(2)
    halfWidth = max(0.5,abs(limits(1))*0.01);
    limits = limits+[-halfWidth halfWidth];
end
end

function path = resolvedExportPath(eddyFile,exportDirectory,exportPrefix)
[modelDirectory,modelName,~] = fileparts(eddyFile);
if strlength(exportDirectory) == 0
    exportDirectory = string(modelDirectory);
end
if strlength(exportPrefix) == 0
    exportPrefix = replace(string(modelName),"-eddy-","-");
end
path = fullfile(exportDirectory,exportPrefix+"-paired-diagnostic-energy.png");
end

function validateExportPath(path,shouldOverwriteExisting)
directory = fileparts(path);
if strlength(directory) > 0 && ~isfolder(directory)
    mkdir(directory)
end
if isfile(path) && ~shouldOverwriteExisting
    error("EddyTidePseudoTopographicEnergyComparison:ExportFileExists", "The figure '%s' already exists. Set shouldOverwriteExisting=true to replace it.",path)
end
end
