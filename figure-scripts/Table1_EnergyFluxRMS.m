loadFigureDefaults;

[t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd);

%%
clear ggg ggw ggw_tx wwg_tx
ggg.flux = wvd.diagfile.readVariables("geostrophic-flux/ggg");
ggw.flux = wvd.diagfile.readVariables("geostrophic-flux/ggw");
ggw_tx.flux = wvd.diagfile.readVariables("geostrophic-flux/ggw_tx");
wwg_tx.flux = wvd.diagfile.readVariables("geostrophic-flux/wwg_tx");

filter_phaseI = @(v) mean(v(:,:,wvd.t_diag<t_phaseII),3);
filter_phaseII = @(v) mean(v(:,:,wvd.t_diag>=t_phaseII & wvd.t_diag<t_phaseIII),3);
filter_phaseIII = @(v) mean(v(:,:,wvd.t_diag<t_phaseIII),3);

latexSci = @(x) sprintf('$%.1f \\cdot 10^{%d}$', ...
    x ./ 10.^floor(log10(abs(x))), floor(log10(abs(x))));

inertial_flux_names = ["ggg","ggw","ggw_tx","wwg_tx"];
inertial_flux_fancy_names = ["ggg-cascade","ggw-cascade","ggw-transfer","wwg-transfer"];
tableString = "\begin{tabular}{r|ccc}" + newline;
tableString = tableString + " & phase I & phase II & phase III \\ \hline" + newline;
for iFlux=1:length(inertial_flux_names)
    flux = wvd.diagfile.readVariables("geostrophic-flux/" + inertial_flux_names(iFlux));

    tableString = tableString + inertial_flux_fancy_names(iFlux) + " & ";


    a = filter_phaseI(flux)/wvd.flux_scale;
    flux_rms = mean(sum(a(:).^2));
    tableString = tableString + string(latexSci(flux_rms)) + " & ";

    a = filter_phaseII(flux)/wvd.flux_scale;
    flux_rms = mean(sum(a(:).^2));
    tableString = tableString + string(latexSci(flux_rms)) + " & ";

    a = filter_phaseIII(flux)/wvd.flux_scale;
    flux_rms = mean(sum(a(:).^2));
    tableString = tableString + string(latexSci(flux_rms));
    tableString = tableString + " \\ " + newline;
end
tableString = tableString + "\hline" + newline;
tableString = tableString + "\end{tabular}";

disp(tableString)