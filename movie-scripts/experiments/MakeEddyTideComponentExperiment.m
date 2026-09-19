function [fig, experiment] = MakeEddyTideComponentExperiment(options)
% Preview wave and geostrophic vorticity with separate, blended colormaps.
%
% Compatibility entry point; this view is now the main renderer default.
% Wave vorticity comes from u_w and v_w;
% geostrophic vorticity comes from u_g and v_g. Both use dv/dx - du/dy,
% normalized by f. Their sum is checked against total vertical vorticity.
%
% Gray wave colors form the background. A blue-red geostrophic layer fades
% smoothly to transparent as its magnitude approaches zero. The alpha blend
% is evaluated on each face before rendering to avoid overlapping surfaces.
% This is color-layer translucency, not transparency through the 3D volume.
% The two colorbars show the component maps before blending and lighting.
%
% - Topic: Experiment with component visualization
% - Declaration: [fig, experiment] = MakeEddyTideComponentExperiment(options)
% - Parameter inputFile: simulation NetCDF file; defaults to the unforced run
% - Parameter outputFile: PNG path; an empty string disables export
% - Parameter day: requested simulation day; default 400
% - Parameter coreTrack: optional output of TrackEddyTideAnticyclone
% - Parameter cutMode: "geostrophic" tracks the anticyclone; "fixed" uses manual cuts
% - Parameter xCutKm: fixed x cut coordinate in km; default 0
% - Parameter yCutKm: fixed y cut coordinate in km; default 0
% - Parameter geostrophicColorLimit: symmetric geostrophic zeta/f limits; default 0.12
% - Parameter waveColorLimit: symmetric wave zeta/f limits; default 0.08
% - Parameter maximumGeostrophicOpacity: upper limit of colored-layer opacity; default 0.92
% - Parameter geostrophicOpacityScale: absolute geostrophic zeta/f at 63 percent of maximum opacity; default 0.015
% - Parameter verticalExaggeration: vertical scale relative to horizontal; default 160
% - Parameter viewAngles: camera azimuth and elevation in degrees; default [35 25]
% - Parameter visible: whether to display the figure window; default true
% - Returns fig: figure handle for the experimental composition
% - Returns experiment: component statistics, blend settings, colormaps, and base-frame metadata
arguments (Input)
    options.inputFile (1,1) string {mustBeFile} = defaultInputFile()
    options.outputFile (1,1) string = defaultOutputFile()
    options.day (1,1) double {mustBeFinite,mustBeNonnegative} = 400
    options.coreTrack (1,1) struct = struct()
    options.cutMode (1,1) string {mustBeMember(options.cutMode,["geostrophic","fixed"])} = "geostrophic"
    options.xCutKm (1,1) double {mustBeFinite} = 0
    options.yCutKm (1,1) double {mustBeFinite} = 0
    options.geostrophicColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.12
    options.waveColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.08
    options.maximumGeostrophicOpacity (1,1) double {mustBeFinite,mustBeBetween(options.maximumGeostrophicOpacity,0,1)} = 0.92
    options.geostrophicOpacityScale (1,1) double {mustBeFinite,mustBePositive} = 0.015
    options.verticalExaggeration (1,1) double {mustBeFinite,mustBePositive} = 160
    options.viewAngles (1,2) double {mustBeFinite} = [35 25]
    options.visible (1,1) logical = true
end
arguments (Output)
    fig (1,1) matlab.ui.Figure
    experiment (1,1) struct
end

% Keep earlier preview commands working through the production renderer.
frameOptions = rmfield(options,"geostrophicColorLimit");
frameOptions.colorLimit = options.geostrophicColorLimit;
frameArguments = namedargs2cell(frameOptions);
[fig,frame] = MakeEddyTideCutawayFrame(frameArguments{:});
experiment = frame;
experiment.baseFrame = frame;
fig.UserData = experiment;
end

function inputFile = defaultInputFile()
repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
inputFile = string(fullfile(repoRoot,"model-output","bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc"));
end

function outputFile = defaultOutputFile()
repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
outputFile = string(fullfile(repoRoot,"movie-frames","experiments","eddy-tide-components-day400.png"));
end
