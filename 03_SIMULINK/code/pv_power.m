function Ppv_dispo = pv_power(G, Tamb, P) %#codegen
% PV_POWER  Puissance PV disponible (kW) a partir de l'irradiance et de la temperature.
%   Extrait a l'identique de microgrid_step.m (verifie : ecart nul).
%   Tcell via NOCT, derate global, coefficient de temperature.
%
%   G    : irradiance plan (W/m2)
%   Tamb : temperature ambiante (degC)
%   P    : parametres (voir irak_params.m)

Tcell = Tamb + (P.PV.NOCT - 20.0)/800.0 * G;
Ppv_dispo = P.PV.Pnom_kWp * (G/1000.0) * P.PV.derate * (1.0 - P.PV.gamma*(Tcell - 25.0));
if Ppv_dispo < 0.0
    Ppv_dispo = 0.0;
end
end
