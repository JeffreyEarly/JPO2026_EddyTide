function [figureHandles,summary] = EddyTidePseudoTopographicQuicklook(modelFile,options)
% Create model-only quicklook figures for a pseudo-topographic simulation.
%
% This function reads a saved `WVModel` output file without using
% WaveVortexModelDiagnostics. It shows the physical state and the wave and
% geostrophic spectra at one saved time. The simulation writer must be
% closed before calling this function.
%
% ```matlab
% [figures,summary] = EddyTidePseudoTopographicQuicklook(modelFile);
% ```
%
% - Topic: Provisional figures
% - Declaration: [figureHandles,summary] = EddyTidePseudoTopographicQuicklook(modelFile,options)
% - Parameter modelFile: restartable pseudo-topographic WVModel NetCDF output path
% - Parameter options.iTime: saved-time index, or `Inf` for the final record
% - Parameter options.figureVisible: figure visibility, `"on"` or `"off"`
% - Parameter options.shouldExport: whether to export provisional PNG figures
% - Parameter options.exportDirectory: export directory, default beside `modelFile`
% - Parameter options.exportPrefix: export filename prefix, default model filename
% - Parameter options.exportResolution: PNG resolution in dots per inch
% - Parameter options.shouldOverwriteExisting: whether existing PNG files may be replaced
% - Returns figureHandles: state and spectrum figure handles
% - Returns summary: selected state, spectra, forcing metadata, and output paths
arguments (Input)
    modelFile (1,1) string {mustBeFile}
    options.iTime (1,1) double = Inf
    options.figureVisible (1,1) string {mustBeMember(options.figureVisible,["on" "off"])} = "on"
    options.shouldExport (1,1) logical = true
    options.exportDirectory (1,1) string = ""
    options.exportPrefix (1,1) string = ""
    options.exportResolution (1,1) double {mustBeInteger,mustBePositive} = 300
    options.shouldOverwriteExisting (1,1) logical = false
end
arguments (Output)
    figureHandles (2,1) matlab.ui.Figure
    summary (1,1) struct
end

[exportDirectory,exportPrefix] = resolvedExportLocation(modelFile,options.exportDirectory,options.exportPrefix);
figurePaths = [
    fullfile(exportDirectory,exportPrefix+"-quicklook-state.png")
    fullfile(exportDirectory,exportPrefix+"-quicklook-spectra.png")
    ];
if options.shouldExport
    validateExportPaths(figurePaths,options.shouldOverwriteExisting)
end

[wvt,ncfile] = WVTransform.waveVortexTransformFromFile(char(modelFile),iTime=1,shouldReadOnly=true);
fileCleanup = onCleanup(@()ncfile.close());
time = reshape(ncfile.readVariables("wave-vortex/t"),[],1);
if isempty(time)
    error("EddyTidePseudoTopographicQuicklook:NoSavedTimes", "The model output '%s' contains no saved time records.",modelFile)
end
if any(~isfinite(time)) || any(diff(time) <= 0)
    error("EddyTidePseudoTopographicQuicklook:InvalidSavedTimes", "Saved model times must be finite and strictly increasing.")
end
iTime = resolvedTimeIndex(options.iTime,numel(time));
wvt.initFromNetCDFFile(ncfile,iTime=iTime);
generation = pseudoTopographicGeneration(wvt);

[generationMask,generationComponents] = generation.spectralGenerationMask();
state = stateAtSelectedTime(wvt,generation,generationMask,generationComponents,time(iTime),iTime);
spectra = spectraAtSelectedTime(wvt);
validateFiniteState(state,spectra)

figureHandles = gobjects(2,1);
figureHandles(1) = createStateFigure(state,options.figureVisible);
figureHandles(2) = createSpectrumFigure(spectra,state,options.figureVisible);

summary = struct(modelFile=modelFile,iTime=iTime,time=time(iTime),timeDays=time(iTime)/86400, ...
    state=state,spectra=spectra,forcing=forcingSummary(generation,generationMask), ...
    figurePaths=strings(2,1));
if options.shouldExport
    for iFigure = 1:numel(figureHandles)
        exportgraphics(figureHandles(iFigure),figurePaths(iFigure),Resolution=options.exportResolution)
    end
    summary.figurePaths = figurePaths;
end
clear fileCleanup
end

function iTime = resolvedTimeIndex(requestedIndex,numberOfTimes)
if isinf(requestedIndex) && requestedIndex > 0
    iTime = numberOfTimes;
elseif isfinite(requestedIndex) && requestedIndex == fix(requestedIndex) && requestedIndex >= 1 && requestedIndex <= numberOfTimes
    iTime = requestedIndex;
else
    error("EddyTidePseudoTopographicQuicklook:InvalidTimeIndex", "iTime must be Inf or an integer from 1 through %d.",numberOfTimes)
end
end

function generation = pseudoTopographicGeneration(wvt)
generation = [];
for iForcing = 1:numel(wvt.forcing)
    candidate = wvt.forcing(iForcing);
    if isa(candidate,"WVPseudoTopographicWaveGeneration")
        if ~isempty(generation)
            error("EddyTidePseudoTopographicQuicklook:MultiplePseudoTopographicForcings", "The model contains more than one WVPseudoTopographicWaveGeneration object.")
        end
        generation = candidate;
    end
end
if isempty(generation)
    error("EddyTidePseudoTopographicQuicklook:PseudoTopographicForcingNotFound", "The model must contain one WVPseudoTopographicWaveGeneration object.")
end
end

function state = stateAtSelectedTime(wvt,generation,generationMask,generationComponents,time,iTime)
waveU = wvt.transformToSpatialDomainWithF(Apm=wvt.UAp.*wvt.Apt+wvt.UAm.*wvt.Amt);
waveV = wvt.transformToSpatialDomainWithF(Apm=wvt.VAp.*wvt.Apt+wvt.VAm.*wvt.Amt);
geostrophicU = wvt.transformToSpatialDomainWithF(A0=wvt.UA0.*wvt.A0t);
geostrophicV = wvt.transformToSpatialDomainWithF(A0=wvt.VA0.*wvt.A0t);
[~,iSurface] = max(wvt.z);
waveHorizontalSpeed = squeeze(sqrt(waveU(:,:,iSurface).^2+waveV(:,:,iSurface).^2));
geostrophicVorticity = wvt.diffX(geostrophicV)-wvt.diffY(geostrophicU);
geostrophicSurfaceVorticityOverF = squeeze(geostrophicVorticity(:,:,iSurface))/abs(wvt.f);

allowedCount = wvt.transformToRadialWavenumber(double(generationMask));
validCount = wvt.transformToRadialWavenumber(double(generationComponents.waveValidity));
generationSupportFraction = zeros(size(allowedCount));
hasValidModes = validCount > 0;
generationSupportFraction(hasValidModes) = allowedCount(hasValidModes)./validCount(hasValidModes);

state = struct(time=time,timeDays=time/86400,iTime=iTime,xKilometers=wvt.x(:)/1e3, ...
    yKilometers=wvt.y(:)/1e3,z=wvt.z(iSurface),topographicHeight=generation.topographicHeight, ...
    waveHorizontalSpeed=waveHorizontalSpeed,geostrophicSurfaceVorticityOverF=geostrophicSurfaceVorticityOverF, ...
    maximumSurfaceHorizontalWaveSpeed=max(waveHorizontalSpeed,[],"all"), ...
    maximumGeostrophicSurfaceVorticityOverF=max(abs(geostrophicSurfaceVorticityOverF),[],"all"), ...
    generationSupportFraction=generationSupportFraction,verticalMode=wvt.j(:), ...
    radialWavelengthKilometers=2*pi./wvt.kRadial(:).'/1e3);
end

function spectra = spectraAtSelectedTime(wvt)
waveEnergy = wvt.Apm_TE_factor.*(abs(wvt.Ap).^2+abs(wvt.Am).^2);
geostrophicMask = logical(wvt.geostrophicComponent.maskA0);
geostrophicEnergy = wvt.A0_TE_factor.*abs(geostrophicMask.*wvt.A0).^2;
waveRadial = wvt.transformToRadialWavenumber(waveEnergy);
geostrophicRadial = wvt.transformToRadialWavenumber(geostrophicEnergy);
waveTotal = sum(waveEnergy,"all");
geostrophicTotal = sum(geostrophicEnergy,"all");
spectra = struct(radialWavelengthKilometers=2*pi./wvt.kRadial(:).'/1e3,verticalMode=wvt.j(:), ...
    waveRadial=waveRadial,geostrophicRadial=geostrophicRadial,waveTotal=waveTotal, ...
    geostrophicTotal=geostrophicTotal,waveHorizontal=sum(waveRadial,1), ...
    geostrophicHorizontal=sum(geostrophicRadial,1),waveVertical=sum(waveRadial,2), ...
    geostrophicVertical=sum(geostrophicRadial,2));
end

function summary = forcingSummary(generation,generationMask)
if ~isfinite(generation.frequency) || generation.frequency <= 0 || ...
        any(~isfinite(generation.barotropicVelocityAmplitude),"all")
    error("EddyTidePseudoTopographicQuicklook:InvalidForcingMetadata", "The pseudo-topographic frequency and velocity amplitude must be finite, with positive frequency.")
end
summary = struct(name=generation.name,frequency=generation.frequency,darwinSymbol=generation.darwinSymbol, ...
    barotropicVelocityAmplitude=generation.barotropicVelocityAmplitude,rampDuration=generation.rampDuration, ...
    startTime=generation.startTime,shouldAvoidAdaptiveDamping=generation.shouldAvoidAdaptiveDamping, ...
    maximumForcedHorizontalWavenumber=generation.maximumForcedHorizontalWavenumber, ...
    maximumForcedVerticalMode=generation.maximumForcedVerticalMode, ...
    allowedModeCount=nnz(generationMask),excludedModeCount=numel(generationMask)-nnz(generationMask));
end

function validateFiniteState(state,spectra)
values = [state.topographicHeight(:); state.waveHorizontalSpeed(:); ...
    state.geostrophicSurfaceVorticityOverF(:); state.generationSupportFraction(:); ...
    spectra.waveRadial(:); spectra.geostrophicRadial(:)];
if any(~isfinite(values))
    error("EddyTidePseudoTopographicQuicklook:NonfiniteData", "All reconstructed state and spectral values must be finite.")
end
if any(state.generationSupportFraction(:) < 0 | state.generationSupportFraction(:) > 1)
    error("EddyTidePseudoTopographicQuicklook:InvalidGenerationSupport", "Generation-support fractions must lie between zero and one.")
end
end

function figureHandle = createStateFigure(state,visibility)
figureHandle = figure(Name="Pseudo-topographic state quicklook",Color="w",Visible=visibility,Position=[100 100 1320 850]);
layout = tiledlayout(figureHandle,2,2,TileSpacing="compact",Padding="compact");

axesHandle = nexttile(layout,1);
imagesc(axesHandle,state.xKilometers,state.yKilometers,state.topographicHeight.')
axis(axesHandle,"xy","image")
xlabel(axesHandle,"x (km)")
ylabel(axesHandle,"y (km)")
title(axesHandle,"Pseudo-topography h (m)")
colorbar(axesHandle)

axesHandle = nexttile(layout,2);
validWavelength = isfinite(state.radialWavelengthKilometers) & state.radialWavelengthKilometers > 0;
imagesc(axesHandle,state.radialWavelengthKilometers(validWavelength),state.verticalMode,state.generationSupportFraction(:,validWavelength))
set(axesHandle,XScale="log",XDir="reverse",YDir="normal")
xlabel(axesHandle,"horizontal wavelength (km)")
ylabel(axesHandle,"vertical mode")
title(axesHandle,"Forced fraction of valid modes")
clim(axesHandle,[0 1])
colorbar(axesHandle)

axesHandle = nexttile(layout,3);
imagesc(axesHandle,state.xKilometers,state.yKilometers,state.geostrophicSurfaceVorticityOverF.')
axis(axesHandle,"xy","image")
vorticityLimit = max(abs(state.geostrophicSurfaceVorticityOverF),[],"all");
if vorticityLimit > 0
    clim(axesHandle,[-vorticityLimit vorticityLimit])
end
colormap(axesHandle,blueWhiteRed(256))
xlabel(axesHandle,"x (km)")
ylabel(axesHandle,"y (km)")
title(axesHandle,sprintf("Surface geostrophic ζ/f, max |ζ/f| = %.2f",state.maximumGeostrophicSurfaceVorticityOverF))
colorbar(axesHandle)

axesHandle = nexttile(layout,4);
imagesc(axesHandle,state.xKilometers,state.yKilometers,100*state.waveHorizontalSpeed.')
axis(axesHandle,"xy","image")
if state.maximumSurfaceHorizontalWaveSpeed > 0
    clim(axesHandle,[0 100*state.maximumSurfaceHorizontalWaveSpeed])
else
    clim(axesHandle,[0 1])
end
xlabel(axesHandle,"x (km)")
ylabel(axesHandle,"y (km)")
title(axesHandle,sprintf("Surface wave speed, max = %.2f cm s^{-1}",100*state.maximumSurfaceHorizontalWaveSpeed))
colorbar(axesHandle)

title(layout,sprintf("Pseudo-topographic quicklook at day %g",state.timeDays))
end

function figureHandle = createSpectrumFigure(spectra,state,visibility)
figureHandle = figure(Name="Pseudo-topographic spectrum quicklook",Color="w",Visible=visibility,Position=[100 100 1320 850]);
layout = tiledlayout(figureHandle,2,2,TileSpacing="compact",Padding="compact");
validWavelength = isfinite(spectra.radialWavelengthKilometers) & spectra.radialWavelengthKilometers > 0;

plotSpectrumMap(nexttile(layout,1),spectra.radialWavelengthKilometers(validWavelength),spectra.verticalMode, ...
    spectra.waveRadial(:,validWavelength),spectra.waveTotal,"Combined wave energy")
plotSpectrumMap(nexttile(layout,2),spectra.radialWavelengthKilometers(validWavelength),spectra.verticalMode, ...
    spectra.geostrophicRadial(:,validWavelength),spectra.geostrophicTotal,"Geostrophic energy")

axesHandle = nexttile(layout,3);
hasWave = plotPositiveLogLog(axesHandle,spectra.radialWavelengthKilometers(validWavelength),spectra.waveHorizontal(validWavelength),"wave","-");
hold(axesHandle,"on")
hasGeostrophic = plotPositiveLogLog(axesHandle,spectra.radialWavelengthKilometers(validWavelength),spectra.geostrophicHorizontal(validWavelength),"geostrophic","--");
finishOneDimensionalSpectrum(axesHandle,hasWave || hasGeostrophic,"horizontal wavelength (km)","Radial spectrum")
set(axesHandle,XDir="reverse")

axesHandle = nexttile(layout,4);
hasWave = plotPositiveSemilogy(axesHandle,spectra.verticalMode,spectra.waveVertical,"wave","-");
hold(axesHandle,"on")
hasGeostrophic = plotPositiveSemilogy(axesHandle,spectra.verticalMode,spectra.geostrophicVertical,"geostrophic","--");
finishOneDimensionalSpectrum(axesHandle,hasWave || hasGeostrophic,"vertical mode","Vertical-mode spectrum")

title(layout,sprintf("Energy spectra at day %g",state.timeDays))
end

function plotSpectrumMap(axesHandle,wavelength,verticalMode,energy,totalEnergy,panelTitle)
if totalEnergy > 0
    logFraction = log10(energy/totalEnergy);
    finiteValues = logFraction(isfinite(logFraction));
else
    logFraction = NaN(size(energy));
    finiteValues = [];
end
if isempty(finiteValues)
    axis(axesHandle,"off")
    text(axesHandle,0.5,0.5,"No energy in reservoir",HorizontalAlignment="center")
    title(axesHandle,panelTitle)
    return
end
surface(axesHandle,wavelength,verticalMode,logFraction,EdgeColor="none")
view(axesHandle,2)
set(axesHandle,XScale="log",XDir="reverse")
clim(axesHandle,[max(finiteValues)-6 max(finiteValues)])
xlabel(axesHandle,"horizontal wavelength (km)")
ylabel(axesHandle,"vertical mode")
title(axesHandle,panelTitle+" fraction")
colorbar(axesHandle)
end

function hasData = plotPositiveLogLog(axesHandle,x,y,label,lineStyle)
valid = isfinite(x) & isfinite(y) & x > 0 & y > 0;
hasData = any(valid);
if hasData
    loglog(axesHandle,x(valid),y(valid),LineStyle=lineStyle,LineWidth=2,DisplayName=label)
end
end

function hasData = plotPositiveSemilogy(axesHandle,x,y,label,lineStyle)
valid = isfinite(x) & isfinite(y) & y > 0;
hasData = any(valid);
if hasData
    semilogy(axesHandle,x(valid),y(valid),LineStyle=lineStyle,LineWidth=2,DisplayName=label)
end
end

function finishOneDimensionalSpectrum(axesHandle,hasData,xLabel,panelTitle)
if ~hasData
    axis(axesHandle,"off")
    text(axesHandle,0.5,0.5,"No energy in either reservoir",HorizontalAlignment="center")
    title(axesHandle,panelTitle)
    return
end
grid(axesHandle,"on")
xlabel(axesHandle,xLabel)
ylabel(axesHandle,"energy (m^3 s^{-2})")
title(axesHandle,panelTitle)
legend(axesHandle,Location="best")
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

function validateExportPaths(paths,shouldOverwriteExisting)
for path = paths(:).'
    directory = fileparts(path);
    if strlength(directory) > 0 && ~isfolder(directory)
        mkdir(directory)
    end
    if isfile(path) && ~shouldOverwriteExisting
        error("EddyTidePseudoTopographicQuicklook:ExportFileExists", "The figure '%s' already exists. Set shouldOverwriteExisting=true to replace it.",path)
    end
end
end

function values = blueWhiteRed(numberOfColors)
lowerCount = floor(numberOfColors/2);
upperCount = numberOfColors-lowerCount;
blue = [0.085 0.286 0.621];
white = [0.98 0.98 0.98];
red = [0.706 0.016 0.150];
lower = [linspace(blue(1),white(1),lowerCount).',linspace(blue(2),white(2),lowerCount).',linspace(blue(3),white(3),lowerCount).'];
upper = [linspace(white(1),red(1),upperCount).',linspace(white(2),red(2),upperCount).',linspace(white(3),red(3),upperCount).'];
values = [lower; upper];
end
