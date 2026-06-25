function mdl = build_microgrid_irak_subsystems()
% BUILD_MICROGRID_IRAK_SUBSYSTEMS  Variante "vue par composants" du modele.
%   Construit par programme un modele Simulink organise en SOUS-SYSTEMES NOMMES,
%   plus lisible pour une figure d'annexe :
%
%       Entrees u --(Demux)--> [PV] --Ppv--> [EMS] --y--> journal + Demux
%                                     Pload/grid/dyn/ Ts ---^
%       y --(Demux)--> [BESS]  [Diesel]  [Reseau]   (affichage par composant)
%
%   IMPORTANT - memes resultats :
%     * [PV]  calcule la puissance PV disponible (pv_core -> pv_power).
%     * [EMS] fait toute la repartition + les etats SoC/diesel/frequence
%             (ems_core -> ems_step). L'etat reste DANS l'EMS : aucune boucle
%             de retour, aucun retard unitaire.
%     La composition (PV + EMS) reproduit EXACTEMENT microgrid_step (verifie :
%     ecart nul sur les 3 scenarios). Les sous-systemes BESS/Diesel/Reseau
%     exposent les grandeurs de chaque composant (oscilloscopes) ; ils ne
%     modifient pas le calcul.
%
%   Cette version est INDEPENDANTE de build_microgrid_irak.m (autre nom de
%   modele) : elle ne touche pas a ton modele qui fonctionne.
%
%   Variables de base lues (idem) : u_in (Nx6=[temps,u]), Ts_model, Tstop.

mdl  = 'microreseau_irak_sous_systemes';
here = fileparts(mfilename('fullpath'));

if bdIsLoaded(mdl), close_system(mdl, 0); end
slx = fullfile(here, [mdl '.slx']);
if exist(slx, 'file'), delete(slx); end

new_system(mdl);
load_system(mdl);

% ======================================================================
%  Sources au niveau superieur
% ======================================================================
add_block('simulink/Sources/From Workspace', [mdl '/Entrees_u']);
set_param([mdl '/Entrees_u'], 'VariableName','u_in', 'SampleTime','Ts_model', ...
    'Interpolate','off', 'OutputAfterFinalValue','Holding final value', ...
    'Position',[30 150 110 190]);

add_block('built-in/Demux', [mdl '/Demux_u']);
set_param([mdl '/Demux_u'], 'Outputs','5', 'Position',[150 145 155 195]);

add_block('simulink/Sources/Constant', [mdl '/Ts']);
set_param([mdl '/Ts'], 'Value','Ts_model', 'SampleTime','Ts_model', ...
    'Position',[30 300 110 330]);

% ======================================================================
%  Sous-systeme PV  (calcul : G,Tamb -> Ppv_dispo)
% ======================================================================
pv = [mdl '/PV'];
add_block('built-in/Subsystem', pv);  set_param(pv,'Position',[230 40 330 100]);
add_block('built-in/Inport',  [pv '/G']);          set_param([pv '/G'],'Port','1','Position',[20 30 50 44]);
add_block('built-in/Inport',  [pv '/Tamb']);       set_param([pv '/Tamb'],'Port','2','Position',[20 80 50 94]);
add_block('simulink/User-Defined Functions/MATLAB Function', [pv '/Calcul_PV']);
set_param([pv '/Calcul_PV'],'Position',[120 35 230 95]);
add_block('built-in/Outport', [pv '/Ppv_dispo']);  set_param([pv '/Ppv_dispo'],'Port','1','Position',[290 55 320 69]);
inject_fcn([pv '/Calcul_PV'], fullfile(here,'pv_core.m'));
add_line(pv, 'G/1',    'Calcul_PV/1', 'autorouting','on');
add_line(pv, 'Tamb/1', 'Calcul_PV/2', 'autorouting','on');
add_line(pv, 'Calcul_PV/1', 'Ppv_dispo/1', 'autorouting','on');

% ======================================================================
%  Sous-systeme EMS  (repartition + etats : -> y 1x10)
% ======================================================================
ems = [mdl '/EMS'];
add_block('built-in/Subsystem', ems);  set_param(ems,'Position',[420 150 560 270]);
add_block('built-in/Inport', [ems '/Ppv_dispo']); set_param([ems '/Ppv_dispo'],'Port','1','Position',[20 30 50 44]);
add_block('built-in/Inport', [ems '/Pload']);     set_param([ems '/Pload'],    'Port','2','Position',[20 70 50 84]);
add_block('built-in/Inport', [ems '/grid_on']);   set_param([ems '/grid_on'],  'Port','3','Position',[20 110 50 124]);
add_block('built-in/Inport', [ems '/dyn']);       set_param([ems '/dyn'],      'Port','4','Position',[20 150 50 164]);
add_block('built-in/Inport', [ems '/Ts']);        set_param([ems '/Ts'],       'Port','5','Position',[20 190 50 204]);
add_block('simulink/User-Defined Functions/MATLAB Function', [ems '/Gestion_EMS']);
set_param([ems '/Gestion_EMS'],'Position',[120 60 250 180]);
add_block('built-in/Outport', [ems '/y']);        set_param([ems '/y'],'Port','1','Position',[300 113 330 127]);
inject_fcn([ems '/Gestion_EMS'], fullfile(here,'ems_core.m'));
add_line(ems, 'Ppv_dispo/1','Gestion_EMS/1', 'autorouting','on');
add_line(ems, 'Pload/1',    'Gestion_EMS/2', 'autorouting','on');
add_line(ems, 'grid_on/1',  'Gestion_EMS/3', 'autorouting','on');
add_line(ems, 'dyn/1',      'Gestion_EMS/4', 'autorouting','on');
add_line(ems, 'Ts/1',       'Gestion_EMS/5', 'autorouting','on');
add_line(ems, 'Gestion_EMS/1','y/1', 'autorouting','on');

% ======================================================================
%  Demux de la sortie y (10 voies) + sous-systemes d'affichage
% ======================================================================
add_block('built-in/Demux', [mdl '/Demux_y']);
set_param([mdl '/Demux_y'], 'Outputs','10', 'Position',[600 150 605 320]);

add_presentation_subsystem(mdl, 'BESS',   'Pbatt',   'SoC',  [660 40 770 100]);
add_presentation_subsystem(mdl, 'Diesel', 'Pdiesel', 'Fuel', [660 140 770 200]);
add_presentation_subsystem(mdl, 'Reseau', 'Pgrid',   'Freq', [660 240 770 300]);

% ======================================================================
%  Journalisation + horloge
% ======================================================================
add_block('simulink/Sinks/To Workspace', [mdl '/Sorties_y']);
set_param([mdl '/Sorties_y'], 'VariableName','y_log', 'SaveFormat','Array', ...
    'SampleTime','-1', 'Position',[660 340 740 380]);

add_block('simulink/Sources/Clock', [mdl '/Horloge']);
set_param([mdl '/Horloge'], 'Position',[420 360 450 390]);

add_block('simulink/Sinks/To Workspace', [mdl '/Temps_t']);
set_param([mdl '/Temps_t'], 'VariableName','t_log', 'SaveFormat','Array', ...
    'SampleTime','-1', 'Position',[660 410 740 450]);

% ======================================================================
%  Connexions au niveau superieur
% ======================================================================
add_line(mdl, 'Entrees_u/1', 'Demux_u/1', 'autorouting','on');
add_line(mdl, 'Demux_u/1', 'PV/1', 'autorouting','on');     % G
add_line(mdl, 'Demux_u/2', 'PV/2', 'autorouting','on');     % Tamb
add_line(mdl, 'PV/1',      'EMS/1', 'autorouting','on');    % Ppv_dispo
add_line(mdl, 'Demux_u/3', 'EMS/2', 'autorouting','on');    % Pload
add_line(mdl, 'Demux_u/4', 'EMS/3', 'autorouting','on');    % grid_on
add_line(mdl, 'Demux_u/5', 'EMS/4', 'autorouting','on');    % dyn
add_line(mdl, 'Ts/1',      'EMS/5', 'autorouting','on');    % Ts

add_line(mdl, 'EMS/1', 'Sorties_y/1', 'autorouting','on');  % y -> journal
add_line(mdl, 'EMS/1', 'Demux_y/1',   'autorouting','on');  % y -> demux (branche)

% Routage des voies utiles vers les sous-systemes d'affichage
add_line(mdl, 'Demux_y/2', 'BESS/1',   'autorouting','on'); % Pbatt
add_line(mdl, 'Demux_y/3', 'BESS/2',   'autorouting','on'); % SoC
add_line(mdl, 'Demux_y/4', 'Diesel/1', 'autorouting','on'); % Pdiesel
add_line(mdl, 'Demux_y/8', 'Diesel/2', 'autorouting','on'); % Fuel
add_line(mdl, 'Demux_y/5', 'Reseau/1', 'autorouting','on'); % Pgrid
add_line(mdl, 'Demux_y/7', 'Reseau/2', 'autorouting','on'); % Freq

% Voies non affichees (1 Ppv, 6 Pcurtail, 9 Punmet, 10 Ppv_dispo) -> terminateurs
term_idx = [1 6 9 10];
for k = 1:numel(term_idx)
    tname = sprintf('%s/Fin_%d', mdl, term_idx(k));
    add_block('built-in/Terminator', tname);
    set_param(tname, 'Position', [640 (330+18*k) 660 (344+18*k)]);
    add_line(mdl, sprintf('Demux_y/%d', term_idx(k)), sprintf('Fin_%d/1', term_idx(k)), 'autorouting','on');
end

add_line(mdl, 'Horloge/1', 'Temps_t/1', 'autorouting','on');

% ======================================================================
%  Solveur (idem version compacte)
% ======================================================================
set_param(mdl, 'SolverType','Fixed-step', 'Solver','FixedStepDiscrete', ...
    'FixedStep','Ts_model', 'StopTime','Tstop', ...
    'SaveOutput','off', 'SaveTime','off', 'ReturnWorkspaceOutputs','on');

% Rangement automatique du schema (si disponible) pour une figure propre
try
    Simulink.BlockDiagram.arrangeSystem(mdl);
    Simulink.BlockDiagram.arrangeSystem([mdl '/PV']);
    Simulink.BlockDiagram.arrangeSystem([mdl '/EMS']);
catch
    % fonction indisponible sur cette version : disposition manuelle conservee
end

save_system(mdl, slx);
fprintf('Modele en sous-systemes construit : %s\n', slx);
end

% ======================================================================
%  Fonctions utilitaires
% ======================================================================
function inject_fcn(blockPath, mfile)
% Injecte le code d'un fichier .m dans un bloc MATLAB Function et le cadence
% sur le pas du modele (entoure de try/catch selon la version).
chart = sfroot().find('-isa','Stateflow.EMChart','Path',blockPath);
chart.Script = fileread(mfile);
try, chart.ChartUpdate = 'DISCRETE'; catch, end
try, chart.SampleTime  = 'Ts_model'; catch, end
end

function add_presentation_subsystem(mdl, name, lbl1, lbl2, pos)
% Cree un sous-systeme d'AFFICHAGE : 2 entrees -> Mux -> Scope.
%   Sert uniquement a regrouper et visualiser les grandeurs d'un composant ;
%   il ne modifie aucun calcul.
ss = [mdl '/' name];
add_block('built-in/Subsystem', ss);  set_param(ss,'Position',pos);
add_block('built-in/Inport', [ss '/' lbl1]); set_param([ss '/' lbl1],'Port','1','Position',[20 30 50 44]);
add_block('built-in/Inport', [ss '/' lbl2]); set_param([ss '/' lbl2],'Port','2','Position',[20 80 50 94]);
add_block('built-in/Mux', [ss '/Mux']);      set_param([ss '/Mux'],'Inputs','2','Position',[110 35 115 95]);
add_block('simulink/Sinks/Scope', [ss '/Scope']); set_param([ss '/Scope'],'Position',[170 45 210 85]);
add_line(ss, [lbl1 '/1'], 'Mux/1', 'autorouting','on');
add_line(ss, [lbl2 '/1'], 'Mux/2', 'autorouting','on');
add_line(ss, 'Mux/1', 'Scope/1', 'autorouting','on');
end
