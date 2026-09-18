function validateEddyTideCoreTrack(track, inputFile, time, iTime)
% Verify an explicitly reused core track belongs to the requested snapshot.
%
% - Topic: Track the anticyclonic core
% - Declaration: validateEddyTideCoreTrack(track,inputFile,time,iTime)
% - Parameter track: output of TrackEddyTideAnticyclone
% - Parameter inputFile: simulation file used for rendering
% - Parameter time: complete saved time coordinate, in seconds
% - Parameter iTime: requested saved output index
arguments (Input)
    track (1,1) struct
    inputFile (1,1) string {mustBeFile}
    time (:,1) double {mustBeFinite}
    iTime (1,1) double {mustBeInteger,mustBePositive}
end
required = ["formatVersion","inputFile","sourceBytes","sourceModifiedDatenum","sourceTimeSeconds","timeSeconds","xKm","yKm","gridIndex","depthMeters","zetaOverF","filteredZetaOverF","status","stepKm","settings"];
if ~all(isfield(track,required)) || ~isequal(track.formatVersion,1)
    error("EddyTide:InvalidCoreTrack","Use a track returned by TrackEddyTideAnticyclone.")
end
sourceInfo = dir(inputFile);
sourcePath = string(fullfile(sourceInfo.folder,sourceInfo.name));
if sourcePath ~= track.inputFile || sourceInfo.bytes ~= track.sourceBytes || sourceInfo.datenum ~= track.sourceModifiedDatenum || ~isequal(time,track.sourceTimeSeconds)
    error("EddyTide:StaleCoreTrack","The track source does not match the current simulation file. Rebuild it with TrackEddyTideAnticyclone.")
end
nTrack = numel(track.timeSeconds);
if nTrack > numel(time) || iTime > numel(time) || iTime > nTrack || ~isequal(track.timeSeconds,time(1:nTrack))
    error("EddyTide:IncompleteCoreTrack","The track must cover every saved output from the first time through the requested frame.")
end
if numel(track.xKm) ~= nTrack || numel(track.yKm) ~= nTrack || numel(track.zetaOverF) ~= nTrack || numel(track.filteredZetaOverF) ~= nTrack || numel(track.depthMeters) ~= nTrack || numel(track.status) ~= nTrack || numel(track.stepKm) ~= nTrack || ~isequal(size(track.gridIndex),[nTrack 3])
    error("EddyTide:InvalidCoreTrack","All core track arrays must contain one entry per tracked time.")
end
if track.status(iTime) == "lost"
    error("EddyTide:LostCoreTrack","Core tracking was lost before day %.2f. Inspect the track; the renderer will not switch to a different eddy automatically.",time(iTime)/86400)
end
if ~all(isfinite([track.xKm(iTime),track.yKm(iTime),track.zetaOverF(iTime)])) || track.zetaOverF(iTime) >= 0
    error("EddyTide:InvalidCoreTrack","The selected tracked core must have finite coordinates and negative zeta_g/f.")
end
end
