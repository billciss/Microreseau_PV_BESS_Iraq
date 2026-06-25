function run_simulink(dataDir)
% RUN_SIMULINK  Construit le modele, simule les 3 scenarios et trace les figures.
%   Voie "Simulink" (la voie de demonstration). Pour des resultats immediats
%   sans Simulink, utiliser simulate_offline.m (voie rapide equivalente).
%
%   run_simulink              % dataDir par defaut (../Projet_Microreseau_Irak/...)
%   run_simulink(dataDir)     % indiquer le dossier 02_DONNEES_REELLES du projet
%
%   PREREQUIS : Simulink (de base ; aucune toolbox payante). Les fichiers .m de
%   ce dossier doivent rester ensemble (ils sont ajoutes au path ci-dessous).

here = fileparts(mfilename('fullpath'));
addpath(here);
if nargin < 1 || isempty(dataDir)
    dataDir = fullfile(here, 'data');     % donnees reelles integrees au dossier
end

% 1) Assembler le modele par programme.
mdl = build_microgrid_irak();
load_system(mdl);

% 2) Simuler chaque scenario et tracer.
scenarios = { ...
    'transition',  'Fig1_transition.png'; ...
    'journee',     'Fig2_journee.png'; ...
    'curtailment', 'Fig3_curtailment.png'};

for i = 1:size(scenarios,1)
    kind = scenarios{i,1};
    png  = fullfile(here, scenarios{i,2});

    % donnees du scenario (depuis les CSV reels)
    [t, u, Ts, Tstop] = load_scenario_data(kind, dataDir);

    % variables lues par le modele (base workspace)
    assignin('base', 'u_in',     [t, u]);     % From Workspace : [temps, 5 entrees]
    assignin('base', 'Ts_model', Ts);         % pas du solveur et du bloc
    assignin('base', 'Tstop',    Tstop);      % duree

    fprintf('\n--- Scenario "%s" : Ts=%g s, Tstop=%g s, %d pas ---\n', ...
            kind, Ts, Tstop, numel(t));

    % simulation
    simOut = sim(mdl);

    % recuperer les sorties (variable To Workspace empaquetee dans simOut)
    Y = fetch_var(simOut, 'y_log');
    % reconstruire le vecteur temps a partir du pas : strictement croissant,
    % de meme longueur que Y (evite toute dependance au log de temps Simulink).
    T = (0:size(Y,1)-1).' * Ts;

    % tracer (routine partagee avec la voie hors-ligne)
    plot_microgrid(kind, T, Y, u, png);
end

fprintf('\nTermine. 3 figures generees dans :\n  %s\n', here);
end

% ----------------------------------------------------------------------
function v = fetch_var(simOut, name)
% Recupere une variable enregistree depuis un objet SimulationOutput,
% quelle que soit la version de MATLAB.
v = [];
try
    v = simOut.get(name);
catch
    try
        v = simOut.(name);
    catch
        error('run_simulink:fetch', ...
            'Impossible de recuperer "%s" depuis la sortie de simulation.', name);
    end
end
end
