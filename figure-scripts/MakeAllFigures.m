function MakeAllFigures(options)
% Build all manuscript figures and Table 1 from eddy-tide model output.
%
% - Declaration: MakeAllFigures(options)
% - Parameter figureDataDir: folder containing model output and diagnostics, default repository `model-output`
% - Parameter figureFolder: output folder for figures, default repository `figures-unforced`
arguments (Input)
    options.figureDataDir (1,1) string = defaultFigureDataDir()
    options.figureFolder (1,1) string = defaultFigureFolder()
end

figureDataDir = options.figureDataDir; %#ok<NASGU>
figureFolder = options.figureFolder; %#ok<NASGU>

Figure1_EddySchematic
Figure2_TidalForcingScatter
Figure3_EddySnapshots
Figure4_EnergyTimeSeries
Figure5_EnergyDepthEvolution
Figure6b_EnergySpectra
Figure7_EnergyFluxTimeSeries
Figure8_FluxSpectra
Figure9_EnergyTimeSeries_a
Table1_EnergyFluxRMS

end

function figureDataDir = defaultFigureDataDir()
[scriptFolder,~,~] = fileparts(mfilename("fullpath"));
figureDataDir = string(fullfile(fileparts(scriptFolder),"model-output"));
end

function figureFolder = defaultFigureFolder()
[scriptFolder,~,~] = fileparts(mfilename("fullpath"));
figureFolder = string(fullfile(fileparts(scriptFolder),"figures-unforced"));
end
