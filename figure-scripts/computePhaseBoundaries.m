function [t_phaseII, t_phaseIII] = computePhaseBoundaries(wvd)
[PE_g,E_mda] = wvd.diagfile.readVariables('PE_g','E_mda');
PE_g = PE_g + E_mda;

% these should be first-order differenced, so the cumsum returns the
% correct total energy
t = wvd.t_diag;
t_diff = t(2:end) - (t(2)-t(1))/2;
dPE_g = diff(PE_g)./diff(t);

[maxflux,imaxflux] = max(abs(dPE_g));
t_phaseII = t_diff(find(dPE_g<-0.1*maxflux,1,'first'));
t_phaseIII = t_diff(find(dPE_g>-0.1*maxflux & t_diff>t_diff(imaxflux),1,'first'));
end