%MakeEnergyTimeSeries

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
use EddyTideProfiles;
shear_g = squeeze(mean(shsg,[1 2]));
shear_w = squeeze(mean(shsw+svsw,[1 2]));
shear_t = shear_g + shear_w;

figure(WindowStyle="normal")
subplot(3,1,1)
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
%text(375,0.07,'(a)')
text(maxDays-30,0.07,'(a)')

subplot(3,1,2)
hl = plot(t,Z_apv./Z_apv(1), 'LineWidth', 2);
legend(hl,'Potential Enstrophy $\mathcal{Y}$','Location','Southwest')
ylim([0.61 1.025]),ylabel('Normalized Enstrophy')
%hl = plot(t,[Z_apv NaN*Z_apv Z_quad]./Z_apv(1));
%legend(hl([1 3]),'Potential Enstrophy $\mathcal{Y}$',...
%    'Quasigeostrophic Enstropy $\mathcal{Z}$','Location','Southwest')
%ylim([0.61 1.099]),ylabel('Normalized Enstrophy')
%text(375,0.63,'(b)')
text(maxDays-30,0.63,'(b)')

subplot(3,1,3)
if strcmp(simul_type,"Unforced")
    hl = plot(t,shear_g./shear_g(1),'Color',[0.9290    0.6940    0.1250], 'LineWidth', 2);
    legend('Geostrophic Squared Shear','Location','Northwest')
    ylim([0.8 3])%,ylog
    text(maxDays-30,0.9,'(c)')
elseif strcmp(simul_type,"Forced")
    hl = plot(t,[shear_t shear_w 10*shear_g]./shear_t(1), 'LineWidth', 3);
    legend('Total Squared Shear','Wave Squared Shear',...
        'Geostrophic Squared Shear $\times$ 10','Location','Northwest')
    ylim([0 7])%,ylog
    text(maxDays-30,0.3,'(c)')
end
ylabel('Normalized Squared Shear')
xlabel('Time (days)')
%text(375,0.3,'(c)')

axs = packfig(3,1,'rows');

for i=1:3
    axes(axs(i)),xlim([0 maxDays])%,linestyle thick 
    h = vlines(t_phaseII/86400,'1D:'); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
    h = vlines(t_phaseIII/86400,'1D:'); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
    if i==2
        % text(80,1.05,'Phase I','color',0.7*[1 1 1])
        % text(235,1.05,'Phase II','color',0.7*[1 1 1])
        % text(330,1.05,'Phase III','color',0.7*[1 1 1])
        text(t(1)+(t_phaseII/86400-t(1))/2.5,0.85,'Phase I','color',0.7*[1 1 1])
        text((t_phaseII+(t_phaseIII-t_phaseII)/4)/86400,0.85,'Phase II','color',0.7*[1 1 1])
        text((t_phaseIII/86400+(maxDays-t_phaseIII/86400)/6),0.85,'Phase III','color',0.7*[1 1 1])
    end
end

% fontsize 10.5 10.5 10.5 10.5

set(gcf,'Units','inches')
set(gcf,'Position',[1 1 5 10])
exportgraphics(gcf,figureFolder + "/" + "Figure4_EnergyTimeSeries.png",Resolution=500)