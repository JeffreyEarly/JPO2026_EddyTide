function EddyTideProfiles = computeEddyTideProfiles(wvd)
% loadFigureDefaults;

[fpath,fname,~] = fileparts(wvd.wvpath);
if ~isempty(fpath)
    profilespath = fullfile(fpath,strcat(fname,"-EddyTideProfiles.mat"));
else
    profilespath = fullfile(pwd,strcat(fname,"-EddyTideProfiles.mat"));
end

try
    EddyTideProfiles = load(profilespath);
catch
    wvt = wvd.wvt;
    t = wvd.t_wv;
    [hkeg,hkew,vkew,shsg,shsw,svsw,Zg,Yg,peg,pew] = deal(zeros(wvt.Nz,wvt.Nx,length(t)));

    integrationLastInformWallTime = datetime('now');
    loopStartTime = integrationLastInformWallTime;
    integrationLastInformLoopNumber = 1;
    integrationInformTime = 10;
    timeIndices = 1:length(t);
    fprintf("Starting loop to compute profiles for %d time indices.\n",length(timeIndices));

    for timeIndex=1:length(t)
        deltaWallTime = datetime('now')-integrationLastInformWallTime;
        if ( seconds(deltaWallTime) > integrationInformTime)
            wallTimePerLoopTime = deltaWallTime / (timeIndex - integrationLastInformLoopNumber);
            wallTimeRemaining = wallTimePerLoopTime*(length(timeIndices) - timeIndex + 1);
            fprintf('Time index %d of %d. Estimated time to finish is %s (%s)\n', timeIndex, length(timeIndices), wallTimeRemaining, datetime(datetime('now')+wallTimeRemaining,TimeZone='local',Format='d-MMM-y HH:mm:ss Z')) ;
            integrationLastInformWallTime = datetime('now');
            integrationLastInformLoopNumber = timeIndex;
        end

        wvd.iTime = timeIndex;

        ug = wvt.u_g + wvt.u_mda;
        vg = wvt.v_g + wvt.v_mda;

        uw = wvt.u_w + wvt.u_io;
        vw = wvt.v_w + wvt.v_io;
        ww = wvt.w_w + wvt.w_io;

        hkeg(:,:,timeIndex) = 0.5*squeeze(mean(ug.^2 + vg.^2,1))';
        hkew(:,:,timeIndex) = 0.5*squeeze(mean(uw.^2 + vw.^2,1))';
        vkew(:,:,timeIndex) = 0.5*squeeze(mean(ww.^2,1))';

        peg(:,:,timeIndex) = 0.5 * wvt.N2 .* squeeze(mean((wvt.eta_g).^2,1))';
        pew(:,:,timeIndex) = 0.5 * wvt.N2 .* squeeze(mean((wvt.eta_w).^2,1))';

        uzg = wvt.diffZF(ug);
        vzg = wvt.diffZF(vg);

        uzw = wvt.diffZF(uw);
        vzw = wvt.diffZF(vw);
        wzw = wvt.diffZF(ww);

        shsg(:,:,timeIndex) = squeeze(mean(uzg.^2 + vzg.^2,1))';
        shsw(:,:,timeIndex) = squeeze(mean(uzw.^2 + vzw.^2,1))';
        svsw(:,:,timeIndex) = squeeze(mean(wzw.^2,1))';

        %qg = wvt.diffX(vg)-wvt.diffY(ug) - wvt.f * wvt.diffZG(wvt.eta_g);
        Zg(:,:,timeIndex) = squeeze(mean(wvt.qgpv.^2,1))';
        Yg(:,:,timeIndex) = squeeze(mean(wvt.apv.^2,1))';
    end
    deltaLoopTime = datetime('now')-loopStartTime;
    fprintf("Total loop time %s, which is %s per time index.\n",deltaLoopTime,deltaLoopTime/length(timeIndices));

    clear EddyTideProfiles
    save(profilespath,"hkeg","hkew","vkew","peg","pew","shsg","shsw","svsw","Yg","Zg");
    EddyTideProfiles = load(profilespath);
end

end
