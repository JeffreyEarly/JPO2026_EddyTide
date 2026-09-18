function movie = MakeEddyTideCutawayMovie(options)
% Render saved simulation outputs to a 1920-by-1080 H.264 MP4 movie.
%
% Reuses one transform and figure, with the same composition as the still
% renderer. Every selected saved output contributes one frame. Tracking and
% the fixed color scale are independent options. The default is the entire
% unforced simulation at 30 fps with color limits of +/-0.12.
%
% - Topic: Visualize the simulation
% - Declaration: movie = MakeEddyTideCutawayMovie(options)
% - Parameter inputFile: simulation NetCDF file; defaults to the unforced run
% - Parameter outputFile: MP4 filename; defaults to movies/eddy-tide-unforced-30fps.mp4
% - Parameter frameRate: playback frames per second; default 30
% - Parameter quality: VideoWriter MPEG-4 quality from 0 to 100; default 95
% - Parameter firstDay: first requested simulation day; default 0
% - Parameter lastDay: last requested simulation day; default Inf selects the end
% - Parameter outputStride: use every nth saved output within the day range; default 1
% - Parameter cutMode: "geostrophic" tracks the anticyclone; "fixed" disables tracking
% - Parameter coreTrack: optional saved output of TrackEddyTideAnticyclone
% - Parameter xCutKm: fixed x cut coordinate in km; default 0
% - Parameter yCutKm: fixed y cut coordinate in km; default 0
% - Parameter colorLimit: symmetric limits for zeta_z/f; default 0.12
% - Parameter verticalExaggeration: vertical scale relative to horizontal; default 160
% - Parameter viewAngles: camera azimuth and elevation in degrees; default [35 25]
% - Returns movie: output path, source indices, encoding settings, and elapsed time
arguments (Input)
    options.inputFile (1,1) string {mustBeFile} = defaultInputFile()
    options.outputFile (1,1) string = defaultOutputFile()
    options.frameRate (1,1) double {mustBeFinite,mustBePositive} = 30
    options.quality (1,1) double {mustBeFinite,mustBeBetween(options.quality,0,100)} = 95
    options.firstDay (1,1) double {mustBeFinite,mustBeNonnegative} = 0
    options.lastDay (1,1) double {mustBeNonnegative} = Inf
    options.outputStride (1,1) double {mustBeFinite,mustBeInteger,mustBePositive} = 1
    options.cutMode (1,1) string {mustBeMember(options.cutMode,["geostrophic","fixed"])} = "geostrophic"
    options.coreTrack (1,1) struct = struct()
    options.xCutKm (1,1) double {mustBeFinite} = 0
    options.yCutKm (1,1) double {mustBeFinite} = 0
    options.colorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.12
    options.verticalExaggeration (1,1) double {mustBeFinite,mustBePositive} = 160
    options.viewAngles (1,2) double {mustBeFinite} = [35 25]
end
arguments (Output)
    movie (1,1) struct
end

time = ncread(options.inputFile,"/wave-vortex/t");
indices = find(time/86400 >= options.firstDay & time/86400 <= options.lastDay);
if isempty(indices)
    error("EddyTide:EmptyMovieRange","No saved outputs lie in the requested day range.")
end
if numel(indices) > 2 && any(abs(diff(time(indices)) - median(diff(time(indices)))) > 1e-6)
    error("EddyTide:IrregularMovieTimes","Saved outputs must be equally spaced for one output per movie frame.")
end
indices = indices(1:options.outputStride:end);
[outputFolder,outputName,extension] = fileparts(options.outputFile);
if ~strcmpi(extension,".mp4")
    error("EddyTide:MovieExtension","The MPEG-4 output filename must end in .mp4.")
end
if isfile(options.outputFile)
    error("EddyTide:MovieExists","Output already exists: %s. Choose a new outputFile.",options.outputFile)
end
track = options.coreTrack;
if options.cutMode == "geostrophic"
    if isempty(fieldnames(track))
        track = TrackEddyTideAnticyclone(options.inputFile,lastDay=time(indices(end))/86400);
    end
    validateEddyTideCoreTrack(track,options.inputFile,time,indices(end));
    if any(track.status(indices) == "lost") || any(~isfinite(track.xKm(indices))) || any(~isfinite(track.yKm(indices)))
        error("EddyTide:LostCoreTrack","The core track must remain valid throughout the movie.")
    end
end
timer = tic;
frameOptions = rmfield(options,["frameRate","quality","firstDay","lastDay","outputStride"]);
frameOptions.outputFile = "";
frameOptions.day = time(indices(1))/86400;
frameOptions.coreTrack = track;
frameOptions.visible = false;
frameArguments = namedargs2cell(frameOptions);
[fig,~] = MakeEddyTideCutawayFrame(frameArguments{:});
figureCleanup = onCleanup(@()close(fig));
fig.PaperUnits = "inches";
fig.PaperPosition = [0 0 12.8 7.2];
fig.PaperSize = [12.8 7.2];
geometry = getappdata(fig,"EddyTideGeometry");
ax = findobj(fig,Tag="EddyTideAxes");
dayLabel = findall(fig,Tag="EddyTideDay");
cutCaption = findall(fig,Tag="EddyTideCutCaption");
[wvt,ncfile] = WVTransform.waveVortexTransformFromFile(options.inputFile,iTime=indices(1),shouldReadOnly=true);
fileCleanup = onCleanup(@()ncfile.close());
x = [wvt.x; wvt.Lx]/1000 - wvt.Lx/2000;
y = [wvt.y; wvt.Ly]/1000 - wvt.Ly/2000;
z = wvt.z;
if options.cutMode == "geostrophic"
    xCuts = track.xKm(indices);
    yCuts = track.yKm(indices);
    cutLabel = "Anticyclonic core";
else
    xCuts = repmat(options.xCutKm,numel(indices),1);
    yCuts = repmat(options.yCutKm,numel(indices),1);
    cutLabel = "Fixed cut";
end
if any(xCuts <= x(1) | xCuts >= x(end) | yCuts <= y(1) | yCuts >= y(end))
    error("EddyTide:CutOutsideDomain","All cut coordinates must be strictly inside the horizontal domain.")
end
if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
    mkdir(outputFolder)
end
partialFile = string(fullfile(outputFolder,outputName + ".partial.mp4"));
if isfile(partialFile)
    error("EddyTide:MovieExists","An incomplete movie already exists: %s. Choose a new outputFile or move the incomplete movie.",partialFile)
end
writer = VideoWriter(partialFile,"MPEG-4");
writer.FrameRate = options.frameRate;
writer.Quality = options.quality;
open(writer);
writerCleanup = onCleanup(@()close(writer));
nFrames = numel(indices);
vorticityRange = nan(nFrames,2);
for iFrame = 1:nFrames
    iTime = indices(iFrame);
    if iFrame > 1
        wvt.initFromNetCDFFile(ncfile,iTime=iTime);
    end
    q = wvt.zeta_z/wvt.f;
    vorticityRange(iFrame,:) = [min(q(:)) max(q(:))];
    field = griddedInterpolant({x,y,z},q([1:end 1],[1:end 1],:),"linear","none");
    geometry = updateEddyTideCutawayGeometry(ax,field,x,y,z,xCuts(iFrame),yCuts(iFrame),geometry);
    dayLabel.String = sprintf("Day %.2f",time(iTime)/86400);
    cutCaption.String = cutLabel + newline + sprintf("x = %.1f km, y = %.1f km",xCuts(iFrame),yCuts(iFrame)) + newline + sprintf("Vertical exaggeration %g×",options.verticalExaggeration);
    rgb = print(fig,"-RGBImage","-r150");
    if ~isequal(size(rgb),[1080 1920 3])
        error("EddyTide:MovieFrameSize","Expected a 1920-by-1080 RGB frame.")
    end
    writeVideo(writer,rgb);
    if iFrame == 1 || mod(iFrame,50) == 0 || iFrame == nFrames
        elapsed = toc(timer);
        fprintf("Frame %d/%d, day %.2f; elapsed %.1f s, estimated remaining %.1f s\n",iFrame,nFrames,time(iTime)/86400,elapsed,elapsed*(nFrames/iFrame - 1));
    end
end
close(writer);
clear writerCleanup
movefile(partialFile,options.outputFile);
movie = struct(outputFile=options.outputFile,inputFile=options.inputFile,indices=indices,days=time(indices)/86400,frameRate=options.frameRate,quality=options.quality,resolution=[1920 1080],frameCount=nFrames,durationSeconds=nFrames/options.frameRate,cutMode=options.cutMode,colorLimit=options.colorLimit,verticalExaggeration=options.verticalExaggeration,viewAngles=options.viewAngles,xCutKm=xCuts,yCutKm=yCuts,vorticityRange=vorticityRange,elapsedSeconds=toc(timer));
movie.outputStride = options.outputStride;
movie.lighting = fig.UserData.lighting;
save(fullfile(outputFolder,outputName + ".mat"),"movie");
fprintf("Saved %s (%d frames, %.3f s at %g fps).\n",options.outputFile,nFrames,movie.durationSeconds,options.frameRate);
end

function inputFile = defaultInputFile()
repoRoot = fileparts(fileparts(mfilename("fullpath")));
inputFile = string(fullfile(repoRoot,"model-output","bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc"));
end

function outputFile = defaultOutputFile()
repoRoot = fileparts(fileparts(mfilename("fullpath")));
outputFile = string(fullfile(repoRoot,"movies","eddy-tide-unforced-30fps.mp4"));
end
