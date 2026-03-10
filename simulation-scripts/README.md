#  Eddy-tide simulation script

`EddyTideSimulation` adds a single geostrophic eddy and a single wave mode to the simulation. The wave-mode can be forced, or just an initial condition. The script makes several useful plots before starting the simulation.

After the simulation is complete, you need to create the diagnostics file.

```matlab
wvd = WVDiagnostics("bottom-generated-tide-unforced-const-N-5cms.nc");
wvd.createDiagnosticsFile();
wvd.createGeostrophicFluxGroup();
```

The `createGeostrophicFluxGroup` only works for constant stratification at the moment.
