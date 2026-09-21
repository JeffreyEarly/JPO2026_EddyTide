function movie = MakeEddyTideCutawayMovie(options)
% Render the cutaway as an H.264 movie or a numbered PNG sequence.
%
% Reuses one transform and figure, with the component palettes, labels,
% lighting, typography, and opacity blend of MakeEddyTideCutawayFrame. Tracking
% uses the complete saved history; outputStride selects frames for display.
% Defaults to all days of the unforced run with outputStride=2 at 30 fps.
% Component mode verifies the wave and geostrophic vorticity sum at each time.
% The "geostrophic-pv" mode checks qgpv = zeta_z - f*diffZG(eta) instead.
% PNG output bypasses VideoWriter and saves lossless frames plus frames.mat.
% Existing video files or nonempty frame folders are never overwritten.
%
% - Topic: Visualize the simulation
% - Declaration: movie = MakeEddyTideCutawayMovie(options)
% - Parameter inputFile: simulation NetCDF file; defaults to the unforced run
% - Parameter outputFormat: "video" (default) or "png" for a frame sequence
% - Parameter outputFile: MP4 filename for video output; defaults to movies/eddy-tide-cutaway-12hour-30fps.mp4
% - Parameter outputFolder: PNG destination; defaults to movie-frames/eddy-tide-sequence
% - Parameter resolutionScale: integer pixel scale relative to 1920-by-1080; default 1
% - Parameter frameRate: playback frames per second, recorded as metadata for PNG output; default 30
% - Parameter quality: VideoWriter MPEG-4 quality from 0 to 100; unused for lossless PNG; default 95
% - Parameter firstDay: first requested simulation day; default 0
% - Parameter lastDay: last requested simulation day; default Inf selects the end
% - Parameter outputStride: use every nth saved output within the day range; default 2
% - Parameter cutMode: "geostrophic" tracks the anticyclone; "fixed" disables tracking
% - Parameter coreTrack: optional saved output of TrackEddyTideAnticyclone
% - Parameter xCutKm: fixed x cut coordinate in km; default 0
% - Parameter yCutKm: fixed y cut coordinate in km; default 0
% - Parameter colorMode: "components" (default), "geostrophic-pv", or "total"
% - Parameter colorLimit: symmetric geostrophic (or total) vorticity limits in units of f; default 0.12
% - Parameter waveColorLimit: symmetric wave zeta/f limits; default 0.08
% - Parameter pvColorLimit: symmetric QGPV limits in units of f for "geostrophic-pv"; default 0.6
% - Parameter pvOpacityScale: absolute QGPV/f at 63 percent of maximum opacity; default 0.075
% - Parameter maximumGeostrophicOpacity: upper limit of colored-layer opacity; default 0.92
% - Parameter geostrophicOpacityScale: absolute geostrophic zeta/f at 63 percent of maximum opacity; default 0.015
% - Parameter verticalExaggeration: vertical scale relative to horizontal; default 160
% - Parameter viewAngles: camera azimuth and elevation in degrees; default [35 25]
% - Returns movie: source indices, style, encoding settings, component statistics, and elapsed time
arguments (Input)
    options.inputFile (1,1) string {mustBeFile} = defaultInputFile()
    options.outputFormat (1,1) string {mustBeMember(options.outputFormat,["video","png"])} = "video"
    options.outputFile (1,1) string = defaultOutputFile()
    options.outputFolder (1,1) string = defaultOutputFolder()
    options.resolutionScale (1,1) double {mustBeFinite,mustBeInteger,mustBePositive} = 1
    options.frameRate (1,1) double {mustBeFinite,mustBePositive} = 30
    options.quality (1,1) double {mustBeFinite,mustBeBetween(options.quality,0,100)} = 95
    options.firstDay (1,1) double {mustBeFinite,mustBeNonnegative} = 0
    options.lastDay (1,1) double {mustBeNonnegative} = Inf
    options.outputStride (1,1) double {mustBeFinite,mustBeInteger,mustBePositive} = 2
    options.cutMode (1,1) string {mustBeMember(options.cutMode,["geostrophic","fixed"])} = "geostrophic"
    options.coreTrack (1,1) struct = struct()
    options.xCutKm (1,1) double {mustBeFinite} = 0
    options.yCutKm (1,1) double {mustBeFinite} = 0
    options.colorMode (1,1) string {mustBeMember(options.colorMode,["components","geostrophic-pv","total"])} = "components"
    options.colorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.12
    options.waveColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.08
    options.pvColorLimit (1,1) double {mustBeFinite,mustBePositive} = 0.6
    options.pvOpacityScale (1,1) double {mustBeFinite,mustBePositive} = 0.075
    options.maximumGeostrophicOpacity (1,1) double {mustBeFinite,mustBeBetween(options.maximumGeostrophicOpacity,0,1)} = 0.92
    options.geostrophicOpacityScale (1,1) double {mustBeFinite,mustBePositive} = 0.015
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
if options.outputFormat == "video"
    [destinationFolder,outputName,extension] = fileparts(options.outputFile);
    if ~strcmpi(extension,".mp4")
        error("EddyTide:MovieExtension","The MPEG-4 output filename must end in .mp4.")
    end
    partialFile = string(fullfile(destinationFolder,outputName + ".partial.mp4"));
    metadataFile = string(fullfile(destinationFolder,outputName + ".mat"));
    if isfile(options.outputFile) || isfile(partialFile) || isfile(metadataFile)
        error("EddyTide:MovieExists","A movie, partial movie, or sidecar already exists for %s. Choose a new outputFile.",options.outputFile)
    end
else
    destinationFolder = options.outputFolder;
    if strlength(destinationFolder) == 0 || isfile(destinationFolder)
        error("EddyTide:InvalidFrameFolder","outputFolder must name a new or empty directory.")
    end
    if isfolder(destinationFolder)
        entries = dir(destinationFolder);
        if any(~ismember(string({entries.name}),[".",".."]))
            error("EddyTide:FrameFolderNotEmpty","Frame folder is not empty: %s. Choose a new outputFolder.",destinationFolder)
        end
    end
    metadataFile = string(fullfile(destinationFolder,"frames.mat"));
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
frameOptions = rmfield(options,["outputFormat","outputFolder","frameRate","quality","firstDay","lastDay","outputStride"]);
frameOptions.outputFile = "";
frameOptions.day = time(indices(1))/86400;
frameOptions.coreTrack = track;
frameOptions.visible = false;
frameArguments = namedargs2cell(frameOptions);
[fig,firstFrame] = MakeEddyTideCutawayFrame(frameArguments{:});
style = firstFrame.style;
figureCleanup = onCleanup(@()close(fig));
resolution = options.resolutionScale*[1920 1080];
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
if strlength(destinationFolder) > 0 && ~isfolder(destinationFolder)
    mkdir(destinationFolder)
end
nFrames = numel(indices);
frameFiles = strings(0,1);
if options.outputFormat == "video"
    writer = VideoWriter(partialFile,"MPEG-4");
    writer.FrameRate = options.frameRate;
    writer.Quality = options.quality;
    open(writer);
    writerCleanup = onCleanup(@()close(writer));
else
    frameFiles = fullfile(destinationFolder,compose("frame-%06d.png",(1:nFrames).'));
end
vorticityRange = nan(nFrames,2);
if options.colorMode ~= "total"
    geostrophicRange = nan(nFrames,2);
    waveRange = nan(nFrames,2);
    identityResidual = nan(nFrames,1);
    saturatedGridFraction = nan(nFrames,2);
end
for iFrame = 1:nFrames
    iTime = indices(iFrame);
    if iFrame > 1
        wvt.initFromNetCDFFile(ncfile,iTime=iTime);
    end
    qt = wvt.zeta_z/wvt.f;
    vorticityRange(iFrame,:) = [min(qt(:)) max(qt(:))];
    if options.colorMode ~= "total"
        if options.colorMode == "geostrophic-pv"
            [qg,identityResidual(iFrame)] = eddyTideGeostrophicPV(wvt);
        else
            qg = (wvt.diffX(wvt.v_g) - wvt.diffY(wvt.u_g))/wvt.f;
        end
        qw = (wvt.diffX(wvt.v_w) - wvt.diffY(wvt.u_w))/wvt.f;
        if options.colorMode == "components"
            identityResidual(iFrame) = max(abs(qt - qg - qw),[],"all");
            if identityResidual(iFrame) > 1e-10*max(1,max(abs(qt),[],"all"))
                error("EddyTide:IncompleteComponentDecomposition","Component vorticities do not reconstruct total vorticity at day %.2f; residual %.3g.",time(iTime)/86400,identityResidual(iFrame))
            end
        end
        geostrophicRange(iFrame,:) = [min(qg(:)) max(qg(:))];
        waveRange(iFrame,:) = [min(qw(:)) max(qw(:))];
        saturatedGridFraction(iFrame,:) = [nnz(abs(qg)>style.geostrophicColorLimit)/numel(qg), nnz(abs(qw)>options.waveColorLimit)/numel(qw)];
        geostrophicField = griddedInterpolant({x,y,z},qg([1:end 1],[1:end 1],:),"linear","none");
        waveField = griddedInterpolant({x,y,z},qw([1:end 1],[1:end 1],:),"linear","none");
        geometry = updateEddyTideCutawayGeometry(ax,geostrophicField,x,y,z,xCuts(iFrame),yCuts(iFrame),geometry);
        applyEddyTideComponentColors(geometry,geostrophicField,waveField,style);
    else
        field = griddedInterpolant({x,y,z},qt([1:end 1],[1:end 1],:),"linear","none");
        geometry = updateEddyTideCutawayGeometry(ax,field,x,y,z,xCuts(iFrame),yCuts(iFrame),geometry);
    end
    dayLabel.String = sprintf("Day %.2f",time(iTime)/86400);
    cutCaption.String = cutLabel + newline + sprintf("x = %.1f km, y = %.1f km",xCuts(iFrame),yCuts(iFrame));
    [rgb,raster] = renderEddyTideFigure(fig,options.resolutionScale);
    if options.outputFormat == "video"
        writeVideo(writer,rgb);
    else
        % Finish each image before publishing its final sequence filename.
        partialFrame = fullfile(destinationFolder,compose("frame-%06d.partial.png",iFrame));
        imwrite(rgb,partialFrame,"png");
        movefile(partialFrame,frameFiles(iFrame));
    end
    if iFrame == 1 || mod(iFrame,50) == 0 || iFrame == nFrames
        elapsed = toc(timer);
        fprintf("Frame %d/%d, day %.2f; elapsed %.1f s, estimated remaining %.1f s\n",iFrame,nFrames,time(iTime)/86400,elapsed,elapsed*(nFrames/iFrame - 1));
    end
end
if options.outputFormat == "video"
    close(writer);
    clear writerCleanup
    movefile(partialFile,options.outputFile);
    outputFile = options.outputFile;
    destination = outputFile;
else
    outputFile = "";
    destination = destinationFolder;
end
movie = struct(outputFormat=options.outputFormat,outputFile=outputFile,outputFolder=destinationFolder,metadataFile=metadataFile,frameFiles=frameFiles,inputFile=options.inputFile,indices=indices,days=time(indices)/86400,frameRate=options.frameRate,quality=options.quality,resolution=resolution,frameCount=nFrames,durationSeconds=nFrames/options.frameRate,cutMode=options.cutMode,colorMode=options.colorMode,colorLimit=options.colorLimit,style=style,verticalExaggeration=options.verticalExaggeration,viewAngles=options.viewAngles,xCutKm=xCuts,yCutKm=yCuts,vorticityRange=vorticityRange,elapsedSeconds=toc(timer));
movie.resolutionScale = options.resolutionScale;
movie.raster = raster;
movie.outputStride = options.outputStride;
movie.lighting = firstFrame.lighting;
if options.colorMode ~= "total"
    movie.waveRange = waveRange;
    movie.saturatedGridFraction = saturatedGridFraction;
    if options.colorMode == "geostrophic-pv"
        movie.pvColorLimit = options.pvColorLimit;
        movie.pvOpacityScale = options.pvOpacityScale;
        movie.pvRange = geostrophicRange;
        movie.pvRangePerSecond = sort(geostrophicRange*wvt.f,2);
        movie.pvIdentityResidual = identityResidual;
        movie.saturatedGridFractionColumns = ["geostrophicPV","waveVorticity"];
    else
        movie.geostrophicRange = geostrophicRange;
        movie.decompositionResidual = identityResidual;
        movie.saturatedGridFractionColumns = ["geostrophic","wave"];
    end
end
save(metadataFile,"movie");
fprintf("Saved %s (%d frames, %.3f s at %g fps).\n",destination,nFrames,movie.durationSeconds,options.frameRate);
end

function inputFile = defaultInputFile()
repoRoot = fileparts(fileparts(mfilename("fullpath")));
inputFile = string(fullfile(repoRoot,"model-output","bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc"));
end

function outputFile = defaultOutputFile()
repoRoot = fileparts(fileparts(mfilename("fullpath")));
outputFile = string(fullfile(repoRoot,"movies","eddy-tide-cutaway-12hour-30fps.mp4"));
end

function outputFolder = defaultOutputFolder()
repoRoot = fileparts(fileparts(mfilename("fullpath")));
outputFolder = string(fullfile(repoRoot,"movie-frames","eddy-tide-sequence"));
end
