# Internal tides catalyze geostrophic eddy instabilities

This repository contains all the code necessary to run the simulations and recreate the figures in the manuscript.

## Installation

After you clone this repository, you will need to install the [WaveVortexModel](https://wavevortexmodel.org) and the [WaveVortexModel Diagnostics](https://energy-pathways-group.github.io/wave-vortex-model-diagnostics/) Matlab packages.

You must first install the [OceanKit](https://github.com/JeffreyEarly/OceanKit) package manager repository, then install the exact package versions used for this paper:

- `WaveVortexModel` version `4.0.7`
- `WaveVortexModelDiagnostics` version `1.0.6`

### 1. Package Manager Repository installation

Clone OceanKit
```shell
git clone https://github.com/JeffreyEarly/OceanKit.git
```
from the command-line. Within Matlab, add this folder as an MPM repository,
```matlab
mpmAddRepository("OceanKit", "/path/to/OceanKit")
```

If you already have an old or stale OceanKit repository registered, remove it first:

```matlab
mpmRemoveRepository("OceanKit")
```

### 2. Basic installation

Install the pinned model and diagnostics packages:

```matlab
mpminstall(matlab.mpm.PackageSpecifier("WaveVortexModel", VersionRange="4.0.7"))
mpminstall(matlab.mpm.PackageSpecifier("WaveVortexModelDiagnostics", VersionRange="1.0.6"))
```

This approach installs the released package snapshots and their dependencies.

## Reproducing the manuscript

`simulation-scripts/EddyTideSimulationMinimal.m` is the minimal manuscript
simulation. It defaults to `Nxy = 256`, a 600-day run, quarter-day output, and
the unforced case. The commands below run the unforced and forced simulations,
create diagnostics, and recreate the manuscript figures.

```matlab
repoRoot = "/path/to/JPO2026_EddyTide";
addpath(fullfile(repoRoot,"simulation-scripts"))
addpath(fullfile(repoRoot,"figure-scripts"))

modelOutput = fullfile(repoRoot,"model-output");
figureOutput = fullfile(repoRoot,"figures-unforced");

EddyTideSimulationMinimal(outputDirectory=modelOutput)
EddyTideSimulationMinimal(isForced=true,outputDirectory=modelOutput)

CreateEddyTideDiagnostics(outputDirectory=modelOutput)

MakeAllFigures(figureDataDir=modelOutput,figureFolder=figureOutput)
```

The recreated figures are written to `figures-unforced`. Figures 1, 3, 4, 5, 6,
7, 8, and Table 1 use the unforced simulation output. Figures 2 and 9 use the
forced simulation output.

The manuscript uses the constant-stratification transform. A separate
Boussinesq comparison was used to validate that this simplified reproduction
gives the same result, but it is not required for recreating the paper.

## Clean verification

To verify the install instructions from a clean MATLAB path, run a fresh MATLAB session and use the commands below. This resets the saved MATLAB path, uninstalls MPM packages, reinstalls the pinned packages from OceanKit, and recreates the figures.

```matlab
repoRoot = "/path/to/JPO2026_EddyTide";
oceanKitPath = "/path/to/OceanKit";

restoredefaultpath
rehash toolboxcache
savepath

installedPackages = mpmlist;
if ~isempty(installedPackages)
    mpmuninstall(installedPackages, Prompt=false, Force=true)
end

try
    mpmRemoveRepository("OceanKit")
catch
end
mpmAddRepository("OceanKit", oceanKitPath)

mpminstall(matlab.mpm.PackageSpecifier("WaveVortexModel", VersionRange="4.0.7"), Prompt=false)
mpminstall(matlab.mpm.PackageSpecifier("WaveVortexModelDiagnostics", VersionRange="1.0.6"), Prompt=false)
savepath

addpath(fullfile(repoRoot, "simulation-scripts"))
addpath(fullfile(repoRoot, "figure-scripts"))
savepath
cd(repoRoot)
MakeAllFigures()
```

## Stronger-beam exponential run

The separate 128 × 128 run keeps 28 vertical points (18 retained modes) and initializes a 0.10 m/s tidal beam. It remains unforced and runs to day 600 with the pinned native FFTW executable. Stronger waves test eddy stability; instability is not guaranteed.

Prepare from a fresh MATLAB session (the function selects session-local dependencies without saving the path):

```matlab
addpath(fullfile(repoRoot,"simulation-scripts"))
runFolder = fullfile(repoRoot,"model-output/exponential-Nxy128-Nz28-depth4000-wave10cms-shift0");
PrepareEddyTideExponentialRun(Nxy=128,Nz=28,u0Wave=0.10,outputDirectory=runFolder)
```

Launch from the repository root with MATLAB available on PATH:

```sh
python3 simulation-scripts/run-exponential-simulation.py start model-output/exponential-Nxy128-Nz28-depth4000-wave10cms-shift0 --segment-days 50
python3 simulation-scripts/run-exponential-simulation.py status model-output/exponential-Nxy128-Nz28-depth4000-wave10cms-shift0
python3 simulation-scripts/run-exponential-simulation.py stop model-output/exponential-Nxy128-Nz28-depth4000-wave10cms-shift0
```

Omitting `--segment-days` preserves uninterrupted execution. The segmented supervisor holds `.run.lock` throughout native integration and MATLAB monitoring. Each native invocation gets its own request and execution report. A stop request prevents further segments; the current native writer stops gracefully, or an active energy calculation finishes before pausing. Failures pause the sequence for inspection. Once the supervisor exits and releases its lock, repeat the same start command to continue from the last complete checkpoint. Never delete a lock belonging to a live supervisor.

Between segments, `MonitorEddyTideExponentialRun` reads the closed model file and uses `geostrophicKineticEnergy` and `geostrophicPotentialEnergy` for newly saved records. `energy.csv` contains seconds, absolute energies in the model's spectral normalization, and energies divided by their time-zero values. `energy.json` summarizes the latest completed day; `energy.png` plots both normalized histories. `segments.json` records segment timings and report paths; `process.json` provides process status and an estimate of remaining wall time. Monitoring checks ordered six-hour times and reuses existing CSV rows without duplicating them. Status reporting must read these files, not the model NetCDF while integration is active.

At day 600 the supervisor verifies all 2,401 records are readable and produces `surface-vorticity-snapshots.png` at days 0, 150, 300, 450, and 600. Energy changes are indicators to interpret alongside these snapshots. The full diagnostics and figure builders are not invoked. Previous output and manuscript dependency pins remain separate.
