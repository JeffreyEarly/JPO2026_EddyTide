# Visualization experiments

The approved component colors, soft lighting, cropped cutaway, distance labels, tracked-core caption, and Optima typography are now the defaults in the main [movie scripts](../README.md). Add `movie-scripts` to the MATLAB path and use `MakeEddyTideCutawayFrame` or `MakeEddyTideCutawayMovie` for new work, including PNG sequence output.

The two component entry points here remain as compatibility wrappers for existing commands. Add both directories to the MATLAB path to use them. They translate `geostrophicColorLimit` to the main scripts' `colorLimit` and retain their previous output paths and default day. They call the main implementation; there is no separate experimental renderer to maintain.

## Geostrophic PV in place of geostrophic vorticity

`MakeEddyTidePVExperiment` is now a compatibility wrapper for the main renderer's `colorMode="geostrophic-pv"` option, which substitutes `wvt.qgpv/wvt.f` for the colored geostrophic layer. Wave vertical vorticity remains gray. The camera, palettes, lighting, annotations, and original vorticity-based core track are reused, so the experiment compares the diagnostic fields at the same cut locations. The main still and movie defaults remain unchanged.

```matlab
addpath("movie-scripts","movie-scripts/experiments")
saved = load("movie-frames/anticyclone-track.mat");
for day = [0 400]
    outputFile = fullfile("movie-frames","experiments",compose("eddy-tide-qgpv-day%03d.png",day));
    [fig,experiment] = MakeEddyTidePVExperiment(day=day,coreTrack=saved.track,resolutionScale=2,outputFile=outputFile);
    close(fig)
end
```

In the pinned WaveVortexModel, QGPV has units of inverse seconds and is computed from the balanced `A0` coefficients. Its definition is `qgpv = zeta_z - f*diffZG(eta)`. The experiment uses the full `wvt.qgpv`, including any mean-density contribution; it does not subtract a background profile or interpret this as full nonlinear Ertel PV. The figure displays this quantity in units of `f`, and the renderer checks its physical-space identity against the saved velocity and displacement fields. The colorbar reads `geostrophic PV q (f)`.

The same default `pvColorLimit=0.6` is used at both days. The unforced run's `qgpv/f` ranges are [-0.571728, 0.215797] at day 0 and [-0.578608, 0.216882] at day 400, with no grid samples outside ±0.6. The wave color limit remains ±0.08. Opacity depends on the absolute PV value, with `pvOpacityScale=0.075` (one eighth of the default PV color limit) and maximum opacity 0.92; this preserves the production blend's threshold relative to its color limit. Both options are adjustable.

The returned metadata is the main renderer's frame struct, including PV extrema, full-grid and retained-top saturation fractions, identity residual, style, and raster precision. Each face stores the actual displayed `geostrophicPV` samples. Use `MakeEddyTideCutawayMovie(colorMode="geostrophic-pv",outputFormat="png",...)` for a sequence; see the [main scripts](../README.md#geostrophic-pv-with-wave-vorticity) for the complete command. The two colored/gray layers represent different diagnostics; their sum is not a total PV or total vorticity field.
