# Internal tides catalyze geostrophic eddy instabilities

This repository contains all the code necessary to run the simulations and recreate the figures in the manuscript.

## Installation

After you clone this repository, you will need to install the [WaveVortexModel](https://wavevortexmodel.org) and the [WaveVortexModel Diagnostics](https://energy-pathways-group.github.io/wave-vortex-model-diagnostics/) Matlab packages.

You must first install the [OceanKit](https://github.com/JeffreyEarly/OceanKit) package manager repository, then install the exact package versions used for this paper:

- `WaveVortexModel` version `4.0.6`
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
mpminstall(matlab.mpm.PackageSpecifier("WaveVortexModel", VersionRange="4.0.6"))
mpminstall(matlab.mpm.PackageSpecifier("WaveVortexModelDiagnostics", VersionRange="1.0.6"))
```

This approach installs the released package snapshots and their dependencies.

## Running manuscript simulations

`simulation-scripts/EddyTideSimulationMinimal.m` is a constant-stratification
version of the manuscript simulation. It defaults to `Nxy = 256`, a 600-day run,
quarter-day output, and the unforced case. The commands below run both unforced
and forced simulations and write model output to `model-output`.

```matlab
repoRoot = "/path/to/JPO2026_EddyTide";
addpath(fullfile(repoRoot,"simulation-scripts"))

outputDirectory = fullfile(repoRoot,"model-output");

EddyTideSimulationMinimal(outputDirectory=outputDirectory)
EddyTideSimulationMinimal(isForced=true,outputDirectory=outputDirectory)
```

After the simulations finish, create the diagnostics files and geostrophic flux
groups:

```matlab
simulationFiles = [
    "bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc"
    "bottom-generated-tide-forced-const-N-5cms-wave-10cms-eddy.nc"
];

for iFile = 1:numel(simulationFiles)
    wvd = WVDiagnostics(fullfile(outputDirectory,simulationFiles(iFile)));
    wvd.createDiagnosticsFile();
    wvd.createGeostrophicFluxGroup();
end
```

## Recreating the figures

The figure scripts expect the model output, diagnostics file, and profile cache in `model-output`. Figures 1, 3, 4, 5, 6, 7, 8, and Table 1 use the unforced simulation output. Figures 2 and 9 use the forced simulation output. With the pinned packages on the path, run:

```matlab
addpath("figure-scripts")
MakeAllFigures
```

The recreated figures are written to `figures-unforced`.

To create figures from a separate reproducibility output folder instead, point
the figure scripts at that output folder and choose a separate figure folder:

```matlab
figureDataDir = fullfile(repoRoot,"reproducibility-output","model-output");
figureFolder = fullfile(repoRoot,"reproducibility-output","figures");

addpath(fullfile(repoRoot,"figure-scripts"))
MakeAllFigures
```

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

mpminstall(matlab.mpm.PackageSpecifier("WaveVortexModel", VersionRange="4.0.6"), Prompt=false)
mpminstall(matlab.mpm.PackageSpecifier("WaveVortexModelDiagnostics", VersionRange="1.0.6"), Prompt=false)
savepath

addpath(fullfile(repoRoot, "figure-scripts"))
savepath
cd(repoRoot)
MakeAllFigures
```
