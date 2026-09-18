# Eddy–tide cutaway movie and frames

`MakeEddyTideCutawayMovie` renders the full simulation to a 1920 × 1080 H.264 MP4, with one frame per saved output. `MakeEddyTideCutawayFrame` renders individual stills using the same geometry and composition. It uses the WaveVortexModel installation described in the repository README and restores the saved simulation state directly from its NetCDF file. Diagnostics files are not needed.

From the repository root in MATLAB:

```matlab
addpath("movie-scripts")
[fig, frame] = MakeEddyTideCutawayFrame(day=0);
```

The default is day 0 of `model-output/bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc`. The PNG is written to `movie-frames/eddy-tide-cutaway.png` at 1920 × 1080 pixels. Repeated calls replace this preview; pass `outputFile` to keep multiple versions. Generated PNGs are already excluded by the repository's `.gitignore`.

Tracking and the vorticity color range are independent options. Tracking is enabled by default with `cutMode="geostrophic"`; `cutMode="fixed"` disables it and skips the history scan. The default `colorLimit=0.12` sets a symmetric colorbar range of ±0.12 in `zeta_z/f`. For example:

```matlab
% Fixed cut through the original center, with no tracking computation.
MakeEddyTideCutawayFrame(day=400,cutMode="fixed",colorLimit=0.12);

% Follow the anticyclonic core, with an explicitly chosen color range.
MakeEddyTideCutawayFrame(day=400,cutMode="geostrophic",colorLimit=0.12);
```

The default cut follows the anticyclonic core continuously from the first saved output. `TrackEddyTideAnticyclone` computes geostrophic vertical vorticity from `(wvt.diffX(wvt.v_g) - wvt.diffY(wvt.u_g))/wvt.f` at every intervening output. The minimum along each vertical column gives an anticyclonic footprint; a periodic Gaussian average with a 20 km standard deviation suppresses small spatial variations for localization only. Negative local minima stronger than `0.005` in magnitude are candidates. The strongest candidate seeds the first frame, and each subsequent frame follows the nearest eligible minimum in periodic distance. A stronger distant fragment cannot take over the track merely because its amplitude increases.

The movement limit is `maximumSpeed * elapsedTime + one horizontal grid-cell diagonal`, with default `maximumSpeed=0.25` m/s. This is 9.54 km per six-hour output for the available simulation. The extra diagonal accommodates gridded extrema. The algorithm never clamps a large motion or interpolates across a lost core. If no eligible minimum remains, the track is marked `lost` and the renderer refuses that frame and subsequent frames. If two eligible minima are within one grid diagonal in their distances from the previous location, that association is marked `ambiguous`; the nearer candidate is selected, with stronger negative vorticity breaking exact distance ties. These rules provide a reproducible continuity check, not a unique physical identity after fragmentation.

Localization smoothing changes only the cut position. All colored faces retain the original total vorticity. `frame.geostrophicPeak` records the selected grid index, coordinates, depth, unfiltered geostrophic vorticity at the tracked column minimum, and filtered localization value. `frame.trackingStatus` reports the selected association status. The tracked location need not be the instantaneous minimum of the unfiltered field.

For one still, the renderer computes the history through the requested day. For repeated frames, compute the track once and pass it explicitly:

```matlab
inputFile = fullfile(pwd,"model-output","bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc");
track = TrackEddyTideAnticyclone(inputFile,outputFile="movie-frames/anticyclone-track.mat");
[fig, frame] = MakeEddyTideCutawayFrame(day=400,coreTrack=track,outputFile="movie-frames/eddy-tide-cutaway-day400-anticyclone.png");
PlotEddyTideCoreTrack(track,outputFile="movie-frames/anticyclone-track-check.png");
```

A saved MAT file can be reused with `saved = load("movie-frames/anticyclone-track.mat"); track = saved.track;`. Reuse validates the source's absolute path, file size, modification time, complete saved time coordinate, and requested coverage. Rebuild the track if the source moves or changes. There is no implicit disk cache.

The full day-0–600 audit of the available unforced run includes all 2,401 snapshots. The independent global minimum switches by more than 10 km 613 times, with a largest periodic displacement of 388.0 km. The default continuous track has no lost outputs and a maximum step of 9.26 km. One local association is flagged at day 429.75, when two nearby minima are 9.26 km apart. A 30 km localization average follows the same broad branch, with a median separation of zero and a maximum separation of 16.56 km from the 20 km track. These results describe this input file and these settings; other runs must be checked independently.

Run the focused association and source-validation tests with `runtests("movie-scripts/tests")` after adding `movie-scripts` to the MATLAB path.

The front quadrant (`x > xCutKm`, `y < yCutKm`) is removed. The remaining top surface and two exposed vertical sections reveal the shallow eddy and the wave beam. Every face shows the same total vertical vorticity, `zeta_z = dv/dx - du/dy`, normalized by `f`. The geostrophic field is used only to locate the cut. Blue is negative, red is positive, and white is zero. The default linear color scale is ±0.12; values outside this interval saturate. No smoothing or per-face rescaling is applied to the displayed field. Face colors interpolate linearly between model grid points. The horizontal periodic endpoint repeats the first grid point to close the domain.

Coordinates are relative to the original domain center. Depth is labeled in meters; the default vertical exaggeration is 160×. The camera is orthographic, with azimuth 35°, elevation 25°, and a fixed 1.10× camera zoom. These choices and the color scale remain fixed when changing the requested day. The compact layout includes the paper title, “Internal tides catalyze geostrophic eddy instabilities,” and attribution, “Hiron et al. 2026.” The nearest saved output is selected within the file's time range, and its actual time is displayed. `frame` and `fig.UserData` record the selected output, source file, and rendering settings.

`frame.vorticityRange` gives the actual minimum and maximum of total vorticity divided by `f`, before color saturation. `frame.saturatedGridFraction` counts samples outside the color limits on the original full three-dimensional grid. `frame.saturatedTopFraction` counts them on the retained top surface after the cut. Neither count includes duplicated periodic endpoints. These are fractions of grid samples, not fractions of rendered pixels or volume-weighted statistics.

Render day 400 with the compact layout:

```matlab
[fig, frame] = MakeEddyTideCutawayFrame(day=400,outputFile="movie-frames/eddy-tide-cutaway-day400.png");
```

Render the final day with the cut following the eddy:

```matlab
[fig, frame] = MakeEddyTideCutawayFrame(day=600,outputFile="movie-frames/eddy-tide-cutaway-final-tracked.png");
```

To position the cut manually, use `cutMode="fixed"`. The original domain-centered cut is reproduced with `xCutKm=0` and `yCutKm=0`. These two options apply only in fixed mode. Both coordinates must lie strictly inside the domain; if the tracked peak lies on a periodic boundary, choose an interior fixed cut. Adjust the composition without editing the renderer:

```matlab
[fig, frame] = MakeEddyTideCutawayFrame(day=0,cutMode="fixed",viewAngles=[45 30],verticalExaggeration=120,colorLimit=0.12,xCutKm=0,yCutKm=0,outputFile="movie-frames/cutaway-alternative.png");
```

Use `inputFile` to select another simulation, `visible=false` for a batch render, or `outputFile=""` to inspect the figure without writing a PNG. The default camera looks into the removed quadrant; changing it substantially can hide the interior faces. The movie renderer reuses one transform and one figure while updating the data and tracked cut position.

## Render the movie

From the repository root, using the same WaveVortexModel installation as the still renderer:

```matlab
addpath("movie-scripts")
movie = MakeEddyTideCutawayMovie(frameRate=30);
```

The default output is `movies/eddy-tide-unforced-30fps.mp4`, with a matching MAT file containing source indices, simulation days, encoding settings, cut positions, and per-frame vorticity extrema. Generated movies are excluded from version control. The available unforced simulation has 2,401 equally spaced outputs covering days 0–600; at 30 fps the full movie lasts 80.033 seconds. Every saved snapshot is included, without temporal interpolation.

To reuse the previously audited track and avoid another tracking scan:

```matlab
saved = load("movie-frames/anticyclone-track.mat");
movie = MakeEddyTideCutawayMovie(coreTrack=saved.track,frameRate=30,colorLimit=0.12);
```

For 12-hour spacing, use every other output from the six-hour source file:

```matlab
saved = load("movie-frames/anticyclone-track.mat");
movie = MakeEddyTideCutawayMovie(coreTrack=saved.track,outputStride=2,frameRate=30,outputFile="movies/eddy-tide-unforced-12hour-30fps.mp4");
```

This selects days 0, 0.5, 1, …, 600: 1,201 frames lasting 40.033 seconds at 30 fps. Sampling every 12 hours avoids alternating between the two tidal phases in consecutive six-hour snapshots. Frames are rendered directly from the simulation without temporal averaging. Core tracking still uses every six-hour output to preserve the audited trajectory; only rendering is subsampled. `outputStride` defaults to 1 and counts from the first saved output within the selected day range. The movie metadata records the stride and exact source indices.

Tracking remains optional. For a fixed cut or a short encoding preview:

```matlab
movie = MakeEddyTideCutawayMovie(cutMode="fixed",xCutKm=0,yCutKm=0,colorLimit=0.12,firstDay=400,lastDay=401,outputFile="movies/fixed-cut-preview.mp4");
```

`firstDay` and `lastDay` select saved outputs within an inclusive day range; the default includes the complete simulation. `quality`, `frameRate`, `inputFile`, `viewAngles`, and `verticalExaggeration` are also options. The movie requires equally spaced saved times. Tracking is validated before rendering, and a lost track or a cut on the domain boundary stops the render. The current track is inspected without changing its association rules.

Progress is printed every 50 frames. Encoding writes to a `.partial.mp4` file, which is renamed only after all frames are written and the encoder closes. Existing final or partial movies are preserved: choose another `outputFile` or move the old file before rerunning. An interrupted render must be restarted; it does not resume a partial encode.

## Video encoding settings

The defaults are 1920 × 1080, 30 fps, and MATLAB's `MPEG-4` profile at `Quality=95`:

```matlab
writer = VideoWriter("eddy-tide.mp4","MPEG-4");
writer.FrameRate = 30;
writer.Quality = 95;
```

Set these properties before calling `open(writer)`. The MPEG-4 profile uses H.264; `Quality` ranges from 0 to 100, with higher values trading larger files for higher quality. Resolution comes from the supplied image arrays, so pass the full-resolution RGB frames consistently. At one frame per saved output, 2,401 outputs give approximately 80 seconds at 30 fps, or 100 seconds at 24 fps.

MATLAB R2026a's `VideoWriter` offers MPEG-4/H.264, Motion JPEG AVI, Motion JPEG 2000 (including the lossless `Archival` profile), and uncompressed AVI variants. Its MPEG-4 interface exposes quality and frame rate, but no CRF, target bitrate, H.265/HEVC, or AV1 selection. The `CompressionRatio`, `LosslessCompression`, and `MJ2BitDepth` controls apply to Motion JPEG 2000, not MPEG-4. See the [MathWorks VideoWriter reference](https://www.mathworks.com/help/matlab/ref/videowriter.html). Use `MakeEddyTideCutawayMovie` for encoding; the still renderer writes only PNGs.
