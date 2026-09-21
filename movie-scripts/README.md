# Eddy–tide cutaway movie and frames

`MakeEddyTideCutawayMovie` renders the simulation to a 1920 × 1080 H.264 MP4 or a lossless PNG sequence. The default uses every second saved output (`outputStride=2`) and the approved wave–geostrophic component view. `MakeEddyTideCutawayFrame` renders individual stills using the same geometry, palettes, lighting, and typography. It uses the WaveVortexModel installation described in the repository README and restores the saved simulation state directly from its NetCDF file. Diagnostics files are not needed.

From the repository root in MATLAB:

```matlab
addpath("movie-scripts")
[fig, frame] = MakeEddyTideCutawayFrame(day=0);
```

The default is day 0 of `model-output/bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc`. The PNG is written to `movie-frames/eddy-tide-cutaway.png` at 1920 × 1080 pixels. Repeated calls replace this preview; pass `outputFile` to keep multiple versions. Generated PNGs are already excluded by the repository's `.gitignore`.

Tracking and the vorticity color range are independent options. Tracking is enabled by default with `cutMode="geostrophic"`; `cutMode="fixed"` disables it and skips the history scan. The default `colorLimit=0.12` sets the geostrophic colorbar range to ±0.12 in units of `f`; `waveColorLimit=0.08` independently sets the wave range. Select `colorMode="total"` for the original total-vorticity coloring, with `colorLimit` controlling its single colorbar. For example:

```matlab
% Fixed cut through the original center, with no tracking computation.
MakeEddyTideCutawayFrame(day=400,cutMode="fixed",colorLimit=0.12);

% Follow the anticyclonic core, with an explicitly chosen color range.
MakeEddyTideCutawayFrame(day=400,cutMode="geostrophic",colorLimit=0.12);
```

The default cut follows the anticyclonic core continuously from the first saved output. `TrackEddyTideAnticyclone` computes geostrophic vertical vorticity from `(wvt.diffX(wvt.v_g) - wvt.diffY(wvt.u_g))/wvt.f` at every intervening output. The minimum along each vertical column gives an anticyclonic footprint; a periodic Gaussian average with a 20 km standard deviation suppresses small spatial variations for localization only. Negative local minima stronger than `0.005` in magnitude are candidates. The strongest candidate seeds the first frame, and each subsequent frame follows the nearest eligible minimum in periodic distance. A stronger distant fragment cannot take over the track merely because its amplitude increases.

The movement limit is `maximumSpeed * elapsedTime + one horizontal grid-cell diagonal`, with default `maximumSpeed=0.25` m/s. This is 9.54 km per six-hour output for the available simulation. The extra diagonal accommodates gridded extrema. The algorithm never clamps a large motion or interpolates across a lost core. If no eligible minimum remains, the track is marked `lost` and the renderer refuses that frame and subsequent frames. If two eligible minima are within one grid diagonal in their distances from the previous location, that association is marked `ambiguous`; the nearer candidate is selected, with stronger negative vorticity breaking exact distance ties. These rules provide a reproducible continuity check, not a unique physical identity after fragmentation.

Localization smoothing changes only the cut position. All displayed vorticity and PV fields retain their original spatial detail. `frame.geostrophicPeak` records the selected grid index, coordinates, depth, unfiltered geostrophic vorticity at the tracked column minimum, and filtered localization value. `frame.trackingStatus` reports the selected association status. The tracked location need not be the instantaneous minimum of the unfiltered field.

For one still, the renderer computes the history through the requested day. For repeated frames, compute the track once and pass it explicitly:

```matlab
inputFile = fullfile(pwd,"model-output","bottom-generated-tide-unforced-const-N-5cms-wave-10cms-eddy.nc");
track = TrackEddyTideAnticyclone(inputFile,outputFile="movie-frames/anticyclone-track.mat");
[fig, frame] = MakeEddyTideCutawayFrame(day=400,coreTrack=track,outputFile="movie-frames/eddy-tide-cutaway-day400-anticyclone.png");
PlotEddyTideCoreTrack(track,outputFile="movie-frames/anticyclone-track-check.png");
```

A saved MAT file can be reused with `saved = load("movie-frames/anticyclone-track.mat"); track = saved.track;`. Reuse validates the source's absolute path, file size, modification time, complete saved time coordinate, and requested coverage. Rebuild the track if the source moves or changes. There is no implicit disk cache.

The full day-0–600 audit of the available unforced run includes all 2,401 snapshots. The independent global minimum switches by more than 10 km 613 times, with a largest periodic displacement of 388.0 km. The default continuous track has no lost outputs and a maximum step of 9.26 km. One local association is flagged at day 429.75, when two nearby minima are 9.26 km apart. A 30 km localization average follows the same broad branch, with a median separation of zero and a maximum separation of 16.56 km from the 20 km track. These results describe this input file and these settings; other runs must be checked independently.

Run the focused association, source-validation, and output-protection tests with `runtests("movie-scripts/tests")` after adding `movie-scripts` to the MATLAB path. `TestEddyTideRenderOutputs` also renders a synthetic gradient at 1080p and 4K to check dimensions, sample precision, white background, and lossless PNG round trips without loading the simulation. For changes to the rendering path, compare simulation stills at days 0, 400, and 600, plus a 4K day-400 frame, against the previous renderer; inspect typography, cropping, and faint wave detail.

The front quadrant (`x > xCutKm`, `y < yCutKm`) is removed. The remaining top surface and two exposed vertical sections reveal the shallow eddy and the wave beam. Both vertical-vorticity components are normalized by `f`:

```matlab
qg = (wvt.diffX(wvt.v_g) - wvt.diffY(wvt.u_g))/wvt.f;
qw = (wvt.diffX(wvt.v_w) - wvt.diffY(wvt.u_w))/wvt.f;
```

In the default `colorMode="components"`, the renderer verifies that `qg + qw` reconstructs `wvt.zeta_z/wvt.f` to numerical precision at every frame. The wave field includes all internal gravity wave modes, including waves generated by the evolving flow. Horizontally uniform inertial motion has zero vertical vorticity.

Wave colors are grayscale (negative darker, zero pale gray, positive white). Geostrophic colors run blue–white–red, with negative values blue. The geostrophic layer opacity is `maximumGeostrophicOpacity * (1 - exp(-(abs(qg)/geostrophicOpacityScale)^2))`, with defaults 0.92 and 0.015. Strong geostrophic structures approach 92% opacity; weak ones reveal the underlying waves. The final face colors are `alpha * geostrophicRGB + (1-alpha) * waveRGB`, computed as truecolor to avoid artifacts from overlapping transparent surfaces. This is a color-layer blend on each face, not transparency through the volume or an average of the physical fields. The two colorbars describe the component palettes before blending and lighting, so a blended pixel does not represent a single colorbar value.

Color scales remain fixed across the simulation. Values outside each range saturate. No spatial smoothing or per-face rescaling is applied to the displayed field. Field samples interpolate linearly between model grid points; the horizontal periodic endpoint repeats the first grid point to close the domain.

Horizontal ticks show positive distances from the empty front corner, with one `distance (km)` label. Cut positions and the tracked-core caption retain their original domain-centered coordinates. The fluid view is enlarged by 15%, allowing the empty foreground origin to fall outside the canvas. Depth is labeled in meters; the default geometric vertical exaggeration is 160×, without an on-frame exaggeration caption. The camera is orthographic, with azimuth 35°, elevation 25°, and a fixed 1.10× camera zoom. These choices and the color scale remain fixed when changing the requested day. The compact layout includes the paper title, “Internal tides catalyze geostrophic eddy instabilities,” and attribution, “Hiron et al. 2026.” The nearest saved output is selected within the file's time range, and its actual time is displayed. `frame` and `fig.UserData` record the selected output, source file, and rendering settings.

All text uses Optima at regular weight: title 24 pt, day counter 18 pt, labels and ticks 12 pt, and tracking caption 11 pt. The title includes an invisible second line to preserve descenders in MATLAB raster exports. Optima must be installed for this appearance; it is available on the rendering Mac. Font selection is applied centrally after both colorbars exist. Layout and typography settings are recorded in the frame metadata.

The cutaway has no box-outline lines. Soft matte lighting distinguishes the top and vertical faces, using a camera-relative light direction of 20° azimuth and 30° elevation, inspired by `JAMES2026_EnergyFlux/figure-scripts/PlotTwoSimComparison3D.m`. Ambient strength is 0.85, diffuse strength is 0.15, and specular strength is zero. An infinite light keeps shading uniform on each planar face. Lighting changes displayed brightness; the underlying vorticity samples, colormaps, and color limits stay fixed. Stills and newly rendered movies share this styling and record the lighting settings in their metadata.

`frame.vorticityRange` gives the actual minimum and maximum of total vorticity divided by `f`, before color saturation. `frame.saturatedGridFraction` counts samples outside the color limits on the original full three-dimensional grid. `frame.saturatedTopFraction` counts them on the retained top surface after the cut. Neither count includes duplicated periodic endpoints. These total-field diagnostics use `colorLimit` even in component mode; they do not describe saturation of the blended image. Component mode also records `geostrophicRange`, `waveRange`, `geostrophicSaturatedGridFraction`, `waveSaturatedGridFraction`, and `decompositionResidual`. These are fractions of grid samples, not fractions of rendered pixels or volume-weighted statistics.

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

## Geostrophic PV with wave vorticity

Set `colorMode="geostrophic-pv"` in either the still or movie renderer to display `wvt.qgpv/wvt.f` in the colored layer, with wave vertical vorticity in gray. The default remains `colorMode="components"`. PV mode uses the same camera, palettes, lighting, typography, and continuous vorticity-based core track, so comparisons retain the same cut location.

```matlab
saved = load("movie-frames/anticyclone-track.mat");
[fig, frame] = MakeEddyTideCutawayFrame(day=400,coreTrack=saved.track,colorMode="geostrophic-pv",pvColorLimit=0.6,outputFile="movie-frames/eddy-tide-qgpv-day400.png");
sequence = MakeEddyTideCutawayMovie(coreTrack=saved.track,colorMode="geostrophic-pv",outputFormat="png",outputFolder="movie-frames/eddy-tide-qgpv-4k-12hour",resolutionScale=2,outputStride=2);
```

`pvColorLimit=0.6` sets the PV colorbar to ±0.6 in units of `f`; `pvOpacityScale=0.075` sets the PV magnitude at 63% of the maximum opacity. `maximumGeostrophicOpacity=0.92` and `waveColorLimit=0.08` still apply. The PV options are independent of the vorticity options `colorLimit` and `geostrophicOpacityScale`. Opacity uses the same formula as component mode, substituting PV and `pvOpacityScale`. The colorbar reads `geostrophic PV q (f)`.

In the pinned WaveVortexModel, QGPV has units of inverse seconds and is computed from the balanced `A0` coefficients. Its definition is `qgpv = zeta_z - f*diffZG(eta)`. The renderer retains the full field, including any mean-density contribution, and verifies this physical-space identity at every rendered time. This is quasigeostrophic PV, not full nonlinear Ertel PV. The gray layer still represents wave vertical vorticity; the displayed layers are separate diagnostics and are not added to form a total field.

PV metadata includes `pvRange` in units of `f`, `pvRangePerSecond`, `pvIdentityResidual`, `pvColorLimit`, and `pvOpacityScale`. Stills record `pvSaturatedGridFraction` and `pvSaturatedTopFraction`; movie sidecars record the full-grid saturation fractions in `saturatedGridFraction`, with columns named by `saturatedGridFractionColumns`. Face metadata stores the displayed samples as `geostrophicPV`. Total-vorticity diagnostics remain available under their existing names. The day-0 and day-400 PV ranges are [-0.571728, 0.215797] and [-0.578608, 0.216882], respectively, with no saturation at the default PV limit.

## Production workflow: 4K PNG frames and Image2Movie

For final movies, render a lossless PNG sequence at 3840 × 2160, then encode those frames in Image2Movie. Keep the PNG sequence as the rendered master so codec and quality comparisons do not require another simulation render. The direct MATLAB H.264 path below remains convenient for previews; function defaults are unchanged.

From the repository root, reuse the previously computed track:

```matlab
addpath("movie-scripts")
saved = load("movie-frames/anticyclone-track.mat");
sequence = MakeEddyTideCutawayMovie(coreTrack=saved.track,outputFormat="png",outputFolder="movie-frames/eddy-tide-production-4k",resolutionScale=2,outputStride=2,frameRate=30);
```

The output folder must be new or empty. Add `firstDay=400,lastDay=401` to a call with a separate output folder for a three-frame layout check. Compare a longer moving sequence when assessing compression, particularly the faint grayscale wave structure. If no saved track is available, omit `coreTrack`; the renderer computes it. See the tracking instructions above to save and reuse that result.

In Image2Movie, import only the numbered PNG files in ascending filename order and select **HEVC, High, 3840 × 2160, and 30 fps**. The PNG sidecar's `frameRate` is an intended playback rate; Image2Movie does not read `frames.mat`, so set the rate in the app. Select ProRes 422 when making an editing intermediate; retain the PNGs as the lossless rendered master. Avoid encoding a MATLAB MP4 and then transcoding it to HEVC.

The current MATLAB capture produces **8 bits per RGB channel**, including at 4K. Floating-point palette and blend calculations do not imply a 16-bit raster export. Both stills and movies use `renderEddyTideFigure`; rendered still metadata (`frame.raster`, also in `fig.UserData`) and movie metadata (`movie.raster`, saved in the sidecar) record `bitsPerChannel`, `sampleClass`, `matlabVersion`, and `matlabRelease` from the captured RGB array. These describe the source raster, not the encoded movie's bit depth. A still requested with `outputFile=""` does not capture a raster and has no `raster` field.

Image2Movie's HEVC Main10 pipeline retains precision during color conversion and encoding but cannot recover shades already quantized in an 8-bit source. Converting captured frames to `uint16` or switching the file extension to TIFF does not restore those shades. A genuinely higher-precision MATLAB export remains a separate experiment: verify additional gradient levels and the approved scene's appearance before adopting it.

PNG remains the default production intermediate for these dense, lit 3D surfaces. A PDF/vector route needs checks for shading, face ordering, seams, and embedded raster content; it is not an automatic quality upgrade. See the [MathWorks print reference](https://www.mathworks.com/help/matlab/ref/print.html) for RGB output and vector export limitations.

## Render an MP4 preview

From the repository root, using the same WaveVortexModel installation as the still renderer:

```matlab
addpath("movie-scripts")
movie = MakeEddyTideCutawayMovie(frameRate=30);
```

The default output is `movies/eddy-tide-cutaway-12hour-30fps.mp4`, with a matching MAT file containing source indices, simulation days, encoding settings, cut positions, component extrema and saturation fractions, and decomposition residuals. Generated movies are excluded from version control. The available unforced simulation has 2,401 equally spaced six-hour outputs covering days 0–600; the default stride selects 1,201 snapshots, lasting 40.033 seconds at 30 fps. There is no temporal interpolation.

To reuse the previously audited track and avoid another tracking scan:

```matlab
saved = load("movie-frames/anticyclone-track.mat");
movie = MakeEddyTideCutawayMovie(coreTrack=saved.track,frameRate=30,colorLimit=0.12);
```

The default 12-hour spacing can also be specified explicitly:

```matlab
saved = load("movie-frames/anticyclone-track.mat");
movie = MakeEddyTideCutawayMovie(coreTrack=saved.track,outputStride=2,frameRate=30,outputFile="movies/eddy-tide-cutaway-12hour-30fps.mp4");
```

This selects days 0, 0.5, 1, …, 600: 1,201 frames lasting 40.033 seconds at 30 fps. Sampling every 12 hours reduces the near-alternating tidal phases seen in consecutive six-hour snapshots and emphasizes slow eddy evolution. This is temporal subsampling, not an average or an exact tidal-phase lock: near-semidiurnal waves can appear stationary or slowly varying through aliasing. Do not interpret apparent wave motion in this sequence as resolved tidal propagation. Showing that propagation requires more frequent full-field simulation output; a higher playback frame rate or interpolated movie frames cannot supply missing temporal information. Frames are rendered directly from the simulation without temporal averaging. Core tracking still uses every six-hour output to preserve the audited trajectory; only rendering is subsampled. `outputStride` defaults to 2 and counts from the first saved output within the selected day range. The movie metadata records the stride and exact source indices.

Tracking remains optional. For a fixed cut or a short encoding preview:

```matlab
movie = MakeEddyTideCutawayMovie(cutMode="fixed",xCutKm=0,yCutKm=0,colorLimit=0.12,firstDay=400,lastDay=401,outputFile="movies/fixed-cut-preview.mp4");
```

`firstDay` and `lastDay` select saved outputs within an inclusive day range; the default includes the complete simulation. `quality`, `frameRate`, `inputFile`, `viewAngles`, and `verticalExaggeration` are also options. Both video and PNG output require equally spaced saved times. Tracking is validated before rendering, and a lost track or a cut on the domain boundary stops the render. The current track is inspected without changing its association rules.

Progress is printed every 50 frames. Encoding writes to a `.partial.mp4` file, which is renamed only after all frames are written and the encoder closes. Existing final movies, partial movies, or metadata sidecars are preserved: choose another `outputFile` or move the old file before rerunning. An interrupted render must be restarted; it does not resume a partial encode.

## Export PNG frames instead of a movie

Use the same renderer with `outputFormat="png"` and a new or empty `outputFolder`:

```matlab
saved = load("movie-frames/anticyclone-track.mat");
sequence = MakeEddyTideCutawayMovie(coreTrack=saved.track,outputFormat="png",outputFolder="movie-frames/eddy-tide-sequence",outputStride=2);
```

This bypasses `VideoWriter` entirely and writes lossless 1920 × 1080 RGB images named `frame-000001.png`, `frame-000002.png`, and so on. Sequence numbers start at 1 within the selected day range. Each PNG uses the same RGB array that would be sent to the video encoder, currently 8 bits per channel. Lossless PNG compression preserves that captured raster, not the full precision of the underlying simulation. `outputFile` and `quality` apply only to video output; `frameRate` is retained as the intended playback rate in the PNG metadata and does not alter the images.

Set `resolutionScale=2` to render 3840 × 2160 images, doubling both pixel dimensions. The renderer increases sampling density without changing the framing, relative font sizes, or scientific grid; it does not upscale an existing image. This option also works for single stills and video output and defaults to 1. Both the scale and pixel dimensions are saved in the metadata.

```matlab
sequence = MakeEddyTideCutawayMovie(coreTrack=saved.track,outputFormat="png",outputFolder="movie-frames/eddy-tide-cutaway-4k-12hour",outputStride=2,resolutionScale=2);
```

The folder also contains `frames.mat`, with a `movie` struct matching the returned `sequence`. Its `frameFiles`, `indices`, `days`, and tracked coordinates map each filename to the simulation snapshot; `style` preserves palettes, blend settings, lighting, and typography. The `raster` field records captured precision and MATLAB version as described above. The sidecar is written only after all frames finish. For the default source and stride, the complete sequence contains 1,201 PNGs, spanning days 0–600.

Use `firstDay=400,lastDay=401` for a three-frame check. An existing nonempty destination is rejected before rendering, preserving prior frames. Each image is written as a temporary `.partial.png` and renamed when complete. If a run is interrupted, completed PNGs remain available, but the renderer does not resume into that folder; choose a new folder for a rerun. PNGs use lossless compression and generally need more disk space than an H.264 movie.

## Video encoding settings

The defaults are 1920 × 1080, 30 fps, and MATLAB's `MPEG-4` profile at `Quality=95`:

```matlab
writer = VideoWriter("eddy-tide.mp4","MPEG-4");
writer.FrameRate = 30;
writer.Quality = 95;
```

Set these properties before calling `open(writer)`. The MPEG-4 profile uses H.264; `Quality` ranges from 0 to 100, with higher values trading larger files for higher quality. Resolution comes from the supplied image arrays, so pass the full-resolution RGB frames consistently. At the default stride, 1,201 frames give approximately 40 seconds at 30 fps, or 50 seconds at 24 fps. Set `outputStride=1` to include all 2,401 outputs.

MATLAB R2026a's `VideoWriter` offers MPEG-4/H.264, Motion JPEG AVI, Motion JPEG 2000 (including the lossless `Archival` profile), and uncompressed AVI variants. Its MPEG-4 interface exposes quality and frame rate, but no CRF, target bitrate, H.265/HEVC, or AV1 selection. The `CompressionRatio`, `LosslessCompression`, and `MJ2BitDepth` controls apply to Motion JPEG 2000, not MPEG-4. See the [MathWorks VideoWriter reference](https://www.mathworks.com/help/matlab/ref/videowriter.html). Use `MakeEddyTideCutawayMovie` for either video encoding or PNG sequences; the still renderer writes one PNG.
