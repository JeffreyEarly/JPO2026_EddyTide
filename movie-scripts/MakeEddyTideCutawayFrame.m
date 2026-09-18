function [fig, frame] = MakeEddyTideCutawayFrame(options)
% Render a quarter-cutaway view of the simulation's vertical vorticity.
%
% The front quadrant beyond the cut coordinates is removed to expose two
% vertical sections. By default, the cut follows an anticyclonic core from
% the initial output using TrackEddyTideAnticyclone. Its localization field
% is spatially averaged and its minima associated by proximity between saved
% times. A supplied coreTrack avoids repeating the history scan for each frame.
% Set cutMode="fixed" to specify the cut coordinates manually.
% All colored faces show the total vertical vorticity
% divided by the Coriolis frequency, with a common, fixed linear color scale.
% Horizontal coordinates are relative to the original domain center.
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
% - Parameter day: requested simulation day; selects the nearest saved output
% - Parameter cutMode: "geostrophic" follows the continuous anticyclonic track (default); "fixed" uses manual cut coordinates
% - Parameter coreTrack: optional output of TrackEddyTideAnticyclone for the same input file; default computes the history through this frame
% - Parameter xCutKm: x coordinate of the vertical cut for cutMode="fixed", in km; default 0
% - Parameter yCutKm: y coordinate of the vertical cut for cutMode="fixed", in km; default 0
% - Parameter colorLimit: symmetric limits for vorticity divided by f; default 0.12
% - Parameter verticalExaggeration: vertical scale relative to horizontal; default 160
% - Parameter viewAngles: camera azimuth and elevation in degrees; default [35 25]
% - Parameter visible: whether to display the figure window; default true
% - Returns fig: figure handle, suitable for interactive camera adjustment
% - Returns frame: source file, selected time, rendering settings, output path, vorticity extrema, and fractions of grid samples beyond the color limits
arguments (Input)
    options.inputFile (1,1) string {mustBeFile} = defaultInputFile()
    options.outputFile (1,1) string = defaultOutputFile()
    options.day (1,1) double {mustBeFinite, mustBeNonnegative} = 0
    options.cutMode (1,1) string {mustBeMember(options.cutMode,["geostrophic","fixed"])} = "geostrophic"
    options.coreTrack (1,1) struct = struct()
    options.xCutKm (1,1) double {mustBeFinite} = 0
    options.yCutKm (1,1) double {mustBeFinite} = 0
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

colormap(ax,vorticityColormap());
clim(ax,options.colorLimit*[-1 1]);
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
cutCaption = cutLabel + newline + sprintf("x = %.1f km, y = %.1f km",xCut,yCut) + newline + sprintf("Vertical exaggeration %g×",options.verticalExaggeration);
annotation(fig,"textbox",[0.765 0.765 0.21 0.105],Tag="EddyTideCutCaption",String=cutCaption,FontName="Helvetica",FontSize=11,Color=edgeColor,HorizontalAlignment="right",EdgeColor="none",Interpreter="none");
drawnow

frame = struct(inputFile=options.inputFile,iTime=iTime,day=t(iTime)/86400,outputFile=options.outputFile,colorLimit=options.colorLimit,verticalExaggeration=options.verticalExaggeration,xCutKm=xCut,yCutKm=yCut,cutMode=options.cutMode,geostrophicPeak=geostrophicPeak,viewAngles=options.viewAngles,cameraZoom=1.10,vorticityRange=vorticityRange,saturatedGridFraction=saturatedGridFraction,saturatedTopFraction=saturatedTopFraction);
frame.trackingStatus = trackingStatus;
frame.trackingSettings = trackingSettings;
frame.lighting = struct(cameraAngles=[20 30],style="infinite",ambientStrength=0.85,diffuseStrength=0.15,specularStrength=0);
fig.UserData = frame;
if strlength(options.outputFile) > 0
    outputFolder = fileparts(options.outputFile);
    if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
        mkdir(outputFolder)
    end
    % Keep the entire canvas and an exact 1920-by-1080 movie-frame size.
    fig.PaperUnits = "inches";
    fig.PaperPosition = [0 0 12.8 7.2];
    fig.PaperSize = [12.8 7.2];
    print(fig,options.outputFile,"-dpng","-r150");
    fprintf("Saved day %.3f (output %d) to %s\n",frame.day,frame.iTime,frame.outputFile);
end
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
