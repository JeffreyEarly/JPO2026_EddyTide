%MakeEddySnapshots

loadFigureDefaults;

x = (wvt.x-mean(wvt.x))/1e3;
y = (wvt.y-mean(wvt.y))/1e3; 

ci = (-50:50)./50*.15;

Times = 4*(maxDays/4)*(0:4)+1;
figure(WindowStyle="normal")
n=0;
for j=1:3
    for i=1:5
        n=n+1;
        subplot(3,5,n)
        iTime = Times(i);
        wvd.iTime = iTime;
        % wvt.initFromNetCDFFile(ncfile,iTime=iTime)
        switch j
            case 1 
                zeta=wvt.zeta_z(:,:,end);
            case 2
                zeta=wvt.diffX(wvt.v_g(:,:,end))-wvt.diffY(wvt.u_g(:,:,end));
            case 3
                zeta=wvt.diffX(wvt.v_w(:,:,end))-wvt.diffY(wvt.u_w(:,:,end));
        end
        zeta=zeta./wvt.f;
        zeta(zeta<min(ci))=min(ci);
        zeta(zeta>max(ci))=max(ci);
        jpcolor(x, y, zeta'), axis equal, axis tight
        axis equal, axis tight
        clim([-.15 .15])
        if i==1 && j==2
            hc = colorbar(gca,'South');
            hc.Label.String = 'Relative Vorticity $\zeta/f_0$';
            hc.Label.Interpreter = 'latex';
        end
        if j==2
            text(50,300,['t = ' int2str(wvd.t_wv(Times(i))/86400) ' days']);
        end
        colormap(divergingcolormap)
        xtick(-400:100:400),ytick(-400:100:400)
    end
end
packfig(3,5,'both')

% fontsize 10 10 10 10
set(gcf,'Units','inches')
set(gcf,'Position',[1 1 12 6.8])
exportgraphics(gcf,figureFolder + "/" + "Figure3_EddySnapShots.png",Resolution=500)

%--------------------------------------------------------------------------
% %ci = (-50:50)./50*.15;
% %Times = 1:14*4:407*4;
% Times = round(linspace(1,1601,30));
% slope = -1.5;
% theta = angle(1 + slope*1i);
% 
% figure
% n=0;
% for j=1:6
%     for i=1:5
%         n=n+1;
%         subplot(6,5,n)
%         %iTime = 1+(-1)*400;
%         %iTime = Times(n);
%         iTime = round(Times(n));
%         wvt.initFromNetCDFFile(ncfile,iTime=iTime)
%         zeta=wvt.diffX(wvt.v_g(:,:,end))-wvt.diffY(wvt.u_g(:,:,end));
%         zeta=zeta./wvt.f;
%         zeta(zeta<min(ci))=min(ci);
%         zeta(zeta>max(ci))=max(ci);
%         jpcolor(x, y, zeta'), axis equal, axis tight 
%         if n == 1 || n == 18
%             hold on, plot(0*x,x,'color',[1 1 1]*0.7,'linewidth',0.5)
%         elseif n == 22
%             x0 = x.*real(exp(1i*theta));
%             y0 = y.*imag(exp(1i*theta));
%             hold on, plot(x0,y0,'color',[1 1 1]*0.7,'linewidth',0.5)
%         end
%         axis equal, axis([-1 1 -1 1]*max(x))
%         clim([-.15 .15])
%         if i==5 && j==1  
%             hc = colorbar(gca,'South');
%             hc.Label.String = 'Relative Vorticity $\zeta/f_0$';
%             hc.Label.Interpreter = 'latex';
%             hc.Ticks = (-0.1:.1:.1);
%         end
%         text(50,300,['t = ' int2str(t(Times(n))) ' days']);
%         colormap(divergingcolormap)
%         xtick(-400:100:400),ytick(-400:100:400)
%         noxlabels, noylabels, xticks([]),yticks([])
% 
%         if t(iTime)<round(t_phaseII) || t(iTime)>round(t_phaseIII)
%             set(gca,'XColor',0.8*[1 1 1])
%             set(gca,'YColor',0.8*[1 1 1])
%         else
%             set(gca,'XColor',0*[1 1 1])
%             set(gca,'YColor',0*[1 1 1])
%         end
%     end
% end
% packfig(6,5,'both')
% 
% set(gcf,'paperposition',[1 1 12 13.75])
% jprint(printdir,'EddyFlipBook','-r500')
% %--------------------------------------------------------------------------
% %Same as above but at -689 m, and only during Phase II
% 
% %Times = 1:14*4:407*4;
% figure
% n=17;
% for i=1:5
%     n=n+1;
%     subplot(1,5,n-17)
%     iTime = Times(n);
%     wvt.initFromNetCDFFile(ncfile,iTime=iTime)
%     zeta=wvt.diffX(wvt.v_g(:,:,20))-wvt.diffY(wvt.u_g(:,:,20));
%     zeta=zeta./wvt.f;
%     zeta(zeta<min(ci))=min(ci);
%     zeta(zeta>max(ci))=max(ci);
%     jpcolor(x, y, zeta'), axis equal, axis tight
%     axis equal, axis([-1 1 -1 1]*max(x))
%     clim([-.15 .15]/4)
%     if i==5
%         hc = colorbar(gca,'South');
%         hc.Label.String = 'Relative Vorticity $\zeta/f_0$';
%         hc.Label.Interpreter = 'latex';
%         hc.Ticks = (-0.04:.02:.04);
%     end
%     if n == 1 || n == 18
%         hold on, plot(0*x,x,'color',[1 1 1]*0.7,'linewidth',0.5)
%     elseif n == 22
%         x0 = x.*real(exp(1i*theta));
%         y0 = y.*imag(exp(1i*theta));
%         hold on, plot(x0,y0,'color',[1 1 1]*0.7,'linewidth',0.5)
%     end
%     text(50,300,['t = ' int2str(t(Times(n))) ' days']);
%     colormap(divergingcolormap)
%     xtick(-400:100:400),ytick(-400:100:400)
%     noxlabels, noylabels, xticks([]),yticks([])
% 
%     if t(iTime)<round(t_phaseII) || t(iTime)>round(t_phaseIII)
%         set(gca,'XColor',0.8*[1 1 1])
%         set(gca,'YColor',0.8*[1 1 1])
%     else
%         set(gca,'XColor',0*[1 1 1])
%         set(gca,'YColor',0*[1 1 1])
%     end
% end
% 
% packfig(1,5,'columns')
% 
% set(gcf,'paperposition',[1 1 12 2.5])
% jprint(printdir,'EddyFlipBookDeep','-r500')
%--------------------------------------------------------------------------
%Eddy Movie

if false
for  n = 561:1601
    wvt.initFromNetCDFFile(ncfile,iTime=n)

    subplot(2,1,1)

    zeta=wvt.diffX(wvt.v_g(:,:,end))-wvt.diffY(wvt.u_g(:,:,end));
    zeta=zeta./wvt.f;
    zeta(zeta<min(ci))=min(ci);
    zeta(zeta>max(ci))=max(ci);
    jpcolor(x, y, zeta'), axis equal, axis tight 
    axis equal, axis([-1 1 -1 1]*max(x))
    clim([-.15 .15])

    hc = colorbar(gca,'EastOutside');
    hc.Label.String = 'Relative Vorticity $\zeta/f_0$';
    hc.Label.Interpreter = 'latex';
    hc.Ticks = (-0.1:.1:.1);
    
    text(160,340,['t = ' int2str(t(n)) ' days']);
    text(-340,340,'z = 0 m');
    colormap(divergingcolormap)
    xtick(-400:100:400),ytick(-400:100:400)
    noxlabels, noylabels, xticks([]),yticks([])

    subplot(2,1,2)

    zeta=wvt.diffX(wvt.v_g(:,:,20))-wvt.diffY(wvt.u_g(:,:,20));
    zeta=zeta./wvt.f;
    zeta(zeta<min(ci))=min(ci);
    zeta(zeta>max(ci))=max(ci);
    jpcolor(x, y, zeta'), axis equal, axis tight
    axis equal, axis([-1 1 -1 1]*max(x))
    clim([-.15 .15]/4)

    hc = colorbar(gca,'EastOutside');
    hc.Label.String = 'Relative Vorticity $\zeta/f_0$';
    hc.Label.Interpreter = 'latex';
    hc.Ticks = (-0.04:.02:.04);

    text(160,340,['t = ' int2str(t(n)) ' days']);
    text(-340,340,'z = -689 m');
    colormap(divergingcolormap)
    xtick(-400:100:400),ytick(-400:100:400)
    noxlabels, noylabels, xticks([]),yticks([])

    set(gcf,'paperposition',[1 1 6 8])
    packfig(2,1)

    jprint([printdir '/movie'],['frame' int2str(n)],'-r500')
end
end