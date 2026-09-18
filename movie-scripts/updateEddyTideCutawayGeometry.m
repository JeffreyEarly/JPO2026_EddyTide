function geometry = updateEddyTideCutawayGeometry(ax, field, x, y, z, xCut, yCut, geometry)
% Create or update the eight softly lit faces shared by stills and movies.
arguments (Input)
    ax (1,1) matlab.graphics.axis.Axes
    field (1,1) griddedInterpolant
    x (:,1) double
    y (:,1) double
    z (:,1) double
    xCut (1,1) double
    yCut (1,1) double
    geometry (1,1) struct = struct()
end
arguments (Output)
    geometry (1,1) struct
end

if xCut <= x(1) || xCut >= x(end) || yCut <= y(1) || yCut >= y(end)
    error("EddyTide:CutOutsideDomain","Both cut coordinates must be strictly inside the horizontal domain.")
end
xLeft = [x(x < xCut); xCut];
xRight = [xCut; x(x > xCut)];
yFront = [y(y < yCut); yCut];
yBack = [yCut; y(y > yCut)];
coordinates = {x,yBack,z(end); xLeft,yFront,z(end); xRight,yCut,z; xCut,yFront,z; xLeft,y(1),z; x(end),yBack,z; x,y(end),z; x(1),y,z};
isNew = isempty(fieldnames(geometry));
if isNew
    geometry.faces = gobjects(8,1);
end
for iFace = 1:8
    [X,Y,Z] = ndgrid(coordinates{iFace,:});
    X = squeeze(X);
    Y = squeeze(Y);
    Z = squeeze(Z);
    C = field(X,Y,Z);
    if isNew
        geometry.faces(iFace) = surf(ax,X,Y,Z,C,EdgeColor="none",FaceColor="interp",FaceLighting="gouraud",AmbientStrength=0.85,DiffuseStrength=0.15,SpecularStrength=0,BackFaceLighting="reverselit");
    else
        set(geometry.faces(iFace),XData=X,YData=Y,ZData=Z,CData=C);
    end
end
end
