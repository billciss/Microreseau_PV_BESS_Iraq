function mdl = build_microgrid_irak(animate)
% BUILD_MICROGRID_IRAK  Construit par programme le modele Simulink du microreseau.
%   Assemble un modele DISCRET a pas fixe contenant un unique bloc
%   "MATLAB Function" (Microreseau) qui execute microgrid_core.m, alimente par
%   un bloc "From Workspace" (les entrees u) et un bloc "Constant" (le pas Ts).
%   Les sorties sont enregistrees via deux blocs "To Workspace" (y_log, t_log).
%
%   C'est la methode "assemblage par script" : on ne dessine rien a la main,
%   tout le .slx est genere par ce code (equivalent de la demarche de la video).
%
%   mdl = BUILD_MICROGRID_IRAK            % construction silencieuse
%   mdl = BUILD_MICROGRID_IRAK(true)      % ouvre le modele et le construit
%                                         % bloc par bloc (effet "live", on regarde)
%
%   PREREQUIS : irak_params.m, microgrid_step.m et microgrid_core.m doivent se
%   trouver dans le meme dossier (ajoute au path par run_simulink.m).
%
%   VARIABLES DE BASE LUES PAR LE MODELE (a definir AVANT sim) :
%     u_in     : matrice Nx6 = [temps, G, Tamb, Pload, grid_on, dyn]  (From Workspace)
%     Ts_model : pas de temps du solveur et du bloc (s)
%     Tstop    : duree de simulation (s)
%
%   Retour : mdl = nom du modele ('microreseau_irak').

if nargin < 1 || isempty(animate)
    animate = false;     % true = fenetre ouverte + pauses : on voit la construction
end

mdl  = 'microreseau_irak';
here = fileparts(mfilename('fullpath'));

% -- repartir d'un etat propre (fermer / supprimer un modele existant) --
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
slx = fullfile(here, [mdl '.slx']);
if exist(slx, 'file')
    delete(slx);
end

% -- creer le systeme --
new_system(mdl);
load_system(mdl);
if animate
    open_system(mdl);    % fenetre visible : les blocs apparaitront un a un
end

% ----------------------------------------------------------------------
%  Blocs
% ----------------------------------------------------------------------
% Entrees u (From Workspace) : sort un vecteur 1x5 a chaque pas.
add_block('simulink/Sources/From Workspace', [mdl '/Entrees_u']);
set_param([mdl '/Entrees_u'], ...
    'VariableName',         'u_in', ...
    'SampleTime',           'Ts_model', ...
    'Interpolate',          'off', ...          % maintien (ZOH), pas d'interpolation
    'OutputAfterFinalValue','Holding final value', ...
    'Position',             [40 40 120 80]);
pace(animate);

% Pas de temps Ts (Constant) -> 2e entree du bloc.
add_block('simulink/Sources/Constant', [mdl '/Ts']);
set_param([mdl '/Ts'], ...
    'Value',      'Ts_model', ...
    'SampleTime', 'Ts_model', ...
    'Position',   [40 130 120 160]);
pace(animate);

% Coeur de calcul (MATLAB Function) : execute microgrid_core.m.
add_block('simulink/User-Defined Functions/MATLAB Function', [mdl '/Microreseau']);
set_param([mdl '/Microreseau'], 'Position', [200 50 340 150]);
pace(animate);

% Injecter le code du bloc via l'API Stateflow (un bloc MATLAB Function est
% represente par un objet Stateflow.EMChart ; aucune licence Stateflow requise).
chart = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', [mdl '/Microreseau']);
chart.Script = fileread(fullfile(here, 'microgrid_core.m'));
% Rendre le bloc discret et cadence par Ts_model (entoure d'un try/catch car le
% nom exact des proprietes peut varier selon la version de MATLAB).
try
    chart.ChartUpdate = 'DISCRETE';
catch
    warning('build:ChartUpdate', ...
        'Impossible de forcer ChartUpdate=DISCRETE ; reglez le mode du bloc manuellement si besoin.');
end
try
    chart.SampleTime = 'Ts_model';
catch
    warning('build:SampleTime', ...
        'Impossible de forcer SampleTime=Ts_model sur le bloc ; il heritera du pas du modele.');
end
pace(animate);

% Sortie y (To Workspace) -> variable y_log (format tableau).
add_block('simulink/Sinks/To Workspace', [mdl '/Sorties_y']);
set_param([mdl '/Sorties_y'], ...
    'VariableName', 'y_log', ...
    'SaveFormat',   'Array', ...
    'SampleTime',   '-1', ...
    'Position',     [430 70 510 110]);
pace(animate);

% Horloge -> temps (To Workspace) -> variable t_log.
add_block('simulink/Sources/Clock', [mdl '/Horloge']);
set_param([mdl '/Horloge'], 'Position', [200 200 230 230]);
pace(animate);

add_block('simulink/Sinks/To Workspace', [mdl '/Temps_t']);
set_param([mdl '/Temps_t'], ...
    'VariableName', 't_log', ...
    'SaveFormat',   'Array', ...
    'SampleTime',   '-1', ...
    'Position',     [430 195 510 235]);
pace(animate);

% Oscilloscope (visualisation rapide, facultatif).
add_block('simulink/Sinks/Scope', [mdl '/Scope']);
set_param([mdl '/Scope'], 'Position', [430 300 510 340]);
pace(animate);

% ----------------------------------------------------------------------
%  Connexions
% ----------------------------------------------------------------------
add_line(mdl, 'Entrees_u/1', 'Microreseau/1', 'autorouting', 'on');   pace(animate);
add_line(mdl, 'Ts/1',        'Microreseau/2', 'autorouting', 'on');   pace(animate);
add_line(mdl, 'Microreseau/1', 'Sorties_y/1', 'autorouting', 'on');   pace(animate);
add_line(mdl, 'Microreseau/1', 'Scope/1',     'autorouting', 'on');   pace(animate);
add_line(mdl, 'Horloge/1',    'Temps_t/1',    'autorouting', 'on');   pace(animate);

% ----------------------------------------------------------------------
%  Solveur : discret, pas fixe (pilote par les variables de base)
% ----------------------------------------------------------------------
set_param(mdl, ...
    'SolverType',              'Fixed-step', ...
    'Solver',                  'FixedStepDiscrete', ...
    'FixedStep',               'Ts_model', ...
    'StopTime',                'Tstop', ...
    'SaveOutput',              'off', ...   % on utilise les blocs To Workspace
    'SaveTime',                'off', ...
    'ReturnWorkspaceOutputs',  'on');

% ----------------------------------------------------------------------
%  Enregistrer
% ----------------------------------------------------------------------
save_system(mdl, slx);
fprintf('Modele construit et enregistre : %s\n', slx);
end

% ======================================================================
function pace(animate)
% Petite pause pour rendre la construction visible (mode "live").
%   Sans effet quand animate = false.
if animate
    drawnow;
    pause(0.4);
end
end
