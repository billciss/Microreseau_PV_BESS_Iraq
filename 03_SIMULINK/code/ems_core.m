function y = ems_core(Ppv_dispo, Pload, grid_on, dyn, Ts) %#codegen
% EMS_CORE  Corps du bloc "MATLAB Function" du sous-systeme EMS.
%   Conserve l'etat (SoC, frequence, carburant) entre les pas et appelle ems_step.
%   PREREQUIS : irak_params.m et ems_step.m sur le path.
%
%   y : vecteur 1x10 (voir ems_step.m)
persistent st P done
if isempty(done)
    P    = irak_params();
    st   = struct('SoC', P.BESS.SoC_init, ...
                  'freq', P.FREQ.f0, ...
                  'fuel_L', 0.0, ...
                  'f_int', 0.0);
    done = true;
end
[y, st] = ems_step(Ppv_dispo, Pload, grid_on, dyn, Ts, st, P);
end
