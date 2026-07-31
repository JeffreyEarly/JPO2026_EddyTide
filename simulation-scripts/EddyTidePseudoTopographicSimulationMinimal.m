function [model,wvt,filename] = EddyTidePseudoTopographicSimulationMinimal(options)
% Run a minimal eddy-tide simulation with pseudo-topographic generation.
%
% The model starts with no wave field. A spatially uniform zonal M2 current
% generates waves through
%
% $$
% w_b=U_{\mathrm{bt}}(t)\partial_x h,
% $$
%
% where $$h(x,y)$$ is a deterministic Goff abyssal-hill realization. The
% pseudo-topography modifies the bottom boundary condition without changing
% the flat model geometry. Generation automatically avoids the exact
% spectral support of `WVAdaptiveDamping`.
%
% Select either a named forcing regime or a custom zonal barotropic-current
% speed. The named speeds are $$0.05/\sqrt{10}$$, $$0.05/\sqrt{40}$$, and
% $$0.05/\sqrt{160}\ \mathrm{m\,s^{-1}}$$ for `"strong"`, `"moderate"`, and
% `"weak"`, respectively. The corresponding wave-speed scales depend on the
% domain, resolution, and terrain bandwidth.
%
% Select the square-domain width directly with `Lxy`, or as a multiple of
% the mode-one M2 wavelength with `domainSizeTidalWavelengths`. Omitting both
% uses four mode-one M2 wavelengths. Supplying both domain options, or both
% forcing options, is an error.
%
% ```matlab
% [model,wvt,filename] = EddyTidePseudoTopographicSimulationMinimal;
% [model,wvt,filename] = EddyTidePseudoTopographicSimulationMinimal(Nxy=256,Lxy=500e3,minimumTopographicWavelength=6e3,forcingRegime="strong");
% ```
%
% When the target file exists and `shouldOverwriteExisting` is false, the
% model restarts from its final saved state and appends output.
%
% - Declaration: [model,wvt,filename] = EddyTidePseudoTopographicSimulationMinimal(options)
% - Parameter options.Nxy: horizontal resolution in each direction
% - Parameter options.Lxy: square-domain width in meters
% - Parameter options.domainSizeTidalWavelengths: square-domain width in mode-one M2 wavelengths
% - Parameter options.forcingRegime: named `"strong"`, `"moderate"`, or `"weak"` current amplitude
% - Parameter options.barotropicCurrentSpeed: custom nonnegative zonal-current amplitude in meters per second
% - Parameter options.includeEddy: whether to initialize the shallow Gaussian eddy
% - Parameter options.maxT: final integration time in seconds
% - Parameter options.outputInterval: NetCDF output interval in seconds
% - Parameter options.outputDirectory: output folder
% - Parameter options.shouldOverwriteExisting: whether to replace existing output instead of restarting
% - Parameter options.minimumTopographicWavelength: shortest retained terrain wavelength in meters
% - Returns model: integrated model with its output file closed
% - Returns wvt: integrated constant-stratification transform
% - Returns filename: restartable NetCDF output path
arguments (Input)
    options.Nxy (1,1) double {mustBeInteger,mustBePositive} = 128
    options.Lxy (1,1) double {mustBePositive,mustBeFinite}
    options.domainSizeTidalWavelengths (1,1) double {mustBePositive,mustBeFinite}
    options.forcingRegime (1,1) string
    options.barotropicCurrentSpeed (1,1) double {mustBeNonnegative,mustBeFinite}
    options.includeEddy (1,1) logical = true
    options.maxT (1,1) double {mustBePositive,mustBeFinite} = 600*86400
    options.outputInterval (1,1) double {mustBePositive,mustBeFinite} = 86400/4
    options.outputDirectory (1,1) string = defaultOutputDirectory()
    options.shouldOverwriteExisting (1,1) logical = false
    options.minimumTopographicWavelength (1,1) double {mustBePositive,mustBeFinite} = 20e3
end
arguments (Output)
    model WVModel
    wvt WVTransformConstantStratification
    filename (1,1) string
end

hasLxy = isfield(options,"Lxy");
hasTidalDomainSize = isfield(options,"domainSizeTidalWavelengths");
if hasLxy && hasTidalDomainSize
    error("EddyTidePseudoTopographicSimulationMinimal:ConflictingDomainOptions", "Specify either Lxy or domainSizeTidalWavelengths, but not both.")
end

hasForcingRegime = isfield(options,"forcingRegime");
hasCustomCurrent = isfield(options,"barotropicCurrentSpeed");
if hasForcingRegime && hasCustomCurrent
    error("EddyTidePseudoTopographicSimulationMinimal:ConflictingForcingOptions", "Specify either forcingRegime or barotropicCurrentSpeed, but not both.")
end

N0 = sqrt(2e-5);
Lz = 2000;
latitude = 45;
M2Period = 12.420602*3600;
N2 = @(z)N0*N0*ones(size(z));

internalModes = InternalModesWKBSpectral(N2=N2,zIn=[-Lz 0],latitude=latitude);
[~,~,~,kM2] = internalModes.modesAtFrequency(2*pi/M2Period);
modeOneWavelength = 2*pi/kM2(1);
if hasLxy
    Lxy = options.Lxy;
else
    if hasTidalDomainSize
        domainSizeTidalWavelengths = options.domainSizeTidalWavelengths;
    else
        domainSizeTidalWavelengths = 4;
    end
    Lxy = domainSizeTidalWavelengths*modeOneWavelength;
end

if hasCustomCurrent
    barotropicCurrentSpeed = options.barotropicCurrentSpeed;
    forcingToken = sprintf("custom-Ubt%gcms",100*barotropicCurrentSpeed);
else
    if hasForcingRegime
        forcingRegime = options.forcingRegime;
    else
        forcingRegime = "moderate";
    end
    switch forcingRegime
        case "strong"
            barotropicCurrentSpeed = 0.05/sqrt(10);
        case "moderate"
            barotropicCurrentSpeed = 0.05/sqrt(40);
        case "weak"
            barotropicCurrentSpeed = 0.05/sqrt(160);
        otherwise
            error("EddyTidePseudoTopographicSimulationMinimal:UnknownForcingRegime", "forcingRegime must be ""strong"", ""moderate"", or ""weak"".")
    end
    forcingToken = char(forcingRegime);
end

if options.includeEddy
    caseName = "eddy";
else
    caseName = "control";
end
filename = fullfile(options.outputDirectory,string(sprintf("eddy-tide-pseudo-topographic-%s-Lxy%gkm-Nxy%d-%s-hrms100m-lmin%gkm-seed2023.nc",caseName,Lxy/1e3,options.Nxy,forcingToken,options.minimumTopographicWavelength/1e3)));

if ~isfolder(options.outputDirectory)
    mkdir(options.outputDirectory)
end
if isfile(filename) && ~options.shouldOverwriteExisting
    model = WVModel.modelFromFile(char(filename));
    outputCleanup = onCleanup(@()model.closeNetCDFFile());
    wvt = model.wvt;
    model.integrateToTime(options.maxT);
    clear outputCleanup
    return
end

Nz = WVStratification.verticalResolutionForHorizontalResolution(Lxy,Lz,options.Nxy,N2=N2,latitude=latitude);
wvt = WVTransformConstantStratification([Lxy Lxy Lz],[options.Nxy options.Nxy Nz],N0=N0,latitude=latitude,isHydrostatic=false,shouldAntialias=true);
wvt.addForcing(WVAdaptiveDamping(wvt));
adaptiveDamping = wvt.forcingWithName("adaptive damping");
wvt.removeAll;

if options.includeEddy
    addShallowGaussianEddy(wvt,adaptiveDamping)
end

[~,topographicHeight] = WVPseudoTopographicWaveGeneration.goffAbyssalHillTopography(wvt,rmsHeight=100,cornerWavenumber=1e-4,minimumWavelength=options.minimumTopographicWavelength,randomSeed=2023);
generation = WVPseudoTopographicWaveGeneration(wvt,topographicHeight=topographicHeight,barotropicVelocityAmplitude=[barotropicCurrentSpeed; 0],darwinSymbol="M2",rampDuration=M2Period,startTime=0);
wvt.addForcing(generation);

model = WVModel(wvt);
model.createNetCDFFileForModelOutput(char(filename),outputInterval=options.outputInterval,shouldOverwriteExisting=options.shouldOverwriteExisting);
outputCleanup = onCleanup(@()model.closeNetCDFFile());
model.integrateToTime(options.maxT);
clear outputCleanup
end

function addShallowGaussianEddy(wvt,adaptiveDamping)
x0 = wvt.Lx/2;
y0 = wvt.Ly/2;
Le = 80e3;
He = 300;
U = 0.10;
verticalStructure = @(z)exp(-(z/He/sqrt(2)).^2);
horizontalStructure = @(x,y)exp(-((x-x0)/Le).^2-((y-y0)/Le).^2);
psi = @(x,y,z)U*(Le/sqrt(2))*exp(1/2)*verticalStructure(z).*(horizontalStructure(x,y)-pi*Le*Le/(wvt.Lx*wvt.Ly));
wvt.addGeostrophicStreamfunction(psi);
wvt.A0(wvt.Kh > adaptiveDamping.k_damp) = 0;
end

function outputDirectory = defaultOutputDirectory()
[scriptFolder,~,~] = fileparts(mfilename("fullpath"));
outputDirectory = string(fullfile(fileparts(scriptFolder),"model-output"));
end
