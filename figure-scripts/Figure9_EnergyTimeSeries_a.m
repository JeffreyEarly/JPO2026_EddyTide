%MakeEnergyTimeSeries

figureSimulationType = "Forced";
loadFigureDefaults;

[t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd);

% Total energy and enstrophy over time

[E_g,KE_g,PE_g,E_mda,E_w,E_io,ke,pe_quad,ape] = wvd.diagfile.readVariables('E_g','KE_g','PE_g','E_mda','E_w','E_io','ke','pe_quadratic','ape');
[Z_quad,Z_apv] = wvd.diagfile.readVariables('enstrophy_quadratic','enstrophy_apv');
t = wvd.t_wv/86400;

totalEnergy = ke + pe_quad;
totalEnergy_ape = ke + ape;

clear ugz vgz wgz

EddyTideProfiles = computeEddyTideProfiles(wvd);
shsg = EddyTideProfiles.shsg;
shsw = EddyTideProfiles.shsw;
svsw = EddyTideProfiles.svsw;
shear_g = squeeze(mean(shsg,[1 2]));
shear_w = squeeze(mean(shsw+svsw,[1 2]));
shear_t = shear_g + shear_w;

figure(WindowStyle="normal")
plot(t,[totalEnergy E_w E_g KE_g PE_g]./totalEnergy(1), 'LineWidth', 2);
hleg=legend('Total Energy $\mathcal{E}$','Wave Energy $\mathcal{E}_w$',...
    'Geostrophic Energy $\mathcal{E}_g$',...
    'Geostrophic Kinetic $\mathcal{K}_g$',...
    'Geostrophic Potential $\mathcal{P}_g$',...
    'Location','Northwest','NumColumns', 2);
if strcmp(simul_type,"Unforced")
    ylim([0 1.4])
elseif strcmp(simul_type,"Forced")
    ylim([0 2.0])
end

ylabel('Normalized Energy')

xlabel('Time (days)')

xlim([0 maxDays])
h = xline(t_phaseII/86400,":",Color=0.7*[1 1 1],LineWidth=1); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
h = xline(t_phaseIII/86400,":",Color=0.7*[1 1 1],LineWidth=1); h.Annotation.LegendInformation.IconDisplayStyle = 'off';

text(t(1)+(t_phaseII/86400-t(1))/2,1.1,'Phase I','color',0.7*[1 1 1])
text((t_phaseII+(t_phaseIII-t_phaseII)/4)/86400,1.1,'Phase II','color',0.7*[1 1 1])
text((t_phaseIII/86400+(maxDays-t_phaseIII/86400)/7),1.1,'Phase III','color',0.7*[1 1 1])


set(gcf,'Units','inches')
set(gcf,'Position',[1 1 5 3.34])
exportgraphics(gcf,figureFolder + "/" + "Figure9_EnergyTimeSeries_a_"+simul_type+".png",Resolution=500)
