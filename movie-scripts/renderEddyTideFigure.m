function [rgb, raster] = renderEddyTideFigure(fig, resolutionScale)
% Capture a fixed-layout RGB frame for both stills and movies.
arguments (Input)
    fig (1,1) matlab.ui.Figure
    resolutionScale (1,1) double {mustBeFinite,mustBeInteger,mustBePositive}
end
arguments (Output)
    rgb (:,:,3) {mustBeA(rgb,["uint8","uint16"])}
    raster (1,1) struct
end

% Increase sampling density without changing the physical layout.
fig.PaperUnits = "inches";
fig.PaperPosition = [0 0 12.8 7.2];
fig.PaperSize = [12.8 7.2];
rgb = print(fig,"-RGBImage",sprintf("-r%d",150*resolutionScale));
resolution = resolutionScale*[1920 1080];
if ~isequal(size(rgb),[fliplr(resolution) 3])
    error("EddyTide:MovieFrameSize","Expected a %d-by-%d RGB frame.",resolution(1),resolution(2))
end
sample = whos("rgb");
raster = struct(bitsPerChannel=8*sample.bytes/numel(rgb),sampleClass=string(class(rgb)),matlabVersion=string(version),matlabRelease=string(version("-release")));
end
