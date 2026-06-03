classdef rxWindowStyle
    % rxWindowStyle  Static styling helpers shared by all reactor windows.

    methods (Static)

        % ── Axes ─────────────────────────────────────────────────────────────

        function animAx(ax, ttl, accent)
            titleColor = min(accent * 0.45 + [0.52 0.52 0.52], [1 1 1]);
            ax.Color     = [0.07 0.07 0.09];
            ax.XColor    = [0.35 0.35 0.40];
            ax.YColor    = ax.XColor;   ax.ZColor = ax.XColor;
            ax.GridColor = [0.26 0.26 0.32];  ax.GridAlpha = 0.35;
            ax.XGrid = 'on';  ax.YGrid = 'on';  ax.ZGrid = 'on';
            ax.Box   = 'on';
            ax.XTickLabel = {};  ax.YTickLabel = {};  ax.ZTickLabel = {};
            view(ax, 30, 22);
            title(ax, ttl, 'Color', titleColor, 'FontSize', 12, 'FontWeight', 'bold');
        end

        function plotAx(ax, ttl, xl, yl)
            ax.Color          = [0.07 0.07 0.09];
            ax.XColor         = [0.50 0.50 0.56];
            ax.YColor         = ax.XColor;
            ax.GridColor      = [0.28 0.28 0.34];  ax.GridAlpha      = 0.40;
            ax.MinorGridColor = [0.20 0.20 0.26];  ax.MinorGridAlpha = 0.25;
            ax.XGrid = 'on';  ax.YGrid = 'on';
            ax.XMinorGrid = 'on';  ax.YMinorGrid = 'on';
            ax.Box = 'on';  ax.FontSize = 10;
            title(ax,  ttl, 'Color', [0.90 0.90 0.92], 'FontSize', 11, 'FontWeight', 'bold');
            xlabel(ax, xl,  'Color', [0.64 0.64 0.70], 'FontSize', 10);
            ylabel(ax, yl,  'Color', [0.64 0.64 0.70], 'FontSize', 10);
        end

        % ── Colour ────────────────────────────────────────────────────────────

        function c = convColor(Xa)
            % convColor  Liquid colour for a conversion Xa in [0,1]:
            %   blue (unreacted) blends to amber (fully converted).
            c = (1 - Xa) * [0.15 0.40 0.88] + Xa * [0.65 0.50 0.28];
        end

        % ── Controls panel helpers ────────────────────────────────────────────

        function secHdr(parent, row, txt, accent)
            l = uilabel(parent, 'Text', txt, ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'FontColor', accent, 'HorizontalAlignment', 'center');
            l.Layout.Row = row;  l.Layout.Column = [1 2];
        end

        function [runBtn, resetBtn] = btnRow(parent, row, accent)
            runBtn = uibutton(parent, 'Text', 'RUN', ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', accent);
            runBtn.Layout.Row = row;  runBtn.Layout.Column = 1;

            resetBtn = uibutton(parent, 'Text', 'RESET', ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', [0.75 0.75 0.80], ...
                'BackgroundColor', [0.18 0.18 0.24]);
            resetBtn.Layout.Row = row;  resetBtn.Layout.Column = 2;
        end

        function lbl = valLbl(parent, row, txt)
            lbl = uilabel(parent, 'Text', txt, ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'FontColor', [0.96 0.83 0.38], 'HorizontalAlignment', 'center');
            lbl.Layout.Row = row;  lbl.Layout.Column = [1 2];
        end

        function vl = outRow(parent, row, name, unit, BP)
            if isempty(unit); ns = [name ':'];
            else;             ns = sprintf('%s  (%s):', name, unit);
            end
            nl = uilabel(parent, 'Text', ns, 'FontSize', 11, ...
                'FontColor', [0.50 0.50 0.56], 'BackgroundColor', BP);
            nl.Layout.Row = row;  nl.Layout.Column = 1;
            vl = uilabel(parent, 'Text', '—', 'FontSize', 13, ...
                'FontWeight', 'bold', 'FontColor', [0.96 0.83 0.38], ...
                'HorizontalAlignment', 'right', 'BackgroundColor', BP);
            vl.Layout.Row = row;  vl.Layout.Column = 2;
        end

        % ── Status bar ────────────────────────────────────────────────────────

        function lbl = statusBar(parent, row, txt)
            lbl = uilabel(parent, 'Text', txt, ...
                'FontSize', 10, 'FontColor', [0.45 0.45 0.52], ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', [0.06 0.06 0.08]);
            lbl.Layout.Row = row;  lbl.Layout.Column = 1;
        end

    end
end
