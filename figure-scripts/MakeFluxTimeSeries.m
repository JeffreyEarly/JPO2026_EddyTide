%MakeFluxTimeSeries

dt = t(2) - t(1);

E_gm = 3.74;
flux_conversion = 86400*365/E_gm;
flux_units = 'GM/yr';

[E_g,KE_g,PE_g,E_mda,E_w,E_io,ke,pe_quad,ape] = ...
    diagfile.readVariables('E_g','KE_g','PE_g','E_mda','E_w','E_io','ke','pe_quadratic','ape');
[Z_quad,Z_apv] = diagfile.readVariables('enstrophy_quadratic','enstrophy_apv');

%--------------------------------------------------------------------------
% Fetch all the *forcing* fluxes, and sum them spatially
filter_sum_kj = @(v) squeeze(sum(sum(v,1),2));

EnergyForcing = configureDictionary('string','cell');
EnergyForcingSummed = configureDictionary('string','cell');
forcingNames = wvt.forcingNames;
for i=1:length(forcingNames)
     %replace space or - with _ 
     forcingNames(i) = replace(replace(forcingNames(i),'-','_'),' ','_');
end
for i=1:length(forcingNames)
    name = forcingNames(i);
    Ep = diagfile.readVariables('Ep_' + name);
    Em = diagfile.readVariables('Em_' + name);
    KE0 = diagfile.readVariables('KE0_' + name);
    PE0 = diagfile.readVariables('PE0_' + name);

    EnergyForcing{'ke_g_' + name} = filter_sum_kj(KE0);
    EnergyForcing{'pe_g_' + name} = filter_sum_kj(PE0);
    EnergyForcing{'te_g_' + name} = EnergyForcing{'ke_g_' + name} ...
        + EnergyForcing{'pe_g_' + name};
    EnergyForcing{'te_igw_' + name} = filter_sum_kj(Ep+Em);
    EnergyForcingSummed{forcingNames(i)} = EnergyForcing{'te_g_' + name} ...
        + EnergyForcing{'te_igw_' + name};
end
%--------------------------------------------------------------------------
%Fetch all the *triad* fluxes, and sum them spatially
filter = @(v) squeeze(sum(sum(v,1),2));
triadFlowComponents = ...
    [wvt.flowComponentWithName('wave');...
    wvt.flowComponentWithName('inertial'); ...
    wvt.flowComponentWithName('geostrophic'); ...
    wvt.flowComponentWithName('mda')];
EnergyTriads = configureDictionary('string','cell');
for i=1:length(triadFlowComponents)
    for j=1:length(triadFlowComponents)
        name = triadFlowComponents(i).abbreviatedName +  ...
            '_' + triadFlowComponents(j).abbreviatedName;
        Ep = diagfile.readVariables('Ep_' + name);
        Em = diagfile.readVariables('Em_' + name);
        KE0 = diagfile.readVariables('KE0_' + name);
        PE0 = diagfile.readVariables('PE0_' + name);

        EnergyTriads{'ke_g_' + name} = filter(KE0);
        EnergyTriads{'pe_g_' + name} = filter(PE0);
        EnergyTriads{'te_g_' + name} = EnergyTriads{'ke_g_' + name} + ...
            EnergyTriads{'pe_g_' + name};
        EnergyTriads{'te_igw_' + name} = filter(Ep+Em);
    end
end
%--------------------------------------------------------------------------
%Make flux plots, sorted by flow component

%remove 'nonlinear advection' from the list of forcing names
%the 'sort' guarantees that M2_tidal_forcing comes before adaptive_damping
forcingNames = setdiff(forcingNames,'nonlinear_advection','sorted');

fluxComponentNames = {'te_g_','ke_g_', 'pe_g_'};
Energy = {KE_g+PE_g,KE_g,PE_g};

hl=zeros(3,1);
for n = 1:length(fluxComponentNames)
    subplot(3,1,n)

    %time rate of change
    hl(n)=plot(t, vfilt(flux_conversion*vdiff(dt*86400,Energy{n},1),21), ...
        'Zdata',-1*t);hold on

    %triads
    iFlux = 0;
    w_grad_w = 0;
    g_grad_w = 0;
    w_grad_g = 0;
    for i=1:length(triadFlowComponents)
        for j=1:length(triadFlowComponents)
            iFlux = iFlux+1;
            name = triadFlowComponents(i).abbreviatedName + '_' + ...
                triadFlowComponents(j).abbreviatedName;
            if ismember(iFlux,[1 2 5 6]) %w_w,w_io,io_w,io_io
                w_grad_w = EnergyTriads{fluxComponentNames(n) + name} + w_grad_w;
            end
            if ismember(iFlux,[9 10]) %g_w, g_io
                g_grad_w = EnergyTriads{fluxComponentNames(n) + name} + g_grad_w;
            end
            if ismember(iFlux,[3 7]) %w_g, io_g
                w_grad_g = EnergyTriads{fluxComponentNames(n) + name} + w_grad_g;
            end
            if ismember(iFlux,11) %g_g
                g_grad_g = EnergyTriads{fluxComponentNames(n) + name};
            end
        end
    end

    plot(t,flux_conversion*vfilt(w_grad_w,21));hold on 
    plot(t,flux_conversion*vfilt(g_grad_w,21));
    plot(t,flux_conversion*vfilt(w_grad_g,21));
    plot(t,flux_conversion*vfilt(g_grad_g,21),...
        'w','linewidth',3,'HandleVisibility','off');
    plot(t,flux_conversion*vfilt(g_grad_g,21));

    %mean((flux_conversion*vfilt(w_grad_w,1)).^2)%0.0016    
    %mean((flux_conversion*vfilt(g_grad_w,1)).^2)%0.0051
    %mean((flux_conversion*vfilt(w_grad_g,1)).^2)%0.0016    
    %mean((flux_conversion*vfilt(g_grad_g,1)).^2)%0.0579

    %forcing
    for i=1:length(forcingNames)
        name = forcingNames(i);
        plot(t,flux_conversion * ...
            vfilt(EnergyForcing{fluxComponentNames(i) + name},21));
    end
end

axs = packfig(3,1,'rows');
for i=1:3
    axes(axs(i))
    xlim([0 400]),ylim([-0.95 0.95]),yticks(-1:.2:1)
    linestyle thick
    vlines(t_phaseII,'1D:')
    vlines(t_phaseIII,'1D:')
    if i == 1
        hleg=legend('d/dt','w{\nabla}w','g{\nabla}w','w{\nabla}g',...
            'g{\nabla}g','M2 Tidal Forcing','Adaptive Damping',...
            'Location','northwest','NumColumns',2);
        text(80,-0.6,'Phase I','color',0.7*[1 1 1])
        text(235,-0.6,'Phase II','color',0.7*[1 1 1])
        text(330,-0.6,'Phase III','color',0.7*[1 1 1])
        ylabel('$\mathcal{E}_g$ Flux (GM/yr)')
    elseif i == 2
        ylabel('$\mathcal{K}_g$ Flux (GM/yr)') 
    elseif i == 3
        xlabel('Time (days)')
        ylabel('$\mathcal{P}_g$ Flux (GM/yr)')
    end
    text(375,0.8,['(' char(real('a')+i-1) ')'])
end

linestyle(hl,'5T')

set(gcf,'paperposition',[1 1 5 6])
jprint(printdir,'FluxTimeSeries','-r500')