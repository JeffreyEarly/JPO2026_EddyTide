%MakeEddySchematic

loadFigureDefaults;

Ue = -15/100; 
He = 0.424 * 1000;
Le = 56.57 * 1000;
Lxy = wvt.Lx;
Lz = wvt.Lz;
N2 = wvt.N2(1);
f =  wvt.f;
g = wvt.g;
rho0 =  wvt.rho0;

%Define some functions for the conservative Gaussian eddy 
ce = exp(1/2)./(1+exp(-Lz^2/He^2));
Psifun = @(z) exp(-1/2*(z./He).^2) + exp(-(Lz/He)^2 +1/2*(z./He).^2);
rhofun = @(x,y,z) (rho0 * f / g) * ce * Ue * Le * exp(-1/2*((x./Le).^2 + (y./Le).^2)) .* (z./He^2) .* (-exp(-1/2*(z./He).^2) + exp(-(Lz/He)^2 +1/2*(z./He).^2));
ufun = @(y,z) -ce * Ue * (y./Le) .* exp(-1/2*(y./Le).^2) .* Psifun(z);

z = (-Lz:5:0)';
x = (-Lxy/2:1000:Lxy/2)';

[xg,yg,zg] = ndgrid(x,x,z);

rhonm = rho0*(1-(N2/g).*zg);
rhonmbar = rho0*(1-(N2/g).*z);
rhoe =  rhofun(xg,yg,zg);
rhoebar = squeeze(mean(mean(rhoe,1),2));

N=3;
rhobbar=zeros(length(rhoebar),N+1);

for i = 1:N
    rhobmat = repmat(permute(sum(rhobbar(:,1:i),2),[3 2 1]),[length(x),length(x),1]);
    rhotilde = reshape(sort(rhonm(:) + rhoe(:) + rhobmat(:), 1, "descend"),length(x),length(x),length(z));
    rhotilde = squeeze(mean(mean(rhotilde,1),2));
    rhobbar(:,i+1) = rhonmbar - rhotilde;
end

rhobbar =  sum(rhobbar(:,2:3),2);
rhobbar = interp1(z,rhobbar,wvt.z);

x=wvt.x-mean(wvt.x);
z=wvt.z;
[xg,zg] = ndgrid(x,z);

u = ufun(xg,zg);
rhonm = rho0*(1-(N2/g).*zg);
rho = rhonm + rhofun(xg,0,zg) + rhobbar';

figure(WindowStyle="normal")
contourf(x/1000,z/1000,rho',100,LineStyle="none"), hold on
contour(x/1000,z/1000,rho',(1020:0.2:1029),'color',[1 1 1]*0.6)
colormap(gca,sequentialcolormap)
contour(x/1000,z/1000,u'*100,(1:2:31),'color',lowcontourcolor)
contour(x/1000,z/1000,u'*100,(-31:2:-1),'--','color',lowcontourcolor)
clim([1025 1029])
xline([-80 80]/sqrt(2),":",Color="k",LineWidth=0.65)
xline([-80 80],":",Color="w",LineWidth=0.65)
yline(-He/1000,":",Color="k",LineWidth=0.65)
xlabel('South-North Location (km)')
ylabel('Depth (km)'),
yticks((-2:.2:0))

axpos=get(gca,'position');
hc1 = colorbar(gca,'southoutside');
hc1.Label.String = 'Density (kg/m$^3$)';
hc1.Label.Interpreter = 'latex';
pos=get(hc1,'position');
set(hc1,'position',[pos(1)+0.025 pos(2) pos(3)-0.05 pos(4)/2])
set(hc1,'Ticks',(1025:1029))
set(gca,'position',[axpos(1) axpos(2)+0.15 axpos(3) axpos(4)-0.17])

set(gcf,'Units','inches')
set(gcf,'Position',[1 1 5 5])
exportgraphics(gcf,figureFolder + "/" + "Figure1_EddySchematic.png",Resolution=500)
