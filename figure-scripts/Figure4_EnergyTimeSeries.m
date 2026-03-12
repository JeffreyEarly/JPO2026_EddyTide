%MakeEnergyTimeSeries

loadFigureDefaults;

[t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd);

% Total energy and enstrophy over time

[E_g,KE_g,PE_g,E_mda,E_w,E_io,ke,pe_quad,ape] = wvd.diagfile.readVariables('E_g','KE_g','PE_g','E_mda','E_w','E_io','ke','pe_quadratic','ape');
[Z_quad,Z_apv] = wvd.diagfile.readVariables('enstrophy_quadratic','enstrophy_apv');

totalEnergy = ke + pe_quad;
totalEnergy_ape = ke + ape;

clear ugz vgz wgz 

EddyTideProfiles = ComputeEddyTideProfiles(wvd);
use EddyTideProfiles;
shear_g = squeeze(mean(shsg,[1 2]));
shear_w = squeeze(mean(shsw+svsw,[1 2]));
shear_t = shear_g + shear_w;

figure(WindowStyle="normal")
subplot(3,1,1)
plot(t,[totalEnergy E_w E_g KE_g PE_g]./totalEnergy(1));
hleg=legend('Total Energy $\mathcal{E}$','Wave Energy $\mathcal{E}_w$',...
    'Geostrophic Energy $\mathcal{E}_g$',...
    'Geostrophic Potential $\mathcal{P}_g$',...
    'Geostrophic Kinetic $\mathcal{K}_g$',...
    'Location','Northwest');
ylim([0 2.0]),ylabel('Normalized Energy')
text(375,0.07,'(a)')

subplot(3,1,2)
hl = plot(t,Z_apv./Z_apv(1));
legend(hl,'Potential Enstrophy $\mathcal{Y}$','Location','Southwest')
ylim([0.61 1.025]),ylabel('Normalized Enstrophy')
%hl = plot(t,[Z_apv NaN*Z_apv Z_quad]./Z_apv(1));
%legend(hl([1 3]),'Potential Enstrophy $\mathcal{Y}$',...
%    'Quasigeostrophic Enstropy $\mathcal{Z}$','Location','Southwest')
%ylim([0.61 1.099]),ylabel('Normalized Enstrophy')
text(375,0.63,'(b)')

subplot(3,1,3)
hl = plot(t,[shear_t shear_w 10*shear_g]./shear_t(1));
legend('Total Squared Shear','Wave Squared Shear',...
    'Geostrophic Squared Shear $\times$ 10','Location','Northwest')
ylim([0 7])%,ylog
ylabel('Normalized Squared Shear')
xlabel('Time (days)')
text(375,0.3,'(c)')

axs = packfig(3,1,'rows');

for i=1:3
    axes(axs(i)),xlim([0 400]),linestyle thick 
    h = vlines(t_phaseII/86400,'1D:'); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
    h = vlines(t_phaseIII/86400,'1D:'); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
    if i==1
        text(80,1.05,'Phase I','color',0.7*[1 1 1])
        text(235,1.05,'Phase II','color',0.7*[1 1 1])
        text(330,1.05,'Phase III','color',0.7*[1 1 1])
    end
end

% fontsize 10.5 10.5 10.5 10.5

set(gcf,'Units','inches')
set(gcf,'Position',[1 1 5 10])
exportgraphics(gcf,figureFolder + "/" + "Figure4_EnergyTimeSeries.png",Resolution=500)