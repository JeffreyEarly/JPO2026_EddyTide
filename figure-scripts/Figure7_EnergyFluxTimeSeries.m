loadFigureDefaults;

[t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd);

%% Read in the time series and define the phases
[E_g,KE_g,PE_g,E_mda] = wvd.diagfile.readVariables('E_g','KE_g','PE_g','E_mda');
E_g = E_g + E_mda;
PE_g = PE_g + E_mda;

% these should be first-order differenced, so the cumsum returns the
% correct total energy
t = wvd.t_diag;
t_diff = t(2:end) - (t(2)-t(1))/2;
dE_g = diff(E_g)./diff(t);
dKE_g = diff(KE_g)./diff(t);
dPE_g = diff(PE_g)./diff(t);

%% Read in the geostrophic inertial fluxes and create TE/KE/PE time series
[geo_hke_jk, geo_pe_jk] = wvd.diagfile.readVariables("geo_hke_jk","geo_pe_jk");
ke_ratio = geo_hke_jk./(geo_hke_jk + geo_pe_jk);
pe_ratio = geo_pe_jk./(geo_hke_jk + geo_pe_jk);
ke_ratio(isnan(ke_ratio)) = 0;
pe_ratio(isnan(pe_ratio)) = 0;

filter_te = @(v) reshape( sum(sum(v,1),2), [], 1);
filter_ke = @(v) reshape( sum(sum( ke_ratio.*v,1),2), [], 1);
filter_pe = @(v) reshape( sum(sum( pe_ratio.*v,1),2), [], 1);

inertial_flux_names = ["ggg","ggw","ggw_tx","wwg_tx"];
clear inertial_flux;
for iFlux=1:length(inertial_flux_names)
    inertial_flux(iFlux).name = inertial_flux_names(iFlux);
    inertial_flux(iFlux).fancyName = inertial_flux_names(iFlux);
    ggg = wvd.diagfile.readVariables("geostrophic-flux/" + inertial_flux_names(iFlux));
    inertial_flux(iFlux).te_gmda = filter_te(ggg);
    inertial_flux(iFlux).ke_g = filter_ke(ggg);
    inertial_flux(iFlux).pe_g = filter_pe(ggg);
end

%% Combine the forcing fluxes into one
[forcing_fluxes,t] = wvd.quadraticEnergyFluxesOverTime(energyReservoirs=[EnergyReservoir.geostrophic_mda, EnergyReservoir.geostrophic_kinetic,EnergyReservoir.geostrophic_potential_mda ]);
d1 = forcing_fluxes([forcing_fluxes.name] == "adaptive_damping");
d2 = forcing_fluxes([forcing_fluxes.name] == "antialias_filter");

iFlux = iFlux + 1;
inertial_flux(iFlux).name = "damping";
inertial_flux(iFlux).fancyName = "damping";
inertial_flux(iFlux).te_gmda = d1.te_gmda + d2.te_gmda;
inertial_flux(iFlux).ke_g = d1.ke_g + d2.ke_g;
inertial_flux(iFlux).pe_g = d1.te_gmda + d2.pe_g;

%%

% flux_filter = @(v) movmean(v,21);
flux_filter = @(v) vfilt(v,21);

figure(PaperPosition=[1 1 300 800]);
tl = tiledlayout(3,1,TileSpacing="compact");
nexttile(tl);
plot(t_diff/86400,flux_filter(dE_g)/wvd.flux_scale,LineWidth=4,Color=0.3*[1 1 1]), hold on
set(gca,'ColorOrderIndex',5)
for iFlux=1:length(inertial_flux)
    plot(wvd.t_diag/86400,flux_filter(inertial_flux(iFlux).te_gmda)/wvd.flux_scale,LineWidth=2)
end
ylim([-1 1])
xticklabels([])

nexttile(tl);
plot(t_diff/86400,flux_filter(dKE_g)/wvd.flux_scale,LineWidth=4,Color=0.3*[1 1 1]), hold on
set(gca,'ColorOrderIndex',5)
for iFlux=1:length(inertial_flux)
    plot(wvd.t_diag/86400,flux_filter(inertial_flux(iFlux).ke_g)/wvd.flux_scale,LineWidth=2)
end
ylim([-0.2 1])
xticklabels([])

nexttile(tl);
plot(t_diff/86400,flux_filter(dPE_g)/wvd.flux_scale,LineWidth=4,Color=0.3*[1 1 1]), hold on
set(gca,'ColorOrderIndex',5)
for iFlux=1:length(inertial_flux)
    plot(wvd.t_diag/86400,flux_filter(inertial_flux(iFlux).pe_g)/wvd.flux_scale,LineWidth=2)
end
ylim([-1 0.2])

%%
for i=1:3
    nexttile(tl,i)
    xlim([0 400]),ylim([-0.95 0.95]),yticks(-1:.2:1)
    % linestyle thick
    vlines(t_phaseII/86400,'1D:')
    vlines(t_phaseIII/86400,'1D:')
    if i == 1
        hleg=legend('d/dt','ggg-cascade','ggw-cascade','ggw-transfer','wwg-transfer','damping',...
            'Location','northwest','NumColumns',2);
        text(80,-0.6,'Phase I','color',0.7*[1 1 1])
        text(235,-0.6,'Phase II','color',0.7*[1 1 1])
        text(330,-0.6,'Phase III','color',0.7*[1 1 1])
        ylabel('$\mathcal{E}_g$ Flux (GM/yr)',Interpreter='latex')
    elseif i == 2
        ylabel('$\mathcal{K}_g$ Flux (GM/yr)',Interpreter='latex')
    elseif i == 3
        xlabel('Time (days)')
        ylabel('$\mathcal{P}_g$ Flux (GM/yr)',Interpreter='latex')
    end
    text(375,0.8,['(' char(real('a')+i-1) ')'])
end

exportgraphics(tl,figureFolder + "/" + "Figure7_FluxTimeSeries.png",Resolution=300)