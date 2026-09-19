function layout = layoutEddyTideCutawayFigure(fig, frame)
% Enlarge the fluid and label distances from the empty front domain corner.
arguments (Input)
    fig (1,1) matlab.ui.Figure
    frame (1,1) struct
end
arguments (Output)
    layout (1,1) struct
end
% The raster exporter trims descenders on the final text line even in a
% larger box. An empty second line provides padding in the text raster.
titleBox = findall(fig,String="Internal tides catalyze geostrophic eddy instabilities");
titleBox.String = string(titleBox.String) + newline + " ";
titleBox.FontWeight = "normal";
titleBox.Position = [0.025 0.859 0.95 0.13];
titleBox.VerticalAlignment = "top";
titleBox.Tag = "EddyTideTitle";
ax = findobj(fig,Tag="EddyTideAxes");
ax.FontSize = 12;
xDistance = 0:150:diff(ax.XLim);
yDistance = 0:150:diff(ax.YLim);
ax.XTick = fliplr(ax.XLim(2)-xDistance);
ax.XTickLabel = string(fliplr(xDistance));
ax.YTick = ax.YLim(1)+yDistance;
ax.YTickLabel = string(yDistance);
xlabel(ax,"");
ylabel(ax,"");
zlabel(ax,"");

% Grow about the back/top corner; only the empty foreground reaches beyond
% the canvas. Keep the physical coordinates and the camera direction fixed.
ax.Position = [-0.0358 -0.0392 1.00625 0.9085];
% Figure-relative labels stay visible when the empty axis origin is cropped.
labelAxes = axes(fig,Position=[0 0 1 1],Visible="off",Color="none",XLim=[0 1],YLim=[0 1],HandleVisibility="off",HitTest="off",PickableParts="none",Tag="EddyTideDistanceLabels");
text(labelAxes,0.80,0.06,"distance (km)",FontSize=12,Color=ax.XColor,HorizontalAlignment="center",VerticalAlignment="middle",Interpreter="none");
text(labelAxes,0.009,0.36,"Depth (m)",FontSize=12,Color=ax.ZColor,Rotation=90,HorizontalAlignment="center",VerticalAlignment="middle",Interpreter="none");

caption = findall(fig,Tag="EddyTideCutCaption");
if frame.cutMode == "geostrophic"
    cutLabel = "Anticyclonic core";
else
    cutLabel = "Fixed cut";
end
caption.String = cutLabel + newline + sprintf("x = %.1f km, y = %.1f km",frame.xCutKm,frame.yCutKm);
dayLabel = findall(fig,Tag="EddyTideDay");
dayLabel.FontWeight = "normal";
% Apply after both colorbars exist so every label and tick uses one family.
fontname(fig,"Optima");
layout = struct(axesPosition=ax.Position,distanceOriginKm=[ax.XLim(2) ax.YLim(1)],distanceDirections=[-1 1],distanceTickSpacingKm=150,fluidScale=1.15,distanceLabelPosition=[0.80 0.06],depthLabelPosition=[0.009 0.36]);
layout.fontName = "Optima";
layout.title = struct(fontName=titleBox.FontName,fontSize=titleBox.FontSize,fontWeight=titleBox.FontWeight,position=titleBox.Position,blankLinePadding=true);
end
