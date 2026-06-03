classdef PFRWindow < matlab.apps.AppBase

    properties (GetAccess = public, SetAccess = private)
        UIFigure   matlab.ui.Figure
    end

    properties (Access = private)
        AnimAx    matlab.ui.control.UIAxes
        ConcAx    matlab.ui.control.UIAxes
        ConvAx    matlab.ui.control.UIAxes
        TSlider   matlab.ui.control.Slider
        TValLbl   matlab.ui.control.Label
        qSlider   matlab.ui.control.Slider
        qValLbl   matlab.ui.control.Label
        CaLbl     matlab.ui.control.Label
        XaLbl     matlab.ui.control.Label
        tauLbl    matlab.ui.control.Label
        kLbl      matlab.ui.control.Label
        CompLbl   matlab.ui.control.Label
        RunBtn    matlab.ui.control.Button
        ResetBtn  matlab.ui.control.Button
        StatusLbl matlab.ui.control.Label
        CaLine
        XaLine
        CaPreview
        XaPreview
        P
        StopFlag       = false
        IdleLoopActive = false
        IsAnimating    = false
        Anim3DState    = []
        Built3D        = false
    end

    properties (Constant, Access = private)
        ACCENT = [0.10 0.58 0.48]
    end

    methods (Access = public)
        function app = PFRWindow(P)
            if nargin < 1 || isempty(P)
                P = PFRWindow.defaultParams();
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

        % ── Ca formula (order-aware) ──────────────────────────────────────────
        function Ca = computeCa(app, k, V, q)
            Ca = rxKinetics.caPFR(app.P, k, V, q);
        end

        function s = kStr(app, k)
            if app.P.order == 1; s = sprintf('%.3g /min', k);
            else;                 s = sprintf('%.3g L/mol/min', k);
            end
        end

        function createComponents(app)
            BG=[0.09 0.09 0.11]; BP=[0.13 0.13 0.18]; AC=app.ACCENT;

            app.UIFigure=uifigure('Name','PFR — Shell-and-Tube', ...
                'Position',[360 40 1380 900],'Color',BG);

            outer=uigridlayout(app.UIFigure,[4 1]);
            outer.RowHeight={'fit','1x',260,'fit'};
            outer.ColumnWidth={'1x'};
            outer.Padding=[0 0 0 0]; outer.RowSpacing=0;
            outer.BackgroundColor=BG;

            % ── Header ──────────────────────────────────────────────────────
            hg=uigridlayout(outer,[2 1]);
            hg.Layout.Row=1; hg.Layout.Column=1;
            hg.RowHeight={'fit','fit'}; hg.ColumnWidth={'1x'};
            hg.Padding=[0 10 0 8]; hg.RowSpacing=4;
            hg.BackgroundColor=AC;

            h1=uilabel(hg,'Text','PFR  —  Plug Flow Reactor  (Shell-and-Tube, 7 Tubes)', ...
                'FontSize',17,'FontWeight','bold','FontColor',[1 1 1], ...
                'HorizontalAlignment','center');
            h1.Layout.Row=1; h1.Layout.Column=1;
            ord_str='Second'; if app.P.order==1; ord_str='First'; end
            h2=uilabel(hg,'Text', ...
                sprintf('A  +  B   →   C  +  D     |     %s-Order     |     k = %.3g exp(−Ea/RT)', ...
                    ord_str, app.P.A), ...
                'FontSize',10,'FontColor',[0.78 1.00 0.92],'HorizontalAlignment','center');
            h2.Layout.Row=2; h2.Layout.Column=1;

            % ── Animation + Controls ─────────────────────────────────────────
            mid=uigridlayout(outer,[1 2]);
            mid.Layout.Row=2; mid.Layout.Column=1;
            mid.RowHeight={'1x'}; mid.ColumnWidth={'1x',300};
            mid.Padding=[10 10 10 8]; mid.ColumnSpacing=8;
            mid.BackgroundColor=BG;

            app.AnimAx=uiaxes(mid);
            app.AnimAx.Layout.Row=1; app.AnimAx.Layout.Column=1;
            rxWindowStyle.animAx(app.AnimAx,'PFR — 3D Animation  (Shell-and-Tube, 7 Tubes)',AC);
            text(app.AnimAx,0.5,0.5,{'▶  Click  RUN  to begin'}, ...
                'Units','normalized','HorizontalAlignment','center', ...
                'VerticalAlignment','middle','Color',[0.32 0.32 0.40], ...
                'FontSize',15,'FontWeight','bold');

            bw=uigridlayout(mid,[1 1]);
            bw.Layout.Row=1; bw.Layout.Column=2;
            bw.Padding=[3 3 3 3]; bw.BackgroundColor=AC;

            cp=uigridlayout(bw,[17 2]);
            cp.Layout.Row=1; cp.Layout.Column=1;
            cp.RowHeight={'fit',32,'fit',46,'fit','fit',46,'fit','fit','fit','fit','fit','fit','fit','fit',8,'1x'};
            cp.ColumnWidth={'1x','1x'};
            cp.Padding=[10 12 10 8]; cp.RowSpacing=5;
            cp.BackgroundColor=BP;

            rxWindowStyle.secHdr(cp,1,'CONTROLS',AC);
            [app.RunBtn,app.ResetBtn]=rxWindowStyle.btnRow(cp,2,AC);
            app.RunBtn.ButtonPushedFcn  =@(~,~) runAnimation(app);
            app.ResetBtn.ButtonPushedFcn=@(~,~) resetAll(app);

            tl=uilabel(cp,'Text', ...
                sprintf('Temperature  (%.0f – %.0f K)', app.P.Tmin, app.P.Tmax), ...
                'FontSize',11,'FontColor',[0.78 0.78 0.84]);
            tl.Layout.Row=3; tl.Layout.Column=[1 2];
            ticks=round(linspace(app.P.Tmin,app.P.Tmax,4));
            tlbls=arrayfun(@(t) sprintf('%.0f K',t), ticks, 'UniformOutput',false);
            app.TSlider=uislider(cp,'Limits',[app.P.Tmin app.P.Tmax],'Value',app.P.Tmin, ...
                'MajorTicks',ticks,'MajorTickLabels',tlbls);
            app.TSlider.Layout.Row=4; app.TSlider.Layout.Column=[1 2];
            app.TSlider.ValueChangingFcn=@(~,~) onSliderDrag(app);
            app.TSlider.ValueChangedFcn =@(~,~) onSliderRelease(app);
            app.TValLbl=rxWindowStyle.valLbl(cp,5,sprintf('%.1f K',app.P.Tmin));

            ql=uilabel(cp,'Text', ...
                sprintf('Flow Rate  (%.2g – %.2g L/min)', app.P.qmin, app.P.qmax), ...
                'FontSize',11,'FontColor',[0.78 0.78 0.84]);
            ql.Layout.Row=6; ql.Layout.Column=[1 2];
            qticks=linspace(app.P.qmin,app.P.qmax,4);
            qtlbls=arrayfun(@(q) sprintf('%.3g',q), qticks, 'UniformOutput',false);
            app.qSlider=uislider(cp,'Limits',[app.P.qmin app.P.qmax],'Value',app.P.qmin, ...
                'MajorTicks',qticks,'MajorTickLabels',qtlbls);
            app.qSlider.Layout.Row=7; app.qSlider.Layout.Column=[1 2];
            app.qSlider.ValueChangingFcn=@(~,~) onSliderDrag(app);
            app.qSlider.ValueChangedFcn =@(~,~) onSliderRelease(app);
            app.qValLbl=rxWindowStyle.valLbl(cp,8,sprintf('%.3f L/min',app.P.qmin));

            rxWindowStyle.secHdr(cp,9,'RESULTS',AC);
            app.CaLbl =rxWindowStyle.outRow(cp,10,'Ca,exit','mol/L',BP);
            app.XaLbl =rxWindowStyle.outRow(cp,11,'Xa,exit','',BP);
            app.tauLbl=rxWindowStyle.outRow(cp,12,'tau','min',BP);
            app.kLbl  =rxWindowStyle.outRow(cp,13,'k','',BP);

            pl=uilabel(cp,'Text', ...
                sprintf('C₀=%.4g mol/L  |  Ea=%.0f J/mol  |  V=%.2g L  |  Order: %d', ...
                    app.P.C0, app.P.Ea, app.P.Vr, app.P.order), ...
                'FontSize',9,'FontColor',[0.38 0.38 0.46],'HorizontalAlignment','center');
            pl.Layout.Row=14; pl.Layout.Column=[1 2];

            app.CompLbl=uilabel(cp,'Text','—', ...
                'FontSize',9,'FontColor',[0.82 0.72 0.38],'HorizontalAlignment','center');
            app.CompLbl.Layout.Row=15; app.CompLbl.Layout.Column=[1 2];

            % ── Bottom plots ─────────────────────────────────────────────────
            bot=uigridlayout(outer,[1 2]);
            bot.Layout.Row=3; bot.Layout.Column=1;
            bot.RowHeight={'1x'}; bot.ColumnWidth={'1x','1x'};
            bot.Padding=[10 8 10 10]; bot.ColumnSpacing=8;
            bot.BackgroundColor=BG;

            PC=AC*0.45+[0.04 0.04 0.06];

            app.ConcAx=uiaxes(bot);
            app.ConcAx.Layout.Row=1; app.ConcAx.Layout.Column=1;
            rxWindowStyle.plotAx(app.ConcAx,'Concentration Profile along PFR', ...
                'Reactor Volume (L)','Concentration  (mol/L)');
            hold(app.ConcAx,'on');
            app.CaPreview=plot(app.ConcAx,NaN,NaN,'--','Color',PC,'LineWidth',1.0);
            app.CaLine   =plot(app.ConcAx,NaN,NaN,'-', 'Color',AC,'LineWidth',2.5);
            app.ConcAx.XLim=[0 app.P.Vr];
            app.ConcAx.YLim=[0 app.P.C0*1.06];
            app.ConcAx.XLimMode='manual'; app.ConcAx.YLimMode='manual';

            app.ConvAx=uiaxes(bot);
            app.ConvAx.Layout.Row=1; app.ConvAx.Layout.Column=2;
            rxWindowStyle.plotAx(app.ConvAx,'Conversion Profile along PFR', ...
                'Reactor Volume (L)','Conversion  Xa');
            hold(app.ConvAx,'on');
            app.XaPreview=plot(app.ConvAx,NaN,NaN,'--','Color',PC,'LineWidth',1.0);
            app.XaLine   =plot(app.ConvAx,NaN,NaN,'-', 'Color',AC,'LineWidth',2.5);
            app.ConvAx.XLim=[0 app.P.Vr]; app.ConvAx.YLim=[0 1.05];
            app.ConvAx.XLimMode='manual'; app.ConvAx.YLimMode='manual';

            app.StatusLbl=rxWindowStyle.statusBar(outer,4, ...
                'Ready  —  set conditions and click RUN');

            onSliderRelease(app);
        end

        function onSliderDrag(app)
            app.TValLbl.Text=sprintf('%.1f K',app.TSlider.Value);
            app.qValLbl.Text=sprintf('%.3f L/min',app.qSlider.Value);
        end

        function onSliderRelease(app)
            if app.IdleLoopActive; return; end
            T=app.TSlider.Value; q=app.qSlider.Value;
            app.TValLbl.Text=sprintf('%.1f K',T);
            app.qValLbl.Text=sprintf('%.3f L/min',q);

            V_r=app.P.Vr; k=app.P.A*exp(-app.P.Ea/(8.314*T)); tau=V_r/q;
            V_p=linspace(0,V_r,200);
            Ca_new=computeCa(app,k,V_p,q);
            Xa_new=1-Ca_new/app.P.C0;

            Ca_old=app.CaPreview.YData; Xa_old=app.XaPreview.YData;
            if numel(Ca_old)~=numel(Ca_new)||any(isnan(Ca_old(:)))
                Ca_old=Ca_new; Xa_old=Xa_new;
            end

            if ~app.IsAnimating && ~isequal(Ca_old,Ca_new)
                app.IsAnimating=true;
                app.CaPreview.XData=V_p; app.XaPreview.XData=V_p;
                for f=1:15
                    if ~isvalid(app.UIFigure); break; end
                    al=f/15;
                    app.CaPreview.YData=(1-al)*Ca_old+al*Ca_new;
                    app.XaPreview.YData=(1-al)*Xa_old+al*Xa_new;
                    drawnow limitrate; pause(0.015);
                end
                app.IsAnimating=false;
            end
            app.CaPreview.XData=V_p; app.CaPreview.YData=Ca_new;
            app.XaPreview.XData=V_p; app.XaPreview.YData=Xa_new;

            updateComp(app,k,tau,q);
        end

        function updateComp(app, k, tau, q)
            C0=app.P.C0; V=app.P.Vr;
            Ca_pfr=computeCa(app,k,V,q);    Xa_pfr=1-Ca_pfr/C0;
            Ca_cstr=rxKinetics.caCSTR(app.P,k,tau);
            Xa_cstr=1-Ca_cstr/C0;
            app.CompLbl.Text=sprintf( ...
                'T=%.0fK, q=%.3f:  PFR Xa=%.3f  |  CSTR Xa=%.3f  (PFR +%.3f)', ...
                app.TSlider.Value, q, Xa_pfr, Xa_cstr, Xa_pfr-Xa_cstr);
        end

        function C=pfrCdata(~,Xa,N_th,N_x)
            C=zeros(N_th,N_x,3);
            for ix=1:N_x
                nc=rxWindowStyle.convColor(Xa(ix));
                C(:,ix,1)=nc(1); C(:,ix,2)=nc(2); C(:,ix,3)=nc(3);
            end
        end

        function build3D(app)
            rngState=rng;   % preserve the caller's global RNG stream
            ax=app.AnimAx;
            delete(findobj(ax,'Type','text'));

            set(ax,'XColor','none','YColor','none','ZColor','none');
            set(ax,'XGrid','off','YGrid','off','ZGrid','off','Box','off');
            view(ax,30,22);
            set(ax,'PlotBoxAspectRatio',[3.0 1 1.1]);
            set(ax,'CameraTarget',[0 0 0]);
            hold(ax,'on');

            l1=camlight(ax,'right'); set(l1,'Color',[1.00 0.97 0.90]);
            l2=camlight(ax,'left');  set(l2,'Color',[0.50 0.62 0.82]);
            lighting(ax,'gouraud');
            camzoom(ax,1.35);

            A_k=app.P.A; Ea=app.P.Ea; Rg=8.314; C0=app.P.C0;
            V_total=app.P.Vr*10;    % 3D model scaled for visual gradient
            R_shell=0.22; L_h=2.0; h_hdr=0.18; r_noz=0.060; l_noz=0.20;
            n_tubes=7; r_tube=0.035; r_pitch=0.095;
            hex_ang=(0:5)*pi/3;
            tube_cy=[0, r_pitch*cos(hex_ang)];
            tube_cz=[0, r_pitch*sin(hex_ang)];

            N_th=40; N_x=61;
            th=linspace(0,2*pi,N_th);
            x_pos=linspace(-L_h/2,L_h/2,N_x);
            V_at_x=linspace(0,V_total,N_x);

            T_i=app.P.Tmin; q_i=app.P.qmin;
            k_i=A_k*exp(-Ea/(Rg*T_i));
            Ca_i=computeCa(app,k_i,V_at_x,q_i);
            Xa_i=1-Ca_i/C0;

            [Xp,Th]=meshgrid(x_pos,th);
            Yt_b=r_tube*cos(Th); Zt_b=r_tube*sin(Th);
            rd_d=linspace(0,R_shell,30); [Rd_d,Th_d]=meshgrid(rd_d,th);
            th_n=linspace(0,2*pi,24);
            rd_f=linspace(r_noz,r_noz+0.030,6); [Rd_f,Th_f]=meshgrid(rd_f,th_n);

            surf(ax,Xp,R_shell*cos(Th),R_shell*sin(Th), ...
                'FaceColor',[0.54 0.60 0.68],'EdgeColor','none','FaceAlpha',0.13, ...
                'SpecularStrength',0.92,'DiffuseStrength',0.28);
            for xr=[-L_h/2,L_h/2]
                [Th_r,Xr]=meshgrid(th,[xr-0.017,xr+0.017]);
                surf(ax,Xr,(R_shell+0.012)*cos(Th_r),(R_shell+0.012)*sin(Th_r), ...
                    'FaceColor',[0.40 0.44 0.51],'EdgeColor','none','SpecularStrength',0.80);
            end

            x_in=-L_h/2-h_hdr; x_out=L_h/2+h_hdr;
            [Th_h,X_h]=meshgrid(th,[x_in,-L_h/2]);
            surf(ax,X_h,R_shell*cos(Th_h),R_shell*sin(Th_h), ...
                'FaceColor',[0.42 0.47 0.54],'EdgeColor','none','FaceAlpha',0.92, ...
                'SpecularStrength',0.78,'DiffuseStrength',0.55);
            surf(ax,ones(size(Rd_d))*x_in,Rd_d.*cos(Th_d),Rd_d.*sin(Th_d), ...
                'FaceColor',[0.36 0.40 0.47],'EdgeColor','none','SpecularStrength',0.65);
            [Th_h2,X_h2]=meshgrid(th,[L_h/2,x_out]);
            surf(ax,X_h2,R_shell*cos(Th_h2),R_shell*sin(Th_h2), ...
                'FaceColor',[0.42 0.47 0.54],'EdgeColor','none','FaceAlpha',0.92, ...
                'SpecularStrength',0.78,'DiffuseStrength',0.55);
            surf(ax,ones(size(Rd_d))*x_out,Rd_d.*cos(Th_d),Rd_d.*sin(Th_d), ...
                'FaceColor',[0.36 0.40 0.47],'EdgeColor','none','SpecularStrength',0.65);
            for xts=[-L_h/2,L_h/2]
                surf(ax,ones(size(Rd_d))*xts,Rd_d.*cos(Th_d),Rd_d.*sin(Th_d), ...
                    'FaceColor',[0.30 0.33 0.39],'EdgeColor','none','SpecularStrength',0.58);
            end

            [Th_n,X_n]=meshgrid(th_n,[x_in-l_noz,x_in]);
            surf(ax,X_n,r_noz*cos(Th_n),r_noz*sin(Th_n), ...
                'FaceColor',[0.40 0.45 0.52],'EdgeColor','none','SpecularStrength',0.82);
            surf(ax,ones(size(Rd_f))*(x_in-l_noz),Rd_f.*cos(Th_f),Rd_f.*sin(Th_f), ...
                'FaceColor',[0.36 0.40 0.47],'EdgeColor','none','SpecularStrength',0.72);
            [Th_no,X_no]=meshgrid(th_n,[x_out,x_out+l_noz]);
            surf(ax,X_no,r_noz*cos(Th_no),r_noz*sin(Th_no), ...
                'FaceColor',[0.40 0.45 0.52],'EdgeColor','none','SpecularStrength',0.82);
            surf(ax,ones(size(Rd_f))*(x_out+l_noz),Rd_f.*cos(Th_f),Rd_f.*sin(Th_f), ...
                'FaceColor',[0.36 0.40 0.47],'EdgeColor','none','SpecularStrength',0.72);

            C_i=pfrCdata(app,Xa_i,N_th,N_x);
            h_tubes=gobjects(1,n_tubes);
            for t=1:n_tubes
                h_tubes(t)=surf(ax,Xp,tube_cy(t)+Yt_b,tube_cz(t)+Zt_b,C_i, ...
                    'EdgeColor','none','FaceColor','interp','FaceAlpha',0.92, ...
                    'SpecularStrength',0.50,'DiffuseStrength',0.75);
            end

            for xl=[-0.55,0.55]
                r_leg=0.030; [Th_l,Zl]=meshgrid(th,[-R_shell,-R_shell-0.32]);
                surf(ax,xl+r_leg*cos(Th_l),r_leg*sin(Th_l),Zl, ...
                    'FaceColor',[0.34 0.38 0.45],'EdgeColor','none','SpecularStrength',0.65);
                rd_b=linspace(0,r_leg*2.6,6); [Rb,Thb]=meshgrid(rd_b,th);
                surf(ax,xl+Rb.*cos(Thb),Rb.*sin(Thb),ones(size(Rb))*(-R_shell-0.32), ...
                    'FaceColor',[0.28 0.32 0.38],'EdgeColor','none');
            end

            N_ppT=4; N_part=n_tubes*N_ppT; rng(42);
            p_x=zeros(1,N_part); p_y=zeros(1,N_part); p_z=zeros(1,N_part);
            for t=1:n_tubes
                idx=(t-1)*N_ppT+(1:N_ppT);
                x_off=(t-1)*(L_h/n_tubes);
                p_x(idx)=mod(linspace(0,L_h*(N_ppT-1)/N_ppT,N_ppT)+x_off,L_h)-L_h/2;
                ang_p=2*pi*rand(1,N_ppT); r_p=r_tube*0.56*rand(1,N_ppT);
                p_y(idx)=tube_cy(t)+r_p.*cos(ang_p);
                p_z(idx)=tube_cz(t)+r_p.*sin(ang_p);
            end
            Xa_p0=max(0,min(1,interp1(x_pos,Xa_i,p_x,'linear','extrap')));
            nc_p0=min(1,((1-Xa_p0(:))*[0.15 0.40 0.88]+Xa_p0(:)*[0.65 0.50 0.28])*1.85+0.06);
            h_part=scatter3(ax,p_x,p_y,p_z,50,nc_p0,'filled','MarkerFaceAlpha',0.95);

            N_ext=9; rng(11);
            x_ein_min=x_in-l_noz-0.24; x_ein_max=x_in-l_noz-0.02;
            p_ein_x=linspace(x_ein_min,x_ein_max,N_ext);
            r_ei=r_noz*0.55*rand(1,N_ext); ang_ei=2*pi*rand(1,N_ext);
            p_ein_y=r_ei.*cos(ang_ei); p_ein_z=r_ei.*sin(ang_ei);
            h_ein=scatter3(ax,p_ein_x,p_ein_y,p_ein_z,52, ...
                repmat([0.28 0.68 1.00],N_ext,1),'filled','MarkerFaceAlpha',0.92);

            rng(17);
            x_eout_min=x_out+l_noz+0.02; x_eout_max=x_out+l_noz+0.24;
            p_eout_x=linspace(x_eout_min,x_eout_max,N_ext);
            r_eo=r_noz*0.55*rand(1,N_ext); ang_eo=2*pi*rand(1,N_ext);
            p_eout_y=r_eo.*cos(ang_eo); p_eout_z=r_eo.*sin(ang_eo);
            nc_ei=rxWindowStyle.convColor(Xa_i(end));
            h_eout=scatter3(ax,p_eout_x,p_eout_y,p_eout_z,52, ...
                repmat(min(1,nc_ei*1.85+0.06),N_ext,1),'filled','MarkerFaceAlpha',0.92);

            text(ax,x_in-l_noz-0.04,0,R_shell+0.07,'FEED \rightarrow', ...
                'Color',[0.38 0.62 0.96],'FontSize',9,'FontWeight','bold', ...
                'HorizontalAlignment','right','VerticalAlignment','bottom');
            text(ax,x_out+l_noz+0.04,0,R_shell+0.07,'\rightarrow PRODUCT', ...
                'Color',[0.88 0.70 0.28],'FontSize',9,'FontWeight','bold', ...
                'HorizontalAlignment','left','VerticalAlignment','bottom');

            x_lim=x_out+l_noz+0.40;
            set(ax,'XLim',[-x_lim x_lim],'YLim',[-0.52 0.52],'ZLim',[-0.60 0.40]);

            s.h_tubes=h_tubes; s.h_part=h_part;
            s.h_ein=h_ein;     s.h_eout=h_eout;
            s.A_k=app.P.A; s.Ea=app.P.Ea; s.Rg=8.314; s.C0=app.P.C0; s.V_total=V_total;
            s.V_at_x=V_at_x; s.N_x=N_x; s.N_th=N_th; s.n_tubes=n_tubes;
            s.x_pos=x_pos; s.L_h=L_h;
            s.Xa_profile=Xa_i;
            s.p_x=p_x;   s.p_y=p_y;   s.p_z=p_z;   s.p_x0=p_x;
            s.p_ein_x=p_ein_x;   s.p_ein_y=p_ein_y;  s.p_ein_z=p_ein_z;
            s.p_eout_x=p_eout_x; s.p_eout_y=p_eout_y; s.p_eout_z=p_eout_z;
            s.p_ein_x0=p_ein_x; s.p_eout_x0=p_eout_x;
            s.x_ein_min=x_ein_min; s.x_ein_max=x_ein_max;
            s.x_eout_min=x_eout_min; s.x_eout_max=x_eout_max;
            s.Xa_i=Xa_i; s.nc_ei=nc_ei;
            app.Anim3DState=s;
            app.Built3D=true;
            rng(rngState);   % restore the caller's global RNG stream
        end

        function reset3D(app)
            s=app.Anim3DState;
            if isempty(s), return; end
            C_i=pfrCdata(app,s.Xa_i,s.N_th,s.N_x);
            for t=1:s.n_tubes; set(s.h_tubes(t),'CData',C_i); end
            set(s.h_part,'XData',s.p_x0,'YData',s.p_y,'ZData',s.p_z);
            s.p_x=s.p_x0;
            s.p_ein_x=s.p_ein_x0; s.p_eout_x=s.p_eout_x0;
            set(s.h_ein,'XData',s.p_ein_x0);
            set(s.h_eout,'XData',s.p_eout_x0, ...
                'CData',repmat(min(1,s.nc_ei*1.85+0.06),size(s.p_eout_x0,2),1));
            app.Anim3DState=s;
        end

        function runAnimation(app)
            if ~app.Built3D; build3D(app); end

            app.StopFlag=false;
            app.RunBtn.Enable='off';
            app.TSlider.Enable='off';
            app.qSlider.Enable='off';

            C0=app.P.C0; A_pre=app.P.A; Ea=app.P.Ea; Rg=8.314; V_r=app.P.Vr;
            T=app.TSlider.Value;
            q=app.qSlider.Value;
            tau=V_r/q;
            k=A_pre*exp(-Ea/(Rg*T));

            V_full=linspace(0,V_r,200);
            Ca_full=computeCa(app,k,V_full,q);
            Xa_full=1-Ca_full/C0;

            app.CaLine.XData=NaN; app.CaLine.YData=NaN;
            app.XaLine.XData=NaN; app.XaLine.YData=NaN;
            drawnow;

            s=app.Anim3DState;
            k_3d=s.A_k*exp(-s.Ea/(s.Rg*T));
            Ca_pfr=rxKinetics.caPFR(app.P,k_3d,s.V_at_x,q);
            Xa_pfr=1-Ca_pfr/s.C0;
            s.Xa_profile=Xa_pfr;
            C_new=pfrCdata(app,Xa_pfr,s.N_th,s.N_x);
            for t=1:s.n_tubes; set(s.h_tubes(t),'CData',C_new); end
            nc_exit=(1-Xa_pfr(end))*[0.15 0.40 0.88]+Xa_pfr(end)*[0.65 0.50 0.28];
            set(s.h_eout,'CData',repmat(min(1,nc_exit*1.85+0.06),size(s.p_eout_x,2),1));
            app.Anim3DState=s;

            n=numel(V_full);
            for f=1:80
                if app.StopFlag || ~isvalid(app.UIFigure); break; end
                idx=max(1,round(f/80*n));
                s=app.Anim3DState;

                app.CaLine.XData=V_full(1:idx); app.CaLine.YData=Ca_full(1:idx);
                app.XaLine.XData=V_full(1:idx); app.XaLine.YData=Xa_full(1:idx);
                app.CaLbl.Text=sprintf('%.4f',Ca_full(idx));
                app.XaLbl.Text=sprintf('%.4f',Xa_full(idx));
                app.tauLbl.Text=sprintf('%.2f',tau);
                app.kLbl.Text=kStr(app,k);
                app.StatusLbl.Text=sprintf( ...
                    'Running...  V = %.3f / %.3f L     Ca = %.4f mol/L     Xa = %.4f', ...
                    V_full(idx),V_r,Ca_full(idx),Xa_full(idx));

                flow_sp=0.010+0.016*(q/app.P.qmax);
                p_x=s.p_x+flow_sp; p_x(p_x>s.L_h/2)=-s.L_h/2; s.p_x=p_x;
                Xa_at_p=max(0,min(1,interp1(s.x_pos,s.Xa_profile,p_x,'linear','extrap')));
                nc_p=min(1,((1-Xa_at_p(:))*[0.15 0.40 0.88]+Xa_at_p(:)*[0.65 0.50 0.28])*1.85+0.06);
                set(s.h_part,'XData',p_x,'YData',s.p_y,'ZData',s.p_z,'CData',nc_p);
                sp_ext=0.008+0.012*(q/app.P.qmax);
                p_ein=s.p_ein_x+sp_ext; p_ein(p_ein>s.x_ein_max)=s.x_ein_min; s.p_ein_x=p_ein;
                set(s.h_ein,'XData',p_ein,'YData',s.p_ein_y,'ZData',s.p_ein_z);
                p_eo=s.p_eout_x+sp_ext; p_eo(p_eo>s.x_eout_max)=s.x_eout_min; s.p_eout_x=p_eo;
                set(s.h_eout,'XData',p_eo,'YData',s.p_eout_y,'ZData',s.p_eout_z);
                app.Anim3DState=s;
                drawnow limitrate; pause(0.04);
            end

            if ~app.StopFlag && isvalid(app.UIFigure)
                app.TSlider.Enable='on'; app.qSlider.Enable='on';
                T_idle=T; q_idle=q; k_idle=k; tau_idle=tau;
                app.CaLbl.Text=sprintf('%.4f',Ca_full(end));
                app.XaLbl.Text=sprintf('%.4f',Xa_full(end));
                app.tauLbl.Text=sprintf('%.2f',tau_idle);
                app.kLbl.Text=kStr(app,k_idle);
                updateComp(app,k_idle,tau_idle,q_idle);
                app.StatusLbl.Text=sprintf( ...
                    'Done ✓   T = %.1f K   q = %.3f L/min   —   Animating  |  RESET to run again', ...
                    T_idle, q_idle);

                app.IdleLoopActive=true;
                while ~app.StopFlag && isvalid(app.UIFigure)
                    T_now=app.TSlider.Value; q_now=app.qSlider.Value;

                    if abs(T_now-T_idle)>1e-3 || abs(q_now-q_idle)>1e-4
                        T_idle=T_now; q_idle=q_now;
                        k_idle=A_pre*exp(-Ea/(Rg*T_idle));
                        tau_idle=V_r/q_idle;
                        Ca_new=computeCa(app,k_idle,V_full,q_idle);
                        Xa_new=1-Ca_new/C0;

                        Ca_old=app.CaLine.YData; Xa_old=app.XaLine.YData;
                        if any(isnan(Ca_old(:))); Ca_old=Ca_new; Xa_old=Xa_new; end
                        for fa=1:20
                            if app.StopFlag||~isvalid(app.UIFigure); break; end
                            al=fa/20;
                            app.CaLine.YData=(1-al)*Ca_old+al*Ca_new;
                            app.XaLine.YData=(1-al)*Xa_old+al*Xa_new;
                            s=app.Anim3DState;
                            flow_sp=0.010+0.016*(q_idle/app.P.qmax);
                            p_x=s.p_x+flow_sp; p_x(p_x>s.L_h/2)=-s.L_h/2; s.p_x=p_x;
                            Xa_at_p=max(0,min(1,interp1(s.x_pos,s.Xa_profile,p_x,'linear','extrap')));
                            nc_p=min(1,((1-Xa_at_p(:))*[0.15 0.40 0.88]+Xa_at_p(:)*[0.65 0.50 0.28])*1.85+0.06);
                            set(s.h_part,'XData',p_x,'YData',s.p_y,'ZData',s.p_z,'CData',nc_p);
                            app.Anim3DState=s;
                            drawnow limitrate; pause(0.02);
                        end

                        app.CaLine.XData=V_full; app.CaLine.YData=Ca_new;
                        app.XaLine.XData=V_full; app.XaLine.YData=Xa_new;
                        app.CaLbl.Text=sprintf('%.4f',Ca_new(end));
                        app.XaLbl.Text=sprintf('%.4f',Xa_new(end));
                        app.tauLbl.Text=sprintf('%.2f',tau_idle);
                        app.kLbl.Text=kStr(app,k_idle);

                        s=app.Anim3DState;
                        Ca_pfr2=rxKinetics.caPFR(app.P,k_idle,s.V_at_x,q_idle);
                        Xa_pfr2=1-Ca_pfr2/s.C0;
                        s.Xa_profile=Xa_pfr2;
                        C_upd=pfrCdata(app,Xa_pfr2,s.N_th,s.N_x);
                        for ti=1:s.n_tubes; set(s.h_tubes(ti),'CData',C_upd); end
                        nc_ex=(1-Xa_pfr2(end))*[0.15 0.40 0.88]+Xa_pfr2(end)*[0.65 0.50 0.28];
                        set(s.h_eout,'CData',repmat(min(1,nc_ex*1.85+0.06),size(s.p_eout_x,2),1));
                        app.Anim3DState=s;

                        updateComp(app,k_idle,tau_idle,q_idle);
                        app.StatusLbl.Text=sprintf( ...
                            'Live   T = %.1f K   q = %.3f L/min   τ = %.2f min   —   Animating  |  RESET to run again', ...
                            T_idle, q_idle, tau_idle);
                    end

                    s=app.Anim3DState;
                    flow_sp=0.010+0.016*(q_idle/app.P.qmax);
                    p_x=s.p_x+flow_sp; p_x(p_x>s.L_h/2)=-s.L_h/2; s.p_x=p_x;
                    Xa_at_p=max(0,min(1,interp1(s.x_pos,s.Xa_profile,p_x,'linear','extrap')));
                    nc_p=min(1,((1-Xa_at_p(:))*[0.15 0.40 0.88]+Xa_at_p(:)*[0.65 0.50 0.28])*1.85+0.06);
                    set(s.h_part,'XData',p_x,'YData',s.p_y,'ZData',s.p_z,'CData',nc_p);
                    sp_ext=0.008+0.012*(q_idle/app.P.qmax);
                    p_ein=s.p_ein_x+sp_ext; p_ein(p_ein>s.x_ein_max)=s.x_ein_min; s.p_ein_x=p_ein;
                    set(s.h_ein,'XData',p_ein,'YData',s.p_ein_y,'ZData',s.p_ein_z);
                    p_eo=s.p_eout_x+sp_ext; p_eo(p_eo>s.x_eout_max)=s.x_eout_min; s.p_eout_x=p_eo;
                    set(s.h_eout,'XData',p_eo,'YData',s.p_eout_y,'ZData',s.p_eout_z);
                    app.Anim3DState=s;
                    drawnow limitrate; pause(0.04);
                end
                app.IdleLoopActive=false;
            end

            if isvalid(app.UIFigure)
                app.RunBtn.Enable='on';
                app.TSlider.Enable='on'; app.qSlider.Enable='on';
                app.StopFlag=false;
            end
        end

        function resetAll(app)
            app.StopFlag=true;
            app.TSlider.Value=app.P.Tmin; app.qSlider.Value=app.P.qmin;
            app.TSlider.Enable='on';  app.qSlider.Enable='on';
            app.RunBtn.Enable='on';
            app.CaLbl.Text='—'; app.XaLbl.Text='—';
            app.tauLbl.Text='—'; app.kLbl.Text='—';
            app.CaLine.XData=NaN; app.CaLine.YData=NaN;
            app.XaLine.XData=NaN; app.XaLine.YData=NaN;
            reset3D(app);
            onSliderRelease(app);
            app.StatusLbl.Text='Ready  —  set conditions and click RUN';
        end

    end
end
