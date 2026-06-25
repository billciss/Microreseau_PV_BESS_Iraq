function simulate_offline(dataDir)
% SIMULATE_OFFLINE  Simule les 3 scenarios en MATLAB pur (SANS Simulink).
%   Voie RAPIDE et "a toute epreuve" : appelle exactement la meme logique que
%   le modele Simulink (microgrid_step.m), donc les figures sont identiques,
%   mais sans dependre de Simulink. A utiliser pour obtenir des resultats
%   immediatement, puis passer a run_simulink.m pour la version Simulink.
%
%   simulate_offline              % dataDir par defaut
%   simulate_offline(dataDir)     % dossier 02_DONNEES_REELLES du projet
%
%   PREREQUIS : MATLAB seul. Garder les .m de ce dossier ensemble.

here = fileparts(mfilename('fullpath'));
addpath(here);
if nargin < 1 || isempty(dataDir)
    dataDir = fullfile(here, 'data');     % donnees reelles integrees au dossier
end

P = irak_params();

scenarios = { ...
    'transition',  'Fig1_transition_offline.png'; ...
    'journee',     'Fig2_journee_offline.png'; ...
    'curtailment', 'Fig3_curtailment_offline.png'};

for i = 1:size(scenarios,1)
    kind = scenarios{i,1};
    png  = fullfile(here, scenarios{i,2});

    [t, u, Ts, ~] = load_scenario_data(kind, dataDir);
    N = numel(t);

    % etat initial (identique a microgrid_core.m)
    st = struct('SoC', P.BESS.SoC_init, 'freq', P.FREQ.f0, 'fuel_L', 0.0, 'f_int', 0.0);

    % boucle de simulation (meme fonction de pas que Simulink)
    Y = zeros(N, 10);
    for k = 1:N
        [yk, st] = microgrid_step(u(k,:), Ts, st, P);
        Y(k,:) = yk;
    end

    fprintf('\n--- [hors-ligne] "%s" : Ts=%g s, %d pas | carburant=%.1f L | SoC final=%.0f%% ---\n', ...
            kind, Ts, N, st.fuel_L, st.SoC*100);

    plot_microgrid(kind, t, Y, u, png);
end

fprintf('\nTermine (hors-ligne). 3 figures generees dans :\n  %s\n', here);
end
