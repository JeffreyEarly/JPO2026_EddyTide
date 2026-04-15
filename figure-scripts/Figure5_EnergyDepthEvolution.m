%MakeEnergyDepthEvolution

loadFigureDefaults;
[t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd);
t = wvd.t_wv/86400;

eddyProperties.Ue = -15/100; 
eddyProperties.He = 0.424 * 1000;
eddyProperties.Le = 56.57 * 1000;
eddyProperties.Lxy = wvt.Lx;
eddyProperties.Lz = wvt.Lz;
eddyProperties.N2 = wvt.N2(1);
eddyProperties.f =  wvt.f;
eddyProperties.g = wvt.g;
eddyProperties.rho0 =  wvt.rho0;
use eddyProperties

EddyTideProfiles = computeEddyTideProfiles(wvd);
use EddyTideProfiles;

E0 = mean(mean(hkeg(:,:,1)+peg(:,:,1),1),2);
shsg0 = mean(mean(shsg(:,:,1),1),2);
Yg0 = mean(mean(Yg(:,:,1),1),2);

%Some hovmueller diagrams—energy and vertical shear
ci1 = logspace(-3,-1/2,6);
ci2 = [0.5,0.6,0.7,0.8,0.9];
hcs = zeros(5,1);

figure(WindowStyle="normal")
subplot(5,1,1),
contourf(t,wvt.z/1000,squeeze(mean(hkeg+peg,2))./E0,100)
nocontours,hold on,clim([0 maxmax(mean(hkeg+peg,2))./E0])
contour(t,wvt.z/1000,squeeze(mean(hkeg+peg,2))./E0,ci1*max(clim),...
    'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(hkeg+peg,2))./E0,ci2*max(clim),...
    'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Total Geostrophic Energy $\mathcal{E}_g$';
hcs(1)=hc;

subplot(5,1,2)
contourf(t,wvt.z/1000,squeeze(mean(peg,2))./E0,100)
nocontours,hold on,clim([0 maxmax(mean(hkeg+peg,2))./E0])
contour(t,wvt.z/1000,squeeze(mean(peg,2))./E0,ci1*max(clim),...
    'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(peg,2))./E0,ci2*max(clim),...
    'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Geostrophic Potential Energy $\mathcal{P}_g$';
hcs(2)=hc;

subplot(5,1,3)
contourf(t,wvt.z/1000,squeeze(mean(hkeg,2))./E0,100)
nocontours,hold on,clim([0 maxmax(mean(hkeg+peg,2))./E0])
contour(t,wvt.z/1000,squeeze(mean(hkeg,2))./E0,ci1*max(clim),...
    'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(hkeg,2))./E0,ci2*max(clim),...
    'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Geostrophic Kinetic Energy $\mathcal{K}_g$';
hcs(3)=hc;

subplot(5,1,4)
contourf(t,wvt.z/1000,squeeze(mean(Yg,2))./Yg0,100)
nocontours,hold on,clim([0 maxmax(mean(Yg,2))./Yg0])
contour(t,wvt.z/1000,squeeze(mean(Yg,2))./Yg0,ci1*max(clim),...
    'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(Yg,2))./Yg0,ci2*max(clim),...
    'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Potential Enstrophy $\mathcal{Z}$';
%hc.Label.String='Squared APV';
hcs(4)=hc;

subplot(5,1,5),
contourf(t,wvt.z/1000,squeeze(mean(shsg,2))./shsg0,100),
nocontours,hold on,clim([0 maxmax(mean(shsg,2))./shsg0])
contour(t,wvt.z/1000,squeeze(mean(shsg,2))./shsg0,ci1*max(clim),...
    'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(shsg,2))./shsg0,ci2*max(clim),...
    'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Geostrophic Squared Vertical Shear';
xlabel('Time (days)')
hcs(5)=hc;

ax=packfig(5,1,'rows');

for i=1:length(ax)
    axes(ax(i))
    pos=get(hcs(i),'position');
    set(hcs(i),'position',[pos(1:2) pos(3)/2 pos(4)])
    xlim([0 maxDays]),ylim([-2 0]),yticks([-2:.5:0]),
    ylabel('Depth (km)'),
    vlines(t_phaseII/86400,'1D:')
    vlines(t_phaseIII/86400,'1D:')
    text(5,-1.85,['(' char(real('a')+i-1) ')'],'color',0.7*[1 1 1])
    if i == 4
        WVDiagnostics.cmocean('tempo')
    
    elseif i == 5
        WVDiagnostics.cmocean('dense')
    else
        colormap(sequentialcolormap)
    end
    hlines(-He/1000,'2w')
    hlines(-He/1000,'1k:')
end

axes(ax(4))
% text(80,-1.5,'Phase I','color',0.7*[1 1 1])
% text(235,-1.5,'Phase II','color',0.7*[1 1 1])
% text(330,-1.5,'Phase III','color',0.7*[1 1 1])
text(t(1)+(t_phaseII/86400-t(1))/2.5,-1.5,'Phase I','color',0.7*[1 1 1])
text((t_phaseII+(t_phaseIII-t_phaseII)/4)/86400,-1.5,'Phase II','color',0.7*[1 1 1])
text((t_phaseIII/86400+(maxDays-t_phaseIII/86400)/6),-1.5,'Phase III','color',0.7*[1 1 1])

% fontsize 10 10 10 10
set(gcf,'Units','inches')
set(gcf,'Position',[1 1 5 12])
exportgraphics(gcf,figureFolder + "/" + "Figure5_EnergyDepthEvolution_units.png",Resolution=500)

%keprof= squeeze(mean(hkeg,2));
%plot(wvt.z/1000,keprof(:,end)-keprof(:,1))
%Zprof = squeeze(mean(Zg,2))./Zg0;
%plot(t,Zprof)

% zetag = zeros(length(wvt.x),length(wvt.z),length(t));
% for i=1:length(t)
%     i
%     wvt.initFromNetCDFFile(ncfile,iTime=i)
% 
%     zetai = wvt.diffX(wvt.v_g) - wvt.diffY(wvt.u_g);
%     %zetag(:,:,i) =  squeeze(zetai(:,128,:));
%     zetag(:,:,i) =  squeeze(zetai(128,:,:));
% end
% 
% 
% figure
% subplot(1,3,1)
% jpcolor(x,t,squeeze(zetag(:,end,:))'./wvt.f),clim([-0.15 .15])
% subplot(1,3,2)
% jpcolor(x,t,squeeze(zetag(:,end-5,:))'./wvt.f),clim([-0.15 .15])
% subplot(1,3,3)
% jpcolor(x,t,squeeze(zetag(:,end-10,:))'./wvt.f),clim([-0.15 .15])
% packfig(1,3,'col')