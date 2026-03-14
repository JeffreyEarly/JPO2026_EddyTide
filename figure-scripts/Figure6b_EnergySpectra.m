%MakeEnergySpectra

loadFigureDefaults;
[t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd);

t = wvd.t_wv/86400;
t_phaseII = t_phaseII/86400;
t_phaseIII = t_phaseIII/86400;

% options.iTime = {1 4*t_phaseII+1 4*t_phaseIII+1 4*400+1};
options.iTime = {1 find(t<t_phaseII,1,"last") find(t<t_phaseIII,1,"last") 4*maxDays+1};
%options.iTime = {1 4*100+1 4*200+1 4*300+1 4*400+1};
N = length(options.iTime);
energy_limits = [-8 -0.001];
v = [1 2 3 4]; %levels for frequency contours

wvd.iTime = options.iTime{1};

% %create radial wavelength vectors
radialWavelength = 2*pi./wvd.wvt.kRadial/1000;
radialWavelength(1) = 2*radialWavelength(2); %What is this? 
% 
% jWavelength = 2*pi./wvd.jWavenumber/1000;

% Create wavelength axes for wvt variables
% We will pretend the "0" wavenumber is actually evenly spaced
% from the nearest two wavenumbers
kPseudoLocation = wvt.kRadial;
kPseudoLocation(1) = exp(-log(kPseudoLocation(3)) + 2*log(kPseudoLocation(2)));
jPseudoLocation = wvt.j;
jPseudoLocation(1) = exp(-log(jPseudoLocation(3)) + 2*log(jPseudoLocation(2)));
[KPseudoLocation,JPseudoLocation] = ndgrid(kPseudoLocation,jPseudoLocation);
kPseudoRadial = sqrt(JPseudoLocation.^2 + KPseudoLocation.^2);

% For interpolation to work correctly we need to repeat the
% first entry, but properly back at zero
% NOTE: these are from wvd, including the anti-aliased modes.
kPseudoLocationWVD = wvt.kRadial;
kPseudoLocationWVD(1) = exp(-log(kPseudoLocationWVD(3)) + 2*log(kPseudoLocationWVD(2)));
jPseudoLocationWVD = wvt.j;
jPseudoLocationWVD(1) = exp(-log(jPseudoLocationWVD(3)) + 2*log(jPseudoLocationWVD(2)));
kPaddedWVD = cat(1,0,kPseudoLocationWVD);
jPaddedWVD = cat(1,0,jPseudoLocationWVD);
[KPaddedWVD,JPaddedWVD] = ndgrid(kPaddedWVD,jPaddedWVD);



% location for x-z section
iY = round(wvd.wvt.Nx/2);

% create the lines of constant frequency
[omegaN,n] = wvd.wvt.transformToRadialWavenumber(abs(wvd.wvt.Omega),...
    ones(size(wvd.wvt.Omega)));
%omegaJK = (omegaN./n) ./ (2*pi/(24*3600));
omegaJK = (omegaN./n) ./ (2*pi/(12.420602*3600));

%cyclic frequency for diurnal cycle = 2*pi/(24*3600)
%cyclic frequency for M2 = 2*pi/(12.420602*3600)

% create the lines of constant deformation radius
deformationJK = repmat(sqrt(wvd.wvt.Lr2)./1000,1,length(wvd.wvt.kRadial));

figure(WindowStyle="normal")

tl = tiledlayout(2,N,TileSpacing="tight");

for n = 1:N

    wvd.iTime = options.iTime{n};
    
    %compute some quantities
    TE_A0_j_kl = wvd.wvt.A0_TE_factor .* abs(wvd.wvt.A0).^2; % m^2/s^3
    TE_A0_j_kR = wvd.wvt.transformToRadialWavenumber(TE_A0_j_kl);
    TE_Apm_j_kl = wvd.wvt.Apm_TE_factor .* (abs(wvd.wvt.Ap).^2 + abs(wvd.wvt.Am).^2); % m^2/s^3
    TE_Apm_j_kR = wvd.wvt.transformToRadialWavenumber(TE_Apm_j_kl);

    %wave energy spectrum
    nexttile(tl,n);
    val = log10(TE_Apm_j_kR);
    val(val==-inf) = energy_limits(1);

    % jpcolor(flipud(radialWavelength),wvd.wvt.j,fliplr(val)), xlog, flipx, hold on
    % xlim([min(radialWavelength) max(radialWavelength)]), ylim([-0.5 18.5]), yticks(0:2:18), clim(energy_limits)
    pcolor(2*pi./kPseudoLocation/1000,jPseudoLocation,val), shading flat, hold on
    set(gca,'XDir','reverse')
    set(gca,'XScale','log')
    set(gca,'YScale','log')
    % manually set yticks
    jInd = [1,2,3,4,5,6,11:10:length(wvt.j)];
    set(gca,'YTick', jPseudoLocation(jInd));
    set(gca,'YTickLabel', wvt.j(jInd));
    clim(energy_limits)
   
    contour(radialWavelength,wvd.wvt.j',omegaJK,[v(1) v(1)],'k','LineWidth',0.5)
    contour(radialWavelength,wvd.wvt.j',omegaJK,v(2:end),'LineWidth',0.5,...
        'Color',0.6*[1 1 1])

    if n == 1
        ylabel('Vertical mode number')
        text(800,15,'Wave Spectra','color',0.7*[1 1 1])
    else
        set(gca,'YTickLabels',[])
    end

    if n == N
        cb = colorbar;
        cb.Label.String = 'Log_{10} Energy Density (m^3 s^{-2})';
    end
    %text(10^2.95,17.25,['(' char(real('a')+(n-1)) ')'])
    axis square
    noxlabels
    colormap(sequentialcolormap)
    title(['T = ' num2str(round(t(options.iTime{n}))) ' days'])
    %geostrophic energy spectrum
    nexttile(tl,n+N);
    val = log10(TE_A0_j_kR);
    val(val==-inf) = energy_limits(1); 

    % jpcolor(flipud(radialWavelength),wvd.wvt.j,fliplr(val)), xlog, flipx
    % xlim([min(radialWavelength) max(radialWavelength)]), ylim([-0.5 18.5])
    % yticks(0:2:18),xticks([10^1 10^2 10^3])
    pcolor(2*pi./kPseudoLocation/1000,jPseudoLocation,val), shading flat, hold on
    set(gca,'XDir','reverse')
    set(gca,'XScale','log')
    set(gca,'YScale','log')
    % manually set yticks
    jInd = [1,2,3,4,5,6,11:10:length(wvt.j)];
    set(gca,'YTick', jPseudoLocation(jInd));
    set(gca,'YTickLabel', wvt.j(jInd));
    clim(energy_limits)
    
    if n == 1
        ylabel('Vertical mode number')
        text(800,15,'Geostrophic Spectra','color',0.7*[1 1 1])
    else
        set(gca,'YTickLabels',[])
    end

    if n == N
        yticksTemp = yticks;
        ticks_y = 2*pi*sqrt(wvd.wvt.Lr2)./1000;
        labels_y = cell(length(yticksTemp),1);
        for i=1:length(yticksTemp)
            labels_y{i} = sprintf('%0.0f',ticks_y(wvt.j(jInd(i))+1));
        end
        text(0.6*min(xlim)*ones(size(yticksTemp)),yticksTemp,labels_y,...
            'Color',0.5*[1 1 1],'HorizontalAlignment','center')
        %text(0.5*min(xlim),1.05*max(ylim),'$L_r$ (km)',...
        %    'Color',0.5*[1 1 1],'HorizontalAlignment','center')
        text(0.3*min(xlim),10^mean(log10(ylim)),'$2 \pi L_r$ (km)','Color',0.5*[1 1 1],...
            'HorizontalAlignment', 'center', 'Rotation', 90);
    end
    %text(10^2.95,17.25,['(' setstr(real('a')+5+(n-1)) ')'])
    axis square, xlabel('Wavelength (km)')
    colormap(sequentialcolormap)
end

set(gcf,'Units','inches')
set(gcf,'Position',[1 1 10 4.72])
exportgraphics(gcf,figureFolder + "/" + "Figure6_EnergySpectra.png",Resolution=500)