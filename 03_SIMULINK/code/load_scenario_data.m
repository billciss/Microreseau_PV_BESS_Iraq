function [t, u, Ts, Tstop] = load_scenario_data(kind, dataDir)
% LOAD_SCENARIO_DATA  Construit le signal d'entree u(t) d'un scenario.
%   A partir des donnees REELLES du projet (NASA POWER + profils HOMER), produit
%   le vecteur temps et la matrice d'entrees attendue par le modele.
%
%   [t, u, Ts, Tstop] = LOAD_SCENARIO_DATA(kind, dataDir)
%
%   kind    : 'transition' | 'journee' | 'curtailment'
%   dataDir : chemin du dossier 02_DONNEES_REELLES du projet.
%
%   Retour
%     t     : temps (Nx1, s)
%     u     : entrees (Nx5) = [G_Wm2, Tamb_C, Pload_kW, grid_on, dyn]
%     Ts    : pas de temps recommande pour ce scenario (s)
%     Tstop : duree recommandee (s)
%
%   Pour Simulink, run_simulink.m assemble la variable From Workspace u_in = [t u].
%   Pour la voie hors-ligne, simulate_offline.m parcourt les lignes de u.

if nargin < 2 || isempty(dataDir)
    here    = fileparts(mfilename('fullpath'));
    dataDir = fullfile(here, 'data');     % donnees reelles integrees au dossier
end

doy = 173;   % jour de l'annee de reference (~21 juin) : jour d'ete ensoleille a Bagdad

switch lower(kind)

    % ------------------------------------------------------------------
    case 'transition'
        % Transition reseau -> ilote (echelle ms). Donnees synthetiques :
        % ensoleillement et charge constants, le reseau tombe a t = 1 s.
        Ts    = 1e-3;
        Tstop = 8.0;
        t     = (0:Ts:Tstop-Ts).';
        N     = numel(t);
        G       = 600.0  * ones(N,1);          % W/m2 (apres-midi clair)
        Tamb    = 42.0   * ones(N,1);          % degC (ete Bagdad)
        Pload   = 70.0   * ones(N,1);          % kW (charge communautaire moderee)
        grid_on = double(t < 1.0);             % reseau present puis perdu a 1 s
        dyn     = ones(N,1);                   % couche dynamique (frequence) ACTIVE

    % ------------------------------------------------------------------
    case 'journee'
        % Journee type (24 h, pas 60 s) : profil RESIDENTIEL, coupure reseau
        % l'apres-midi (13 h -> 20 h) pour montrer batterie puis diesel.
        Ts    = 60.0;
        Tstop = 86400.0;
        [Gh, Th] = read_solar_day(dataDir, doy);
        Lh       = read_load_day(dataDir, 'profil_D_residentiel_8760h.csv', doy);
        island_start_h = 13;  island_end_h = 20;
        [t, G, Tamb, Pload, grid_on] = expand_day(Gh, Th, Lh, Ts, Tstop, ...
                                                  island_start_h, island_end_h);
        dyn = zeros(numel(t),1);               % regime energetique (bilan parfait)

    % ------------------------------------------------------------------
    case 'curtailment'
        % Ecretage solaire (24 h, pas 60 s) : profil RURAL (charge faible),
        % ilote toute la journee. La batterie se remplit puis le PV est ecrete.
        Ts    = 60.0;
        Tstop = 86400.0;
        [Gh, Th] = read_solar_day(dataDir, doy);
        Lh       = read_load_day(dataDir, 'profil_B_rural_8760h.csv', doy);
        [t, G, Tamb, Pload, grid_on] = expand_day(Gh, Th, Lh, Ts, Tstop, 0, 24);
        dyn = zeros(numel(t),1);

    otherwise
        error('load_scenario_data:kind', ...
            'Scenario inconnu "%s" (attendu : transition | journee | curtailment).', kind);
end

u = [G, Tamb, Pload, grid_on, dyn];
end

% ======================================================================
%  Fonctions utilitaires
% ======================================================================
function [Gh, Th] = read_solar_day(dataDir, doy)
% Lit 24 valeurs horaires (GHI, Tamb) pour le jour doy depuis NASA POWER.
csvSolar = fullfile(dataDir, 'solar', 'nasa_power_output', 'nasa_power_bagdad.csv');
T = readtable(csvSolar, 'TextType', 'string');
% acces par nom de colonne, avec repli sur la position si besoin
G = col_by_name(T, 'ghi_w_m2',   2);
A = col_by_name(T, 'temp_amb_c', 4);
h0 = (doy-1)*24;                       % decalage 0-based
idx = h0 + (1:24);                      % 24 heures de la journee (1-based)
Gh = G(idx);
Th = A(idx);
end

function Lh = read_load_day(dataDir, fname, doy)
% Lit 24 valeurs horaires de charge (kW) pour le jour doy (profil mono-colonne).
csvLoad = fullfile(dataDir, 'load', 'profils_homer', fname);
L = readmatrix(csvLoad);               % Nx1, sans en-tete
L = L(:,1);
h0 = (doy-1)*24;
idx = h0 + (1:24);
Lh = L(idx);
end

function v = col_by_name(T, name, pos)
% Renvoie la colonne 'name' de la table T, ou la colonne 'pos' en repli.
if any(strcmpi(T.Properties.VariableNames, name))
    v = T.(T.Properties.VariableNames{find(strcmpi(T.Properties.VariableNames,name),1)});
else
    v = T{:, pos};
end
v = double(v);
end

function [t, G, Tamb, Pload, grid_on] = expand_day(Gh, Th, Lh, Ts, Tstop, hs, he)
% Sur-echantillonne 24 valeurs horaires au pas Ts par maintien (ZOH) et
% construit le signal de presence reseau (0 pendant la fenetre [hs, he[).
t   = (0:Ts:Tstop-Ts).';
hr  = min(floor(t/3600), 23);          % indice d'heure 0..23
G       = Gh(hr+1);
Tamb    = Th(hr+1);
Pload   = max(0.0, Lh(hr+1));
grid_on = double(~(hr >= hs & hr < he));
end
