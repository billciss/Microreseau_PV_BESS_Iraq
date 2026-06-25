function plot_microgrid(kind, t, Y, U, outPng)
% PLOT_MICROGRID  Trace l'une des trois figures cibles du projet.
%   Routine UNIQUE partagee par run_simulink.m (voie Simulink) et
%   simulate_offline.m (voie hors-ligne) : les deux voies produisent donc des
%   figures identiques.
%
%   kind   : 'transition' | 'journee' | 'curtailment'
%   t      : temps (s)
%   Y      : sorties Nx10 (voir microgrid_step.m)
%   U      : entrees Nx5 = [G, Tamb, Pload, grid_on, dyn]
%   outPng : chemin du PNG a enregistrer
%
%   Colonnes de Y :
%     1 Ppv | 2 Pbatt | 3 SoC% | 4 Pdiesel | 5 Pgrid | 6 Pcurtail
%     7 freq | 8 fuel_L | 9 Punmet | 10 Ppv_dispo

% -- aligner les longueurs (Simulink renvoie parfois un point de plus) --
n = min([numel(t), size(Y,1), size(U,1)]);
t = t(1:n); Y = Y(1:n,:); U = U(1:n,:);

Ppv   = Y(:,1);  Pbatt = Y(:,2);  SoC  = Y(:,3);  Pdg = Y(:,4);
Pcur  = Y(:,6);  freq  = Y(:,7);  Ppvd = Y(:,10);
Pload = U(:,3);  gon   = U(:,4);

% couleurs coherentes entre figures
c.pv = [0.90 0.65 0.00];  c.load = [0.15 0.15 0.15];  c.batt = [0.00 0.45 0.74];
c.dg = [0.75 0.20 0.20];  c.soc  = [0.20 0.55 0.20];  c.cur  = [0.55 0.30 0.65];

fig = figure('Color','w','Position',[100 100 1000 560]);

switch lower(kind)

    % ==================================================================
    case 'transition'
        th = t;   % en secondes (evenement a l'echelle de la seconde)

        ax1 = subplot(2,1,1);
        plot(th, freq, 'LineWidth', 1.8, 'Color', c.batt); hold on;
        yline(50, '--', 'Color', [0.5 0.5 0.5]);
        mark_grid_loss(ax1, th, gon);
        ylabel('Frequency (Hz)');
        title('Fig. 1 — Grid-Connected to Islanded Transition (Battery Grid-Forming Response)');
        grid on; safe_xlim(th);

        ax2 = subplot(2,1,2);
        plot(th, Ppv,  'LineWidth',1.6,'Color',c.pv);   hold on;
        plot(th, Pbatt,'LineWidth',1.6,'Color',c.batt);
        plot(th, Pdg,  'LineWidth',1.6,'Color',c.dg);
        plot(th, Pload,'LineWidth',1.4,'Color',c.load,'LineStyle','--');
        mark_grid_loss(ax2, th, gon);
        ylabel('Power (kW)'); xlabel('Time (s)');
        legend({'PV','Battery (>0 discharge)','Diesel','Load'}, ...
               'Location','best','Box','off');
        grid on; safe_xlim(th);

    % ==================================================================
    case 'journee'
        th = t/3600;   % en heures

        ax = axes(fig);
        shade_island(ax, th, gon);                 % zone d'ilotage
        yyaxis left;
        plot(th, Pload,'LineWidth',1.8,'Color',c.load); hold on;
        plot(th, Ppv,  'LineWidth',1.8,'Color',c.pv);
        plot(th, Pbatt,'LineWidth',1.6,'Color',c.batt);
        plot(th, Pdg,  'LineWidth',1.6,'Color',c.dg);
        ylabel('Power (kW)');
        ax.YColor = 'k';

        yyaxis right;
        plot(th, SoC,'LineWidth',2.0,'Color',c.soc,'LineStyle','-');
        ylabel('State of Charge SoC (%)');
        ylim([0 100]); ax.YColor = c.soc;

        xlabel('Hour of the day (h)');
        title('Fig. 2 — Daily Profile: PV, Load, Battery, Diesel and SoC (Afternoon Grid Outage)');
        legend({'Load','PV','Battery','Diesel','SoC'}, ...
               'Location','northwest','Box','off');
        grid on; xlim([0 24]); xticks(0:3:24);

    % ==================================================================
    case 'curtailment'
        th = t/3600;

        ax = axes(fig);
        % zone ecretee : entre PV disponible et PV injecte
        fill([th; flipud(th)], [Ppvd; flipud(Ppv)], c.cur, ...
             'FaceAlpha',0.20,'EdgeColor','none'); hold on;
        yyaxis left;
        plot(th, Ppvd, 'LineWidth',1.8,'Color',c.pv,'LineStyle','--');
        plot(th, Ppv,  'LineWidth',1.8,'Color',c.pv);
        plot(th, Pcur, 'LineWidth',1.6,'Color',c.cur);
        plot(th, Pload,'LineWidth',1.6,'Color',c.load);
        ylabel('Power (kW)'); ax.YColor = 'k';

        yyaxis right;
        plot(th, SoC,'LineWidth',2.0,'Color',c.soc);
        ylabel('State of Charge SoC (%)'); ylim([0 100]); ax.YColor = c.soc;

        xlabel('Hour of the day (h)');
        title('Fig. 3 — Solar Curtailment: Available vs. Injected PV (Battery at 90% SoC)');
        legend({'Curtailed zone','PV available','PV injected','Curtailment','Load','SoC'}, ...
               'Location','northwest','Box','off');
        grid on; xlim([0 24]); xticks(0:3:24);

    otherwise
        error('plot_microgrid:kind','Scenario inconnu : %s', kind);
end

% -- enregistrer --
try
    exportgraphics(fig, outPng, 'Resolution', 150);
catch
    print(fig, outPng, '-dpng', '-r150');     % repli pour anciennes versions
end
fprintf('Figure saved: %s\n', outPng);
end

% ======================================================================
function mark_grid_loss(ax, th, gon)
% Trace une ligne verticale a l'instant de perte du reseau (1 -> 0).
k = find(gon(1:end-1) > 0.5 & gon(2:end) < 0.5, 1);
if ~isempty(k)
    hold(ax,'on');
    xline(ax, th(k), '-', 'Grid loss', 'Color',[0.75 0.20 0.20], ...
          'LabelOrientation','horizontal','LineWidth',1.2);
end
end

function safe_xlim(tv)
% Fixe les bornes X uniquement si l'intervalle est valide (croissant et fini),
% pour ne jamais provoquer l'erreur "Limits must be increasing".
if numel(tv) >= 2
    lo = tv(1); hi = tv(end);
    if isfinite(lo) && isfinite(hi) && hi > lo
        xlim([lo hi]);
    end
end
end

function shade_island(ax, th, gon)
% Colore en gris clair la (les) fenetre(s) ou le reseau est absent.
hold(ax,'on');
isl = gon < 0.5;
d = diff([0; isl(:); 0]);
starts = find(d == 1);  ends = find(d == -1) - 1;
for i = 1:numel(starts)
    x1 = th(starts(i));  x2 = th(min(ends(i), numel(th)));
    patch(ax, [x1 x2 x2 x1], [-1e6 -1e6 1e6 1e6], [0.85 0.85 0.85], ...
          'FaceAlpha',0.45,'EdgeColor','none','HandleVisibility','off');
end
end
