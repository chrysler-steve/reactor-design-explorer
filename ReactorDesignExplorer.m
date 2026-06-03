classdef ReactorDesignExplorer < matlab.apps.AppBase

    properties (Access = private)
        UIFigure  matlab.ui.Figure
        BatchWin
        CSTRWin
        PFRWin
        CompareWin
        BatchOpenLbl
        CSTROpenLbl
        PFROpenLbl
        fC0     matlab.ui.control.NumericEditField
        fEa     matlab.ui.control.NumericEditField
        fA      matlab.ui.control.NumericEditField
        ddOrder matlab.ui.control.DropDown
        fVr     matlab.ui.control.NumericEditField
        ftmax   matlab.ui.control.NumericEditField
        fTmin   matlab.ui.control.NumericEditField
        fTmax   matlab.ui.control.NumericEditField
        fQmin   matlab.ui.control.NumericEditField
        fQmax   matlab.ui.control.NumericEditField
    end

    methods (Access = public)
        function app = ReactorDesignExplorer()
            app.BatchWin = [];  app.CSTRWin = [];  app.PFRWin = [];  app.CompareWin = [];
            createComponents(app);
            registerApp(app, app.UIFigure);
            if nargout == 0; clear app; end
        end

        function delete(app)
            if ~isempty(app.BatchWin) && isvalid(app.BatchWin); delete(app.BatchWin); end
            if ~isempty(app.CSTRWin)  && isvalid(app.CSTRWin);  delete(app.CSTRWin);  end
            if ~isempty(app.PFRWin)     && isvalid(app.PFRWin);     delete(app.PFRWin);     end
            if ~isempty(app.CompareWin) && isvalid(app.CompareWin); delete(app.CompareWin); end
            if isvalid(app.UIFigure);  delete(app.UIFigure);  end
        end
    end

    methods (Access = private)

        function createComponents(app)
            BG  = [0.09 0.09 0.11];
            HDR = [0.10 0.14 0.26];

            app.UIFigure = uifigure('Name', 'Reactor Design Explorer', ...
                'Position', [200 60 1060 920], 'Color', BG);

            outer = uigridlayout(app.UIFigure, [4 1]);
            outer.RowHeight = {'fit', 'fit', '1x', 'fit'};
            outer.ColumnWidth = {'1x'};
            outer.Padding = [0 0 0 0];
            outer.RowSpacing = 0;
            outer.BackgroundColor = BG;

            % ── Header ──────────────────────────────────────────────────────
            hg = uigridlayout(outer, [3 1]);
            hg.Layout.Row = 1;  hg.Layout.Column = 1;
            hg.RowHeight = {'fit', 'fit', 'fit'};
            hg.ColumnWidth = {'1x'};
            hg.Padding = [20 22 20 12];
            hg.RowSpacing = 6;
            hg.BackgroundColor = HDR;

            t1 = uilabel(hg, 'Text', 'REACTOR DESIGN EXPLORER', ...
                'FontSize', 26, 'FontWeight', 'bold', ...
                'FontColor', [0.95 0.95 0.97], 'HorizontalAlignment', 'center');
            t1.Layout.Row = 1;  t1.Layout.Column = 1;

            t2 = uilabel(hg, 'Text', 'A  +  B     →     C  +  D', ...
                'FontSize', 17, 'FontWeight', 'bold', ...
                'FontColor', [0.60 0.75 1.00], 'HorizontalAlignment', 'center');
            t2.Layout.Row = 2;  t2.Layout.Column = 1;

            t3 = uilabel(hg, 'Text', ...
                'Arrhenius Kinetics     ·     Configure the reaction system below, then select a reactor to launch', ...
                'FontSize', 11, 'FontColor', [0.48 0.55 0.72], 'HorizontalAlignment', 'center');
            t3.Layout.Row = 3;  t3.Layout.Column = 1;

            % ── Reaction Setup panel ─────────────────────────────────────────
            buildParamPanel(app, outer);

            % ── Reactor cards ────────────────────────────────────────────────
            cg = uigridlayout(outer, [2 3]);
            cg.Layout.Row = 3;  cg.Layout.Column = 1;
            cg.RowHeight = {'1x', 46};
            cg.ColumnWidth = {'1x', '1x', '1x'};
            cg.Padding = [28 22 28 10];
            cg.ColumnSpacing = 22;
            cg.BackgroundColor = BG;

            bSpecs = {'Closed system — no continuous flow';
                      'Concentration evolves over time';
                      'Ideal mixing assumed throughout';
                      'T range: user-defined in setup above'};
            cSpecs = {'Steady-state continuous operation';
                      'Perfect back-mixing inside tank';
                      'Exit concentration = tank concentration';
                      'T and q: user-defined in setup above'};
            pSpecs = {'Steady-state continuous operation';
                      'No axial dispersion (plug flow)';
                      'Shell-and-tube: 7-tube bundle';
                      'T and q: user-defined in setup above'};

            app.BatchOpenLbl = app.buildCard(cg, 1, 'BATCH REACTOR', 'Closed System', ...
                [0.55 0.22 0.75], bSpecs, @(~,~) app.launchBatch());
            app.CSTROpenLbl = app.buildCard(cg, 2, 'CSTR', 'Continuous Stirred Tank Reactor', ...
                [0.15 0.40 0.88], cSpecs, @(~,~) app.launchCSTR());
            app.PFROpenLbl = app.buildCard(cg, 3, 'PFR', 'Plug Flow Reactor  (Shell-and-Tube)', ...
                [0.10 0.58 0.48], pSpecs, @(~,~) app.launchPFR());

            cmpBtn = uibutton(cg, ...
                'Text', 'COMPARE ALL  —  Overlay Batch  |  CSTR  |  PFR on shared axes', ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', [0.78 0.84 1.00], 'BackgroundColor', [0.14 0.18 0.34], ...
                'ButtonPushedFcn', @(~,~) app.launchCompare());
            cmpBtn.Layout.Row = 2;  cmpBtn.Layout.Column = [1 3];

            % ── Footer ───────────────────────────────────────────────────────
            ftr = uilabel(outer, ...
                'Text', ['Tip: multiple reactor windows can be open simultaneously for side-by-side comparison     ' ...
                         '·     Changing setup fields after launch does not affect already-open windows'], ...
                'FontSize', 10, 'FontColor', [0.38 0.38 0.46], ...
                'HorizontalAlignment', 'center', 'BackgroundColor', [0.07 0.07 0.09]);
            ftr.Layout.Row = 4;  ftr.Layout.Column = 1;
        end

        % ── Reaction Setup panel ─────────────────────────────────────────────
        function buildParamPanel(app, outer)
            PANELBG = [0.10 0.12 0.20];
            FB = [0.06 0.06 0.09];
            LC = [0.60 0.62 0.74];
            UC = [0.42 0.43 0.54];
            VC = [0.96 0.83 0.38];
            HC = [0.80 0.85 1.00];

            pg = uigridlayout(outer, [2 1]);
            pg.Layout.Row = 2;  pg.Layout.Column = 1;
            pg.RowHeight = {'fit', 'fit'};
            pg.ColumnWidth = {'1x'};
            pg.Padding = [24 12 24 12];
            pg.RowSpacing = 8;
            pg.BackgroundColor = PANELBG;

            tl = uilabel(pg, 'Text', ...
                'REACTION SETUP  —  configure before launching', ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'FontColor', HC, 'HorizontalAlignment', 'center');
            tl.Layout.Row = 1;  tl.Layout.Column = 1;

            sg = uigridlayout(pg, [1 3]);
            sg.Layout.Row = 2;  sg.Layout.Column = 1;
            sg.RowHeight = {'1x'};
            sg.ColumnWidth = {'1x', '1x', '1x'};
            sg.ColumnSpacing = 28;
            sg.BackgroundColor = PANELBG;

            % Section 1: Kinetics
            k1 = uigridlayout(sg, [6 3]);
            k1.Layout.Row = 1;  k1.Layout.Column = 1;
            k1.RowHeight = {'fit', 28, 28, 28, 28, 4};
            k1.ColumnWidth = {62, '1x', 80};
            k1.Padding = [0 0 0 0];  k1.RowSpacing = 5;  k1.ColumnSpacing = 6;
            k1.BackgroundColor = PANELBG;

            h1 = uilabel(k1, 'Text', 'KINETICS', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', HC, 'HorizontalAlignment', 'center');
            h1.Layout.Row = 1;  h1.Layout.Column = [1 3];

            app.fC0  = addFR(app, k1, 2, 'C0',    0.1,    'mol/L',    FB, LC, VC, UC);
            app.fEa  = addFR(app, k1, 3, 'Ea',   43790,  'J/mol',    FB, LC, VC, UC);
            app.fA   = addFR(app, k1, 4, 'A',    1.11e8, 'L/mol/min',FB, LC, VC, UC);

            ol = uilabel(k1, 'Text', 'Order:', 'FontSize', 10, ...
                'FontColor', LC, 'HorizontalAlignment', 'right');
            ol.Layout.Row = 5;  ol.Layout.Column = 1;
            app.ddOrder = uidropdown(k1, 'Items', {'2nd order', '1st order'}, ...
                'ItemsData', {2, 1}, 'Value', 2, ...
                'FontSize', 11, 'FontColor', VC, 'BackgroundColor', FB);
            app.ddOrder.Layout.Row = 5;  app.ddOrder.Layout.Column = [2 3];

            % Section 2: Reactor geometry
            k2 = uigridlayout(sg, [4 3]);
            k2.Layout.Row = 1;  k2.Layout.Column = 2;
            k2.RowHeight = {'fit', 28, 28, 4};
            k2.ColumnWidth = {62, '1x', 45};
            k2.Padding = [0 0 0 0];  k2.RowSpacing = 5;  k2.ColumnSpacing = 6;
            k2.BackgroundColor = PANELBG;

            h2 = uilabel(k2, 'Text', 'REACTOR', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', HC, 'HorizontalAlignment', 'center');
            h2.Layout.Row = 1;  h2.Layout.Column = [1 3];

            app.fVr   = addFR(app, k2, 2, 'Vr',   1.0, 'L',   FB, LC, VC, UC);
            app.ftmax = addFR(app, k2, 3, 'tmax', 20,  'min', FB, LC, VC, UC);

            % Section 3: Operating ranges
            k3 = uigridlayout(sg, [6 3]);
            k3.Layout.Row = 1;  k3.Layout.Column = 3;
            k3.RowHeight = {'fit', 28, 28, 28, 28, 4};
            k3.ColumnWidth = {62, '1x', 55};
            k3.Padding = [0 0 0 0];  k3.RowSpacing = 5;  k3.ColumnSpacing = 6;
            k3.BackgroundColor = PANELBG;

            h3 = uilabel(k3, 'Text', 'OPERATING RANGES', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', HC, 'HorizontalAlignment', 'center');
            h3.Layout.Row = 1;  h3.Layout.Column = [1 3];

            app.fTmin = addFR(app, k3, 2, 'T min',  298,  'K',     FB, LC, VC, UC);
            app.fTmax = addFR(app, k3, 3, 'T max',  450,  'K',     FB, LC, VC, UC);
            app.fQmin = addFR(app, k3, 4, 'q min', 0.02, 'L/min', FB, LC, VC, UC);
            app.fQmax = addFR(app, k3, 5, 'q max', 0.50, 'L/min', FB, LC, VC, UC);

            % ── Input guards: reject non-physical values at entry ────────────
            posFields = [app.fC0, app.fA, app.fVr, app.ftmax, ...
                         app.fTmin, app.fTmax, app.fQmin, app.fQmax];
            for fld = posFields
                fld.Limits = [0 Inf];
                fld.LowerLimitInclusive = 'off';   % must be strictly > 0
            end
            app.fEa.Limits = [0 Inf];              % Ea = 0 allowed (k = A)
        end

        function fld = addFR(~, parent, row, lbl, val, unit, FB, LC, VC, UC)
            nl = uilabel(parent, 'Text', [lbl ':'], 'FontSize', 10, ...
                'FontColor', LC, 'HorizontalAlignment', 'right');
            nl.Layout.Row = row;  nl.Layout.Column = 1;
            fld = uieditfield(parent, 'numeric', 'Value', val, ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'FontColor', VC, 'BackgroundColor', FB, ...
                'HorizontalAlignment', 'center');
            fld.Layout.Row = row;  fld.Layout.Column = 2;
            ul = uilabel(parent, 'Text', unit, 'FontSize', 9, ...
                'FontColor', UC, 'HorizontalAlignment', 'left');
            ul.Layout.Row = row;  ul.Layout.Column = 3;
        end

        function P = collectParams(app)
            P.C0    = app.fC0.Value;
            P.Ea    = app.fEa.Value;
            P.A     = app.fA.Value;
            P.order = app.ddOrder.Value;
            P.Vr    = app.fVr.Value;
            P.tmax  = app.ftmax.Value;
            P.Tmin  = app.fTmin.Value;
            P.Tmax  = app.fTmax.Value;
            P.qmin  = app.fQmin.Value;
            P.qmax  = app.fQmax.Value;
            if P.Tmin >= P.Tmax; P.Tmin = P.Tmax - 10;  app.fTmin.Value = P.Tmin; end
            if P.qmin >= P.qmax; P.qmin = P.qmax * 0.1; app.fQmin.Value = P.qmin; end
        end

        function openLbl = buildCard(~, parent, col, name, typeLbl, accent, specs, cb)
            BC = [0.12 0.13 0.19];
            BD = [0.22 0.24 0.36];

            bw = uigridlayout(parent, [1 1]);
            bw.Layout.Row = 1;  bw.Layout.Column = col;
            bw.Padding = [2 2 2 2];
            bw.BackgroundColor = BD;

            cc = uigridlayout(bw, [4 1]);
            cc.Layout.Row = 1;  cc.Layout.Column = 1;
            cc.RowHeight = {52, 'fit', '1x', 58};
            cc.ColumnWidth = {'1x'};
            cc.Padding = [0 0 0 0];
            cc.RowSpacing = 0;
            cc.BackgroundColor = BC;

            badgeGrid = uigridlayout(cc, [1 2]);
            badgeGrid.Layout.Row = 1;  badgeGrid.Layout.Column = 1;
            badgeGrid.RowHeight = {'1x'};
            badgeGrid.ColumnWidth = {'1x', 70};
            badgeGrid.Padding = [0 0 0 0];  badgeGrid.ColumnSpacing = 0;
            badgeGrid.BackgroundColor = accent;

            badge = uilabel(badgeGrid, 'Text', typeLbl, ...
                'FontSize', 11, 'FontWeight', 'bold', 'FontColor', [1 1 1], ...
                'HorizontalAlignment', 'center', 'BackgroundColor', accent);
            badge.Layout.Row = 1;  badge.Layout.Column = 1;

            openLbl = uilabel(badgeGrid, 'Text', '● OPEN', ...
                'FontSize', 9, 'FontWeight', 'bold', ...
                'FontColor', [0.30 0.95 0.55], ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', accent, 'Visible', 'off');
            openLbl.Layout.Row = 1;  openLbl.Layout.Column = 2;

            nl = uilabel(cc, 'Text', name, ...
                'FontSize', 17, 'FontWeight', 'bold', ...
                'FontColor', [0.93 0.93 0.96], ...
                'HorizontalAlignment', 'center', 'BackgroundColor', BC);
            nl.Layout.Row = 2;  nl.Layout.Column = 1;

            sg = uigridlayout(cc, [numel(specs) 1]);
            sg.Layout.Row = 3;  sg.Layout.Column = 1;
            sg.RowHeight = repmat({'fit'}, 1, numel(specs));
            sg.ColumnWidth = {'1x'};
            sg.Padding = [20 10 20 8];
            sg.RowSpacing = 7;
            sg.BackgroundColor = BC;
            for i = 1:numel(specs)
                s = uilabel(sg, 'Text', ['  ·  ' specs{i}], ...
                    'FontSize', 11, 'FontColor', [0.55 0.56 0.64], ...
                    'BackgroundColor', BC);
                s.Layout.Row = i;  s.Layout.Column = 1;
            end

            btn = uibutton(cc, 'Text', 'LAUNCH', ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', accent, ...
                'ButtonPushedFcn', cb);
            btn.Layout.Row = 4;  btn.Layout.Column = 1;
        end

        % ── Launch / close handlers ──────────────────────────────────────────

        function launchBatch(app)
            if isempty(app.BatchWin) || ~isvalid(app.BatchWin)
                app.BatchWin = BatchReactorWindow(collectParams(app));
                app.BatchWin.UIFigure.CloseRequestFcn = @(~,~) app.onBatchClose();
                app.BatchOpenLbl.Visible = 'on';
            else
                figure(app.BatchWin.UIFigure);
            end
        end

        function launchCSTR(app)
            if isempty(app.CSTRWin) || ~isvalid(app.CSTRWin)
                app.CSTRWin = CSTRWindow(collectParams(app));
                app.CSTRWin.UIFigure.CloseRequestFcn = @(~,~) app.onCSTRClose();
                app.CSTROpenLbl.Visible = 'on';
            else
                figure(app.CSTRWin.UIFigure);
            end
        end

        function launchPFR(app)
            if isempty(app.PFRWin) || ~isvalid(app.PFRWin)
                app.PFRWin = PFRWindow(collectParams(app));
                app.PFRWin.UIFigure.CloseRequestFcn = @(~,~) app.onPFRClose();
                app.PFROpenLbl.Visible = 'on';
            else
                figure(app.PFRWin.UIFigure);
            end
        end

        function onBatchClose(app)
            if ~isempty(app.BatchWin) && isvalid(app.BatchWin); delete(app.BatchWin); end
            if isvalid(app.BatchOpenLbl); app.BatchOpenLbl.Visible = 'off'; end
        end

        function onCSTRClose(app)
            if ~isempty(app.CSTRWin) && isvalid(app.CSTRWin); delete(app.CSTRWin); end
            if isvalid(app.CSTROpenLbl); app.CSTROpenLbl.Visible = 'off'; end
        end

        function onPFRClose(app)
            if ~isempty(app.PFRWin) && isvalid(app.PFRWin); delete(app.PFRWin); end
            if isvalid(app.PFROpenLbl); app.PFROpenLbl.Visible = 'off'; end
        end

        function launchCompare(app)
            if isempty(app.CompareWin) || ~isvalid(app.CompareWin)
                app.CompareWin = ReactorCompareWindow(collectParams(app));
                app.CompareWin.UIFigure.CloseRequestFcn = @(~,~) app.onCompareClose();
            else
                figure(app.CompareWin.UIFigure);
            end
        end

        function onCompareClose(app)
            if ~isempty(app.CompareWin) && isvalid(app.CompareWin); delete(app.CompareWin); end
        end

    end
end
