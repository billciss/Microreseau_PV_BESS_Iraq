function [y, st] = microgrid_step(u, Ts, st, P) %#codegen
% MICROGRID_STEP  Un pas de simulation du microreseau PV-BESS-Diesel-Reseau.
%   Modele AU NIVEAU PUISSANCE (kW) + une couche de frequence par statisme.
%   >>> SOURCE UNIQUE DE VERITE pour la logique du modele. <<<
%   Utilise a l'identique par le bloc Simulink (microgrid_core.m) et par la
%   simulation hors-ligne (simulate_offline.m).
%
%   ENTREES
%     u  = [G_Wm2, Tamb_C, Pload_kW, grid_on(0/1), dyn(0/1)]
%     Ts = pas de temps (s)
%     st = etat : .SoC (0-1) .freq (Hz) .fuel_L (L) .f_int (integrale secondaire)
%     P  = parametres (voir irak_params.m)
%
%   SORTIE  y (1x10), unites kW sauf indication
%     [Ppv, Pbatt, SoC_pct, Pdiesel, Pgrid, Pcurtail, freq_Hz, fuel_L, Punmet, Ppv_dispo]
%     Convention Pbatt : >0 = decharge (la batterie fournit), <0 = charge.

% ---------- entrees ----------
G       = u(1);
Tamb    = u(2);
Pload   = max(0.0, u(3));
grid_on = u(4) > 0.5;
dyn     = u(5) > 0.5;

dt_h = Ts/3600.0;            % pas de temps en heures

% ---------- sorties initialisees (obligatoire pour la generation de code) ----------
Pbatt = 0.0; Pdiesel = 0.0; Pgrid = 0.0; Pcurtail = 0.0; Punmet = 0.0;

% ---------- 1) puissance PV disponible (irradiance + temperature) ----------
Tcell = Tamb + (P.PV.NOCT - 20.0)/800.0 * G;
Ppv_dispo = P.PV.Pnom_kWp * (G/1000.0) * P.PV.derate * (1.0 - P.PV.gamma*(Tcell - 25.0));
if Ppv_dispo < 0.0
    Ppv_dispo = 0.0;
end

% ---------- 2) limites de puissance batterie (selon SoC et puissance nominale) ----------
eta_c = sqrt(P.BESS.eta_rt);          % rendement de charge
eta_d = sqrt(P.BESS.eta_rt);          % rendement de decharge
Pdis_soc = max(0.0, (st.SoC - P.BESS.SoC_min) * P.BESS.Enom_kWh / dt_h * eta_d);
Pchg_soc = max(0.0, (P.BESS.SoC_max - st.SoC) * P.BESS.Enom_kWh / dt_h / eta_c);
Pdis_max = min(P.BESS.Pmax_kW, Pdis_soc);   % decharge max admissible ce pas (kW)
Pchg_max = min(P.BESS.Pmax_kW, Pchg_soc);   % charge   max admissible ce pas (kW)

net = Pload - Ppv_dispo;     % >0 : deficit ; <0 : surplus PV

if grid_on
    % =================== MODE CONNECTE (reseau = noeud bilan) ===================
    if net < 0.0
        % surplus -> charge batterie, puis export, puis ecretage
        Pchg = min(-net, Pchg_max);
        Pbatt = -Pchg;                       % charge (negatif)
        surplus_rest = (-net) - Pchg;
        if P.GRID.allow_export
            Pexp = min(surplus_rest, P.GRID.export_max_kW);
            Pgrid = -Pexp;                   % export (negatif)
            Pcurtail = surplus_rest - Pexp;
        else
            Pcurtail = surplus_rest;
        end
    else
        % deficit -> ecretage de pointe optionnel par batterie, sinon import reseau
        Pdis = 0.0;
        if P.EMS.peak_shaving && Pload > P.EMS.peak_threshold_kW
            Pdis = min(Pload - P.EMS.peak_threshold_kW, Pdis_max);
        end
        Pbatt = Pdis;                        % decharge (positif) si ecretage
        Pgrid = min(net - Pbatt, P.GRID.import_max_kW);
        Punmet = max(0.0, (net - Pbatt) - Pgrid);
    end
    st.freq  = P.FREQ.f0;                     % reseau raide -> 50 Hz
    st.f_int = 0.0;

else
    % =================== MODE ILOTE ===================
    Pgrid = 0.0;
    if ~dyn
        % ----- regime energetique (figures journalieres) : bilan parfait -----
        if net < 0.0
            Pchg = min(-net, Pchg_max);
            Pbatt = -Pchg;
            Pcurtail = (-net) - Pchg;        % surplus non stockable -> ecrete
        else
            Pdis = min(net, Pdis_max);
            Pbatt = Pdis;
            rest = net - Pdis;
            Pdiesel = min(rest, P.DG.Pmax_kW);
            Punmet = max(0.0, rest - Pdiesel);   % charge non desservie (EENS)
        end
        st.freq  = P.FREQ.f0;                 % frequence supposee regulee
        st.f_int = 0.0;
    else
        % ----- regime dynamique (figure de transition reseau->ilote) -----
        % Batterie grid-forming : statisme primaire + restauration secondaire.
        df = st.freq - P.FREQ.f0;
        Pbatt_ref = (1.0/P.FREQ.Rbatt) * (-df/P.FREQ.f0) * P.FREQ.Sbase_kW ...
                    + P.FREQ.Ksec * st.f_int;
        Pbatt = min(Pdis_max, max(-Pchg_max, Pbatt_ref));    % saturation batterie
        % diesel en secours seulement si SoC bas (statisme simple)
        if st.SoC <= P.EMS.diesel_soc_on
            Pdg_ref = (1.0/P.FREQ.Rdg) * (-df/P.FREQ.f0) * P.FREQ.Sbase_kW;
            Pdiesel = min(P.DG.Pmax_kW, max(0.0, Pdg_ref));
        else
            Pdiesel = 0.0;
        end
        % ecretage si surproduction et batterie pleine
        gen = Ppv_dispo + Pbatt + Pdiesel;    % Pbatt<0 si charge
        if (gen > Pload) && (Pbatt <= -Pchg_max + 1e-6)
            Pcurtail = gen - Pload;
        end
        % equation du mouvement (Euler) : le desequilibre fait varier la frequence
        Pimb = (Ppv_dispo - Pcurtail) + Pbatt + Pdiesel - Pload;     % kW
        dfreq = (P.FREQ.f0/(2.0*P.FREQ.H)) * (Pimb/P.FREQ.Sbase_kW - P.FREQ.D*df/P.FREQ.f0) * Ts;
        st.freq  = st.freq + dfreq;
        st.f_int = st.f_int + (P.FREQ.f0 - st.freq) * Ts;           % restauration lente
        Punmet = max(0.0, Pload - ((Ppv_dispo - Pcurtail) + max(0.0,Pbatt) + Pdiesel));
    end
end

% ---------- 3) mise a jour du SoC ----------
if Pbatt >= 0.0
    dSoC = -(Pbatt/eta_d) * dt_h / P.BESS.Enom_kWh;     % decharge -> SoC baisse
else
    dSoC = -(Pbatt*eta_c) * dt_h / P.BESS.Enom_kWh;     % charge (Pbatt<0) -> SoC monte
end
st.SoC = min(P.BESS.SoC_max, max(P.BESS.SoC_min, st.SoC + dSoC));

% ---------- 4) carburant diesel cumule ----------
st.fuel_L = st.fuel_L + P.DG.fuel_L_per_kWh * Pdiesel * dt_h;

% ---------- 5) sorties ----------
Ppv = Ppv_dispo - Pcurtail;          % PV reellement injecte
y = [Ppv, Pbatt, st.SoC*100.0, Pdiesel, Pgrid, Pcurtail, st.freq, st.fuel_L, Punmet, Ppv_dispo];
end
