# Eddy-tide simulation script

`EddyTideSimulation` adds a single geostrophic eddy and a single wave mode to the simulation. The wave-mode can be forced, or just an initial condition. The script makes several useful plots before starting the simulation.

`EddyTideSimulationMinimal` is the constant-stratification function used for
reproducibility checks. It defaults to the manuscript settings: `Nxy = 256`,
`maxT = 600*86400`, and `outputInterval = 86400/4`. It accepts name-value
options such as `Nxy`, `isForced`, `maxT`, `outputInterval`, `outputDirectory`,
and `shouldOverwriteExisting`, so forced and unforced runs can be launched
without editing code:

```matlab
outputDirectory = "/path/to/JPO2026_EddyTide/model-output";
EddyTideSimulationMinimal(outputDirectory=outputDirectory)
EddyTideSimulationMinimal(isForced=true,outputDirectory=outputDirectory)
```

After the simulation is complete, create the diagnostics file and geostrophic
flux group.

```matlab
wvd = WVDiagnostics(fullfile(outputDirectory,"bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc"));
wvd.createDiagnosticsFile();
wvd.createGeostrophicFluxGroup();
```

The `createGeostrophicFluxGroup` only works for constant stratification at the moment.
