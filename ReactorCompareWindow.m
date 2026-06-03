classdef ReactorCompareWindow < matlab.apps.AppBase

    properties (GetAccess = public, SetAccess = private)
        UIFigure   matlab.ui.Figure
    end

    properties (Access = private)
        ConcAx    matlab.ui.control.UIAxes
        ConvAx    matlab.ui.control.UIAxes
        TSlider   matlab.ui.control.Slider
        qSlider   matlab.ui.control.Slider
        TValLbl   matlab.ui.control.Label
        qValLbl   matlab.ui.control.Label
        StatusLbl matlab.ui.control.Label
        BatchCaLine;  CSTRCaLine;  PFRCaLine
        BatchXaLine;  CSTRXaLine;  PFRXaLine
        BatchCaMark;  CSTRCaMark;  PFRCaMark
        BatchXaMark;  CSTRXaMark;  PFRXaMark
        BatchCaLbl  matlab.ui.control.Label
        BatchXaLbl  matlab.ui.control.Label
        CSTRCaLbl   matlab.ui.control.Label
        CSTRXaLbl   matlab.ui.control.Label
        PFRCaLbl    matlab.ui.control.Label
        PFRXaLbl    matlab.ui.control.Label
        P
    end

    properties (Constant, Access = private)
        AC_B = [0.55 0.22 0.75]
        AC_C = [0.15 0.40 0.88]
        AC_P = [0.10 0.58 0.48]
    end

    methods (Access = public)
        function app = ReactorCompareWindow(P)
            if nargin < 1 || isempty(P)
                P = ReactorCompareWindow.defaultParams();
            end
            app.P = P;
            createComponents(app);
            registerApp(app, app.UIFigure);
            if nargout == 0; clear app; end
        end

        function delete(app)
            if isvalid(app.UIFigure); delete(app.UIFigure); end
        end
    end

    methods (Static, Access = private)
        function P = defaultParams()
            P = rxKinetics.defaultParams();
        end
    end

    methods (Access = private)

        function [Ca_b, Ca_c, Ca_p] = computeAll(app, k_vec, tau)
            % Batch evaluated at t = tmax; CSTR and PFR at steady state.
            % PFR depends only on tau (= V/q), so pass V = Vr, q = Vr/tau.
            Ca_b = rxKinetics.caBatch(app.P, k_vec, app.P.tmax);
            Ca_c = rxKinetics.caCSTR(app.P, k_vec, tau);
            Ca_p = rxKinetics.caPFR(app.P, k_vec, app.P.Vr, app.P.Vr ./ tau);
        end

        function createComponents(app)
            BG  = [0.09 0.09 0.11];
            BP  = [0.13 0.13 0.18];
            HDR = [0.10 0.14 0.26];
            P   = app.P;
            AC_B = app.AC_B; AC_C = app.AC_C; AC_P = app.AC_P;

            app.UIFigure = uifigure('Name', 'Reactor Comparison', ...
                'Position', [120 60 1200 860], 'Color', BG);

            outer = uigridlayout(app.UIFigure, [5 1]);
            outer.RowHeight = {'fit', '1x', 'fit', 'fit', 'fit'};
            outer.ColumnWidth = {'1x'};
            outer.Padding = [0 0 0 0];
            outer.RowSpacing = 0;
            outer.BackgroundColor = BG;

            % ── Header ──────────────────────────────────────────────────────
            hg = uigridlayout(outer, [2 1]);
            hg.Layout.Row = 1; hg.Layout.Column = 1;
            hg.RowHeight = {'fit','fit'}; hg.ColumnWidth = {'1x'};
            hg.Padding = [0 14 0 10]; hg.RowSpacing = 4;
            hg.BackgroundColor = HDR;

            h1 = uilabel(hg, 'Text', 'REACTOR COMPARISON  —  Batch  |  CSTR  |  PFR', ...
                'FontSize', 20, 'FontWeight', 'bold', ...
                'FontColor', [0.95 0.95 0.97], 'HorizontalAlignment', 'center');
            h1.Layout.Row = 1; h1.Layout.Column = 1;

            ord_str = 'Second'; if P.order == 1; ord_str = 'First'; end
            h2 = uilabel(hg, 'Text', sprintf( ...
                '%s-Order Kinetics     |     Batch evaluated at t = %.0f min     |     CSTR & PFR at steady state, V = %.2g L', ...
                ord_str, P.tmax, P.Vr), ...
                'FontSize', 10, 'FontColor', [0.60 0.75 1.00], 'HorizontalAlignment', 'center');
            h2.Layout.Row = 2; h2.Layout.Column = 1;

            % ── Plots ───────────────────────────────────────────────────────
            pg = uigridlayout(outer, [1 2]);
            pg.Layout.Row = 2; pg.Layout.Column = 1;
            pg.RowHeight = {'1x'}; pg.ColumnWidth = {'1x','1x'};
            pg.Padding = [12 10 12 6]; pg.ColumnSpacing = 10;
            pg.BackgroundColor = BG;

            app.ConcAx = uiaxes(pg);
            app.ConcAx.Layout.Row = 1; app.ConcAx.Layout.Column = 1;
            rxWindowStyle.plotAx(app.ConcAx, 'Exit Concentration vs Temperature', ...
                'Temperature (K)', 'Ca,exit  (mol/L)');
            hold(app.ConcAx, 'on');
            app.BatchCaLine = plot(app.ConcAx, NaN, NaN, '-',  'Color', AC_B, 'LineWidth', 2.5);
            app.CSTRCaLine  = plot(app.ConcAx, NaN, NaN, '--', 'Color', AC_C, 'LineWidth', 2.5);
            app.PFRCaLine   = plot(app.ConcAx, NaN, NaN, '-',  'Color', AC_P, 'LineWidth', 2.5);
            app.BatchCaMark = plot(app.ConcAx, NaN, NaN, 'o', 'MarkerSize', 10, ...
                'MarkerFaceColor', AC_B, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.5);
            app.CSTRCaMark  = plot(app.ConcAx, NaN, NaN, 'o', 'MarkerSize', 10, ...
                'MarkerFaceColor', AC_C, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.5);
            app.PFRCaMark   = plot(app.ConcAx, NaN, NaN, 'o', 'MarkerSize', 10, ...
                'MarkerFaceColor', AC_P, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.5);
            lg1 = legend(app.ConcAx, [app.BatchCaLine, app.CSTRCaLine, app.PFRCaLine], ...
                {'Batch','CSTR','PFR'}, 'Location', 'northeast');
            lg1.TextColor = [0.75 0.75 0.80];
            lg1.Color     = [0.10 0.10 0.13];
            lg1.EdgeColor = [0.28 0.28 0.36];
            app.ConcAx.XLim = [P.Tmin P.Tmax]; app.ConcAx.YLim = [0 P.C0*1.06];
            app.ConcAx.XLimMode = 'manual'; app.ConcAx.YLimMode = 'manual';

            app.ConvAx = uiaxes(pg);
            app.ConvAx.Layout.Row = 1; app.ConvAx.Layout.Column = 2;
            rxWindowStyle.plotAx(app.ConvAx, 'Conversion vs Temperature', ...
                'Temperature (K)', 'Xa,exit');
            hold(app.ConvAx, 'on');
            app.BatchXaLine = plot(app.ConvAx, NaN, NaN, '-',  'Color', AC_B, 'LineWidth', 2.5);
            app.CSTRXaLine  = plot(app.ConvAx, NaN, NaN, '--', 'Color', AC_C, 'LineWidth', 2.5);
            app.PFRXaLine   = plot(app.ConvAx, NaN, NaN, '-',  'Color', AC_P, 'LineWidth', 2.5);
            app.BatchXaMark = plot(app.ConvAx, NaN, NaN, 'o', 'MarkerSize', 10, ...
                'MarkerFaceColor', AC_B, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.5);
            app.CSTRXaMark  = plot(app.ConvAx, NaN, NaN, 'o', 'MarkerSize', 10, ...
                'MarkerFaceColor', AC_C, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.5);
            app.PFRXaMark   = plot(app.ConvAx, NaN, NaN, 'o', 'MarkerSize', 10, ...
                'MarkerFaceColor', AC_P, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.5);
            lg2 = legend(app.ConvAx, [app.BatchXaLine, app.CSTRXaLine, app.PFRXaLine], ...
                {'Batch','CSTR','PFR'}, 'Location', 'southeast');
            lg2.TextColor = [0.75 0.75 0.80];
            lg2.Color     = [0.10 0.10 0.13];
            lg2.EdgeColor = [0.28 0.28 0.36];
            app.ConvAx.XLim = [P.Tmin P.Tmax]; app.ConvAx.YLim = [0 1.05];
            app.ConvAx.XLimMode = 'manual'; app.ConvAx.YLimMode = 'manual';

            % ── Sliders ─────────────────────────────────────────────────────
            sg = uigridlayout(outer, [3 2]);
            sg.Layout.Row = 3; sg.Layout.Column = 1;
            sg.RowHeight = {'fit', 46, 'fit'};
            sg.ColumnWidth = {'1x', '1x'};
            sg.Padding = [24 10 24 6]; sg.RowSpacing = 4; sg.ColumnSpacing = 50;
            sg.BackgroundColor = BP;

            tl = uilabel(sg, 'Text', sprintf('Temperature  (%.0f – %.0f K)', P.Tmin, P.Tmax), ...
                'FontSize', 11, 'FontColor', [0.78 0.78 0.84]);
            tl.Layout.Row = 1; tl.Layout.Column = 1;
            ticks_T = round(linspace(P.Tmin, P.Tmax, 4));
            tlbls_T = arrayfun(@(t) sprintf('%.0f K',t), ticks_T, 'UniformOutput', false);
            app.TSlider = uislider(sg, 'Limits', [P.Tmin P.Tmax], 'Value', P.Tmin, ...
                'MajorTicks', ticks_T, 'MajorTickLabels', tlbls_T);
            app.TSlider.Layout.Row = 2; app.TSlider.Layout.Column = 1;
            app.TSlider.ValueChangingFcn = @(~,~) updatePlots(app);
            app.TSlider.ValueChangedFcn  = @(~,~) updatePlots(app);
            app.TValLbl = uilabel(sg, 'Text', sprintf('%.1f K', P.Tmin), ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'FontColor', [0.96 0.83 0.38], 'HorizontalAlignment', 'center');
            app.TValLbl.Layout.Row = 3; app.TValLbl.Layout.Column = 1;

            ql = uilabel(sg, 'Text', sprintf('Flow Rate  (%.2g – %.2g L/min)   [affects CSTR & PFR only]', ...
                P.qmin, P.qmax), 'FontSize', 11, 'FontColor', [0.78 0.78 0.84]);
            ql.Layout.Row = 1; ql.Layout.Column = 2;
            ticks_q = linspace(P.qmin, P.qmax, 4);
            tlbls_q = arrayfun(@(q) sprintf('%.3g',q), ticks_q, 'UniformOutput', false);
            q_init  = P.qmin;
            app.qSlider = uislider(sg, 'Limits', [P.qmin P.qmax], 'Value', q_init, ...
                'MajorTicks', ticks_q, 'MajorTickLabels', tlbls_q);
            app.qSlider.Layout.Row = 2; app.qSlider.Layout.Column = 2;
            app.qSlider.ValueChangingFcn = @(~,~) updatePlots(app);
            app.qSlider.ValueChangedFcn  = @(~,~) updatePlots(app);
            app.qValLbl = uilabel(sg, 'Text', sprintf('%.3f L/min', q_init), ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'FontColor', [0.96 0.83 0.38], 'HorizontalAlignment', 'center');
            app.qValLbl.Layout.Row = 3; app.qValLbl.Layout.Column = 2;

            % ── Results panel ────────────────────────────────────────────────
            rg = uigridlayout(outer, [1 3]);
            rg.Layout.Row = 4; rg.Layout.Column = 1;
            rg.RowHeight = {'fit'}; rg.ColumnWidth = {'1x','1x','1x'};
            rg.Padding = [12 6 12 6]; rg.ColumnSpacing = 10;
            rg.BackgroundColor = [0.09 0.09 0.14];

            [app.BatchCaLbl, app.BatchXaLbl] = buildResultCell(app, rg, 1, 'BATCH', AC_B);
            [app.CSTRCaLbl,  app.CSTRXaLbl]  = buildResultCell(app, rg, 2, 'CSTR',  AC_C);
            [app.PFRCaLbl,   app.PFRXaLbl]   = buildResultCell(app, rg, 3, 'PFR',   AC_P);

            % ── Status bar ───────────────────────────────────────────────────
            app.StatusLbl = uilabel(outer, ...
                'Text', 'Move sliders to explore reactor performance across temperature and flow rate', ...
                'FontSize', 10, 'FontColor', [0.45 0.45 0.52], ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', [0.06 0.06 0.08]);
            app.StatusLbl.Layout.Row = 5; app.StatusLbl.Layout.Column = 1;

            updatePlots(app);
        end

        function [caLbl, xaLbl] = buildResultCell(~, parent, col, name, accent)
            BG2 = [0.12 0.12 0.18];
            cg = uigridlayout(parent, [3 1]);
            cg.Layout.Row = 1; cg.Layout.Column = col;
            cg.RowHeight = {'fit','fit','fit'}; cg.ColumnWidth = {'1x'};
            cg.Padding = [12 8 12 8]; cg.RowSpacing = 4;
            cg.BackgroundColor = BG2;

            hl = uilabel(cg, 'Text', name, 'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', accent, 'HorizontalAlignment', 'center', ...
                'BackgroundColor', BG2);
            hl.Layout.Row = 1; hl.Layout.Column = 1;

            caLbl = uilabel(cg, 'Text', 'Ca = —', 'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', [0.96 0.83 0.38], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', BG2);
            caLbl.Layout.Row = 2; caLbl.Layout.Column = 1;

            xaLbl = uilabel(cg, 'Text', 'Xa = —', 'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', [0.96 0.83 0.38], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', BG2);
            xaLbl.Layout.Row = 3; xaLbl.Layout.Column = 1;
        end

        function updatePlots(app)
            T   = app.TSlider.Value;
            q   = app.qSlider.Value;
            tau = app.P.Vr / q;
            app.TValLbl.Text = sprintf('%.1f K', T);
            app.qValLbl.Text = sprintf('%.3f L/min', q);

            T_vec = linspace(app.P.Tmin, app.P.Tmax, 300);
            k_vec = rxKinetics.rateConstant(app.P, T_vec);
            [Ca_b, Ca_c, Ca_p] = computeAll(app, k_vec, tau);
            Xa_b = 1 - Ca_b / app.P.C0;
            Xa_c = 1 - Ca_c / app.P.C0;
            Xa_p = 1 - Ca_p / app.P.C0;

            app.BatchCaLine.XData = T_vec; app.BatchCaLine.YData = Ca_b;
            app.CSTRCaLine.XData  = T_vec; app.CSTRCaLine.YData  = Ca_c;
            app.PFRCaLine.XData   = T_vec; app.PFRCaLine.YData   = Ca_p;
            app.BatchXaLine.XData = T_vec; app.BatchXaLine.YData = Xa_b;
            app.CSTRXaLine.XData  = T_vec; app.CSTRXaLine.YData  = Xa_c;
            app.PFRXaLine.XData   = T_vec; app.PFRXaLine.YData   = Xa_p;

            k_T = rxKinetics.rateConstant(app.P, T);
            [Ca_bT, Ca_cT, Ca_pT] = computeAll(app, k_T, tau);
            Xa_bT = 1 - Ca_bT / app.P.C0;
            Xa_cT = 1 - Ca_cT / app.P.C0;
            Xa_pT = 1 - Ca_pT / app.P.C0;

            app.BatchCaMark.XData = T; app.BatchCaMark.YData = Ca_bT;
            app.CSTRCaMark.XData  = T; app.CSTRCaMark.YData  = Ca_cT;
            app.PFRCaMark.XData   = T; app.PFRCaMark.YData   = Ca_pT;
            app.BatchXaMark.XData = T; app.BatchXaMark.YData = Xa_bT;
            app.CSTRXaMark.XData  = T; app.CSTRXaMark.YData  = Xa_cT;
            app.PFRXaMark.XData   = T; app.PFRXaMark.YData   = Xa_pT;

            app.BatchCaLbl.Text = sprintf('Ca = %.4f mol/L', Ca_bT);
            app.BatchXaLbl.Text = sprintf('Xa = %.4f', Xa_bT);
            app.CSTRCaLbl.Text  = sprintf('Ca = %.4f mol/L', Ca_cT);
            app.CSTRXaLbl.Text  = sprintf('Xa = %.4f', Xa_cT);
            app.PFRCaLbl.Text   = sprintf('Ca = %.4f mol/L', Ca_pT);
            app.PFRXaLbl.Text   = sprintf('Xa = %.4f', Xa_pT);

            if Xa_pT > Xa_cT + 1e-4
                dXa = Xa_pT - Xa_cT;
                app.StatusLbl.Text = sprintf( ...
                    'T = %.0f K  |  q = %.3f L/min  |  tau = %.2f min  |  PFR outperforms CSTR by  dXa = %.4f  (%.1f%% higher conversion)', ...
                    T, q, tau, dXa, 100*dXa/max(Xa_cT, 1e-9));
            else
                app.StatusLbl.Text = sprintf( ...
                    'T = %.0f K  |  q = %.3f L/min  |  tau = %.2f min', T, q, tau);
            end
            drawnow limitrate;
        end

    end
end
