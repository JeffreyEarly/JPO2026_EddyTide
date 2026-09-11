function MonitorEddyTideExponentialRun(directory,options)
% Update geostrophic energies from a closed exponential model file.
%
% The segmented supervisor owns the run lock and invokes this only after the
% native writer exits. CSV rows are reused only when their times and source
% configuration match. Energies use the model's spectral KE and PE methods.
%
% - Parameter directory: prepared run directory
% - Parameter snapshots: generate five surface-vorticity panels at completion
arguments (Input)
    directory (1,1) string
    options.snapshots (1,1) logical = false
end
scriptFolder = string(fileparts(mfilename("fullpath")));
workspaceRoot = string(fileparts(fileparts(scriptFolder)));
p = jsondecode(fileread(fullfile(directory,"provenance.json")));
restoredefaultpath;
roots = [fullfile(workspaceRoot,"OceanKit",string(p.environment.dependencySnapshots(:)')),string(p.environment.modelSource)];
roots = roots(:);
for iRoot = 1:numel(roots)
    root = roots(iRoot);
    manifest = jsondecode(fileread(fullfile(root,"resources/mpackage.json")));
    addpath(root);
    for iFolder = 1:numel(manifest.folders)
        addpath(fullfile(root,manifest.folders(iFolder).path));
    end
end
addpath(scriptFolder);
path = fullfile(directory,"eddy-tide-exponential.nc");
assert(isequaln(jsondecode(ncreadatt(path,"/","eddyTideExponentialConfiguration")),p.configuration),"Configuration mismatch.");
t = double(ncread(path,"/wave-vortex/t"));
t = t(:);
assert(t(1) == 0 && all(diff(t) == p.configuration.outputInterval),"Output times must be ordered six-hour records from zero.");
[wvt,ncfile] = WVTransform.waveVortexTransformFromFile(path,iTime=1,shouldReadOnly=true);
closeFile = onCleanup(@()ncfile.close());
assert(wvt.Nx == p.configuration.Nxy && wvt.Ny == p.configuration.Nxy && wvt.Nz == p.resolved.Nz && wvt.Nj == p.resolved.Nj,"Grid differs from provenance.");
expectedN2 = p.configuration.N0^2*exp(2*wvt.z/p.configuration.stratificationScale);
assert(max(abs(wvt.N2-expectedN2)) < 1e-12*max(expectedN2),"Profile mismatch.");
assert(abs(wvt.Lx-p.resolved.Lxy) < 1e-6,"Domain mismatch.");
initialA0 = wvt.A0;
wvt.A0 = zeros(size(initialA0));
assert(abs(wvt.uvMax-p.configuration.u0Wave) < 1e-10,"Initial wave maximum mismatch.");
wvt.A0 = initialA0;
ke0 = wvt.geostrophicKineticEnergy;
pe0 = wvt.geostrophicPotentialEnergy;
csvPath = fullfile(directory,"energy.csv");
values = zeros(0,5);
if isfile(csvPath)
    values = readmatrix(csvPath);
    assert(size(values,2) == 5 && size(values,1) <= numel(t),"Invalid energy history.");
    assert(isequal(values(:,1),t(1:size(values,1))),"Energy history times differ from model.");
    assert(abs(values(1,2)/ke0-1) < 1e-12 && abs(values(1,3)/pe0-1) < 1e-12,"Energy normalization mismatch.");
end
for iTime = size(values,1)+1:numel(t)
    wvt.initFromNetCDFFile(ncfile,iTime=iTime);
    assert(all(isfinite(wvt.Ap),"all") && all(isfinite(wvt.Am),"all") && all(isfinite(wvt.A0),"all"),"Nonfinite checkpoint.");
    ke = wvt.geostrophicKineticEnergy;
    pe = wvt.geostrophicPotentialEnergy;
    assert(abs(ke+pe-wvt.geostrophicEnergy) < 1e-12*(ke+pe),"KE and PE disagree with total geostrophic energy.");
    values(iTime,:) = [t(iTime),ke,pe,ke/ke0,pe/pe0];
end
assert(all(isfinite(values),"all") && ke0 > 0 && pe0 > 0,"Invalid energies.");
tableValues = array2table(values,VariableNames=["time_seconds","KE_g","PE_g","KE_g_normalized","PE_g_normalized"]);
writetable(tableValues,csvPath+".tmp",FileType="text",Delimiter=",");
movefile(csvPath+".tmp",csvPath,"f");
fig = figure(Visible="off");
plot(t/86400,values(:,4:5),LineWidth=1.5);
xlabel("Model day"); ylabel("Energy / initial energy"); legend("Geostrophic KE","Geostrophic PE",Location="best"); grid on;
exportgraphics(fig,fullfile(directory,"energy.png"),Resolution=150); close(fig);
summary = struct("records",numel(t),"completedDay",t(end)/86400,"KE",values(end,2),"PE",values(end,3),"KEnormalized",values(end,4),"PEnormalized",values(end,5),"configuration",p.configuration);
fid = fopen(fullfile(directory,"energy.json.tmp"),"w");
fprintf(fid,"%s\n",jsonencode(summary,PrettyPrint=true)); fclose(fid);
movefile(fullfile(directory,"energy.json.tmp"),fullfile(directory,"energy.json"),"f");
if options.snapshots
    days = [0 150 300 450 600];
    assert(t(end) == 600*86400 && numel(t) == 2401,"Final checkpoint or energy history is incomplete.");
    fig = figure(Visible="off",Position=[0 0 1500 350]);
    tiledlayout(1,5,TileSpacing="compact",Padding="compact");
    for i = 1:5
        wvt.initFromNetCDFFile(ncfile,iTime=find(t == days(i)*86400,1));
        nexttile;
        imagesc((wvt.x-mean(wvt.x))/1e3,(wvt.y-mean(wvt.y))/1e3,wvt.zeta_z(:,:,end)'/wvt.f);
        axis xy equal tight; clim([-0.12 0.12]); title(sprintf("Day %d",days(i))); xlabel("x (km)");
    end
    colorbar; exportgraphics(fig,fullfile(directory,"surface-vorticity-snapshots.png"),Resolution=200); close(fig);
end
fprintf("Monitored %d records through day %.6g: KE/KE0 %.9g, PE/PE0 %.9g.\n",numel(t),t(end)/86400,values(end,4),values(end,5));
end
