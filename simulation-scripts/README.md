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

## Exponential stratification with C++ integration

`PrepareEddyTideExponentialRun` prepares a separate unforced experiment at 256 × 256 horizontal resolution, 4000 m depth, and zero beam shift. It retains the minimal simulation's 5 cm/s initialized M2 beam, 10 cm/s eddy, 45° latitude, and adaptive damping. The profile is $$N^2(z) = N_0^2 \exp(2z/H)$$ with $$N_0 = 3(2\pi)/3600\ \mathrm{s^{-1}}$$ and $$H = 1300\ \mathrm{m}$$. The four-wavelength domain is approximately 587.49 km wide. Automatic vertical resolution gives 28 grid points and 18 retained modes.

The run uses WaveVortexModel source commit `a74ed4e61bc1bc57f731c999d7d404f8732f8679` in an isolated detached checkout at `.dependencies/wave-vortex-model`. Its native standalone runner performs integration and NetCDF output. This experiment does not change the manuscript reproduction package pins.

Create the isolated checkout from the sibling authoring repository, then build the native executable (skip worktree creation if it already exists):

```sh
git -C ../wave-vortex-model worktree add --detach "$PWD/.dependencies/wave-vortex-model" a74ed4e61bc1bc57f731c999d7d404f8732f8679
cd .dependencies/wave-vortex-model
PortableRuntime/buildWaveVortexRun.sh
```

In a fresh MATLAB session, prepare the run:

```matlab
repoRoot = "/path/to/JPO2026_EddyTide";
addpath(fullfile(repoRoot,"simulation-scripts"))
[requestPath,modelPath,provenance] = PrepareEddyTideExponentialRun;
```

Preparation selects the model source and these OceanKit snapshots for the current MATLAB session: InternalModes 1.3.0, ClassAnnotations 1.2.1, NetCDF 1.0.2, SplineCore 2.2.0, and Chebfun 5.7.0. It resets the session path and does not call `savepath`. Local Apple Silicon `matlab -batch` commands must run outside the Codex sandbox. The optional `modelSource` argument selects another checkout of the same pinned commit.

The default folder is `model-output/exponential-Nxy256-depth4000-shift0`. It contains `eddy-tide-exponential.nc`, `provenance.json`, and `run.json`. Preparation writes the initial record at time zero and closes it before generating the request. Scientific configuration is also recorded as a NetCDF root attribute. The request uses the standard v2 defaults: adaptive RK78 (`ode78` equivalent), relative tolerance `1e-3`, absolute-tolerance scale `1e-6`, native FFTW, automatic threads, and default adaptive step selection. Its final time is 600 days, with coefficient output every six hours: 2401 records totaling approximately 22.1 GiB before overhead.

From the JPO repository root, launch and inspect the detached process:

```sh
python3 simulation-scripts/run-exponential-simulation.py start
python3 simulation-scripts/run-exponential-simulation.py status
```

The launcher checks the source revision, tracked source changes, executable SHA-256, and available disk space. It requires space for projected coefficient output with 25% overhead plus a 20 GiB reserve. A run-directory lock excludes duplicate launches and preparation during integration. `process.json` records the native PID, supervisor PID, log path, and eventual exit code. Each launch has its own log; the runner writes `run-report.json` when it exits. Status uses process information and file size without opening the active NetCDF writer. The native runner normally emits its detailed report at exit, so an empty log during integration is expected.

Request a graceful stop, then wait for status to show that the process has finished:

```sh
python3 simulation-scripts/run-exponential-simulation.py stop
python3 simulation-scripts/run-exponential-simulation.py status
```

The first SIGINT requests a stop at a complete checkpoint. Do not issue repeated stops: a second SIGINT terminates immediately. After graceful termination, `start` resumes the same request from the last complete checkpoint. Previous reports and all launch logs are retained. If a machine crash leaves `.run.lock`, first establish that both recorded processes are absent before removing that empty lock directory. Do not open the model file in MATLAB while integration is active.

For disposable validation or a different final time, pass an `outputDirectory` and `maxT` to preparation, and pass that directory as the launcher's final argument. `maxT` must be a multiple of six hours. Repreparing existing output checks the stored configuration and environment and never overwrites its state. Use the same MATLAB version and binary, or a new output directory, when provenance differs. Completion requires runner exit code zero, report status `complete`, and a readable model checkpoint at day 600; a graceful `stopped` report is resumable but is not completion. Diagnostics and manuscript figures are separate workflows.
