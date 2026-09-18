function fig = PlotEddyTideCoreTrack(track, options)
% Compare the continuous core track with independent global minima.
%
% - Topic: Track the anticyclonic core
% - Declaration: fig = PlotEddyTideCoreTrack(track,options)
% - Parameter track: output of TrackEddyTideAnticyclone
% - Parameter outputFile: optional PNG path; default empty
% - Parameter visible: whether to display the figure; default true
% - Returns fig: continuity diagnostic figure
arguments (Input)
    track (1,1) struct
    options.outputFile (1,1) string = ""
    options.visible (1,1) logical = true
end
arguments (Output)
    fig (1,1) matlab.ui.Figure
end
fig = figure(Color="white",Position=[100 100 1400 900],Visible=options.visible,WindowStyle="normal");
layout = tiledlayout(fig,2,2,TileSpacing="compact",Padding="compact");
blue = [0.08 0.35 0.62];
gray = [0.70 0.70 0.70];
orange = [0.88 0.35 0.08];
ambiguous = track.status == "ambiguous";
for iAxis = 1:2
    ax = nexttile(layout);
    plot(ax,track.day,track.globalMinimum(:,iAxis),Color=gray,LineWidth=0.6,DisplayName="Independent global minimum");
    hold(ax,"on")
    plot(ax,track.day,track.unwrappedKm(:,iAxis),Color=blue,LineWidth=1.8,DisplayName="Continuous anticyclone");
    scatter(ax,track.day(ambiguous),track.unwrappedKm(ambiguous,iAxis),45,orange,"filled",DisplayName="Ambiguous local choice");
    xlabel(ax,"Day");
    coordinates = ["x (km)","y (km)"];
    ylabel(ax,coordinates(iAxis));
    grid(ax,"on")
    ax.FontSize = 12;
    if iAxis == 1
        legend(ax,Location="southwest");
    end
end
ax = nexttile(layout);
plot(ax,track.day,track.globalStepKm,Color=gray,LineWidth=0.6);
hold(ax,"on")
plot(ax,track.day,track.stepKm,Color=blue,LineWidth=1.2);
ax.YScale = "log";
ylim(ax,[1 max(500,1.2*max(track.globalStepKm))]);
xlabel(ax,"Day");
ylabel(ax,"Distance per saved interval (km)");
title(ax,sprintf("Largest step: global %.1f km; tracked %.1f km",max(track.globalStepKm),max(track.stepKm,[],"omitmissing")));
grid(ax,"on")
ax.FontSize = 12;
ax = nexttile(layout);
plot(ax,track.day,track.globalMinimum(:,3),Color=gray,LineWidth=0.6);
hold(ax,"on")
plot(ax,track.day,track.zetaOverF,Color=blue,LineWidth=1.4);
scatter(ax,track.day(ambiguous),track.zetaOverF(ambiguous),45,orange,"filled");
xlabel(ax,"Day");
ylabel(ax,"Unfiltered geostrophic vorticity  \zeta_g / f",Interpreter="tex");
grid(ax,"on")
ax.FontSize = 12;
title(layout,sprintf("Anticyclonic-core continuity | %d consecutive snapshots | %d lost, %d ambiguous",numel(track.day),nnz(track.status=="lost"),nnz(ambiguous)),FontSize=19,FontWeight="bold");
subtitle(layout,sprintf("%.0f km Gaussian averaging for localization only. Zero-motion intervals are omitted on the logarithmic distance axis.",track.settings.smoothingKm),FontSize=11);
drawnow
if strlength(options.outputFile) > 0
    outputFolder = fileparts(options.outputFile);
    if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
        mkdir(outputFolder)
    end
    fig.PaperUnits = "inches";
    fig.PaperPosition = [0 0 14 9];
    fig.PaperSize = [14 9];
    print(fig,options.outputFile,"-dpng","-r150");
end
end
