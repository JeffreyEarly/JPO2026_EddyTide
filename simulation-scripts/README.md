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

## Concurrent pseudo-topographic suite

`run-pseudo-topographic-suite.sh` manages a restartable 12-case campaign using independent detached MATLAB processes. The Hiron suite uses the four-mode-one-M2-wavelength domain, approximately 749.284 km, and the Shakespeare suite uses a 500 km domain. Each suite combines strong, moderate, and weak forcing with an initial-eddy run and a no-initial-eddy control. The default campaign runs every case to day 600 at `Nxy=128`, retains the 20 km terrain cutoff, and permits three simultaneous simulation workers:

```sh
./simulation-scripts/run-pseudo-topographic-suite.sh start
./simulation-scripts/run-pseudo-topographic-suite.sh status
```

Model files remain in `model-output`, so the existing matching Hiron moderate-eddy calculation is restored and extended rather than recomputed. Logs, manifests, state markers, and campaign-control files are stored under `model-output/suites/pseudo-topographic-Nxy128-day600-lmin20km`; the enabled-case set is persisted there. Per-model locks live under `model-output/.pseudo-topographic-locks`. Every model receives its own provisional quicklook. Integrations retain scheduling priority. Once all enabled integrations and quicklooks finish, independent energy analyses run concurrently up to the same global worker limit.

Select a subset when starting a campaign:

```sh
./simulation-scripts/run-pseudo-topographic-suite.sh start --suite hiron --initial-condition eddy --forcing all
./simulation-scripts/run-pseudo-topographic-suite.sh start --suite shakespeare --initial-condition both --forcing moderate
```

The selectors are `--suite all|hiron|shakespeare`, `--initial-condition both|eddy|control`, and `--forcing all|strong|moderate|weak`. Their defaults select the full campaign. A later `start` on a stopped campaign adds its selected cases to the persisted set without removing or recomputing prior work. For example, an eddy-first campaign can be expanded with controls after the active workers finish:

```sh
./simulation-scripts/run-pseudo-topographic-suite.sh start --initial-condition eddy
./simulation-scripts/run-pseudo-topographic-suite.sh start --initial-condition control
```

When both members of a suite/forcing pair are enabled, the campaign produces one comparison figure. Its energy panel uses the eddy's initial quadratic total energy as the common normalization, solid lines for the eddy, and dashed lines for the control; its lower panel compares maximum horizontal wave speed. An eddy selected without its control retains the normalized single-run energy figure. A control selected without its eddy uses an absolute-energy, zero-origin figure because the control's initial energy is zero.

Pause the queue without interrupting active NetCDF writers, then resume incomplete simulations or analysis:

```sh
./simulation-scripts/run-pseudo-topographic-suite.sh pause
./simulation-scripts/run-pseudo-topographic-suite.sh resume
```

`pause` only prevents additional queued cases from starting. It deliberately does not kill MATLAB processes. `resume`, `pause`, and `status` operate on the persisted enabled-case set; selection flags are only meaningful for `start`. If a worker fails, the scheduler preserves all partial files, lets already-running workers finish, and stops launching queued cases. Inspect the case or analysis log and `failed.txt` marker, correct the cause, and use `resume`. Simulation validation, model-only quicklooks, standalone energy analysis, and paired energy analysis have separate completion markers, so a failed downstream stage does not trigger reintegration. Per-model locks prevent overlapping campaign invocations from opening the same NetCDF file for writing.

All commands that address an existing suite must use the same scientific options that identify its directory. For example, a later `Nxy=256`, 6 km-cutoff suite with two workers is launched and inspected with:

```sh
./simulation-scripts/run-pseudo-topographic-suite.sh start --nxy 256 --max-workers 2 --minimum-topographic-wavelength-km 6
./simulation-scripts/run-pseudo-topographic-suite.sh status --nxy 256 --minimum-topographic-wavelength-km 6
```

Additional options set `--target-day`, `--output-directory`, and `--matlab-command`. The scheduler derives all default paths from its own location, checks WaveVortexModel 4.2.0 and WaveVortexModelDiagnostics 1.0.7 before launch, and retains a conservative 20 GiB storage reserve. The full default campaign projects approximately 50 GiB of new model output. Status is grouped by Hiron and Shakespeare and parses active worker logs instead of opening NetCDF files that are in read-write mode.

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

Both public functions above analyze one simulation per call. `EddyTidePseudoTopographicEnergyComparison` provides the campaign runner's paired eddy-control energy and wave-speed view with common eddy normalization. Their PNGs are provisional analysis products and are not used by the manuscript figure workflow.
