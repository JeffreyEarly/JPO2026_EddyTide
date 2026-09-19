# Former component-color experiment

The approved component colors, soft lighting, cropped cutaway, distance labels, tracked-core caption, and Optima typography are now the defaults in the main [movie scripts](../README.md). Add `movie-scripts` to the MATLAB path and use `MakeEddyTideCutawayFrame` or `MakeEddyTideCutawayMovie` for new work, including PNG sequence output.

The two entry points here remain as compatibility wrappers for existing commands. Add both directories to the MATLAB path to use them. They translate `geostrophicColorLimit` to the main scripts' `colorLimit` and retain their previous output paths and default day. They call the main implementation; there is no separate experimental renderer to maintain.
