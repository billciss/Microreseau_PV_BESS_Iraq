function run_simulink_subsystems(dataDir)
% RUN_SIMULINK_SUBSYSTEMS  Construit le modele EN SOUS-SYSTEMES, simule les 3
%   scenarios et trace les figures. Variante "vue par composants" de run_simulink.
%   Resultats identiques a run_simulink / simulate_offline (verifie).
%
%   run_simulink_subsystems              % dataDir par defaut (data/ integre)
%   run_simulink_subsystems(dataDir)     % autre dossier 02_DONNEES_REELLES
%
%   Les figures sont nommees *_ss.png pour ne pas ecraser celles de run_simulink.

here = fileparts(mfilename('fullpath'));
addpath(here);
if nargin < 1 || isempty(dataDir)
    dataDir = fullfile(here, 'data');
end

mdl = build_microgrid_irak_subsystems();
load_system(mdl);

scenarios = { ...
    'transition',  'Fig1_transition_ss.png'; ...
    'journee',     'Fig2_journee_ss.png'; ...
    'curtailment', 'Fig3_curtailment_ss.png'};

for i = 1:size(scenarios,1)
    kind = scenarios{i,1};
    png  = fullfile(here, scenarios{i,2});

    [t, u, Ts, Tstop] = load_scenario_data(kind, dataDir);
    assignin('base', 'u_in',     [t, u]);
    assignin('base', 'Ts_model', Ts);
    assignin('base', 'Tstop',    Tstop);

    fprintf('\n--- [sous-systemes] "%s" : Ts=%g s, Tstop=%g s, %d pas ---\n', ...
            kind, Ts, Tstop, numel(t));

    simOut = sim(mdl);

    Y = fetch_var(simOut, 'y_log');
    T = (0:size(Y,1)-1).' * Ts;   % temps reconstruit du pas (robuste)

    plot_microgrid(kind, T, Y, u, png);
end

fprintf('\nTermine (sous-systemes). 3 figures *_ss.png generees dans :\n  %s\n', here);
end

% ----------------------------------------------------------------------
function v = fetch_var(simOut, name)
v = [];
try
    v = simOut.get(name);
catch
    try
        v = simOut.(name);
    catch
        error('run_simulink_subsystems:fetch', ...
            'Impossible de recuperer "%s" depuis la sortie de simulation.', name);
    end
end
end
