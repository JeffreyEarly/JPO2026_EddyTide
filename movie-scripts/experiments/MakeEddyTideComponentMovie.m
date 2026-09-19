function movie = MakeEddyTideComponentMovie(options)
% Compatibility entry point for the promoted component movie renderer.
%
% Reuses one transform and figure, with the component palettes, labels,
% lighting, and opacity blend of MakeEddyTideComponentExperiment. Tracking
% uses the complete saved history; outputStride selects frames for display.
% Defaults to all days of the unforced run with outputStride=2 at 30 fps.
% The wave and geostrophic vorticity sum is verified at every rendered time.
%
% - Topic: Experiment with component visualization
% - Declaration: movie = MakeEddyTideComponentMovie(options)
% - Parameter inputFile: simulation NetCDF file; defaults to the unforced run
% - Parameter outputFile: MP4 filename; defaults to movies/eddy-tide-components-12hour-30fps.mp4
% - Parameter frameRate: playback frames per second; default 30
% - Parameter quality: VideoWriter MPEG-4 quality from 0 to 100; default 95
% - Parameter firstDay: first requested simulation day; default 0
% - Parameter lastDay: last requested simulation day; default Inf selects the end
% - Parameter outputStride: use every nth saved output within the day range; default 2
% - Parameter cutMode: "geostrophic" tracks the anticyclone; "fixed" disables tracking
% - Parameter coreTrack: optional saved output of TrackEddyTideAnticyclone
% - Parameter xCutKm: fixed x cut coordinate in km; default 0
% - Parameter yCutKm: fixed y cut coordinate in km; default 0
% - Parameter geostrophicColorLimit: symmetric geostrophic zeta/f limits; default 0.12
% - Parameter waveColorLimit: symmetric wave zeta/f limits; default 0.08
% - Parameter maximumGeostrophicOpacity: upper limit of colored-layer opacity; default 0.92
% - Parameter geostrophicOpacityScale: absolute geostrophic zeta/f at 63 percent of maximum opacity; default 0.015
% - Parameter verticalExaggeration: vertical scale relative to horizontal; default 160
% - Parameter viewAngles: camera azimuth and elevation in degrees; default [35 25]
% - Returns movie: source indices, style, encoding settings, component statistics, and elapsed time
arguments (Input)
    options.inputFile (1,1) string {mustBeFile} = defaultInputFile()
    options.outputFile (1,1) string = defaultOutputFile()
    options.frameRate (1,1) double {mustBeFinite,mustBePositive} = 30
    options.quality (1,1) double {mustBeFinite,mustBeBetween(options.quality,0,100)} = 95
    options.firstDay (1,1) double {mustBeFinite,mustBeNonnegative} = 0
    options.lastDay (1,1) double {mustBeNonnegative} = Inf
    options.outputStride (1,1) double {mustBeFinite,mustBeInteger,mustBePositive} = 2
    options.cutMode (1,1) string {mustBeMember(options.cutMode,["geostrophic","fixed"])} = "geostrophic"
    options.coreTrack (1,1) struct = struct()
    options.xCutKm (1,1) double {mustBeFinite} = 0
    options.yCutKm (1,1) double {mustBeFinite} = 0
    options.geostrophicColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.12
    options.waveColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.08
    options.maximumGeostrophicOpacity (1,1) double {mustBeFinite,mustBeBetween(options.maximumGeostrophicOpacity,0,1)} = 0.92
    options.geostrophicOpacityScale (1,1) double {mustBeFinite,mustBePositive} = 0.015
    options.verticalExaggeration (1,1) double {mustBeFinite,mustBePositive} = 160
    options.viewAngles (1,2) double {mustBeFinite} = [35 25]
end
arguments (Output)
    movie (1,1) struct
end

% Keep earlier movie commands and option names working after promotion.
movieOptions = rmfield(options,"geostrophicColorLimit");
movieOptions.colorLimit = options.geostrophicColorLimit;
movieArguments = namedargs2cell(movieOptions);
movie = MakeEddyTideCutawayMovie(movieArguments{:});
end

function inputFile = defaultInputFile()
repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
inputFile = string(fullfile(repoRoot,"model-output","bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc"));
end

function outputFile = defaultOutputFile()
repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
outputFile = string(fullfile(repoRoot,"movies","eddy-tide-components-12hour-30fps.mp4"));
end
