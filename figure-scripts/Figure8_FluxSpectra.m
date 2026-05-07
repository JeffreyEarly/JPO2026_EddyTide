%%
loadFigureDefaults;

[t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd);

%%
clear ggg ggw
ggg.flux = wvd.diagfile.readVariables("geostrophic-flux/ggg");
ggw.flux = wvd.diagfile.readVariables("geostrophic-flux/ggw");

filter_phaseI = @(v) mean(v(:,:,wvd.t_diag<t_phaseII),3);
filter_phaseII = @(v) mean(v(:,:,wvd.t_diag>=t_phaseII & wvd.t_diag<t_phaseIII),3);
filter_phaseIII = @(v) mean(v(:,:,wvd.t_diag>=t_phaseIII),3);

fig = figure(WindowStyle="normal");

tl = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');

yAxisLabel = "vertical mode";
vDLTW = 10^(-3.9);
jmax=Inf;
kmax=min(2*pi/9e3,max(wvd.kRadial(:)));
quiverScaleGGG=40;
quiverScaleGGW=10*quiverScaleGGG;

clear tempFlux

tile = nexttile(tl,1);
tempFlux.flux = filter_phaseI(ggg.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGG,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
title("Phase I")
xlabel([])
xticklabels([])
text(.99*tile.XLim(1),.99*tile.YLim(1),'ggg flux','Color','k','HorizontalAlignment','left','VerticalAlignment','bottom')
box on

tile = nexttile(tl,2);
tempFlux.flux = filter_phaseII(ggg.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGG,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
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
title("Phase III")
xlabel([])
ylabel([])
xticklabels([])
yticklabels([])
box on

tile = nexttile(tl,4);
tempFlux.flux = filter_phaseI(ggw.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGW,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
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
ylabel([])
yticklabels([])
box on

tile = nexttile(tl,6);
tempFlux.flux = filter_phaseIII(ggw.flux)/wvd.flux_scale;
wvd.plotPoissonFlowOverContours(figureHandle=tile,vectorDensityLinearTransitionWavenumber=vDLTW,jmax=jmax,kmax=kmax,quiverScale=quiverScaleGGW,inertialFlux=tempFlux,addFrequencyContours=false,addKEPEContours=true,yAxisLabel=yAxisLabel);
fig.Children(1).Visible='off';
ylabel([])
yticklabels([])
box on

set(gcf,'Units','inches')
set(gcf,'Position',[1 1 10 6.66])
exportgraphics(gcf,figureFolder + "/" + "Figure8_FluxSpectra.png",Resolution=500)
