[scriptFolder,~,~] = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptFolder);
datadir = fullfile(repoRoot,"model-output");
if ~exist("figureSimulationType","var")
    figureSimulationType = "Unforced";
end

simul_type = figureSimulationType; % This flag changes the axis scaling, etc.
if figureSimulationType == "Forced"
    wvtfilepath = fullfile(datadir,"bottom-generated-tide-forced-const-N-5cms-wave-10cms-eddy.nc");
elseif figureSimulationType == "Unforced"
    wvtfilepath = fullfile(datadir,"bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc");
else
    error("JPO2026:InvalidFigureSimulationType","figureSimulationType must be ""Forced"" or ""Unforced"".")
end
maxDays = 600;
clear figureSimulationType

if ~exist("figureFolder","var")
    figureFolder = fullfile(repoRoot,"figures-unforced");
end

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
