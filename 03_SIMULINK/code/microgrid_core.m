function y = microgrid_core(u, Ts) %#codegen
% MICROGRID_CORE  Corps du bloc "MATLAB Function" du modele Simulink.
%   Enveloppe a etat persistant autour de la fonction de pas partagee.
%   Le contenu de ce fichier est injecte dans le bloc par build_microgrid_irak.m.
%
%   PREREQUIS : irak_params.m et microgrid_step.m doivent etre sur le path
%   MATLAB (les garder dans le meme dossier que ce fichier).
%
%   u = [G_Wm2, Tamb_C, Pload_kW, grid_on(0/1), dyn(0/1)]   (vecteur 1x5)
%   Ts = pas de temps (s)
%   y  = vecteur 1x10 de sorties (voir microgrid_step.m)

persistent st P done
if isempty(done)
    P    = irak_params();
    st   = struct('SoC', P.BESS.SoC_init, ...
                  'freq', P.FREQ.f0, ...
                  'fuel_L', 0.0, ...
                  'f_int', 0.0);
    done = true;
end

[y, st] = microgrid_step(u, Ts, st, P);
end
