function h = centeredPcolor(x,y,z)
x = x(:); y = y(:); z = squeeze(z);
x = [x(1)-(x(2)-x(1))/2; (x(1:end-1)+x(2:end))/2; x(end)+(x(end)-x(end-1))/2];
y = [y(1)-(y(2)-y(1))/2; (y(1:end-1)+y(2:end))/2; y(end)+(y(end)-y(end-1))/2];
z = [z z(:,end); z(end,:) z(end,end)];
z(z == -Inf) = NaN;
h = pcolor(x,y,z);
shading flat
set(gca,Layer="top")
