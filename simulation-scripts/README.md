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

## Pseudo-topographic generation

`EddyTidePseudoTopographicSimulationMinimal` starts without an initialized wave beam and instead generates M2 waves from a prescribed zonal barotropic current over deterministic Goff abyssal hills. This optional experiment requires WaveVortexModel 4.2.0, which is available through OceanKit. The manuscript reproduction environment remains pinned to WaveVortexModel 4.0.7.

The default calculation uses `Nxy=128`, four mode-one M2 wavelengths, a 20 km terrain cutoff, and the moderate forcing regime:

```matlab
EddyTidePseudoTopographicSimulationMinimal
```

The named regimes set the zonal barotropic-current amplitude:

| Regime | Current amplitude | Nominal energy-input scale |
|---|---:|---:|
| `"strong"` | $$0.05/\sqrt{10}\ \mathrm{m\,s^{-1}}$$ | $$E_{\mathrm{in}}/10$$ |
| `"moderate"` | $$0.05/\sqrt{40}\ \mathrm{m\,s^{-1}}$$ | $$E_{\mathrm{in}}/40$$ |
| `"weak"` | $$0.05/\sqrt{160}\ \mathrm{m\,s^{-1}}$$ | $$E_{\mathrm{in}}/160$$ |

Select a regime or provide a custom nonnegative zonal speed:

```matlab
EddyTidePseudoTopographicSimulationMinimal(forcingRegime="strong")
EddyTidePseudoTopographicSimulationMinimal(forcingRegime="moderate")
EddyTidePseudoTopographicSimulationMinimal(forcingRegime="weak")
EddyTidePseudoTopographicSimulationMinimal(barotropicCurrentSpeed=0.01)
```

The strong and weak presets produced late-run maximum horizontal wave speeds of approximately 20 cm/s and 5 cm/s in the 500 km, `Nxy=256`, 6 km-cutoff experiments. The moderate value interpolates to approximately 10 cm/s. These are empirical guides, not guaranteed outcomes when the domain, resolution, or terrain bandwidth changes.

Set the square-domain width directly, or as a multiple of the mode-one M2 wavelength. The two options are mutually exclusive:

```matlab
EddyTidePseudoTopographicSimulationMinimal(Lxy=500e3)
EddyTidePseudoTopographicSimulationMinimal(domainSizeTidalWavelengths=6)
```

The active strong-forcing configuration is reproduced with:

```matlab
EddyTidePseudoTopographicSimulationMinimal(Nxy=256,Lxy=500e3,minimumTopographicWavelength=6e3,forcingRegime="strong")
```

Use `includeEddy=false` for the matched control. Existing output is restored and extended unless `shouldOverwriteExisting=true` is supplied. The simulation driver does not create diagnostics or manuscript figures.

## Provisional pseudo-topographic figures

The provisional quicklook reads the model output directly and requires only WaveVortexModel. The model writer must be closed before analysis; `EddyTidePseudoTopographicSimulationMinimal` closes it before returning.

```matlab
[~,~,modelFile] = EddyTidePseudoTopographicSimulationMinimal(maxT=25*86400);
[figures,summary] = EddyTidePseudoTopographicQuicklook(modelFile);
```

This produces state and spectral figures at the final saved time by default. The state figure includes a midpoint vertical-vorticity section, and the spectral figure shows absolute wave and geostrophic energy with a fixed $$10^{-8}\ \mathrm{m^3\,s^{-2}}$$ plotting floor. Select another saved record with `iTime` and suppress file export with `shouldExport=false`.

The energy-history figure additionally requires WaveVortexModelDiagnostics 1.0.7 or newer:

```matlab
[figureHandle,energy,diagnosticsFile] = EddyTidePseudoTopographicEnergyDiagnostics(modelFile);
```

Missing diagnostics are created at full saved cadence and stale diagnostics are extended by default. The top panel follows the normalized-energy panel of manuscript Figure 4: total quadratic energy, internal-gravity-wave energy $$E_w$$, geostrophic energy, geostrophic kinetic energy, and geostrophic potential energy are normalized by the initial total quadratic energy. The bottom panel shows $$\max_{x,y,z}\sqrt{u_w^2+v_w^2}$$ at every saved model time, independent of the diagnostics stride. Phase boundaries are omitted. The returned `energy.wave` field remains the combined reservoir $$E_w+E_{io}$$, with the internal-wave and inertial components also returned separately. Set `shouldUpdateDiagnostics=false` to require an already-current diagnostics file.

Both functions analyze one simulation per call. Call them separately for the initial-eddy and control outputs. Their PNGs are provisional analysis products and are not used by the manuscript figure workflow.
