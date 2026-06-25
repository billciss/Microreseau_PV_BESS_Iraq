function [y, st] = ems_step(Ppv_dispo, Pload, grid_on, dyn, Ts, st, P) %#codegen
% EMS_STEP  Un pas de gestion d'energie : repartition + etats (SoC, diesel, frequence).
%   IDENTIQUE a microgrid_step.m, mais la puissance PV disponible est RECUE en
%   entree (calculee par le sous-systeme PV) au lieu d'etre calculee ici.
%   Verifie : compose avec pv_power, l'ecart avec microgrid_step est nul.
%
%   ENTREES
%     Ppv_dispo : puissance PV disponible (kW)
%     Pload     : charge (kW)
%     grid_on   : reseau present (0/1)
%     dyn       : couche dynamique de frequence active (0/1)
%     Ts        : pas de temps (s)
%     st        : etat .SoC .freq .fuel_L .f_int
%     P         : parametres (irak_params.m)
%
%   SORTIE  y (1x10), unites kW sauf indication
%     [Ppv, Pbatt, SoC_pct, Pdiesel, Pgrid, Pcurtail, freq_Hz, fuel_L, Punmet, Ppv_dispo]
%     Convention Pbatt : >0 = decharge, <0 = charge.

% ---------- entrees ----------
Pload   = max(0.0, Pload);
grid_on = grid_on > 0.5;
dyn     = dyn > 0.5;
if Ppv_dispo < 0.0
    Ppv_dispo = 0.0;
end

dt_h = Ts/3600.0;

% ---------- sorties initialisees (obligatoire pour la generation de code) ----------
Pbatt = 0.0; Pdiesel = 0.0; Pgrid = 0.0; Pcurtail = 0.0; Punmet = 0.0;

% ---------- limites de puissance batterie (selon SoC et puissance nominale) ----------
eta_c = sqrt(P.BESS.eta_rt);
eta_d = sqrt(P.BESS.eta_rt);
Pdis_soc = max(0.0, (st.SoC - P.BESS.SoC_min) * P.BESS.Enom_kWh / dt_h * eta_d);
Pchg_soc = max(0.0, (P.BESS.SoC_max - st.SoC) * P.BESS.Enom_kWh / dt_h / eta_c);
Pdis_max = min(P.BESS.Pmax_kW, Pdis_soc);
Pchg_max = min(P.BESS.Pmax_kW, Pchg_soc);

net = Pload - Ppv_dispo;

if grid_on
    % =================== MODE CONNECTE ===================
    if net < 0.0
        Pchg = min(-net, Pchg_max);
        Pbatt = -Pchg;
        surplus_rest = (-net) - Pchg;
        if P.GRID.allow_export
            Pexp = min(surplus_rest, P.GRID.export_max_kW);
            Pgrid = -Pexp;
            Pcurtail = surplus_rest - Pexp;
        else
            Pcurtail = surplus_rest;
        end
    else
        Pdis = 0.0;
        if P.EMS.peak_shaving && Pload > P.EMS.peak_threshold_kW
            Pdis = min(Pload - P.EMS.peak_threshold_kW, Pdis_max);
        end
        Pbatt = Pdis;
        Pgrid = min(net - Pbatt, P.GRID.import_max_kW);
        Punmet = max(0.0, (net - Pbatt) - Pgrid);
    end
    st.freq  = P.FREQ.f0;
    st.f_int = 0.0;

else
    % =================== MODE ILOTE ===================
    Pgrid = 0.0;
    if ~dyn
        % ----- regime energetique (figures journalieres) : bilan parfait -----
        if net < 0.0
            Pchg = min(-net, Pchg_max);
            Pbatt = -Pchg;
            Pcurtail = (-net) - Pchg;
        else
            Pdis = min(net, Pdis_max);
            Pbatt = Pdis;
            rest = net - Pdis;
            Pdiesel = min(rest, P.DG.Pmax_kW);
            Punmet = max(0.0, rest - Pdiesel);
        end
        st.freq  = P.FREQ.f0;
        st.f_int = 0.0;
    else
        % ----- regime dynamique (figure de transition) -----
        df = st.freq - P.FREQ.f0;
        Pbatt_ref = (1.0/P.FREQ.Rbatt) * (-df/P.FREQ.f0) * P.FREQ.Sbase_kW ...
                    + P.FREQ.Ksec * st.f_int;
        Pbatt = min(Pdis_max, max(-Pchg_max, Pbatt_ref));
        if st.SoC <= P.EMS.diesel_soc_on
            Pdg_ref = (1.0/P.FREQ.Rdg) * (-df/P.FREQ.f0) * P.FREQ.Sbase_kW;
            Pdiesel = min(P.DG.Pmax_kW, max(0.0, Pdg_ref));
        else
            Pdiesel = 0.0;
        end
        gen = Ppv_dispo + Pbatt + Pdiesel;
        if (gen > Pload) && (Pbatt <= -Pchg_max + 1e-6)
            Pcurtail = gen - Pload;
        end
        Pimb = (Ppv_dispo - Pcurtail) + Pbatt + Pdiesel - Pload;
        dfreq = (P.FREQ.f0/(2.0*P.FREQ.H)) * (Pimb/P.FREQ.Sbase_kW - P.FREQ.D*df/P.FREQ.f0) * Ts;
        st.freq  = st.freq + dfreq;
        st.f_int = st.f_int + (P.FREQ.f0 - st.freq) * Ts;
        Punmet = max(0.0, Pload - ((Ppv_dispo - Pcurtail) + max(0.0,Pbatt) + Pdiesel));
    end
end

% ---------- mise a jour du SoC ----------
if Pbatt >= 0.0
    dSoC = -(Pbatt/eta_d) * dt_h / P.BESS.Enom_kWh;
else
    dSoC = -(Pbatt*eta_c) * dt_h / P.BESS.Enom_kWh;
end
st.SoC = min(P.BESS.SoC_max, max(P.BESS.SoC_min, st.SoC + dSoC));

% ---------- carburant diesel cumule ----------
st.fuel_L = st.fuel_L + P.DG.fuel_L_per_kWh * Pdiesel * dt_h;

% ---------- sorties ----------
Ppv = Ppv_dispo - Pcurtail;
y = [Ppv, Pbatt, st.SoC*100.0, Pdiesel, Pgrid, Pcurtail, st.freq, st.fuel_L, Punmet, Ppv_dispo];
end
