function P = irak_params() %#codegen
% IRAK_PARAMS  Parametres du microreseau communautaire PV-BESS adapte a l'Irak (Bagdad).
%
%   >>> SOURCE UNIQUE DE VERITE pour le modele simplifie. <<<
%   Coherent avec 03_PARAMETRES/system_params.yaml et 01_MODELE_SIMULINK/
%   Microgrid_BESS_PV_Data.m. Toute modification de taille se fait ICI seulement.
%
%   Communaute : 20 foyers, Bagdad (33.31 N, 44.37 E), reseau 50 Hz.

P.Fnom = 50.0;                 % Hz - reseau irakien

% --- Champ PV (100 kWp, monocristallin, Bagdad) ---
P.PV.Pnom_kWp = 100.0;         % puissance crete (kWp)
P.PV.derate   = 0.85;          % onduleur + salissure + cables combines
P.PV.gamma    = 0.0040;        % coeff. temperature puissance (1/degC) ~ -0.40 %/degC
P.PV.NOCT     = 45.0;          % degC - temperature nominale de cellule

% --- Batterie (LiFePO4, 100 kW / 200 kWh) ---
P.BESS.Enom_kWh = 200.0;       % energie utile (kWh)
P.BESS.Pmax_kW  = 100.0;       % puissance max charge/decharge (kW)
P.BESS.SoC_min  = 0.15;        % etat de charge mini
P.BESS.SoC_max  = 0.90;        % etat de charge maxi
P.BESS.SoC_init = 0.50;        % etat de charge initial
P.BESS.eta_rt   = 0.95;        % rendement aller-retour (round-trip)

% --- Groupe diesel de secours ---
P.DG.Pmax_kW        = 150.0;   % dimensionne pour couvrir la pointe ilotee
P.DG.fuel_L_per_kWh = 0.40;    % Djelailia 2019 via Mushref 2026
P.DG.co2_kg_per_kWh = 0.80;    % UNFCCC/CDM

% --- Connexion au reseau principal ---
P.GRID.import_max_kW = 300.0;  % limite d'import depuis le reseau
P.GRID.export_max_kW = 100.0;  % limite d'export vers le reseau
P.GRID.allow_export  = true;   % autoriser l'injection du surplus

% --- Strategie de gestion de l'energie (EMS) ---
P.EMS.peak_shaving      = false;   % ecretage de pointe par batterie (mode connecte)
P.EMS.peak_threshold_kW = 80.0;    % seuil d'ecretage de pointe (kW)
P.EMS.diesel_soc_on     = 0.20;    % demarre le diesel si SoC <= 20 % (mode ilote)

% --- Dynamique de frequence (couche de justification "Simulink") ---
%   Modele de mouvement (swing equation) + statisme. Premiere version a affiner :
%   ces gains n'influencent QUE la figure de transition, pas les bilans d'energie.
P.FREQ.f0       = 50.0;     % frequence nominale (Hz)
P.FREQ.Sbase_kW = 100.0;    % puissance de base (kW)
P.FREQ.H        = 2.0;      % constante d'inertie equivalente (s)
P.FREQ.D        = 1.5;      % amortissement de charge (pu)
P.FREQ.Rbatt    = 0.04;     % statisme batterie grid-forming (pu)
P.FREQ.Rdg      = 0.05;     % statisme diesel (pu)
P.FREQ.Ksec     = 2.0;      % gain de restauration secondaire (kW/(Hz.s))
end
