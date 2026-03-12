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
filter_phaseIII = @(v) mean(v(:,:,wvd.t_diag<t_phaseIII),3);

flux = filter_phaseII(ggg.flux)/wvd.flux_scale;
axislim = 0.1*min([max(flux(:)), abs(min(flux(:)))]);

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