% datadir should point to the folder where the model output file is, the
% diagnostics file, and the EddyTideProfiles.mat
% datadir = "../data/";
% datadir = "/Users/jearly/Dropbox/Shared/Luna-Keshav-Jonathan/";
% datadir = '/Users/cwortham/Documents/research/JeffreyEarly/EddyTideData/';

%% Forced
% simul_type = "Forced";
% datadir = '/Users/lunahiron/Documents/Projects/EddyWave/data/forced/';
% wvtfilepath = fullfile(datadir,"bottom-generated-tide-forced-const-N-5cms.nc");
% 
% figureFolder = "./figures-forced";
% maxDays = 500;
%% Unforced
simul_type = "Forced";
simul_type = "Unforced"; % This flag changes the axis scaling, etc.
datadir = '/Users/jearly/Documents/OceanKitRepositories/JPO2026_EddyTide/model-output';
wvtfilepath = fullfile(datadir,"bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc");

figureFolder = "./figures-unforced";
maxDays = 600;
%%

if ~(exist("wvd","var") && wvd.wvpath == wvtfilepath)
    wvd = WVDiagnostics(wvtfilepath);
    wvt = wvd.wvt;
end

% AMS figure widths, in points
FigureWidth1Col = 19*12;
FigureWidth23Page = 27*12;
FigureWidth2Col = 33*12;

if ~exist(figureFolder, 'dir')
    mkdir(figureFolder)
end

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
colorscheme = 'broc';
% colorscheme = 'vic';
if strcmp(colorscheme,'broc')
    divergingcolormap = WVDiagnostics.crameri('broc');
    sequentialcolormap = flipud(WVDiagnostics.crameri('davos'));
    lowcontourcolor = 'k';
    highcontourcolor = 'w';
elseif strcmp(colorscheme,'vic')
    divergingcolormap = WVDiagnostics.crameri('vik');
    sequentialcolormap = WVDiagnostics.crameri('lapaz');
    lowcontourcolor = 'w';
    highcontourcolor = 'k';
end

