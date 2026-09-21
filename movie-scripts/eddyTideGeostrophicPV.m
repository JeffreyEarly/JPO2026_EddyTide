function [pv, identityResidual] = eddyTideGeostrophicPV(wvt)
% Normalize the full balanced QGPV by f and verify its physical-space identity.
% Retain the mean-density contribution; this is not nonlinear Ertel PV.
arguments (Input)
    wvt (1,1) WVTransform
end
arguments (Output)
    pv (:,:,:) double
    identityResidual (1,1) double
end
pv = wvt.qgpv/wvt.f;
pvPhysical = (wvt.zeta_z - wvt.f*wvt.diffZG(wvt.eta))/wvt.f;
identityResidual = max(abs(pv-pvPhysical),[],"all");
if identityResidual > 1e-10*max(1,max(abs(pv),[],"all"))
    error("EddyTide:PVIdentityMismatch","QGPV differs from zeta_z - f*d(eta)/dz; normalized maximum residual is %.3g.",identityResidual)
end
end
