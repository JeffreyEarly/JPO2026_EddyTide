function tests = TestEddyTideCoreTracking
% Test core identity, periodic motion, missing detections, and reused tracks.
tests = functiontests(localfunctions);
end

function testStrongerDistantCoreCannotStealTrack(testCase)
candidates = {[0 0 -0.1 1 1 1]; [1 0 -0.09 2 1 1; 40 0 -0.3 41 1 1]; [2 0 -0.08 3 1 1; 39 0 -0.4 40 1 1]};
path = followAnticyclonicCores(candidates,[0;86400;172800],[100 100],[1 1]);
verifyEqual(testCase,path.selected(:,1),[0;1;2]);
verifyEqual(testCase,path.status,["seed";"ok";"ok"]);
end

function testPeriodicBoundaryIsNotAJump(testCase)
candidates = {[49 0 -0.1 100 1 1]; [-49 0 -0.09 2 1 1]};
path = followAnticyclonicCores(candidates,[0;86400],[100 100],[1 1]);
verifyEqual(testCase,path.stepKm,[0;2]);
verifyEqual(testCase,path.unwrappedKm(:,1),[49;51]);
end

function testLostCoreIsNeverReacquired(testCase)
candidates = {[0 0 -0.1 1 1 1]; [40 0 -0.3 41 1 1]; [0 0 -0.1 1 1 1]};
path = followAnticyclonicCores(candidates,[0;86400;172800],[100 100],[1 1]);
verifyEqual(testCase,path.status,["seed";"lost";"lost"]);
verifyTrue(testCase,all(isnan(path.selected(2:end,:)),"all"));
end

function testEmptyDetectionStopsTrack(testCase)
path = followAnticyclonicCores({zeros(0,6);[0 0 -0.1 1 1 1]},[0;86400],[100 100],[1 1]);
verifyEqual(testCase,path.status,["lost";"lost"]);
end

function testNearbyCompetingMinimaAreFlagged(testCase)
path = followAnticyclonicCores({[0 0 -0.1 1 1 1];[1 0 -0.08 2 1 1;-1 0 -0.09 100 1 1]},[0;86400],[100 100],[1 1]);
verifyEqual(testCase,path.status(2),"ambiguous");
verifyEqual(testCase,path.selected(2,1),-1);
verifyEqual(testCase,path.runnerUpDistanceKm(2),1);
end

function testPositiveVorticityIsRejected(testCase)
verifyError(testCase,@()followAnticyclonicCores({[0 0 0.1 1 1 1]},0,[100 100],[1 1]),"EddyTide:InvalidCoreCandidates");
end

function testReusedTrackSourceAndCoverage(testCase)
file = string(tempname);
fid = fopen(file,"w");
fclose(fid);
cleanup = onCleanup(@()delete(file));
info = dir(file);
sourcePath = string(fullfile(info.folder,info.name));
time = [0;21600];
track = struct(formatVersion=1,inputFile=sourcePath,sourceBytes=info.bytes,sourceModifiedDatenum=info.datenum,sourceTimeSeconds=time,timeSeconds=time,xKm=[0;1],yKm=[0;0],gridIndex=ones(2,3),depthMeters=[0;0],zetaOverF=[-0.1;-0.09],filteredZetaOverF=[-0.08;-0.07],status=["seed";"ok"],stepKm=[0;1],settings=struct());
validateEddyTideCoreTrack(track,file,time,2);
changed = track;
changed.sourceBytes = 1;
verifyError(testCase,@()validateEddyTideCoreTrack(changed,file,time,2),"EddyTide:StaleCoreTrack");
changed = track;
changed.timeSeconds = time(1);
verifyError(testCase,@()validateEddyTideCoreTrack(changed,file,time,2),"EddyTide:IncompleteCoreTrack");
changed = track;
changed.status(2) = "lost";
verifyError(testCase,@()validateEddyTideCoreTrack(changed,file,time,2),"EddyTide:LostCoreTrack");
end
