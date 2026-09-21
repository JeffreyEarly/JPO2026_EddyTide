function [fig, experiment] = MakeEddyTidePVExperiment(options)
% Compatibility wrapper for the main renderer's geostrophic-pv mode.
%
% Reuses the approved cutaway, lighting, palettes, and vorticity-based core
% track. The colored layer is wvt.qgpv/f instead of geostrophic vorticity/f.
% QGPV has units 1/s and is zeta_z - f*diffZG(eta); it is computed from A0.
% The full qgpv field is retained, including any mean-density contribution.
% The gray layer remains wave vertical vorticity, not wave PV.
%
% The shared +/-0.6 PV scale contains both day-0 and day-400 extrema in the
% unforced run. The default opacity scale is one eighth of the default color limit,
% preserving the production renderer's relative opacity-to-color response.
%
% - Topic: Experiment with component visualization
% - Declaration: [fig, experiment] = MakeEddyTidePVExperiment(options)
% - Parameter inputFile: simulation NetCDF file; defaults to the unforced run
% - Parameter day: requested simulation day; default 400
% - Parameter outputFile: PNG filename; an empty string disables export
% - Parameter resolutionScale: integer scale relative to 1920-by-1080; default 1
% - Parameter coreTrack: optional saved anticyclonic vorticity track
% - Parameter cutMode: "geostrophic" (default) follows that track; "fixed" uses manual cuts
% - Parameter xCutKm: fixed x cut coordinate in km; default 0
% - Parameter yCutKm: fixed y cut coordinate in km; default 0
% - Parameter pvColorLimit: symmetric QGPV color limit in units of f; default 0.6
% - Parameter waveColorLimit: symmetric wave vorticity limit in units of f; default 0.08
% - Parameter maximumGeostrophicOpacity: maximum colored-layer opacity; default 0.92
% - Parameter pvOpacityScale: absolute QGPV/f at 63 percent opacity; default 0.075
% - Parameter verticalExaggeration: vertical scale relative to horizontal; default 160
% - Parameter viewAngles: camera azimuth and elevation in degrees; default [35 25]
% - Parameter visible: whether to display the figure window; default true
% - Returns fig: figure handle for the PV experiment
% - Returns experiment: main renderer metadata, including PV statistics, style, and raster precision
arguments (Input)
    options.inputFile (1,1) string {mustBeFile} = defaultInputFile()
    options.day (1,1) double {mustBeFinite,mustBeNonnegative} = 400
    options.outputFile (1,1) string = defaultOutputFile()
    options.resolutionScale (1,1) double {mustBeFinite,mustBeInteger,mustBePositive} = 1
    options.coreTrack (1,1) struct = struct()
    options.cutMode (1,1) string {mustBeMember(options.cutMode,["geostrophic","fixed"])} = "geostrophic"
    options.xCutKm (1,1) double {mustBeFinite} = 0
    options.yCutKm (1,1) double {mustBeFinite} = 0
    options.pvColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.6
    options.waveColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.08
    options.maximumGeostrophicOpacity (1,1) double {mustBeFinite,mustBeBetween(options.maximumGeostrophicOpacity,0,1)} = 0.92
    options.pvOpacityScale (1,1) double {mustBeFinite,mustBePositive} = 0.075
    options.verticalExaggeration (1,1) double {mustBeFinite,mustBePositive} = 160
    options.viewAngles (1,2) double {mustBeFinite} = [35 25]
    options.visible (1,1) logical = true
end
arguments (Output)
    fig (1,1) matlab.ui.Figure
    experiment (1,1) struct
end

options.colorMode = "geostrophic-pv";
frameArguments = namedargs2cell(options);
[fig,experiment] = MakeEddyTideCutawayFrame(frameArguments{:});
end

function inputFile = defaultInputFile()
repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
inputFile = string(fullfile(repoRoot,"model-output","bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc"));
end

function outputFile = defaultOutputFile()
repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
outputFile = string(fullfile(repoRoot,"movie-frames","experiments","eddy-tide-geostrophic-pv.png"));
end
