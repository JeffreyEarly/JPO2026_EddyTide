%MakeTidalForcingScatter

loadFigureDefaults;

% Compute the intrinsic frequency of the wave modes
frequencies = wvt.transformToKLAxes(wvt.Omega);
frequenciesKJ = squeeze(frequencies(:,wvt.lAxis==0,:));
intrinsicFrequenciesKJ = frequenciesKJ - wvt.kAxis*abs(eddyProperties.Ue);

figure(WindowStyle="normal")
jpcolor(wvt.kAxis,wvt.j,intrinsicFrequenciesKJ.'/wvt.f), hold on
contour(wvt.kAxis,wvt.j,intrinsicFrequenciesKJ.'/wvt.f,(0:.1:1),...
    'color',lowcontourcolor,'LineWidth',0.5);
contour(wvt.kAxis,wvt.j,intrinsicFrequenciesKJ.'/wvt.f,(1.1:.1:2),...
    'color',highcontourcolor,'LineWidth',0.5);

if any(strcmp("M2-tidal-forcing",wvt.forcingNames))
    MAp = zeros(wvt.spectralMatrixSize);
    force = wvt.forcingWithName("M2-tidal-forcing");
    MAp(force.Ap_indices) = 1;
    for iJ=1:max(wvt.j)
        hs = scatter(wvt.K(MAp ==1 & wvt.J == iJ),wvt.j(iJ),50); 
    end
end

xlim(2*pi./(1e3*[-15 15]))
ylim([0,max(wvt.j)])
xlabel('Horizontal wavelength (km)')
ylabel('Vertical mode number')
set(gca,'TickDir','Out')

%Used to put nice labels on the x-axis
ticks_x = [-15;-20;-30;-50;-200;200;50;30;20;15];
labels_x = cell(length(ticks_x),1);
for i=1:length(ticks_x)
    labels_x{i} = sprintf('%.0f',ticks_x(i));
end
ticks_x = 2*pi./(1e3*ticks_x);
xticks(ticks_x),xticklabels(labels_x)

axpos=get(gca,'position');
colormap(sequentialcolormap)
hc=colorbar('southoutside');
hc.Label.Interpreter = 'latex'; %Not possible to set default value
hc.Label.String = 'Normalized Wave Intrinsic Frequency $\tilde\omega/f$';
clim([0.5 2])

pos=get(hc,'position');
set(hc,'position',[pos(1)+0.025 pos(2) pos(3)-0.05 pos(4)/2])
set(gca,'position',[axpos(1) axpos(2)+0.15 axpos(3) axpos(4)-0.17])


% fontsize 10 10 10 10
set(gcf,'Units','inches')
set(gcf,'Position',[1 1 5 5.5])
exportgraphics(gcf,figureFolder + "/" + "Figure2_TidalForcingScatter.png",Resolution=500)