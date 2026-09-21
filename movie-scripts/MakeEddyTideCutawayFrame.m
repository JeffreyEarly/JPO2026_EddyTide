function [fig, frame] = MakeEddyTideCutawayFrame(options)
% Render a quarter-cutaway view of simulation vorticity or geostrophic PV.
%
% The front quadrant beyond the cut coordinates is removed to expose two
% vertical sections. By default, the cut follows an anticyclonic core from
% the initial output using TrackEddyTideAnticyclone. Its localization field
% is spatially averaged and its minima associated by proximity between saved
% times. A supplied coreTrack avoids repeating the history scan for each frame.
% Set cutMode="fixed" to specify the cut coordinates manually.
% Wave vorticity uses grayscale; geostrophic vorticity uses a translucent
% blue-red layer. Both are normalized by the Coriolis frequency f.
% Set colorMode="geostrophic-pv" to color wvt.qgpv/f over gray wave vorticity.
% Set colorMode="total" for the original single-field color map.
% Display distances increase from the front corner; tracked coordinates
% retain their original domain-centered convention.
% The periodic endpoint is included to close the displayed domain.
% Soft directional lighting distinguishes the faces without box outlines.
%
% ```matlab
% [fig, frame] = MakeEddyTideCutawayFrame(day=0);
% ```
%
% - Topic: Visualize the simulation
% - Declaration: [fig, frame] = MakeEddyTideCutawayFrame(options)
% - Parameter inputFile: simulation NetCDF file; defaults to the unforced run
% - Parameter outputFile: PNG filename; an empty string disables export
% - Parameter resolutionScale: integer pixel scale relative to 1920-by-1080; default 1
% - Parameter day: requested simulation day; selects the nearest saved output
% - Parameter cutMode: "geostrophic" follows the continuous anticyclonic track (default); "fixed" uses manual cut coordinates
% - Parameter coreTrack: optional output of TrackEddyTideAnticyclone for the same input file; default computes the history through this frame
% - Parameter xCutKm: x coordinate of the vertical cut for cutMode="fixed", in km; default 0
% - Parameter yCutKm: y coordinate of the vertical cut for cutMode="fixed", in km; default 0
% - Parameter colorMode: "components" (default) blends component vorticities; "geostrophic-pv" blends QGPV and wave vorticity; "total" shows total vorticity
% - Parameter colorLimit: symmetric geostrophic (or total) vorticity limits in units of f; default 0.12
% - Parameter waveColorLimit: symmetric wave vorticity limits in units of f; default 0.08
% - Parameter pvColorLimit: symmetric QGPV limits in units of f for "geostrophic-pv"; default 0.6
% - Parameter pvOpacityScale: absolute QGPV/f at 63 percent of maximum opacity; default 0.075
% - Parameter maximumGeostrophicOpacity: maximum colored-layer opacity; default 0.92
% - Parameter geostrophicOpacityScale: geostrophic vorticity magnitude at 63 percent opacity; default 0.015
% - Parameter verticalExaggeration: vertical scale relative to horizontal; default 160
% - Parameter viewAngles: camera azimuth and elevation in degrees; default [35 25]
% - Parameter visible: whether to display the figure window; default true
% - Returns fig: figure handle, suitable for interactive camera adjustment
% - Returns frame: source file, selected time, rendering settings, output path, vorticity extrema, and fractions of grid samples beyond the color limits
arguments (Input)
    options.inputFile (1,1) string {mustBeFile} = defaultInputFile()
    options.outputFile (1,1) string = defaultOutputFile()
    options.resolutionScale (1,1) double {mustBeFinite,mustBeInteger,mustBePositive} = 1
    options.day (1,1) double {mustBeFinite, mustBeNonnegative} = 0
    options.cutMode (1,1) string {mustBeMember(options.cutMode,["geostrophic","fixed"])} = "geostrophic"
    options.coreTrack (1,1) struct = struct()
    options.xCutKm (1,1) double {mustBeFinite} = 0
    options.yCutKm (1,1) double {mustBeFinite} = 0
    options.colorMode (1,1) string {mustBeMember(options.colorMode,["components","geostrophic-pv","total"])} = "components"
    options.waveColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.08
    options.pvColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.6
    options.pvOpacityScale (1,1) double {mustBeFinite,mustBePositive} = 0.075
    options.maximumGeostrophicOpacity (1,1) double {mustBeFinite,mustBeBetween(options.maximumGeostrophicOpacity,0,1)} = 0.92
    options.geostrophicOpacityScale (1,1) double {mustBeFinite,mustBePositive} = 0.015
    options.colorLimit (1,1) double {mustBeFinite, mustBePositive} = 0.12
    options.verticalExaggeration (1,1) double {mustBeFinite, mustBePositive} = 160
    options.viewAngles (1,2) double {mustBeFinite} = [35 25]
    options.visible (1,1) logical = true
end
arguments (Output)
    fig (1,1) matlab.ui.Figure
    frame (1,1) struct
end

t = ncread(options.inputFile,"/wave-vortex/t");
if options.day < min(t)/86400 || options.day > max(t)/86400
    error("EddyTide:DayOutsideOutput","Requested day %.3f is outside the saved range %.3f to %.3f days.",options.day,min(t)/86400,max(t)/86400)
end
[~,iTime] = min(abs(t/86400 - options.day));
if options.cutMode == "geostrophic"
    coreTrack = options.coreTrack;
    if isempty(fieldnames(coreTrack))
        coreTrack = TrackEddyTideAnticyclone(options.inputFile,lastDay=t(iTime)/86400);
    end
    validateEddyTideCoreTrack(coreTrack,options.inputFile,t,iTime);
end
[wvt,ncfile] = WVTransform.waveVortexTransformFromFile(options.inputFile,iTime=iTime,shouldReadOnly=true);
fileCleanup = onCleanup(@()ncfile.close());

% WVTransform computes zeta_z = dv/dx - du/dy from the saved modal state.
q = wvt.zeta_z/wvt.f;
if options.colorMode == "components"
    qg = (wvt.diffX(wvt.v_g) - wvt.diffY(wvt.u_g))/wvt.f;
    qw = (wvt.diffX(wvt.v_w) - wvt.diffY(wvt.u_w))/wvt.f;
    decompositionResidual = max(abs(q - qg - qw),[],"all");
    if decompositionResidual > 1e-10*max(1,max(abs(q),[],"all"))
        error("EddyTide:IncompleteComponentDecomposition","Wave and geostrophic vorticity do not reconstruct total vorticity; maximum residual is %.3g.",decompositionResidual)
    end
elseif options.colorMode == "geostrophic-pv"
    [qg,pvIdentityResidual] = eddyTideGeostrophicPV(wvt);
    qw = (wvt.diffX(wvt.v_w) - wvt.diffY(wvt.u_w))/wvt.f;
end
vorticityRange = [min(q(:)) max(q(:))];
saturatedGridFraction = nnz(abs(q) > options.colorLimit)/numel(q);
x = [wvt.x; wvt.Lx]/1000 - wvt.Lx/2000;
y = [wvt.y; wvt.Ly]/1000 - wvt.Ly/2000;
z = wvt.z;
q = q([1:end 1],[1:end 1],:);
xCut = options.xCutKm;
yCut = options.yCutKm;
geostrophicPeak = [];
trackingStatus = "fixed";
trackingSettings = struct();
if options.cutMode == "geostrophic"
    xCut = coreTrack.xKm(iTime);
    yCut = coreTrack.yKm(iTime);
    geostrophicPeak = struct(gridIndex=coreTrack.gridIndex(iTime,:),xKm=xCut,yKm=yCut,depthMeters=coreTrack.depthMeters(iTime),zetaOverF=coreTrack.zetaOverF(iTime),filteredZetaOverF=coreTrack.filteredZetaOverF(iTime));
    trackingStatus = coreTrack.status(iTime);
    trackingSettings = coreTrack.settings;
end
if xCut <= x(1) || xCut >= x(end) || yCut <= y(1) || yCut >= y(end)
    error("EddyTide:CutOutsideDomain","Both cut coordinates must be strictly inside the horizontal domain. For a peak on a periodic boundary, use cutMode=""fixed"" with interior xCutKm and yCutKm.")
end
field = griddedInterpolant({x,y,z},q,"linear","none");
% Count samples on the retained top, excluding repeated periodic endpoints.
retainedTop = (x(1:end-1) <= xCut) | (y(1:end-1).' >= yCut);
topVorticity = q(1:end-1,1:end-1,end);
saturatedTopFraction = nnz(abs(topVorticity(retainedTop)) > options.colorLimit)/nnz(retainedTop);

fig = figure(Color="white",Units="pixels",Position=[80 80 1600 900],Visible=options.visible,WindowStyle="normal");
ax = axes(fig,Position=[0.005 0.085 0.875 0.79],FontName="Helvetica",FontSize=13,LineWidth=0.8);
hold(ax,"on")

% Reuse the same geometry updater for stills and movies.
geometry = updateEddyTideCutawayGeometry(ax,field,x,y,z,xCut,yCut);
setappdata(fig,"EddyTideGeometry",geometry);
ax.Tag = "EddyTideAxes";
edgeColor = [0.30 0.34 0.39];

geostrophicMap = vorticityColormap();
waveGray = interp1([-1 0 1],[0.48 0.90 1],linspace(-1,1,257));
waveMap = repmat(waveGray(:),1,3);
style = struct(colorMode=options.colorMode,geostrophicColormap=geostrophicMap,waveColormap=waveMap,geostrophicColorLimit=options.colorLimit,waveColorLimit=options.waveColorLimit,maximumGeostrophicOpacity=options.maximumGeostrophicOpacity,geostrophicOpacityScale=options.geostrophicOpacityScale);
if options.colorMode == "geostrophic-pv"
    style.geostrophicColorLimit = options.pvColorLimit;
    style.geostrophicOpacityScale = options.pvOpacityScale;
    style.geostrophicField = "qgpv/f";
    style.waveField = "wave vertical vorticity/f";
end
colormap(ax,geostrophicMap);
if options.colorMode ~= "total"
    geostrophicField = griddedInterpolant({x,y,z},qg([1:end 1],[1:end 1],:),"linear","none");
    waveField = griddedInterpolant({x,y,z},qw([1:end 1],[1:end 1],:),"linear","none");
    applyEddyTideComponentColors(geometry,geostrophicField,waveField,style);
end
clim(ax,style.geostrophicColorLimit*[-1 1]);
xlim(ax,x([1 end]));
ylim(ax,y([1 end]));
zlim(ax,z([1 end]));
daspect(ax,[1 1 1000/options.verticalExaggeration]);
view(ax,options.viewAngles);
camproj(ax,"orthographic");
camzoom(ax,1.10);
% Use the reference figure's camera-relative light direction, with a softer
% matte material. An infinite light gives each planar face uniform shading.
camlight(ax,20,30,"infinite");
ax.Box = "off";
ax.TickDir = "out";
ax.XTick = -300:150:300;
ax.YTick = -300:150:300;
ax.ZTick = -2000:500:0;
ax.ZTickLabel = string(-ax.ZTick);
ax.XColor = edgeColor;
ax.YColor = edgeColor;
ax.ZColor = edgeColor;
xlabel(ax,"x (km)",Interpreter="none");
ylabel(ax,"y (km)",Interpreter="none");
zlabel(ax,"Depth (m)",Interpreter="none");

cb = colorbar(ax,Position=[0.905 0.24 0.015 0.48],FontSize=12,Color=edgeColor);
cb.Label.String = "Vertical vorticity  \zeta_z / f";
cb.Label.Interpreter = "tex";
cb.Label.FontSize = 14;
cb.Ticks = options.colorLimit*[-1 -0.5 0 0.5 1];
if options.colorMode ~= "total"
    cb.Position = [0.905 0.485 0.015 0.245];
    cb.Ticks = style.geostrophicColorLimit*[-1 0 1];
    cb.Label.String = "geostrophic vorticity  \zeta_z (f)";
    if options.colorMode == "geostrophic-pv"
        cb.Label.String = "geostrophic PV  q (f)";
    end
    cb.Label.FontSize = 12;
    waveAxes = axes(fig,Position=[0.905 0.155 0.015 0.245],Visible="off",HandleVisibility="off",Tag="EddyTideWaveLegendAxes");
    colormap(waveAxes,waveMap);
    clim(waveAxes,options.waveColorLimit*[-1 1]);
    waveBar = colorbar(waveAxes,Position=[0.905 0.155 0.015 0.245],FontSize=12,Color=edgeColor);
    waveBar.Ticks = options.waveColorLimit*[-1 0 1];
    waveBar.Label.String = "wave vorticity  \zeta_z (f)";
    waveBar.Label.Interpreter = "tex";
    waveBar.Label.FontSize = 12;
else
    cb.Label.String = "vertical vorticity  \zeta_z (f)";
    cb.Label.FontSize = 12;
end
annotation(fig,"textbox",[0.025 0.935 0.95 0.05],String="Internal tides catalyze geostrophic eddy instabilities",FontName="Helvetica",FontSize=24,FontWeight="bold",EdgeColor="none",Interpreter="none");
[~,sourceName] = fileparts(options.inputFile);
if contains(sourceName,"-unforced-")
    simulationLabel = "Unforced simulation";
elseif contains(sourceName,"-forced-")
    simulationLabel = "Forced simulation";
else
    simulationLabel = "Simulation";
end
annotation(fig,"textbox",[0.026 0.895 0.70 0.035],String="Hiron et al. 2026   ·   " + simulationLabel,FontName="Helvetica",FontSize=12,Color=edgeColor,EdgeColor="none",Interpreter="none");
annotation(fig,"textbox",[0.805 0.895 0.17 0.04],Tag="EddyTideDay",String=sprintf("Day %.2f",t(iTime)/86400),FontName="Helvetica",FontSize=18,FontWeight="bold",HorizontalAlignment="right",EdgeColor="none",Interpreter="none");
if options.cutMode == "geostrophic"
    cutLabel = "Anticyclonic core";
else
    cutLabel = "Fixed cut";
end
cutCaption = cutLabel + newline + sprintf("x = %.1f km, y = %.1f km",xCut,yCut);
annotation(fig,"textbox",[0.765 0.765 0.21 0.105],Tag="EddyTideCutCaption",String=cutCaption,FontName="Helvetica",FontSize=11,Color=edgeColor,HorizontalAlignment="right",EdgeColor="none",Interpreter="none");
drawnow

frame = struct(inputFile=options.inputFile,iTime=iTime,day=t(iTime)/86400,outputFile=options.outputFile,colorLimit=options.colorLimit,verticalExaggeration=options.verticalExaggeration,xCutKm=xCut,yCutKm=yCut,cutMode=options.cutMode,geostrophicPeak=geostrophicPeak,viewAngles=options.viewAngles,cameraZoom=1.10,vorticityRange=vorticityRange,saturatedGridFraction=saturatedGridFraction,saturatedTopFraction=saturatedTopFraction);
frame.trackingStatus = trackingStatus;
frame.trackingSettings = trackingSettings;
frame.lighting = struct(cameraAngles=[20 30],style="infinite",ambientStrength=0.85,diffuseStrength=0.15,specularStrength=0);
frame.colorMode = options.colorMode;
frame.resolutionScale = options.resolutionScale;
frame.resolution = options.resolutionScale*[1920 1080];
frame.layout = layoutEddyTideCutawayFigure(fig,frame);
style.layout = frame.layout;
style.lighting = frame.lighting;
frame.style = style;
if options.colorMode ~= "total"
    frame.geostrophicColorLimit = style.geostrophicColorLimit;
    frame.waveColorLimit = options.waveColorLimit;
    frame.maximumGeostrophicOpacity = options.maximumGeostrophicOpacity;
    frame.geostrophicOpacityScale = style.geostrophicOpacityScale;
    frame.geostrophicColormap = geostrophicMap;
    frame.waveColormap = waveMap;
    frame.waveRange = [min(qw(:)) max(qw(:))];
    frame.waveSaturatedGridFraction = nnz(abs(qw)>options.waveColorLimit)/numel(qw);
    if options.colorMode == "geostrophic-pv"
        frame.pvColorLimit = options.pvColorLimit;
        frame.pvOpacityScale = options.pvOpacityScale;
        frame.pvRange = [min(qg(:)) max(qg(:))];
        frame.pvRangePerSecond = sort(frame.pvRange*wvt.f);
        frame.pvIdentityResidual = pvIdentityResidual;
        frame.pvSaturatedGridFraction = nnz(abs(qg)>options.pvColorLimit)/numel(qg);
        pvTop = qg(:,:,end);
        frame.pvSaturatedTopFraction = nnz(abs(pvTop(retainedTop))>options.pvColorLimit)/nnz(retainedTop);
    else
        frame.decompositionResidual = decompositionResidual;
        frame.geostrophicRange = [min(qg(:)) max(qg(:))];
        frame.geostrophicSaturatedGridFraction = nnz(abs(qg)>options.colorLimit)/numel(qg);
    end
end
if strlength(options.outputFile) > 0
    outputFolder = fileparts(options.outputFile);
    if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
        mkdir(outputFolder)
    end
    [rgb,frame.raster] = renderEddyTideFigure(fig,options.resolutionScale);
    % Retain print's filename and physical-resolution behavior for stills.
    outputFile = options.outputFile;
    [~,~,extension] = fileparts(outputFile);
    if strlength(extension) == 0
        outputFile = outputFile + ".png";
    end
    pixelsPerMeter = round(size(rgb,2)/(fig.PaperPosition(3)*0.0254));
    imwrite(rgb,outputFile,"png",ResolutionUnit="meter",XResolution=pixelsPerMeter,YResolution=pixelsPerMeter);
    fprintf("Saved day %.3f (output %d) to %s\n",frame.day,frame.iTime,frame.outputFile);
end
fig.UserData = frame;
end

function cmap = vorticityColormap()
% A fixed blue-white-red map; zero stays neutral in every frame.
anchors = [0.13 0.25 0.52; 0.29 0.48 0.72; 0.64 0.78 0.88; 0.98 0.98 0.96; 0.92 0.70 0.61; 0.79 0.34 0.30; 0.55 0.10 0.17];
cmap = interp1(linspace(-1,1,size(anchors,1)),anchors,linspace(-1,1,257));
end

function inputFile = defaultInputFile()
repoRoot = fileparts(fileparts(mfilename("fullpath")));
inputFile = string(fullfile(repoRoot,"model-output","bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc"));
end

function outputFile = defaultOutputFile()
repoRoot = fileparts(fileparts(mfilename("fullpath")));
outputFile = string(fullfile(repoRoot,"movie-frames","eddy-tide-cutaway.png"));
end
