function Ppv_dispo = pv_core(G, Tamb) %#codegen
% PV_CORE  Corps du bloc "MATLAB Function" du sous-systeme PV.
%   Charge les parametres une fois, puis appelle pv_power.
%   PREREQUIS : irak_params.m et pv_power.m sur le path.
persistent P done
if isempty(done)
    P    = irak_params();
    done = true;
end
Ppv_dispo = pv_power(G, Tamb, P);
end
