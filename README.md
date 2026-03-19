# Internal tides catalyze geostrophic eddy instabilities

This repository contains all the code necessary to run the simulations and recreate the figures in the manuscript.

## Installation

After you clone this repository, you will need to install the [WaveVortexModel](https://wavevortexmodel.org) and the [WaveVortexModel Diagnostics](https://energy-pathways-group.github.io/wave-vortex-model-diagnostics/) Matlab packages.

You must first intall the [OceanKit](https://github.com/JeffreyEarly/OceanKit) package manager repository, and then proceed with either the *basic* install or the *advanced* install.

### 1. Package Manager Repository installation

Clone OceanKit
```
git clone https://github.com/JeffreyEarly/OceanKit.git
```
from the command-line. Within Matlab, add this folder as an MPM repository,
```matlab
mpmAddRepository("OceanKit","path/to/folder/OceanKit")
```

### 2a. Basic installation

Install the model package,
```matlab
mpminstall("WaveVortexModel")
```
and then install the diagnostics package,
```matlab
mpminstall("WaveVortexModelDiagnostics")
```
which will install the appropriate dependencies.

This approach will install current release versions of the packages that cannot be edited. If you want editable version, or the very latest versions, use the advanced installation.

### 2b. Advanced installation

Directly clone the two repositories (code snippet here assume the command-line),
```
git clone https://github.com/JeffreyEarly/wave-vortex-model.git
git clone https://github.com/Energy-Pathways-Group/wave-vortex-model-diagnostics.git
```
and then within Matlab, install the two packages,
then install
```matlab
mpminstall("local/path/to/wave-vortex-model", Authoring=true);
mpminstall("local/path/to/wave-vortex-model-diagnostics", Authoring=true);
```
which will install the appropriate dependencies using the OceanKit repo you previously installed.

### 3. Install jlab

To build some of the figures will also require you install [jLab](https://jmlilly.net/code.html).
