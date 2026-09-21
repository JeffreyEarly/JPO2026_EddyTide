function applyEddyTideComponentColors(geometry, geostrophicField, waveField, style)
% Apply the same component palettes and opacity blend to stills and movies.
arguments (Input)
    geometry (1,1) struct
    geostrophicField (1,1) griddedInterpolant
    waveField (1,1) griddedInterpolant
    style (1,1) struct
end
for iFace = 1:numel(geometry.faces)
    face = geometry.faces(iFace);
    geostrophicValues = geostrophicField(face.XData,face.YData,face.ZData);
    waveValues = waveField(face.XData,face.YData,face.ZData);
    geostrophicRGB = mapColors(geostrophicValues,style.geostrophicColormap,style.geostrophicColorLimit);
    waveRGB = mapColors(waveValues,style.waveColormap,style.waveColorLimit);
    alpha = style.maximumGeostrophicOpacity*(-expm1(-(abs(geostrophicValues)/style.geostrophicOpacityScale).^2));
    face.CData = alpha.*geostrophicRGB + (1-alpha).*waveRGB;
    if style.colorMode == "geostrophic-pv"
        face.UserData = struct(geostrophicPV=geostrophicValues,waveVorticity=waveValues,geostrophicOpacity=alpha);
    else
        face.UserData = struct(geostrophicVorticity=geostrophicValues,waveVorticity=waveValues,geostrophicOpacity=alpha);
    end
end
end

function rgb = mapColors(values, cmap, colorLimit)
scaled = max(-1,min(1,values/colorLimit));
rgb = reshape(interp1(linspace(-1,1,size(cmap,1)),cmap,scaled(:),"linear"),[size(values) 3]);
end
