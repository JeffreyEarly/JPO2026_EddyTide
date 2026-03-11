function EddyTideProfiles = ComputeEddyTideProfiles(wvd)
loadFigureDefaults;

try
    EddyTideProfiles = load(datadir + "EddyTideProfiles.mat");
catch
    wvt = wvd.wvt;
    t = wvd.t_wv;
    [hkeg,hkew,vkew,shsg,shsw,svsw,Zg,Yg,peg,pew] = vzeros(wvt.Nz,wvt.Nx,length(t));
    for iTime=1:length(t)
        iTime
        % wvt.initFromNetCDFFile(ncfile,iTime=i)
        wvd.iTime = iTime;

        ug = wvt.u_g + wvt.u_mda;
        vg = wvt.v_g + wvt.v_mda;

        uw = wvt.u_w + wvt.u_io;
        vw = wvt.v_w + wvt.v_io;
        ww = wvt.w_w + wvt.w_io;

        hkeg(:,:,iTime) = 0.5*squeeze(mean(ug.^2 + vg.^2,1))';
        hkew(:,:,iTime) = 0.5*squeeze(mean(uw.^2 + vw.^2,1))';
        vkew(:,:,iTime) = 0.5*squeeze(mean(ww.^2,1))';

        peg(:,:,iTime) = 0.5 * wvt.N2 .* squeeze(mean((wvt.eta_g).^2,1))';
        pew(:,:,iTime) = 0.5 * wvt.N2 .* squeeze(mean((wvt.eta_w).^2,1))';

        uzg = wvt.diffZF(ug);
        vzg = wvt.diffZF(vg);

        uzw = wvt.diffZF(uw);
        vzw = wvt.diffZF(vw);
        wzw = wvt.diffZF(ww);

        shsg(:,:,iTime) = squeeze(mean(uzg.^2 + vzg.^2,1))';
        shsw(:,:,iTime) = squeeze(mean(uzw.^2 + vzw.^2,1))';
        svsw(:,:,iTime) = squeeze(mean(wzw.^2,1))';

        %qg = wvt.diffX(vg)-wvt.diffY(ug) - wvt.f * wvt.diffZG(wvt.eta_g);
        Zg(:,:,iTime) = squeeze(mean(wvt.qgpv.^2,1))';
        Yg(:,:,iTime) = squeeze(mean(wvt.apv.^2,1))';
    end
    clear EddyTideProfiles
    save(datadir + "EddyTideProfiles.mat","hkeg","hkew","vkew","peg","pew","shsg","shsw","svsw","Yg","Zg");
    EddyTideProfiles = load(datadir + "EddyTideProfiles.mat");
end

end

% return;
% 
% %ComputeEddyTideProfiles
% 
% [hkeg,hkew,vkew,shsg,shsw,svsw,Zg,peg,pew,pe2ke,pe2keg,pe2kew] = vzeros(wvt.Nz,wvt.Nx,length(t));
% 
% [gwg,wwg] = vzeros(wvt.Nz,wvt.Nx,length(t),3);
% 
% try
%     load EddyTideProfiles
%     use EddyTideProfiles
% catch
%     for i=1:length(t)
%         i
% 
%         wvt.initFromNetCDFFile(ncfile,iTime=i)
% 
%         pe2ke(:,:,i) = squeeze(mean(-N2*wvt.w.*wvt.eta,1))';
%         pe2keg(:,:,i) = squeeze(mean(-N2*wvt.w.*wvt.eta_g,1))';
%         pe2kew(:,:,i) = squeeze(mean(-N2*wvt.w.*wvt.eta_w,1))';
% 
%         ug = wvt.u_g + wvt.u_mda;
%         vg = wvt.v_g + wvt.v_mda;
%         etag = wvt.eta_g + wvt.eta_mda;
% 
%         uw = wvt.u_w + wvt.u_io;
%         vw = wvt.v_w + wvt.v_io;
%         ww = wvt.w_w + wvt.w_io;
%         etaw = wvt.eta_w + wvt.eta_w;
% 
%         divw = wvt.diffX(uw)+wvt.diffY(vw);
%         zetaw = wvt.diffX(vw)-wvt.diffY(uw);
%         sigw = wvt.diffX(vw)+wvt.diffY(uw);
% 
%         uzw = wvt.diffZF(uw);
%         vzw = wvt.diffZF(vw);
% 
%         gwg(:,:,i,1) = - squeeze(mean((ug.^2+vg.^2).*divw,1))';
%         gwg(:,:,i,2) = - squeeze(mean(ug.*vg.*sigw,1))';
%         gwg(:,:,i,3) = - squeeze(mean(N2.*etag.*...
%             (ug.*wvt.diffX(etaw)+vg.*wvt.diffY(etaw)),1))';
% 
%         wwg(:,:,i,1) = - squeeze(mean(ug.*ww.*uzw+vg.*ww.*vzw,1))';
%         wwg(:,:,i,2) = - squeeze(mean((uw.*vg-vw.*ug).*zetaw,1))';
%         wwg(:,:,i,3) = - squeeze(mean(N2.*etag.*...
%             (uw.*wvt.diffX(etaw)+vw.*wvt.diffY(etaw)),1))';
%     end
%     %clear EddyTideProfiles
%     %matsave EddyTideProfiles hkeg hkew vkew peg pew shsg shsw svsw Zg
% end
% 
% jpcolor(squeeze(mean(pe2ke,2)))
% 
% plot(squeeze(mean(pe2ke,[1 2])))
% 
% plot(t,[squeeze(mean(pe2ke,[1 2])) squeeze(mean(pe2keg,[1 2])) squeeze(mean(pe2kew,[1 2]))])
% 
% plot(t,vfilt([squeeze(mean(pe2ke,[1 2])) squeeze(mean(pe2keg,[1 2])) squeeze(mean(pe2kew,[1 2]))],21))
% 
% 
% plot(t,squeeze(mean(gwg,[1 2])))
% hold on
% plot(t,sum(squeeze(mean(gwg,[1 2])),2))
% 
% jpcolor(squeeze(mean(gwg(:,:,:,1),1)))
% 
% %caxis([-1 1]*1e-10)