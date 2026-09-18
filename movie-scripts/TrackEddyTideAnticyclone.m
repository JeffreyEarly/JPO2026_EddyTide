function track = TrackEddyTideAnticyclone(inputFile, options)
% Follow a continuous anticyclonic core from the first saved model output.
%
% Compute geostrophic vorticity from dv_g/dx - du_g/dy at every saved time.
% Its vertical minimum defines a horizontal anticyclonic footprint. A periodic
% Gaussian average (20 km standard deviation by default) suppresses small
% spatial variations for localization only. Find negative local minima of
% that footprint, seed the strongest one at the first time, and associate
% subsequent minima by proximity using followAnticyclonicCores.
%
% All times are processed consecutively, even when only a late still is wanted.
% Lost tracks are not reacquired. Ambiguous local choices remain flagged.
% The displayed vorticity is never filtered by this function.
%
% - Topic: Track the anticyclonic core
% - Declaration: track = TrackEddyTideAnticyclone(inputFile,options)
% - Parameter inputFile: simulation NetCDF file
% - Parameter lastDay: last requested day; default Inf processes the full file
% - Parameter smoothingKm: Gaussian localization standard deviation in km; default 20
% - Parameter minimumStrength: minimum magnitude of filtered negative zeta_g/f; default 0.005
% - Parameter maximumSpeed: maximum translation speed in m/s, plus a grid-diagonal allowance per output; default 0.25
% - Parameter outputFile: optional MAT file for explicit reuse; default empty
% - Returns track: source identity, settings, path, extrema, and continuity diagnostics
arguments (Input)
    inputFile (1,1) string {mustBeFile}
    options.lastDay (1,1) double {mustBeNonnegative} = Inf
    options.smoothingKm (1,1) double {mustBeFinite,mustBePositive} = 20
    options.minimumStrength (1,1) double {mustBeFinite,mustBePositive} = 0.005
    options.maximumSpeed (1,1) double {mustBeFinite,mustBePositive} = 0.25
    options.outputFile (1,1) string = ""
end
arguments (Output)
    track (1,1) struct
end
sourceInfo = dir(inputFile);
inputFile = string(fullfile(sourceInfo.folder,sourceInfo.name));
allTime = ncread(inputFile,"/wave-vortex/t");
if isnan(options.lastDay) || options.lastDay < allTime(1)/86400 || (isfinite(options.lastDay) && options.lastDay > allTime(end)/86400)
    error("EddyTide:DayOutsideOutput","lastDay must lie within the saved time range, or be Inf for all outputs.")
end
if isinf(options.lastDay)
    iLast = numel(allTime);
else
    [~,iLast] = min(abs(allTime/86400-options.lastDay));
end
time = allTime(1:iLast);
if any(~isfinite(time)) || any(diff(time) <= 0)
    error("EddyTide:InvalidTrackingTimes","Saved times must be finite and strictly increasing.")
end
[wvt,ncfile] = WVTransform.waveVortexTransformFromFile(inputFile,iTime=1,shouldReadOnly=true);
fileCleanup = onCleanup(@()ncfile.close());
x = (wvt.x-wvt.Lx/2)/1000;
y = (wvt.y-wvt.Ly/2)/1000;
domainKm = [wvt.Lx wvt.Ly]/1000;
gridSpacingKm = [wvt.Lx/wvt.Nx wvt.Ly/wvt.Ny]/1000;
kx = 2*pi*ifftshift(-floor(wvt.Nx/2):ceil(wvt.Nx/2)-1)/domainKm(1);
ky = 2*pi*ifftshift(-floor(wvt.Ny/2):ceil(wvt.Ny/2)-1)/domainKm(2);
[K,L] = ndgrid(kx,ky);
gaussian = exp(-0.5*options.smoothingKm^2*(K.^2+L.^2));
candidates = cell(iLast,1);
candidateRawVorticity = cell(iLast,1);
globalMinimum = zeros(iLast,4);
timer = tic;
for iTime = 1:iLast
    % Only A0 is needed for the geostrophic velocity. Its setter invalidates
    % the WVTransform velocity cache; no wave coefficients need to be read.
    wvt.A0 = reshape(ncfile.readVariablesAtIndexAlongDimension('t',iTime,'A0'),wvt.spectralMatrixSize);
    wvt.t = time(iTime);
    qg = (wvt.diffX(wvt.v_g)-wvt.diffY(wvt.u_g))/wvt.f;
    [footprint,iz] = min(qg,[],3);
    filtered = real(ifft2(fft2(footprint).*gaussian));
    isMinimum = filtered < -options.minimumStrength & footprint < 0;
    for dx = -1:1
        for dy = -1:1
            if dx ~= 0 || dy ~= 0
                isMinimum = isMinimum & filtered <= circshift(filtered,[dx dy]);
            end
        end
    end
    indices = find(isMinimum);
    [ix,iy] = ind2sub(size(footprint),indices);
    candidates{iTime} = [x(ix),y(iy),filtered(indices),ix,iy,iz(indices)];
    candidateRawVorticity{iTime} = footprint(indices);
    [minimum,index] = min(footprint(:));
    [ix,iy] = ind2sub(size(footprint),index);
    globalMinimum(iTime,:) = [x(ix),y(iy),minimum,iz(index)];
    if mod(iTime-1,400) == 0 || iTime == iLast
        fprintf("Tracking: read %d/%d outputs (day %.2f), %.1f s elapsed\n",iTime,iLast,time(iTime)/86400,toc(timer));
    end
end
path = followAnticyclonicCores(candidates,time,domainKm,gridSpacingKm,maximumSpeed=options.maximumSpeed);
rawVorticity = nan(iLast,1);
depthMeters = nan(iLast,1);
for iTime = 1:iLast
    if path.status(iTime) ~= "lost"
        rawVorticity(iTime) = candidateRawVorticity{iTime}(path.candidateIndex(iTime));
        depthMeters(iTime) = -wvt.z(path.selected(iTime,6));
    end
end
globalDelta = diff(globalMinimum(:,1:2));
globalDelta = mod(globalDelta+domainKm/2,domainKm)-domainKm/2;
globalStepKm = [0; vecnorm(globalDelta,2,2)];
settings = struct(smoothingKm=options.smoothingKm,minimumStrength=options.minimumStrength,maximumSpeed=options.maximumSpeed);
track = struct(formatVersion=1,inputFile=inputFile,sourceBytes=sourceInfo.bytes,sourceModifiedDatenum=sourceInfo.datenum,sourceTimeSeconds=allTime,timeSeconds=time,day=time/86400,domainKm=domainKm,gridSpacingKm=gridSpacingKm,settings=settings);
track.xKm = path.selected(:,1);
track.yKm = path.selected(:,2);
track.unwrappedKm = path.unwrappedKm;
track.gridIndex = path.selected(:,4:6);
track.depthMeters = depthMeters;
track.zetaOverF = rawVorticity;
track.filteredZetaOverF = path.selected(:,3);
track.stepKm = path.stepKm;
track.stepLimitKm = path.stepLimitKm;
track.status = path.status;
track.eligibleCount = path.eligibleCount;
track.runnerUpDistanceKm = path.runnerUpDistanceKm;
track.globalMinimum = globalMinimum;
track.globalStepKm = globalStepKm;
track.candidates = candidates;
fprintf("Track: %d lost outputs, %d ambiguous outputs; largest step %.3f km (global minimum %.3f km).\n",nnz(track.status=="lost"),nnz(track.status=="ambiguous"),max(track.stepKm,[],"omitmissing"),max(globalStepKm));
if strlength(options.outputFile) > 0
    outputFolder = fileparts(options.outputFile);
    if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
        mkdir(outputFolder)
    end
    save(options.outputFile,"track");
end
end
