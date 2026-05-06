%MakeEddySnapshots

loadFigureDefaults;

x = (wvt.x-mean(wvt.x))/1e3;
y = (wvt.y-mean(wvt.y))/1e3; 

ci = (-50:50)./50*.15;

incrementsPerDay = round(86400/wvd.t_diag(2));
Times = incrementsPerDay*(maxDays/4)*(0:4)+1;
fig = figure(WindowStyle="normal");
set(fig,'Units','inches')
figureSize = [12 6.8];
set(fig,'Position',[1 1 figureSize])

tileInches = 1.95;
gapInches = 0.16;
leftInches = (figureSize(1) - 5*tileInches - 4*gapInches)/2;
bottomInches = 0.55;
axs = gobjects(3,5);
hc = gobjects(1);
axisPositions = zeros(3,5,4);
for j=1:3
    for i=1:5
        xPosition = (leftInches + (i-1)*(tileInches + gapInches))/figureSize(1);
        yPosition = (bottomInches + (3-j)*(tileInches + gapInches))/figureSize(2);
        axisPositions(j,i,:) = [xPosition yPosition tileInches/figureSize(1) tileInches/figureSize(2)];
        axs(j,i) = axes(fig,Position=squeeze(axisPositions(j,i,:))');
        iTime = Times(i);
        wvd.iTime = iTime;
        switch j
            case 1 
                zeta=wvt.zeta_z(:,:,end);
            case 2
                zeta=wvt.diffX(wvt.v_g(:,:,end))-wvt.diffY(wvt.u_g(:,:,end));
            case 3
                zeta=wvt.diffX(wvt.v_w(:,:,end))-wvt.diffY(wvt.u_w(:,:,end));
        end
        zeta=zeta./wvt.f;
        zeta(zeta<min(ci))=min(ci);
        zeta(zeta>max(ci))=max(ci);
        centeredPcolor(x, y, zeta'); axis equal, axis tight
        axis equal, axis tight
        clim([-.12 .12])
        if i==1 && j==2
            hc = colorbar(gca,'South');
            hc.Label.String = 'Relative Vorticity $\zeta/f_0$';
            hc.Label.Interpreter = 'latex';
        end
        if j==2
            text(50,300,['t = ' int2str(wvd.t_wv(Times(i))/86400) ' days']);
        end
        colormap(divergingcolormap)
        xticks(-400:100:400),yticks(-400:100:400)
        if j < 3
            xticklabels([])
        end
        if i > 1
            yticklabels([])
        end
    end
end

axisPosition = squeeze(axisPositions(2,1,:))';
set(axs(2,1),"Position",axisPosition)
set(hc,"Position",[axisPosition(1)+0.01 axisPosition(2)+0.02 axisPosition(3)-0.02 0.035])

exportgraphics(gcf,figureFolder + "/" + "Figure3_EddySnapShots.png",Resolution=500)
