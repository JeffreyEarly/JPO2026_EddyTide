%% Minimal Eddy Bottom Tide Simulation
%
% This script is a minimal, constant-stratification version of
% `EddyTideSimulation.m`. The forced and unforced runs start from the same
% `A0`, `Ap`, and `Am` coefficients; the forced case only adds
% `WVFixedAmplitudeForcing` during time stepping.
%
% The wave-forcing is from the discrete semidiurnal spectrum. Let
%
% $$\omega_{M2} = \frac{2\pi}{T_{M2}}.$$
%
% For each baroclinic mode $$j \ge 1$$ with an undamped `l = 0`
% coefficient, the script selects the single spectral mode $$(k_j,0,j)$$
% that minimizes
%
% $$\left| \Omega(k,0,j) - \omega_{M2} \right|.$$
%
% The vertical modal weights come from projecting the bottom-localized
% taper onto the rigid-lid vertical basis,
%
% $$a_j = \int_{-L_z}^{0} F_j(z)\,T(z)\,\mathrm{d}z,$$
%
% which is implemented discretely as `taperJ = wvt.FMatrix * taper`. The
% initialized tide uses `Ap(k_j,0,j) = A a_j`, with `A` chosen so that the
% resulting maximum horizontal velocity equals `u0_wave`.
%
% To run:
% /Applications/MATLAB_R2025b.app/bin/matlab -nojvm -nodisplay -nosplash
% > mpmAddRepository("OceanKit","/Users/jearly/Documents/OceanKitRepositories")
% > mpminstall("WaveVortexModel")
% > EddyTideSimulationMinimal

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Initialize the wave model with constant stratification
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Nxy = 256;
lat = 45;

isForced = false;
maxT = 600*86400; % integration time, inertial periods
u0_wave = 0.05;

N0 = sqrt(2e-5);
Lz = 2000;
N2 = @(z) N0*N0*ones(size(z));

% Here we find the wavelength of the semidiurnal tide, and use that to set
% the model domain size.
M2Period = 12.420602*3600; % M2 tidal period, s
im = InternalModesWKBSpectral(N2=N2,zIn=[-Lz 0],latitude=lat);
[~,~,~,k_sd] = im.ModesAtFrequency(2*pi/(M2Period));
L_sd = (2*pi/k_sd(1));
Lxy = 4*L_sd;
Nz = WVStratification.verticalResolutionForHorizontalResolution(Lxy,Lz,Nxy,N2=N2,latitude=lat);

% wvt = WVTransformConstantStratification([Lxy, Lxy, Lz],[Nxy, Nxy, Nz], N0=N0, latitude=lat);
wvt = WVTransformBoussinesq([Lxy, Lxy, Lz],[Nxy, Nxy, Nz], N2=@(z) N0*N0*ones(size(z)),latitude=lat);

wvt.addForcing(WVAdaptiveDamping(wvt));
svv = wvt.forcingWithName("adaptive damping");

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Select a subset of the semi-diurnal waveband where L = 0, and is outside
% the damping region.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
maskApSD = zeros(wvt.spectralMatrixSize);
for iJ=1:max(wvt.j)
    indices = find(wvt.L==0 & wvt.j==iJ & wvt.Kh < svv.k_damp & wvt.J < svv.j_damp);
    if isempty(indices)
        continue
    end
    [~,minIndexSubset] = min(abs(wvt.Omega(indices) - 2*pi/M2Period));
    maskApSD(indices(minIndexSubset)) = 1;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Create a wave beam
%
% Use the subset of modes identified in maskApSD to create a wave beam.
% The taper is the second derivative of a Gaussian, which gives the
% bottom-enhanced vertical structure used to set the modal weights.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
wvt.removeAll;
L = 500; % sets the scale of how "tight" the beam is.
taper = 0.10*(1-2*((wvt.z+wvt.Lz)/L).^2) .* exp(-((wvt.z+wvt.Lz)/L).^2);
taperJ = wvt.FMatrix * taper;
for iJ=1:max(wvt.j)
    wvt.Ap(maskApSD ==1 & wvt.J == iJ) = taperJ(iJ);
end

wvt.Ap = u0_wave*wvt.Ap/wvt.uvMax; % renormalize the total amplitude we want

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Add the eddy
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
% Add the forcing, if appropriate
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isForced
    filename = sprintf("bottom-generated-tide-forced-const-N-%dcms-wave-%dcms-eddy.nc",round(100*u0_wave),round(100*U));
    force = WVFixedAmplitudeForcing(wvt,name="M2-tidal-forcing");
    force.setWaveForcingCoefficients(wvt.Ap,wvt.Am);
    wvt.addForcing(force);
else
    filename = sprintf("bottom-generated-tide-unforced-const-N-%dcms-wave-%dcms-eddy.nc",round(100*u0_wave),round(100*U));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initialize the model
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

model = WVModel(wvt);
model.createNetCDFFileForModelOutput(filename,outputInterval=86400/4,shouldOverwriteExisting=false);
model.integrateToTime(maxT);
