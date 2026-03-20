%MakeEddySchematic

loadFigureDefaults;

eddyProperties.Ue = -15/100; 
eddyProperties.He = 0.424 * 1000;
eddyProperties.Le = 56.57 * 1000;
eddyProperties.Lxy = wvt.Lx;
eddyProperties.Lz = wvt.Lz;
eddyProperties.N2 = wvt.N2(1);
eddyProperties.f =  wvt.f;
eddyProperties.g = wvt.g;
eddyProperties.rho0 =  wvt.rho0;

use eddyProperties

%Define some functions for the convervative Gaussian eddy 
ce = frac(exp(1/2),1+exp(-Lz^2/He^2));
Psifun = @(z) exp(-1/2*(z./He).^2) + exp(-(Lz/He)^2 +1/2*(z./He).^2);
psifun = @(x,y,z) -ce * Ue * Le * ...
    exp(-1/2*((x./Le).^2 + (y./Le).^2)) .* Psifun(z);
psibfun = @(z) ce * Ue * Le * ...
   2 * pi * (Le/Lxy)^2 * erf(frac(1,2*sqrt(2))*frac(Lxy,Le))^2 .* Psifun(z);
rhofun = @(x,y,z) (rho0 * f / g) * ce * Ue * Le * ...
    exp(-1/2*((x./Le).^2 + (y./Le).^2)) .* ...
    (z./He^2) .* (-exp(-1/2*(z./He).^2) + exp(-(Lz/He)^2 +1/2*(z./He).^2));
rhobfun = @(z) -1 * (rho0 * f / g) * ce * Ue * Le * ...
     2 * pi * (Le/Lxy)^2 * erf(frac(1,2*sqrt(2))*frac(Lxy,Le))^2 .* ...
    (z./He^2) .* (-exp(-1/2*(z./He).^2) + exp(-(Lz/He)^2 +1/2*(z./He).^2));
ufun = @(y,z) -ce * Ue * (y./Le) .* exp(-1/2*(y./Le).^2) .* Psifun(z);
vfun = @(x,z) ce * Ue * (x./Le) .* exp(-1/2*(x./Le).^2) .* Psifun(z);
zetafun = @(r,z) (2 - (r./Le).^2) .* vfun(r,z)./r;
%--------------------------------------------------------------------------
%Iterate to find psib
z = (-Lz:5:0)';
x = (-Lxy/2:1000:Lxy/2)';

[xg,yg,zg] = ndgrid(x,x,z);

psie =  psifun(xg,yg,zg);
psib =  psibfun(zg);

rhonm = rho0*(1-frac(N2,g).*zg);
rhonmbar = rho0*(1-frac(N2,g).*z);
rhoe =  rhofun(xg,yg,zg);
rhoebar = squeeze(mean(mean(rhoe,1),2));
rhob0 = rhobfun(zg);
rhobbar0 = rhobfun(z);

rhotilde0 = reshape(sort(rhonm(:) + rhoe(:) + rhob0(:), 1, 'descend'),length(x),length(x),length(z));
rhotilde0 = squeeze(mean(mean(rhotilde0,2),1));
rhoerr0 = rhonmbar - rhotilde0;

%Number of iterations for the iterative density solver
N=3;

rhobbar=zeros(length(rhoebar),N+1);

for i = 1:N
    rhobmat = vrep(permute(sum(rhobbar(:,1:i),2),[3 2 1]),[length(x),length(x)],[1 2]);
    rhotilde = reshape(sort(rhonm(:) + rhoe(:) + rhobmat(:), 1, 'descend'),length(x),length(x),length(z));
    rhotilde = squeeze(mean(mean(rhotilde,1),2));
    rhobbar(:,i+1) = rhonmbar - rhotilde;
end

figure
plot(log10(abs([rhobbar0 rhoerr0 rhobbar(:,3:end)])),z/1000),xlim([-12.75 -2])
xlabel('Log$_{10}$ Magnitude Density Anomaly (kg/m$^3$)')
ylabel('Vertical Location (km)')
hl= legend('$\tilde{\rho}_b$',...
'$\left|\tilde\varepsilon_b\right|$',...
'$\left|{\varepsilon_b}^{\left\{1\right\}}\right|$',...
'$\left|{\varepsilon_b}^{\left\{2\right\}}\right|$',...
'location','northwest','interpreter','latex');

% fontsize 12 12 12 12
set(gcf,'paperposition',[1 1 5 5])
% jprint(printdir,'EddyBackgroundError','-r500')
%--------------------------------------------------------------------------
rhobbar =  sum(rhobbar(:,2:3),2);
rhobbar = interp1(z,rhobbar,wvt.z);

x=wvt.x-mean(wvt.x);
z=wvt.z;
[xg,zg] = ndgrid(x,z);

u = ufun(xg,zg);
rhonm = rho0*(1-frac(N2,g).*zg);
%The contribution from psi_b is miniscule but we include it anyway
rho = rhonm + rhofun(xg,0,zg) + rhobbar';
zeta = zetafun(abs(xg),zg);

%One column version 
% fig = figure(Units='points',Position=[1 1 FigureWidth1Col 3*72]);
% set(gcf,'PaperPositionMode','auto')

figure(WindowStyle="normal")
contourf(x/1000,z/1000,rho',100),nocontours,hold on
contour(x/1000,z/1000,rho',(1020:0.2:1029),'color',[1 1 1]*0.6)
colormap(gca,sequentialcolormap)
contour(x/1000,z/1000,u'*100,(1:2:31),'color',lowcontourcolor)
contour(x/1000,z/1000,u'*100,(-31:2:-1),'--','color',lowcontourcolor)
clim([1025 1029])
vlines([-80 80]/sqrt(2),'0.65k:')
vlines([-80 80],'0.65w:')
hlines(-He/1000,'0.65k:')
%xlabel('North-South Location (km)')
xlabel('South-North Location (km)')
ylabel('Depth (km)'),
yticks((-2:.2:0))

% contourf(x/1000,z/1000,rho',100),nocontours,hold on
% contour(x/1000,z/1000,rho',50,'color',[1 1 1]*0.6)
% colormap(flipud(crameri('davos')))
% contour(x/1000,z/1000,u'*100,[1:1:16],'w')
% contour(x/1000,z/1000,u'*100,[-16:1:-1],'w--')
% contour(x/1000,z/1000,zeta',[0 0],'w:')
% vlines([-80 80]./sqrt(2),'0.65k:')
% vlines([-80 80],'0.5w')
% hlines(-He/1000,'0.65k:')
% clim([1025 1029])
% xlabel('East-West Location (km)')
% ylabel('Vertical Location (km)')

% ax = gca;
% axpos = get(ax,'position');
% hc = colorbar('southoutside');
% pos = get(hc,'position');
% hc.Label.String = 'Density (kg/m^3)';

%axes(ax(1))
axpos=get(gca,'position');
hc1 = colorbar(gca,'southoutside');
hc1.Label.String = 'Density (kg/m$^3$)';
hc1.Label.Interpreter = 'latex';
pos=get(hc1,'position');
set(hc1,'position',[pos(1)+0.025 pos(2) pos(3)-0.05 pos(4)/2])
set(hc1,'Ticks',(1025:1029))
set(gca,'position',[axpos(1) axpos(2)+0.15 axpos(3) axpos(4)-0.17])
%text(-360,-.08,'(a)')

set(gcf,'Units','inches')
set(gcf,'Position',[1 1 5 5])
exportgraphics(gcf,figureFolder + "/" + "Figure1_EddySchematic.png",Resolution=500)

%%two column version
% figure
% subplot(1,2,1)
% contourf(x/1000,z/1000,rho',100),nocontours,hold on
% contour(x/1000,z/1000,rho',(1020:0.2:1029),'color',[1 1 1]*0.6)
% colormap(gca,sequentialcolormap)
% contour(x/1000,z/1000,u'*100,(1:2:31),'w')
% contour(x/1000,z/1000,u'*100,(-31:2:-1),'w--')
% clim([1025 1029])
% 
% subplot(1,2,2)
% contourf(x/1000,z/1000,zeta'/f,100),nocontours,hold on
% contour(x/1000,z/1000,zeta'/f,(-.25:0.02:0.25),'color',0.6*[1 1 1])
% %contour(x/1000,z/1000,zeta'/f,[0 0],'color','w','linewidth',0.5)
% colormap(gca,divergingcolormap)
% clim([-0.15 0.15])
% 
% for i=1:2
% subplot(1,2,i)
% vlines([-80 80],'0.65k:')
% %vlines([-80 80],'0.5k')
% hlines(-He/1000,'0.65k:')
% xlabel('North-South Location (km)')
% ylabel('Vertical Location (km)'),
% yticks((-2:.25:0))
% end
% 
% ax = packfig(1,2,'columns');
% 
% axes(ax(1))
% axpos=get(gca,'position');
% hc1 = colorbar(gca,'southoutside');
% hc1.Label.String = 'Density (kg/m$^3$)';
% hc1.Label.Interpreter = 'latex';
% pos=get(hc1,'position');
% set(hc1,'position',[pos(1)+0.025 pos(2) pos(3)-0.05 pos(4)/2])
% set(hc1,'Ticks',(1025:1029))
% set(gca,'position',[axpos(1) axpos(2)+0.17 axpos(3) axpos(4)-0.17])
% text(-360,-.08,'(a)')
% 
% axes(ax(2))
% axpos=get(gca,'position');
% hc2 = colorbar(gca,'southoutside');
% hc2.Label.String = 'Relative Vorticity $\zeta$ (s$^{-1}$)';
% hc2.Label.Interpreter = 'latex';
% pos=get(hc2,'position');
% set(hc2,'position',[pos(1)+0.025 pos(2) pos(3)-0.05 pos(4)/2])
% set(hc2,'Ticks',(-.15:.05:.15))
% set(gca,'position',[axpos(1) axpos(2)+0.17 axpos(3) axpos(4)-0.17])
% text(-360,-.08,'(b)')
% 
% set(gcf,'paperposition',[1 1 10 5.5])
% jprint(printdir,'EddySchematic','-r500')

if false
%--------------------------------------------------------------------------
%Slices through eddy at two different times
use eddyProperties
z = wvt.z;
x=wvt.x-mean(wvt.x);
[xg,zg] = ndgrid(x,z);

Times = 1:14*4:407*4;
for j = 1:2
    if j == 1
        n=18;%North-south slice through tripole at 238 days
        figurename = 'EddyTripoleSlice';
        xlabelstr = 'North-South Location (km)';
    elseif j==2
        n=22;%Rotated slice through elongated eddy at 294 days
        figurename = 'EddyElongatedSlice';
        xlabelstr = 'Rotated North-South Location (km)';
    end

    iTime = Times(n);
    wvt.initFromNetCDFFile(ncfile,iTime=iTime)
    u = wvt.u_g;
    v = wvt.v_g;
    eta = wvt.eta_g;
    zeta=wvt.diffX(v)-wvt.diffY(u);

    if j==1    
        eta = squeeze(eta(end/2,:,:));
        u = squeeze(u(end/2,:,:));
        zeta = squeeze(zeta(end/2,:,:));  
    elseif j ==2
        slope = -1.5;
        theta = angle(1 + slope*1i);
        %Lxyprime = Lxy * sqrt(1^2 + tan(-pi/2-theta)^2);

        %x0 = (-Lxyprime/2:1000:Lxyprime/2)';
       %$[xg,zg] = ndgrid(x0,z);

        u = interp3(x,x,wvt.z,permute(u,[2 1 3]),xg*cos(theta),xg*sin(theta),zg);
        v = interp3(x,x,wvt.z,permute(v,[2 1 3]),xg*cos(theta),xg*sin(theta),zg);
        eta = interp3(x,x,wvt.z,permute(eta,[2 1 3]),xg*cos(theta),xg*sin(theta),zg);
        zeta = interp3(x,x,wvt.z,permute(zeta,[2 1 3]),xg*cos(theta),xg*sin(theta),zg);

        %find component of flow in rotated coordinate system
        uprime = real(exp(-1i*(theta-pi/2)).*(u+1i*v));
    end

    %find total density anomaly
    [xg,zg] = ndgrid(x,z);
    rhonm = rho0*(1-frac(N2,g).*zg);
    rho = rhonm + (N2*rho0/g) * eta;

    figure
    subplot(1,2,1)
    contourf(x/1000,z/1000,rho',100),nocontours,hold on
    contour(x/1000,z/1000,rho',(1020:0.2:1029),'color',[1 1 1]*0.6)
    colormap(gca,sequentialcolormap)
    contour(x/1000,z/1000,u'*100,(1:2:31),'color',lowcontourcolor)
    contour(x/1000,z/1000,u'*100,(-31:2:-1),'--','color',lowcontourcolor)
    clim([1025 1029])

    subplot(1,2,2)
    contourf(x/1000,z/1000,zeta'/f,100),nocontours,hold on
    contour(x/1000,z/1000,zeta'/f,(-.25:0.02:0.25),'color',0.6*[1 1 1])
    colormap(gca,divergingcolormap)
    clim([-0.15 0.15])

    for i=1:2
        subplot(1,2,i)
        vlines([-80 80],'0.65k:')
        hlines(-He/1000,'0.65k:')
        xlabel(xlabelstr)
        ylabel('Vertical Location (km)'),
        yticks((-2:.25:0))
    end

    ax = packfig(1,2,'columns');

    axes(ax(1))
    axpos=get(gca,'position');
    hc1 = colorbar(gca,'southoutside');
    hc1.Label.Interpreter = 'latex';
    hc1.Label.String = 'Geostrophic Portion of Density $\rho_\triangle+\rho_g$ (kg/m$^3$)';
    pos=get(hc1,'position');
    set(hc1,'position',[pos(1)+0.025 pos(2) pos(3)-0.05 pos(4)/2])
    set(hc1,'Ticks',(1025:1029))
    set(gca,'position',[axpos(1) axpos(2)+0.17 axpos(3) axpos(4)-0.17])
    text(-360,-.08,['(' char(97+2*(j-1)) ')'])

    axes(ax(2))
    axpos=get(gca,'position');
    hc2 = colorbar(gca,'southoutside');
    hc2.Label.String = 'Geostrophic Portion of Relative Vorticity $\zeta_g$ (s$^{-1}$)';
    hc2.Label.Interpreter = 'latex';
    pos=get(hc2,'position');
    set(hc2,'position',[pos(1)+0.025 pos(2) pos(3)-0.05 pos(4)/2])
    set(hc2,'Ticks',(-.15:.05:.15))
    set(gca,'position',[axpos(1) axpos(2)+0.17 axpos(3) axpos(4)-0.17])
    text(-360,-.08,['(' char(98+2*(j-1)) ')'])

    set(gcf,'paperposition',[1 1 10 5.5])
    jprint(printdir,figurename,'-r500')
end

end

