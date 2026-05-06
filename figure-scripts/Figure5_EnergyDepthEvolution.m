%MakeEnergyDepthEvolution

loadFigureDefaults;
[t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd);
t = wvd.t_wv/86400;

He = 0.424 * 1000;

EddyTideProfiles = computeEddyTideProfiles(wvd);
hkeg = EddyTideProfiles.hkeg;
peg = EddyTideProfiles.peg;
Yg = EddyTideProfiles.Yg;
shsg = EddyTideProfiles.shsg;

E0 = mean(hkeg(:,:,1)+peg(:,:,1),"all");
shsg0 = mean(shsg(:,:,1),"all");
Yg0 = mean(Yg(:,:,1),"all");

ci1 = logspace(-3,-1/2,6);
ci2 = [0.5,0.6,0.7,0.8,0.9];
hcs = gobjects(5,1);

fig = figure(WindowStyle="normal");
set(fig,'Units','inches')
set(fig,'Position',[1 1 5 12])
tl = tiledlayout(fig,5,1,TileSpacing="compact",Padding="compact");
ax = gobjects(5,1);

ax(1) = nexttile(tl);
contourf(t,wvt.z/1000,squeeze(mean(hkeg+peg,2))./E0,100,LineStyle="none")
hold on,clim([0 max(mean(hkeg+peg,2),[],"all","omitnan")./E0])
contour(t,wvt.z/1000,squeeze(mean(hkeg+peg,2))./E0,ci1*max(clim),'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(hkeg+peg,2))./E0,ci2*max(clim),'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Total Geostrophic Energy $\mathcal{E}_g$';
hcs(1)=hc;

ax(2) = nexttile(tl);
contourf(t,wvt.z/1000,squeeze(mean(peg,2))./E0,100,LineStyle="none")
hold on,clim([0 max(mean(hkeg+peg,2),[],"all","omitnan")./E0])
contour(t,wvt.z/1000,squeeze(mean(peg,2))./E0,ci1*max(clim),'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(peg,2))./E0,ci2*max(clim),'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Geostrophic Potential Energy $\mathcal{P}_g$';
hcs(2)=hc;

ax(3) = nexttile(tl);
contourf(t,wvt.z/1000,squeeze(mean(hkeg,2))./E0,100,LineStyle="none")
hold on,clim([0 max(mean(hkeg+peg,2),[],"all","omitnan")./E0])
contour(t,wvt.z/1000,squeeze(mean(hkeg,2))./E0,ci1*max(clim),'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(hkeg,2))./E0,ci2*max(clim),'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Geostrophic Kinetic Energy $\mathcal{K}_g$';
hcs(3)=hc;

ax(4) = nexttile(tl);
contourf(t,wvt.z/1000,squeeze(mean(Yg,2))./Yg0,100,LineStyle="none")
hold on,clim([0 max(mean(Yg,2),[],"all","omitnan")./Yg0])
contour(t,wvt.z/1000,squeeze(mean(Yg,2))./Yg0,ci1*max(clim),'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(Yg,2))./Yg0,ci2*max(clim),'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Potential Enstrophy $\mathcal{Z}$';
hcs(4)=hc;

ax(5) = nexttile(tl);
contourf(t,wvt.z/1000,squeeze(mean(shsg,2))./shsg0,100,LineStyle="none")
hold on,clim([0 max(mean(shsg,2),[],"all","omitnan")./shsg0])
contour(t,wvt.z/1000,squeeze(mean(shsg,2))./shsg0,ci1*max(clim),'color',lowcontourcolor)
contour(t,wvt.z/1000,squeeze(mean(shsg,2))./shsg0,ci2*max(clim),'color',highcontourcolor)
hc=colorbar('Location','EastOutside');
hc.Label.Interpreter='latex';
hc.Label.String='Geostrophic Squared Vertical Shear';
xlabel('Time (days)')
hcs(5)=hc;

for i=1:length(ax)
    axes(ax(i))
    xlim([0 maxDays]),ylim([-2 0]),yticks([-2:.5:0]),
    if i < length(ax)
        xticklabels([])
    end
    ylabel('Depth (km)'),
    xline(t_phaseII/86400,":",Color=0.7*[1 1 1],LineWidth=1)
    xline(t_phaseIII/86400,":",Color=0.7*[1 1 1],LineWidth=1)
    text(5,-1.85,['(' char(real('a')+i-1) ')'],'color',0.7*[1 1 1])
    if i == 4
        WVDiagnostics.cmocean('tempo')
    elseif i == 5
        WVDiagnostics.cmocean('dense')
    else
        colormap(sequentialcolormap)
    end
    yline(-He/1000,Color="w",LineWidth=2)
    yline(-He/1000,":",Color="k",LineWidth=1)
end

axes(ax(4))
text(t(1)+(t_phaseII/86400-t(1))/2.5,-1.5,'Phase I','color',0.7*[1 1 1])
text((t_phaseII+(t_phaseIII-t_phaseII)/4)/86400,-1.5,'Phase II','color',0.7*[1 1 1])
text((t_phaseIII/86400+(maxDays-t_phaseIII/86400)/6),-1.5,'Phase III','color',0.7*[1 1 1])

drawnow
axisPositions = zeros(length(ax),4);
for i=1:length(ax)
    axisPositions(i,:) = get(ax(i),"Position");
end
colorbarPosition = get(hcs(1),"Position");
colorbarX = colorbarPosition(1);
colorbarWidth = colorbarPosition(3)/2;
set([ax(:); hcs(:)],"Parent",fig)
for i=1:length(hcs)
    set(ax(i),"Position",axisPositions(i,:))
    colorbarPosition = get(hcs(i),"Position");
    colorbarPosition(1) = colorbarX;
    colorbarPosition(3) = colorbarWidth;
    set(hcs(i),"Position",colorbarPosition)
end

exportgraphics(gcf,figureFolder + "/" + "Figure5_EnergyDepthEvolution_units.png",Resolution=500)
