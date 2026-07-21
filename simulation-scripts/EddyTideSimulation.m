%% Eddy Bottom Tide Simulation
%
% Here we construct an ensemble of waves within a given frequency band,
% localed to the bottom of the domain.
%
% The domain is constructed to be similar to Shakespeare (2023)

% addpath(genpath("/Users/jearly/Documents/ProjectRepositories/GLOceanKit-forcing-modules/Matlab"));
% addpath(genpath("/Users/jearly/Documents/ProjectRepositories/chebfun"));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Initialize the wave model with exponential stratification
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Nxy = 256;
lat = 45;

isForced = false;
isConstantStratification = true;
shouldAddMoorings = false;
maxT = 400*86400; % integration time, inertial periods
u0_wave = 0.05;
tideBeamShiftFraction = 0.25; % positive shifts toward +x

if isConstantStratification
    strat_type = "const";
    N0 = sqrt(2e-5);
    Lz = 2000;
    N2 = @(z) N0*N0*ones(size(z));
else
    strat_type = "exp";
    N0 = 3*2*pi/3600;
    L_gm = 1300;
    N2 = @(z) N0*N0*exp(2*z/L_gm);
end

% Here we find the wavelength of the semidiurnal tide, and use that to set
% the model domain size.
M2Period = 12.420602*3600; % M2 tidal period, s
im = InternalModesWKBSpectral(N2=N2,zIn=[-Lz 0],latitude=lat);
[~,~,~,k_sd] = im.ModesAtFrequency(2*pi/(M2Period));
L_sd = (2*pi/k_sd(1));
Lxy = 4*L_sd;
Nz = WVStratification.verticalResolutionForHorizontalResolution(Lxy,Lz,Nxy,N2=N2,latitude=lat);

wvt = WVTransformHydrostatic([Lxy, Lxy, Lz],[Nxy, Nxy, Nz], N2=N2,latitude=lat);

wvt.addForcing(WVAdaptiveDamping(wvt));
svv = wvt.forcingWithName("adaptive damping");

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%% Some stuff for plotting
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Build a few useful tools for making PSD plots
cm = colormap("parula");
cm(1,:) = 1; % I want white for zero

% The dk/2 shift accounts for pcolor's weirdness
% Then convert from radians/m to cycles/km
kAxis = (wvt.kAxis - (wvt.dk)/2)*1e3/(2*pi);
lAxis = (wvt.lAxis - (wvt.dl)/2)*1e3/(2*pi);
kLim = [min(kAxis) max(kAxis)];
xLim = [min(wvt.x) max(wvt.x)]/1e3;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%% Select a wave band around the semi-diurnal frequency +/ dPeriod
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dPeriod = 300;
omega_min =2*pi/(M2Period+dPeriod);
omega_max =2*pi/(M2Period-dPeriod);
Omega = wvt.Omega;
omega_sd = Omega > omega_min & Omega < omega_max;
fprintf('Found %d modes within +/- %d seconds of the semi-diurnal period.\n',sum(omega_sd(:)),dPeriod);

figure(name="Semi-diurnal modes")
OmegaSD = zeros(wvt.spectralMatrixSize);
for j=1:size(omega_sd,1)
    OmegaSD(j,:) = (j-1)*omega_sd(j,:);
end
OmegaSD = sum(OmegaSD,1);
OmegaSD = wvt.transformToKLAxes(OmegaSD);
modemap = flip(turbo); modemap(1,:) = 1;
pcolor(kAxis,lAxis,OmegaSD.'), colormap(modemap); shading flat;  axis equal, xlim(kLim), ylim(kLim) %clim([0 1]),
hold on, plot([0 0],ylim,Color=[0 0 0]),plot(xlim,[0 0],Color=[0 0 0]), xlabel('k (cycles/km)'), ylabel('l (cycles/km)'), title('semi-diurnal wave modes')
cb = colorbar('eastoutside'); cb.Label.String = 'mode';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Select a subset of the semi-diurnal waveband where L = 0, AND is outside the damping region
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
maskApSD = zeros(wvt.spectralMatrixSize);
allIndices = 1:numel(Omega);
for iJ=1:max(wvt.j)
    indices = wvt.L==0 & wvt.j==iJ & wvt.Kh < svv.k_damp & wvt.J < svv.j_damp;
    [~,minIndexSubset] = min(abs(Omega(indices) - 2*pi/M2Period));
    subsetIndices = allIndices(indices);
    maskApSD(subsetIndices(minIndexSubset)) = 1;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Create a wave beam
%
% Use the subset of mode identified in maskApSD to create a wave beam.
% There is probably a better way to do this, but what I chose a functional
% form for the wave beam at one location (which I called taper).
%
% Our tidal modes contain 1 mode for each j, so we have a complete basis.
% However, we do not have a j=0 mode, so our wave function must have
% \int F(z) dz = 0. Below, I choose a functional form that is the second
% derivative of a Gaussian. This shape is zero at the top half of the
% domain.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
wvt.removeAll;
L = 500; % sets the scale of how "tight" the beam is.
taper = 0.10*(1-2*((wvt.z+wvt.Lz)/L).^2) .* exp(-((wvt.z+wvt.Lz)/L).^2);
% trapz(wvt.z,taper)/wvt.Lz;
taperJ = wvt.FMatrix * taper;
for iJ=1:max(wvt.j)
    wvt.Ap( maskApSD ==1 & wvt.J == iJ) = taperJ(iJ);
end

A = u0_wave/wvt.uvMax; % renormalize the total amplitude we want

for iJ=1:max(wvt.j)
    wvt.Ap( maskApSD ==1 & wvt.J == iJ) = A*taperJ(iJ);
end
wvt.Ap = wvt.Ap .* exp(-1i*wvt.K*(tideBeamShiftFraction*L_sd));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Plot the total wave energy
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

TE = wvt.Apm_TE_factor .* (abs(wvt.Ap).^2 + abs(wvt.Am).^2);
figure(Position = [100 100 800 350],Name="Total wave field"), tiledlayout(1,2,TileSpacing="compact");
sp1 = nexttile; pcolor(kAxis,lAxis,log10(sum(wvt.transformToKLAxes(TE),3)).'), colormap(sp1,cm); shading flat; clim( max(log10(TE(:)))-[5 0]), axis equal, xlim(kLim), ylim(kLim)
hold on, plot([0 0],ylim,Color=[0 0 0]),plot(xlim,[0 0],Color=[0 0 0]), xlabel('k (cycles/km)'), ylabel('l (cycles/km)'), title('energy spectrum (log10(m^3/s^2))'), colorbar('eastoutside')
sp2 = nexttile; pcolor(wvt.x/1e3, wvt.y/1e3, 100*wvt.ssh.'), shading interp, colormap(sp2,'parula'), axis equal, xlim(xLim), ylim(xLim)
cb = colorbar('eastoutside');
cb.Label.String = 'cm';
xlabel('x (km)'), ylabel('y (km)'), title('ssh (cm)'), colorbar('eastoutside')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%% y-z slice of (u,v,eta) through the entire domain
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Let's plot a slice through domain
xIndices = 1:wvt.Nx;
yIndices = floor(wvt.Ny/2);
zIndices = 1:wvt.Nz;
horzAxis = wvt.y/1e3;
vertAxis = wvt.z;

figure
tl = tiledlayout(3,1);
title(tl,sprintf('tidal beam on day %d',round(wvt.t/86400)))
xlabel(tl,'y (km)')
ylabel(tl,'depth (m)')

nexttile
p1 = pcolor(horzAxis,vertAxis,squeeze(100*wvt.u(xIndices,yIndices,zIndices)).'); shading interp
title('u (x-velocity)')
cb1 = colorbar('eastoutside');
cb1.Label.String = 'cm/s';
clim([-5 5])

nexttile
p2 = pcolor(horzAxis,vertAxis,squeeze(wvt.zeta_z(xIndices,yIndices,zIndices)).'/wvt.f); shading interp
title('rv')
cb2 = colorbar('eastoutside');
cb2.Label.String = 'f_0';
clim([-0.1 0.1])

nexttile
p3 = pcolor(horzAxis,vertAxis,squeeze(wvt.eta(xIndices,yIndices,zIndices)).'); shading interp
title('\eta (isopycnal deviation)')
cb3 = colorbar('eastoutside');
cb3.Label.String = 'm';
clim([-20 20])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%% Add the eddy
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Consider a "shallow eddy" where the density anomaly sits close to the
% surface. This example was constructed in Early, Hernández-Dueñas, Smith,
% and Lelong (2024), https://arxiv.org/abs/2403.20269

x0 = Lxy/2;
y0 = Lxy/2;

Le = 80e3;
He = 300;
U = 0.10; % m/s

H = @(z) exp(-(z/He/sqrt(2)).^2 );
F = @(x,y) exp(-((x-x0)/Le).^2 -((y-y0)/Le).^2);
psi = @(x,y,z) U*(Le/sqrt(2))*exp(1/2)*H(z).*(F(x,y) - (pi*Le*Le/(wvt.Lx*wvt.Ly)));

wvt.addGeostrophicStreamfunction(psi);

wvt.A0(wvt.Kh > svv.k_damp) = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%% Add the forcing, if appropriate
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if shouldAddMoorings == true
    mooring_string = "-mooring";
else
    mooring_string = "";
end

if isForced == true
    filename = sprintf("bottom-generated-tide-forced"+mooring_string+"-"+strat_type+"-N-%dcms-wave-%dcms-eddy.nc",round(100*u0_wave),round(100*U));
    force = WVFixedAmplitudeForcing(wvt,name="M2-tidal-forcing");
    force.setWaveForcingCoefficients(wvt.Ap,wvt.Am);
    wvt.addForcing(force);
else
    filename = sprintf("bottom-generated-tide-unforced"+mooring_string+"-"+strat_type+"-N-%dcms.nc",round(100*u0_wave));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%% Compute the intrinsic frequency of the wave modes
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Used to put nice labels on the x-axis
ticks_x = [-5;-50;-500; 500;50;5];
labels_x = cell(length(ticks_x),1);
for i=1:length(ticks_x)
    labels_x{i} = sprintf('%.1f',ticks_x(i));
end
ticks_x = 2*pi./(1e3*ticks_x);

frequencies = wvt.transformToKLAxes(wvt.Omega);
frequenciesKJ = squeeze(frequencies(:,wvt.lAxis==0,:));
intrinsicFrequenciesKJ = frequenciesKJ - wvt.kAxis*U;

figure
pcolor(wvt.kAxis,wvt.j,intrinsicFrequenciesKJ.'/wvt.f),shading flat, colorbar('eastoutside'), hold on
contour(wvt.kAxis,wvt.j,intrinsicFrequenciesKJ.'/wvt.f,linspace(0.0,1.0,11),'w','LineWidth',1.5);

colormap(cmocean('balance')), clim([0 2])
% xlog %, ylog
xticks(ticks_x)
xticklabels(labels_x)

if isForced == 1
    MAp = zeros(wvt.spectralMatrixSize);
    MAp(force.Ap_indices) = 1;
    for iJ=1:max(wvt.j)
        scatter(wvt.K(MAp ==1 & wvt.J == iJ),iJ,5^2,0*[1 1 1],'filled');
    end
else
    for iJ=1:max(wvt.j)
        scatter(wvt.K(maskApSD ==1 & wvt.J == iJ),iJ,5^2,0*[1 1 1],'filled');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initialize the model
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% initialize the integrator with the model
model = WVModel(wvt);
outputFile = model.createNetCDFFileForModelOutput(filename,outputInterval=86400/4,shouldOverwriteExisting=false);

if shouldAddMoorings == true
    mooringFieldNames = {"u","v","w","eta","u_g","v_g","eta_g","u_w","v_w","w_w","eta_w","u_io","v_io"};
    moorings = WVMooring(model,nMoorings=400,trackedFieldNames=mooringFieldNames);
    mooringOutputGroup = outputFile.addNewEvenlySpacedOutputGroup("mooring",outputInterval=3600);
    mooringOutputGroup.addObservingSystem(moorings);
end

model.integrateToTime(maxT);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot SSH
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% figure, pcolor(wvt.x/1e3, wvt.y/1e3, squeeze(wvt.zeta_z(:,:,end))/wvt.f.'), shading interp, axis equal

figure, pcolor(wvt.x/1e3, wvt.y/1e3, 100*wvt.ssh.'), shading interp, axis equal
xlim([min(wvt.x) max(wvt.x)]/1e3), ylim([min(wvt.y) max(wvt.y)]/1e3)
cb = colorbar('eastoutside');
cb.Label.String = 'cm';
title('sea surface height')
