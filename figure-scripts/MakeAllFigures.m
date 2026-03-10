readdir = '/Users/lilly/Desktop/Dropbox/NetCDF';
filename = 'bottom-generated-tide-forced-const-N-5cms.nc';

set(groot,'defaultAxesFontName','Georgia')
set(groot,'defaultTextFontName','Georgia')
set(groot,'defaultLegendFontName','Georgia')
set(groot,'defaultColorbarFontName','Georgia')
set(groot,'defaultaxesfontsize',10)
set(groot,'defaulttextfontsize',10)
set(groot,'defaultColorBarFontSize',10)
set(groot,'defaultTextInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
set(groot,'defaultLineLineWidth',1.5)
set(groot,'defaultScatterMarkerFaceColor','k')
set(groot,'defaultScatterMarkerEdgeColor','white')
%colorscheme = 'broc';
colorscheme = 'vic';
if strcmp(colorscheme,'broc')
    printdir = '/Users/Lilly/Desktop/Dropbox/Projects/catalyze/Figures-broc';
    divergingcolormap = crameri('broc');
    sequentialcolormap = flipud(crameri('davos'));
    lowcontourcolor = 'k';
    highcontourcolor = 'w';
elseif strcmp(colorscheme,'vic')
    printdir = '/Users/Lilly/Desktop/Dropbox/Projects/catalyze/Figures-vik';
    divergingcolormap = crameri('vik');
    sequentialcolormap = crameri('lapaz');
    lowcontourcolor = 'w';
    highcontourcolor = 'k';
end
%--------------------------------------------------------------------------
[wvt,ncfile] = WVTransform.waveVortexTransformFromFile([readdir '/' filename]);
wvd = WVDiagnostics([readdir '/' filename]);
diagfile = NetCDFFile([readdir '/' filename(1:end-3) '-diagnostics.nc']);
t = diagfile.readVariables('t')/86400;  %convert to days

%Find phase edges
[E_g,KE_g,PE_g,E_mda,E_w,E_io,ke,pe_quad,ape] = diagfile.readVariables('E_g','KE_g','PE_g','E_mda','E_w','E_io','ke','pe_quadratic','ape');
[Z_quad,Z_apv] = diagfile.readVariables('enstrophy_quadratic','enstrophy_apv');
%t_phaseII = t(find(PE_g/PE_g(1) < .99, 1, 'first'));
%t_phaseIII = t(Z_quad == max(Z_quad));

dPE_g = vdiff(PE_g,1);
[maxflux,imaxflux] = max(abs(dPE_g));
t_phaseII = t(find(dPE_g<-0.1*maxflux,1,'first'));
t_phaseIII = t(find(dPE_g>-0.1*maxflux & t>t(imaxflux),1,'first'));
%--------------------------------------------------------------------------
ComputeEddyTideProfiles
%--------------------------------------------------------------------------
MakeEddySchematic
%--------------------------------------------------------------------------
MakeTidalForcingScatter
%--------------------------------------------------------------------------
MakeEnergySpectra
%--------------------------------------------------------------------------
MakeEnergyTimeSeries
%--------------------------------------------------------------------------
MakeFluxTimeSeries
%--------------------------------------------------------------------------
MakeEnergyDepthEvolution
%--------------------------------------------------------------------------
MakeEddySnapshots
%--------------------------------------------------------------------------
