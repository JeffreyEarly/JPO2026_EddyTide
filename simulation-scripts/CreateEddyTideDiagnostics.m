function diagnosticsFiles = CreateEddyTideDiagnostics(options)
% Create diagnostics files for the manuscript eddy-tide simulations.
%
% CreateEddyTideDiagnostics computes any missing standard diagnostics files
% and ensures the geostrophic-flux group is present for the unforced and forced
% manuscript outputs produced by `EddyTideSimulationMinimal`.
%
% - Declaration: diagnosticsFiles = CreateEddyTideDiagnostics(options)
% - Parameter outputDirectory: folder containing model output, default repository `model-output`
% - Returns diagnosticsFiles: generated diagnostics NetCDF file paths
arguments (Input)
    options.outputDirectory (1,1) string = defaultOutputDirectory()
end
arguments (Output)
    diagnosticsFiles (2,1) string
end

simulationFiles = [
    "bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc"
    "bottom-generated-tide-forced-const-N-5cms-wave-10cms-eddy.nc"
];
diagnosticsFiles = strings(size(simulationFiles));

for iFile = 1:numel(simulationFiles)
    simulationFile = fullfile(options.outputDirectory,simulationFiles(iFile));
    diagnosticsFiles(iFile) = erase(simulationFile,".nc") + "-diagnostics.nc";
    wvd = WVDiagnostics(simulationFile);
    if ~isfile(diagnosticsFiles(iFile))
        wvd.createDiagnosticsFile();
    end
    wvd.createGeostrophicFluxGroup();
end

end

function outputDirectory = defaultOutputDirectory()
[scriptFolder,~,~] = fileparts(mfilename("fullpath"));
outputDirectory = string(fullfile(fileparts(scriptFolder),"model-output"));
end
