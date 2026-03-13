%%
loadFigureDefaults;

[t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd);

%%
clear ggg ggw ggw_tx wwg_tx
ggg.flux = wvd.diagfile.readVariables("geostrophic-flux/ggg");
ggw.flux = wvd.diagfile.readVariables("geostrophic-flux/ggw");
ggw_tx.flux = wvd.diagfile.readVariables("geostrophic-flux/ggw_tx");
wwg_tx.flux = wvd.diagfile.readVariables("geostrophic-flux/wwg_tx");

%%
% axislim = min([max(ggg.flux(:)/wvd.flux_scale), abs(min(ggg.flux(:)/wvd.flux_scale))]);

filter_phaseI = @(v) mean(v(:,:,wvd.t_diag<t_phaseII),3);
filter_phaseII = @(v) mean(v(:,:,wvd.t_diag>=t_phaseII & wvd.t_diag<t_phaseIII),3);
filter_phaseIII = @(v) mean(v(:,:,wvd.t_diag>=t_phaseIII),3);

flux = filter_phaseII(ggg.flux)/wvd.flux_scale;
axislim = 0.1*min([max(flux(:)), abs(min(flux(:)))]);

%% raw flux plot

figure
tiledlayout(2,3)
nexttile
pcolor(wvd.kRadial, wvd.jWavenumber, filter_phaseI(ggg.flux)/wvd.flux_scale),xscale('log'), yscale('log'), shading flat, clim(axislim*[-1 1])
nexttile
pcolor(wvd.kRadial, wvd.jWavenumber, filter_phaseII(ggg.flux)/wvd.flux_scale),xscale('log'), yscale('log'), shading flat, clim(axislim*[-1 1])
nexttile
pcolor(wvd.kRadial, wvd.jWavenumber, filter_phaseIII(ggg.flux)/wvd.flux_scale),xscale('log'), yscale('log'), shading flat, clim(axislim*[-1 1])
colorbar('eastoutside')

nexttile
pcolor(wvd.kRadial, wvd.jWavenumber, filter_phaseI(ggw.flux)/wvd.flux_scale),xscale('log'), yscale('log'), shading flat, clim(axislim*[-1 1])
nexttile
pcolor(wvd.kRadial, wvd.jWavenumber, filter_phaseII(ggw.flux)/wvd.flux_scale),xscale('log'), yscale('log'), shading flat, clim(axislim*[-1 1])
nexttile
pcolor(wvd.kRadial, wvd.jWavenumber, filter_phaseIII(ggw.flux)/wvd.flux_scale),xscale('log'), yscale('log'), shading flat, clim(axislim*[-1 1])
colorbar('eastoutside')

%% quiver flux plot

fig = figure(WindowStyle="normal");

tl = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');

% plot options
% yAxisLabel = "deformation length";
yAxisLabel = "vertical mode";
vDLTW = 10^(-3.9);
jmax=(2*pi/9e3);
kmax=(2*pi/9e3);
quiverScaleGGG=20;
quiverScaleGGW=10*quiverScaleGGG;

clear tempFlux

tile = nexttile(tl,1);
tempFlux.flux = filter_phaseI(ggg.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGG,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
% title("ggg, Phase I")
title("Phase I")
xlabel([])
xticklabels([])
text(.99*tile.XLim(1),.99*tile.YLim(1),'ggg flux','Color','k','HorizontalAlignment','left','VerticalAlignment','bottom')
box on

tile = nexttile(tl,2);
tempFlux.flux = filter_phaseII(ggg.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGG,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
% title("ggg, Phase II")
title("Phase II")
xlabel([])
ylabel([])
xticklabels([])
yticklabels([])
box on

tile = nexttile(tl,3);
tempFlux.flux = filter_phaseIII(ggg.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGG,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
% title("ggg, Phase III")
title("Phase III")
xlabel([])
ylabel([])
xticklabels([])
yticklabels([])
box on
addDeformationLabels

tile = nexttile(tl,4);
tempFlux.flux = filter_phaseI(ggw.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGW,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
% title("ggw, Phase I")
if quiverScaleGGW==quiverScaleGGG
    ggwStr = 'ggw flux';
else
    ggwStr = sprintf('ggw flux $\\times%d$',quiverScaleGGW/quiverScaleGGG);
end
text(.99*tile.XLim(1),.99*tile.YLim(1),ggwStr,'Color','k','HorizontalAlignment','left','VerticalAlignment','bottom')
box on

tile = nexttile(tl,5);
tempFlux.flux = filter_phaseII(ggw.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGW,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
% title("ggw, Phase II")
ylabel([])
yticklabels([])
box on

tile = nexttile(tl,6);
tempFlux.flux = filter_phaseIII(ggw.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGW,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
% title("ggw, Phase III")
ylabel([])
yticklabels([])
box on
addDeformationLabels

function addDeformationLabels
    yticksTemp = yticks;
    % yticksTemp = yticksTemp(2:end);
    labels_y = cell(length(yticksTemp),1);
    for i=1:length(yticksTemp)
        labels_y{i} = sprintf('%0.0f',2*pi/(10^yticksTemp(i))/1000);
    end
    text(.97*max(xlim)*ones(size(yticksTemp)),yticksTemp,labels_y,...
        'Color',0.5*[1 1 1],'HorizontalAlignment','left')
    %text(0.5*min(xlim),1.05*max(ylim),'$L_r$ (km)',...
    %    'Color',0.5*[1 1 1],'HorizontalAlignment','center')
    text(.92*max(xlim),mean(ylim),'$2 \pi L_r$ (km)','Color',0.5*[1 1 1],...
        'HorizontalAlignment', 'center','VerticalAlignment','top', 'Rotation', 90);
end

set(gcf,'Units','inches')
set(gcf,'Position',[1 1 10 6.66])
exportgraphics(gcf,figureFolder + "/" + "Figure8_FluxSpectra.png",Resolution=500)
