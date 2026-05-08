# Eddy-tide simulation scripts

`EddyTideSimulationMinimal` is the function used for manuscript
reproducibility checks. It defaults to `Nxy = 256`, `maxT = 600*86400`, and
`outputInterval = 86400/4`. It accepts name-value options such as `Nxy`,
`isForced`, `maxT`, `outputInterval`, `outputDirectory`, and
`shouldOverwriteExisting`, so forced and unforced runs can be launched without
editing code:

```matlab
outputDirectory = "/path/to/JPO2026_EddyTide/model-output";
EddyTideSimulationMinimal(outputDirectory=outputDirectory)
EddyTideSimulationMinimal(isForced=true,outputDirectory=outputDirectory)
```

After the simulations complete, create the diagnostics files and geostrophic
flux groups:

```matlab
CreateEddyTideDiagnostics(outputDirectory=outputDirectory)
```

`EddyTideSimulation` is the fuller exploratory script. It adds the same eddy and
wave mode, with extra plots before starting the simulation.
