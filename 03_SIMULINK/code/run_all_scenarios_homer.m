function run_all_scenarios_homer(dataDir)
% RUN_ALL_SCENARIOS_HOMER  Simule les 4 scenarios avec les tailles optimales HOMER.
%   Injecte les tailles PV / BESS / Diesel issues de HOMER Pro dans les
%   parametres, puis appelle la simulation hors-ligne pour chaque scenario.
%   Produit 3 figures PNG par scenario (transition, journee, ecretage).
%
%   Usage :
%     run_all_scenarios_homer              % dataDir par defaut (data/ integre)
%     run_all_scenarios_homer(dataDir)     % chemin alternatif vers 02_DONNEES_REELLES
%
%   PREREQUIS : tous les .m du dossier Microreseau_Irak_SIMPLIFIE presents.

here = fileparts(mfilename('fullpath'));
addpath(here);
if nargin < 1 || isempty(dataDir)
    dataDir = fullfile(here, 'data');
end

% ======================================================================
%  TAILLES OPTIMALES HOMER — source unique
%  Lire dans : Results > Tables > ligne 1 de chaque scenario
% ======================================================================
scenarios = struct();

% --- Scenario A : Industriel (Basra, ~574 kW) ---
scenarios(1).name      = 'A_Industriel';
scenarios(1).label     = 'A — Industrial (Basra)';
scenarios(1).load_file = 'profil_A_industriel_8760h.csv';
scenarios(1).PV_kWp    = 819;    % HOMER optimal
scenarios(1).BESS_kWh  = 650;
scenarios(1).BESS_kW   = 599;    % = taille converter HOMER
scenarios(1).DG_kW     = 640;

% --- Scenario B : Rural (Nord Irak, ~50 kW) ---
scenarios(2).name      = 'B_Rural';
scenarios(2).label     = 'B — Rural (North Iraq)';
scenarios(2).load_file = 'profil_B_rural_8760h.csv';
scenarios(2).PV_kWp    = 24;
scenarios(2).BESS_kWh  = 52;
scenarios(2).BESS_kW   = 25;
scenarios(2).DG_kW     = 110;

% --- Scenario C : Affaires (Bagdad, ~200 kW) ---
scenarios(3).name      = 'C_Affaires';
scenarios(3).label     = 'C — Business (Baghdad)';
scenarios(3).load_file = 'profil_C_affaires_8760h.csv';
scenarios(3).PV_kWp    = 290;
scenarios(3).BESS_kWh  = 274;
scenarios(3).BESS_kW   = 219;
scenarios(3).DG_kW     = 270;

% --- Scenario D : Residentiel (Bagdad, ~100 kW) ---
scenarios(4).name      = 'D_Residentiel';
scenarios(4).label     = 'D — Residential (Baghdad)';
scenarios(4).load_file = 'profil_D_residentiel_8760h.csv';
scenarios(4).PV_kWp    = 198;
scenarios(4).BESS_kWh  = 196;
scenarios(4).BESS_kW   = 143;
scenarios(4).DG_kW     = 200;

% ======================================================================
%  BOUCLE DE SIMULATION
% ======================================================================
for s = 1:numel(scenarios)
    sc = scenarios(s);
    fprintf('\n========== %s ==========\n', sc.label);

    % 1) Charger les parametres de base
    P = irak_params();

    % 2) Injecter les tailles HOMER (LES SEULS CHAMPS QUI CHANGENT)
    P.PV.Pnom_kWp   = sc.PV_kWp;
    P.BESS.Enom_kWh = sc.BESS_kWh;
    P.BESS.Pmax_kW  = sc.BESS_kW;
    P.DG.Pmax_kW    = sc.DG_kW;

    % Adapter aussi Sbase et la puissance de reference du statisme
    % proportionnellement (les gains de frequence restent identiques)
    P.FREQ.Sbase_kW = max(sc.PV_kWp, sc.DG_kW);

    fprintf('  PV=%g kWp | BESS=%g kWh | DG=%g kW | Conv=%g kW\n', ...
            sc.PV_kWp, sc.BESS_kWh, sc.DG_kW, sc.BESS_kW);

    % 3) Remplacer le fichier de charge par celui du scenario
    %    -> on patche load_scenario_data via un argument de dataDir modifie
    %    En pratique : on reecrit la variable d'environnement via une
    %    fonction locale qui appelle load_scenario_data en remplacant le
    %    nom de fichier de charge.
    sc_dataDir = dataDir;  % on garde le meme dossier
    load_override = sc.load_file;  % nom du CSV a utiliser

    % 4) Simuler les 3 scenarios dynamiques
    fig_types = {'transition', 'journee', 'curtailment'};
    for f = 1:numel(fig_types)
        kind = fig_types{f};
        png  = fullfile(here, sprintf('Fig_%s_%s_%s.png', ...
               num2str(s), sc.name, kind));

        % Construire u(t) avec le bon fichier de charge
        [t, u, Ts, ~] = load_scenario_data_sc(kind, sc_dataDir, load_override);
        N = numel(t);

        % Etat initial
        st = struct('SoC', P.BESS.SoC_init, 'freq', P.FREQ.f0, ...
                    'fuel_L', 0.0, 'f_int', 0.0);

        % Simulation hors-ligne
        Y = zeros(N, 10);
        for k = 1:N
            [Y(k,:), st] = microgrid_step(u(k,:), Ts, st, P);
        end

        fprintf('  [%s] carburant=%.1f L | SoC final=%.0f%%\n', ...
                kind, st.fuel_L, st.SoC*100);

        % Tracer
        plot_microgrid(kind, t, Y, u, png);
    end
end

fprintf('\nTermine. Figures generees dans : %s\n', here);
end

% ======================================================================
%  Wrapper local : load_scenario_data avec fichier de charge parametrable
% ======================================================================
function [t, u, Ts, Tstop] = load_scenario_data_sc(kind, dataDir, load_file)
% Identique a load_scenario_data mais permet de specifier le fichier de
% charge (pour chaque scenario A/B/C/D).

doy = 173;  % jour de reference (~21 juin)

switch lower(kind)
    case 'transition'
        Ts = 1e-3; Tstop = 8.0;
        t  = (0:Ts:Tstop-Ts).';
        N  = numel(t);
        G     = 600.0 * ones(N,1);
        Tamb  = 42.0  * ones(N,1);
        Pload = 70.0  * ones(N,1);   % stimulus synthetique independant du scenario
        gon   = double(t < 1.0);
        dyn   = ones(N,1);

    case {'journee','curtailment'}
        Ts = 60.0; Tstop = 86400.0;
        [Gh, Th] = read_solar_day_local(dataDir, doy);
        Lh       = read_load_day_local(dataDir, load_file, doy);
        if strcmpi(kind,'journee')
            hs = 13; he = 20;
        else
            hs = 0;  he = 24;
        end
        t   = (0:Ts:Tstop-Ts).';
        hr  = min(floor(t/3600), 23);
        G     = Gh(hr+1);
        Tamb  = Th(hr+1);
        Pload = max(0.0, Lh(hr+1));
        gon   = double(~(hr >= hs & hr < he));
        dyn   = zeros(numel(t),1);

    otherwise
        error('Scenario inconnu : %s', kind);
end
u = [G, Tamb, Pload, gon, dyn];
end

function [Gh, Th] = read_solar_day_local(dataDir, doy)
csvSolar = fullfile(dataDir, 'solar', 'nasa_power_output', 'nasa_power_bagdad.csv');
T = readtable(csvSolar, 'TextType', 'string');
G = double(T{:, strcmp(T.Properties.VariableNames,'ghi_w_m2')});
A = double(T{:, strcmp(T.Properties.VariableNames,'temp_amb_c')});
h0 = (doy-1)*24;
Gh = G(h0+(1:24));
Th = A(h0+(1:24));
end

function Lh = read_load_day_local(dataDir, fname, doy)
csvLoad = fullfile(dataDir, 'load', 'profils_homer', fname);
L = readmatrix(csvLoad);
L = L(:,1);
h0 = (doy-1)*24;
Lh = L(h0+(1:24));
end
