classdef CSTRWindow < matlab.apps.AppBase

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
        CaMark
        XaMark
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
        ACCENT = [0.15 0.40 0.88]
    end

    methods (Access = public)
        function app = CSTRWindow(P)
            if nargin < 1 || isempty(P)
                P = CSTRWindow.defaultParams();
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

        % ── Ca formula (order-aware, accepts scalar or vector k) ─────────────
        function Ca = computeCa(app, k, tau)
            Ca = rxKinetics.caCSTR(app.P, k, tau);
        end

        function s = kStr(app, k)
            if app.P.order == 1; s = sprintf('%.3g /min', k);
            else;                 s = sprintf('%.3g L/mol/min', k);
            end
        end

        function createComponents(app)
            BG=[0.09 0.09 0.11]; BP=[0.13 0.13 0.18]; AC=app.ACCENT;

            app.UIFigure=uifigure('Name','CSTR', ...
                'Position',[200 60 1380 900],'Color',BG);

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

            h1=uilabel(hg,'Text','CSTR  —  Continuous Stirred Tank Reactor', ...
                'FontSize',17,'FontWeight','bold','FontColor',[1 1 1], ...
                'HorizontalAlignment','center');
            h1.Layout.Row=1; h1.Layout.Column=1;
            ord_str='Second'; if app.P.order==1; ord_str='First'; end
            h2=uilabel(hg,'Text', ...
                sprintf('A  +  B   →   C  +  D     |     %s-Order     |     k = %.3g exp(−Ea/RT)', ...
                    ord_str, app.P.A), ...
                'FontSize',10,'FontColor',[0.78 0.88 1.00],'HorizontalAlignment','center');
            h2.Layout.Row=2; h2.Layout.Column=1;

            % ── Animation + Controls ─────────────────────────────────────────
            mid=uigridlayout(outer,[1 2]);
            mid.Layout.Row=2; mid.Layout.Column=1;
            mid.RowHeight={'1x'}; mid.ColumnWidth={'1x',300};
            mid.Padding=[10 10 10 8]; mid.ColumnSpacing=8;
            mid.BackgroundColor=BG;

            app.AnimAx=uiaxes(mid);
            app.AnimAx.Layout.Row=1; app.AnimAx.Layout.Column=1;
            rxWindowStyle.animAx(app.AnimAx,'CSTR — 3D Animation',AC);
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
            rxWindowStyle.plotAx(app.ConcAx,'Exit Concentration vs Temperature', ...
                'Temperature (K)','Ca,exit  (mol/L)');
            hold(app.ConcAx,'on');
            app.CaPreview=plot(app.ConcAx,NaN,NaN,'--','Color',PC,'LineWidth',1.0);
            app.CaLine   =plot(app.ConcAx,NaN,NaN,'-', 'Color',AC,'LineWidth',2.5);
            app.CaMark   =plot(app.ConcAx,NaN,NaN,'o','MarkerSize',9, ...
                'MarkerFaceColor',[0.96 0.83 0.38],'MarkerEdgeColor',[1 1 1],'LineWidth',1.5);
            app.ConcAx.XLim=[app.P.Tmin app.P.Tmax];
            app.ConcAx.YLim=[0 app.P.C0*1.06];
            app.ConcAx.XLimMode='manual'; app.ConcAx.YLimMode='manual';

            app.ConvAx=uiaxes(bot);
            app.ConvAx.Layout.Row=1; app.ConvAx.Layout.Column=2;
            rxWindowStyle.plotAx(app.ConvAx,'Conversion vs Temperature', ...
                'Temperature (K)','Conversion  Xa,exit');
            hold(app.ConvAx,'on');
            app.XaPreview=plot(app.ConvAx,NaN,NaN,'--','Color',PC,'LineWidth',1.0);
            app.XaLine   =plot(app.ConvAx,NaN,NaN,'-', 'Color',AC,'LineWidth',2.5);
            app.XaMark   =plot(app.ConvAx,NaN,NaN,'o','MarkerSize',9, ...
                'MarkerFaceColor',[0.96 0.83 0.38],'MarkerEdgeColor',[1 1 1],'LineWidth',1.5);
            app.ConvAx.XLim=[app.P.Tmin app.P.Tmax]; app.ConvAx.YLim=[0 1.05];
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

            A_pre=app.P.A; Ea=app.P.Ea; Rg=8.314; V=app.P.Vr;
            tau=V/q;
            k=A_pre*exp(-Ea/(Rg*T));
            T_p=linspace(app.P.Tmin,app.P.Tmax,200);
            k_p=A_pre*exp(-Ea./(Rg*T_p));
            Ca_new=computeCa(app,k_p,tau);
            Xa_new=1-Ca_new/app.P.C0;

            Ca_old=app.CaPreview.YData; Xa_old=app.XaPreview.YData;
            if numel(Ca_old)~=numel(Ca_new)||any(isnan(Ca_old(:)))
                Ca_old=Ca_new; Xa_old=Xa_new;
            end

            if ~app.IsAnimating && ~isequal(Ca_old,Ca_new)
                app.IsAnimating=true;
                app.CaPreview.XData=T_p; app.XaPreview.XData=T_p;
                for f=1:15
                    if ~isvalid(app.UIFigure); break; end
                    al=f/15;
                    app.CaPreview.YData=(1-al)*Ca_old+al*Ca_new;
                    app.XaPreview.YData=(1-al)*Xa_old+al*Xa_new;
                    drawnow limitrate; pause(0.015);
                end
                app.IsAnimating=false;
            end
            app.CaPreview.XData=T_p; app.CaPreview.YData=Ca_new;
            app.XaPreview.XData=T_p; app.XaPreview.YData=Xa_new;

            updateComp(app,k,tau,q);
        end

        function updateComp(app, k, tau, q)
            C0=app.P.C0; V=app.P.Vr;
            Ca_cstr=computeCa(app,k,tau); Xa_cstr=1-Ca_cstr/C0;
            Ca_pfr=rxKinetics.caPFR(app.P,k,V,q);
            Xa_pfr=1-Ca_pfr/C0;
            app.CompLbl.Text=sprintf( ...
                'T=%.0fK, q=%.3f:  CSTR Xa=%.3f  |  PFR Xa=%.3f  (PFR +%.3f)', ...
                app.TSlider.Value, q, Xa_cstr, Xa_pfr, Xa_pfr-Xa_cstr);
        end

        function build3D(app)
            rngState=rng;   % preserve the caller's global RNG stream
            ax=app.AnimAx;
            delete(findobj(ax,'Type','text'));

            set(ax,'XColor','none','YColor','none','ZColor','none');
            set(ax,'XGrid','off','YGrid','off','ZGrid','off','Box','off');
            view(ax,38,28);
            set(ax,'CameraTarget',[0 0 0.55]);
            set(ax,'XLim',[-0.75 0.75],'YLim',[-0.75 0.75],'ZLim',[-0.22 1.50]);
            hold(ax,'on');

            l1=camlight(ax,'right'); set(l1,'Color',[1.00 0.97 0.90]);
            l2=camlight(ax,'left');  set(l2,'Color',[0.50 0.62 0.82]);
            lighting(ax,'gouraud');
            camzoom(ax,1.45);

            A_k=app.P.A; Ea=app.P.Ea; Rg=8.314; C0=app.P.C0; V=app.P.Vr;
            Rt=0.40; Ht=1.20; dish=0.16; fz=0.86; zi=0.30;
            rb=0.27; bw=0.055; pt=0.80; rs=0.022;
            r_noz=0.028; r_pos=0.18; phi_in=pi/5; z_noz_top=Ht+0.135;
            r_p=0.036; pl=0.14; phi_o=-pi/3; z_o=0.22;

            th=linspace(0,2*pi,80); th_s=linspace(0,2*pi,24);
            rd=linspace(0,Rt,40); [Rd,Thd]=meshgrid(rd,th);

            Z_dish=-dish*sqrt(max(0,1-(Rd/Rt).^2));
            surf(ax,Rd.*cos(Thd),Rd.*sin(Thd),Z_dish, ...
                'FaceColor',[0.48 0.52 0.58],'EdgeColor','none', ...
                'SpecularStrength',0.82,'DiffuseStrength',0.55);
            [Th,Zw]=meshgrid(th,[0 Ht]);
            surf(ax,Rt*cos(Th),Rt*sin(Th),Zw, ...
                'FaceColor',[0.56 0.62 0.68],'EdgeColor','none', ...
                'FaceAlpha',0.20,'SpecularStrength',0.95,'DiffuseStrength',0.45);
            [Thr,Zr]=meshgrid(th,[Ht Ht+0.030]);
            surf(ax,(Rt+0.007)*cos(Thr),(Rt+0.007)*sin(Thr),Zr, ...
                'FaceColor',[0.48 0.53 0.59],'EdgeColor','none','SpecularStrength',0.90);
            rd_rim=linspace(Rt-0.005,Rt+0.014,5); [Rrim,Thrim]=meshgrid(rd_rim,th);
            surf(ax,Rrim.*cos(Thrim),Rrim.*sin(Thrim),ones(size(Rrim))*(Ht+0.030), ...
                'FaceColor',[0.48 0.53 0.59],'EdgeColor','none','SpecularStrength',0.85);
            rd_top=linspace(rs+0.003,Rt-0.005,35); [Rct,Thct]=meshgrid(rd_top,th);
            surf(ax,Rct.*cos(Thct),Rct.*sin(Thct),ones(size(Rct))*Ht, ...
                'FaceColor',[0.44 0.48 0.54],'EdgeColor','none','FaceAlpha',0.88,'SpecularStrength',0.65);
            br_baf=[Rt-0.092,Rt-0.003]; bz_baf=[0,fz*Ht]; [Rbaf,Zbaf]=meshgrid(br_baf,bz_baf);
            for kb=0:3
                phi_b=kb*pi/2+pi/8;
                surf(ax,Rbaf*cos(phi_b),Rbaf*sin(phi_b),Zbaf, ...
                    'FaceColor',[0.52 0.57 0.64],'EdgeColor',[0.70 0.74 0.80], ...
                    'FaceAlpha',0.92,'SpecularStrength',0.65);
            end

            k_i=A_k*exp(-Ea/(Rg*app.P.Tmin)); q_i=app.P.qmin; tau_i=V/q_i;
            Ca_i=rxKinetics.caCSTR(app.P,k_i,tau_i);
            Xa_i=(C0-Ca_i)/C0;
            liq0=rxWindowStyle.convColor(Xa_i);

            rd_ld=linspace(0,Rt-0.010,40); [Rld,Thld]=meshgrid(rd_ld,th);
            Z_liq_dish=-dish*sqrt(max(0,1-(Rld/(Rt-0.010)).^2));
            h_liqd=surf(ax,Rld.*cos(Thld),Rld.*sin(Thld),Z_liq_dish, ...
                'FaceColor',liq0,'EdgeColor','none','FaceAlpha',0.35);
            [Thl,Zl]=meshgrid(th,[0 fz*Ht]);
            h_liqwall=surf(ax,(Rt-0.010)*cos(Thl),(Rt-0.010)*sin(Thl),Zl, ...
                'FaceColor',liq0,'EdgeColor','none','FaceAlpha',0.45);
            rd_ls=linspace(0,Rt-0.010,38); [Rls,Thls]=meshgrid(rd_ls,th);
            h_liqsurf=surf(ax,Rls.*cos(Thls),Rls.*sin(Thls),ones(size(Rls))*fz*Ht, ...
                'FaceColor',liq0,'EdgeColor','none','FaceAlpha',0.65, ...
                'SpecularStrength',0.98,'DiffuseStrength',0.18,'SpecularExponent',60);

            t_noz=linspace(0,2*pi,18); [Thn,Zn]=meshgrid(t_noz,[Ht+0.030,z_noz_top]);
            surf(ax,r_pos*cos(phi_in)+r_noz*cos(Thn),r_pos*sin(phi_in)+r_noz*sin(Thn),Zn, ...
                'FaceColor',[0.40 0.44 0.50],'EdgeColor','none','SpecularStrength',0.82);
            rd_fn=linspace(r_noz,r_noz+0.022,5); [Rfn,Thfn]=meshgrid(rd_fn,t_noz);
            surf(ax,r_pos*cos(phi_in)+Rfn.*cos(Thfn),r_pos*sin(phi_in)+Rfn.*sin(Thfn), ...
                ones(size(Rfn))*z_noz_top,'FaceColor',[0.40 0.44 0.50],'EdgeColor','none');
            t_op=linspace(0,2*pi,18); [Up,Tp]=meshgrid([0 pl],t_op);
            X_op=(Rt+Up).*cos(phi_o)-r_p*sin(Tp)*sin(phi_o);
            Y_op=(Rt+Up).*sin(phi_o)+r_p*sin(Tp)*cos(phi_o);
            Z_op=z_o+r_p*cos(Tp);
            surf(ax,X_op,Y_op,Z_op,'FaceColor',[0.46 0.50 0.57],'EdgeColor',[0.60 0.64 0.70], ...
                'EdgeAlpha',0.4,'SpecularStrength',0.85);
            rd_fo=linspace(r_p,r_p+0.020,4); [Rfo,Tfo]=meshgrid(rd_fo,t_op);
            X_fo=(Rt+pl+0.001)*cos(phi_o)+Rfo.*sin(Tfo)*(-sin(phi_o));
            Y_fo=(Rt+pl+0.001)*sin(phi_o)+Rfo.*sin(Tfo)*(cos(phi_o));
            Z_fo=z_o+Rfo.*cos(Tfo);
            surf(ax,X_fo,Y_fo,Z_fo,'FaceColor',[0.40 0.44 0.50],'EdgeColor','none');

            [Ths,Zs]=meshgrid(th_s,[-dish-0.02,Ht+0.075]);
            surf(ax,rs*cos(Ths),rs*sin(Ths),Zs, ...
                'FaceColor',[0.25 0.25 0.29],'EdgeColor','none','SpecularStrength',0.72);
            rd_mh=linspace(0,0.062,8); [Rmh,Thmh]=meshgrid(rd_mh,th);
            surf(ax,Rmh.*cos(Thmh),Rmh.*sin(Thmh),ones(size(Rmh))*(Ht+0.075), ...
                'FaceColor',[0.28 0.28 0.34],'EdgeColor','none');
            rd_id=linspace(rs,0.095,8); [Rid,Thid]=meshgrid(rd_id,th);
            surf(ax,Rid.*cos(Thid),Rid.*sin(Thid),ones(size(Rid))*(zi+0.010), ...
                'FaceColor',[0.27 0.27 0.33],'EdgeColor','none');

            bz_pt=[zi-bw*pt,zi-bw*pt,zi+bw*pt,zi+bw*pt];
            b1x=[-rb,rb,rb,-rb]; b1y=[-bw,-bw,bw,bw];
            b2x=[-bw,-bw,bw,bw]; b2y=[-rb,rb,rb,-rb];
            h_b1=patch(ax,'XData',b1x,'YData',b1y,'ZData',bz_pt, ...
                'FaceColor',[0.30 0.30 0.37],'EdgeColor',[0.50 0.52 0.60],'LineWidth',0.8);
            h_b2=patch(ax,'XData',b2x,'YData',b2y,'ZData',bz_pt, ...
                'FaceColor',[0.30 0.30 0.37],'EdgeColor',[0.50 0.52 0.60],'LineWidth',0.8);

            N_in=10; rng(7);
            z_bot_in=Ht-0.15;
            p_in_z=linspace(z_noz_top,z_bot_in,N_in)';
            ang_j=2*pi*rand(N_in,1); r_j=r_noz*0.55*rand(N_in,1);
            p_in_x=r_pos*cos(phi_in)+r_j.*cos(ang_j);
            p_in_y=r_pos*sin(phi_in)+r_j.*sin(ang_j);
            h_pin=scatter3(ax,p_in_x,p_in_y,p_in_z,65, ...
                repmat([0.28 0.68 1.00],N_in,1),'filled','MarkerFaceAlpha',0.95);

            N_out=22; rng(13);
            p_rmin=Rt-0.06; p_rmax=Rt+pl+0.24;
            p_out_r=linspace(p_rmin,p_rmax,N_out);
            p_perp=r_p*0.50*(2*rand(1,N_out)-1);
            p_vert=r_p*0.50*(2*rand(1,N_out)-1);
            p_out_x=p_out_r.*cos(phi_o)+p_perp.*(-sin(phi_o));
            p_out_y=p_out_r.*sin(phi_o)+p_perp.*(cos(phi_o));
            p_out_z=z_o+p_vert;
            h_pout=scatter3(ax,p_out_x,p_out_y,p_out_z,65, ...
                repmat(min(1,liq0*2.0+0.08),N_out,1),'filled','MarkerFaceAlpha',0.95);

            s.angle=0;
            s.h_b1=h_b1;   s.h_b2=h_b2;
            s.b1x=b1x;     s.b1y=b1y;
            s.b2x=b2x;     s.b2y=b2y;
            s.bz_pt=bz_pt;
            s.h_liqd=h_liqd; s.h_liqwall=h_liqwall; s.h_liqsurf=h_liqsurf;
            s.liq0=liq0;
            s.A_k=app.P.A; s.Ea=app.P.Ea; s.Rg=8.314; s.C0=app.P.C0; s.V=app.P.Vr;
            s.k_lo=rxKinetics.rateConstant(app.P, app.P.Tmin);
            s.k_hi=rxKinetics.rateConstant(app.P, app.P.Tmax);
            s.N_in=N_in; s.p_in_x=p_in_x; s.p_in_y=p_in_y;
            s.p_in_z0=p_in_z; s.p_in_z=p_in_z;
            s.z_top=z_noz_top; s.z_bot=z_bot_in; s.h_pin=h_pin;
            s.N_out=N_out; s.p_out_r0=p_out_r; s.p_out_r=p_out_r;
            s.p_rmin=p_rmin; s.p_rmax=p_rmax;
            s.p_perp=p_perp; s.p_vert=p_vert;
            s.phi_o=phi_o; s.z_o=z_o; s.h_pout=h_pout;
            app.Anim3DState=s;
            app.Built3D=true;
            rng(rngState);   % restore the caller's global RNG stream
        end

        function reset3D(app)
            s=app.Anim3DState;
            if isempty(s), return; end
            s.angle=0;
            set(s.h_b1,'XData',s.b1x,'YData',s.b1y,'ZData',s.bz_pt);
            set(s.h_b2,'XData',s.b2x,'YData',s.b2y,'ZData',s.bz_pt);
            set(s.h_liqd,   'FaceColor',s.liq0);
            set(s.h_liqwall,'FaceColor',s.liq0);
            set(s.h_liqsurf,'FaceColor',s.liq0);
            s.p_in_z=s.p_in_z0; s.p_out_r=s.p_out_r0;
            set(s.h_pin,'ZData',s.p_in_z0);
            app.Anim3DState=s;
        end

        function spin3D(app, k_idle)
            s=app.Anim3DState;
            k_lo=s.k_lo; k_hi=s.k_hi;
            fr=max(0,min(1,(log(k_idle)-log(k_lo))/(log(k_hi)-log(k_lo))));
            omega=0.04+0.38*fr;
            s.angle=s.angle+omega;
            cv=cos(s.angle); sv=sin(s.angle); Rm=[cv,-sv;sv,cv];
            r1=Rm*[s.b1x;s.b1y]; set(s.h_b1,'XData',r1(1,:),'YData',r1(2,:),'ZData',s.bz_pt);
            r2=Rm*[s.b2x;s.b2y]; set(s.h_b2,'XData',r2(1,:),'YData',r2(2,:),'ZData',s.bz_pt);
            app.Anim3DState=s;
        end

        function runAnimation(app)
            if ~app.Built3D; build3D(app); end

            app.StopFlag=false;
            app.RunBtn.Enable='off';
            app.TSlider.Enable='off';
            app.qSlider.Enable='off';

            C0=app.P.C0; A_pre=app.P.A; Ea=app.P.Ea; Rg=8.314; V_r=app.P.Vr;
            q=app.qSlider.Value;
            tau=V_r/q;

            T_full=linspace(app.P.Tmin,app.P.Tmax,200);
            k_full=A_pre*exp(-Ea./(Rg*T_full));
            Ca_full=computeCa(app,k_full,tau);
            Xa_full=1-Ca_full/C0;

            app.CaLine.XData=NaN; app.CaLine.YData=NaN;
            app.XaLine.XData=NaN; app.XaLine.YData=NaN;
            app.CaMark.XData=NaN; app.CaMark.YData=NaN;
            app.XaMark.XData=NaN; app.XaMark.YData=NaN;
            drawnow;

            s=app.Anim3DState;
            k_lo=s.k_lo; k_hi=s.k_hi;

            n=numel(T_full);
            for f=1:80
                if app.StopFlag || ~isvalid(app.UIFigure); break; end
                idx=max(1,round(f/80*n));
                T_f=T_full(idx);

                app.CaLine.XData=T_full(1:idx); app.CaLine.YData=Ca_full(1:idx);
                app.XaLine.XData=T_full(1:idx); app.XaLine.YData=Xa_full(1:idx);
                app.CaMark.XData=T_f;           app.CaMark.YData=Ca_full(idx);
                app.XaMark.XData=T_f;           app.XaMark.YData=Xa_full(idx);
                app.CaLbl.Text=sprintf('%.4f',Ca_full(idx));
                app.XaLbl.Text=sprintf('%.4f',Xa_full(idx));
                app.tauLbl.Text=sprintf('%.2f',tau);
                app.kLbl.Text=kStr(app,k_full(idx));
                app.StatusLbl.Text=sprintf( ...
                    'Running...  T = %.1f K     Ca,exit = %.4f mol/L     Xa = %.4f', ...
                    T_f,Ca_full(idx),Xa_full(idx));

                fr=max(0,min(1,(log(k_full(idx))-log(k_lo))/(log(k_hi)-log(k_lo))));
                omega=0.04+0.38*fr;
                s.angle=s.angle+omega;
                cv=cos(s.angle); sv=sin(s.angle); Rm=[cv,-sv;sv,cv];
                r1=Rm*[s.b1x;s.b1y]; set(s.h_b1,'XData',r1(1,:),'YData',r1(2,:),'ZData',s.bz_pt);
                r2=Rm*[s.b2x;s.b2y]; set(s.h_b2,'XData',r2(1,:),'YData',r2(2,:),'ZData',s.bz_pt);
                Xa_f=Xa_full(idx);
                nc=(1-Xa_f)*[0.15 0.40 0.88]+Xa_f*[0.65 0.50 0.28];
                set(s.h_liqd,   'FaceColor',nc);
                set(s.h_liqwall,'FaceColor',nc);
                set(s.h_liqsurf,'FaceColor',nc);
                fall_sp=0.007+0.010*(q/app.P.qmax);
                p_z=s.p_in_z-fall_sp; p_z(p_z<s.z_bot)=s.z_top; s.p_in_z=p_z;
                set(s.h_pin,'XData',s.p_in_x,'YData',s.p_in_y,'ZData',p_z);
                flow_sp=0.006+0.014*(q/app.P.qmax);
                p_r=s.p_out_r+flow_sp; p_r(p_r>s.p_rmax)=s.p_rmin; s.p_out_r=p_r;
                p_ox=p_r.*cos(s.phi_o)+s.p_perp.*(-sin(s.phi_o));
                p_oy=p_r.*sin(s.phi_o)+s.p_perp.*(cos(s.phi_o));
                set(s.h_pout,'XData',p_ox,'YData',p_oy,'ZData',s.z_o+s.p_vert, ...
                    'CData',repmat(min(1,nc*2.0+0.08),s.N_out,1));
                app.Anim3DState=s;
                drawnow limitrate; pause(0.04);
            end

            if ~app.StopFlag && isvalid(app.UIFigure)
                app.TSlider.Enable='on'; app.qSlider.Enable='on';
                T_idle=app.TSlider.Value; q_idle=q; tau_idle=tau;
                k_idle=A_pre*exp(-Ea/(Rg*T_idle));
                Ca_idle=computeCa(app,k_idle,tau_idle);
                Xa_idle=1-Ca_idle/C0;
                app.CaLbl.Text=sprintf('%.4f',Ca_idle);
                app.XaLbl.Text=sprintf('%.4f',Xa_idle);
                app.tauLbl.Text=sprintf('%.2f',tau_idle);
                app.kLbl.Text=kStr(app,k_idle);
                app.CaMark.XData=T_idle; app.CaMark.YData=Ca_idle;
                app.XaMark.XData=T_idle; app.XaMark.YData=Xa_idle;
                updateComp(app,k_idle,tau_idle,q_idle);
                app.StatusLbl.Text=sprintf( ...
                    'Done ✓   T = %.1f K   q = %.3f L/min   τ = %.2f min   —   Animating  |  RESET to run again', ...
                    T_idle, q_idle, tau_idle);

                app.IdleLoopActive=true;
                while ~app.StopFlag && isvalid(app.UIFigure)
                    T_now=app.TSlider.Value; q_now=app.qSlider.Value;

                    if abs(T_now-T_idle)>1e-3 || abs(q_now-q_idle)>1e-4
                        T_old_a=T_idle;
                        T_idle=T_now;
                        q_changed=abs(q_now-q_idle)>1e-4;

                        if q_changed
                            q_idle=q_now; tau_idle=V_r/q_idle;
                            k_arr=A_pre*exp(-Ea./(Rg*T_full));
                            Ca_sw=computeCa(app,k_arr,tau_idle);
                            Xa_sw=1-Ca_sw/C0;
                            Ca_old_c=app.CaLine.YData; Xa_old_c=app.XaLine.YData;
                            if any(isnan(Ca_old_c(:))); Ca_old_c=Ca_sw; Xa_old_c=Xa_sw; end
                            for fa=1:20
                                if app.StopFlag||~isvalid(app.UIFigure); break; end
                                al=fa/20;
                                app.CaLine.YData=(1-al)*Ca_old_c+al*Ca_sw;
                                app.XaLine.YData=(1-al)*Xa_old_c+al*Xa_sw;
                                spin3D(app,k_idle);
                                drawnow limitrate; pause(0.02);
                            end
                            app.CaLine.XData=T_full; app.CaLine.YData=Ca_sw;
                            app.XaLine.XData=T_full; app.XaLine.YData=Xa_sw;
                            app.tauLbl.Text=sprintf('%.2f',tau_idle);
                        end

                        k_idle=A_pre*exp(-Ea/(Rg*T_idle));
                        Ca_idle=computeCa(app,k_idle,tau_idle);
                        Xa_idle=1-Ca_idle/C0;

                        T_mark_start=T_old_a;
                        if isnan(app.CaMark.YData); T_mark_start=T_idle; end
                        for fa=1:20
                            if app.StopFlag||~isvalid(app.UIFigure); break; end
                            al=fa/20;
                            T_f2=(1-al)*T_mark_start+al*T_idle;
                            k_f2=A_pre*exp(-Ea/(Rg*T_f2));
                            Ca_f2=computeCa(app,k_f2,tau_idle);
                            Xa_f2=1-Ca_f2/C0;
                            app.CaMark.XData=T_f2; app.CaMark.YData=Ca_f2;
                            app.XaMark.XData=T_f2; app.XaMark.YData=Xa_f2;
                            spin3D(app,k_idle);
                            drawnow limitrate; pause(0.02);
                        end
                        app.CaMark.XData=T_idle; app.CaMark.YData=Ca_idle;
                        app.XaMark.XData=T_idle; app.XaMark.YData=Xa_idle;

                        liq_idle=(1-Xa_idle)*[0.15 0.40 0.88]+Xa_idle*[0.65 0.50 0.28];
                        s=app.Anim3DState;
                        set(s.h_liqd,   'FaceColor',liq_idle);
                        set(s.h_liqwall,'FaceColor',liq_idle);
                        set(s.h_liqsurf,'FaceColor',liq_idle);
                        app.CaLbl.Text=sprintf('%.4f',Ca_idle);
                        app.XaLbl.Text=sprintf('%.4f',Xa_idle);
                        app.kLbl.Text=kStr(app,k_idle);
                        updateComp(app,k_idle,tau_idle,q_idle);
                        app.StatusLbl.Text=sprintf( ...
                            'Live   T = %.1f K   q = %.3f L/min   τ = %.2f min   —   Animating  |  RESET to run again', ...
                            T_idle, q_idle, tau_idle);
                    end

                    s=app.Anim3DState;
                    fr_now=max(0,min(1,(log(k_idle)-log(k_lo))/(log(k_hi)-log(k_lo))));
                    omega_now=0.04+0.38*fr_now;
                    s.angle=s.angle+omega_now;
                    cv=cos(s.angle); sv=sin(s.angle); Rm=[cv,-sv;sv,cv];
                    r1=Rm*[s.b1x;s.b1y]; set(s.h_b1,'XData',r1(1,:),'YData',r1(2,:),'ZData',s.bz_pt);
                    r2=Rm*[s.b2x;s.b2y]; set(s.h_b2,'XData',r2(1,:),'YData',r2(2,:),'ZData',s.bz_pt);
                    fall_sp=0.007+0.010*(q_idle/app.P.qmax);
                    p_z=s.p_in_z-fall_sp; p_z(p_z<s.z_bot)=s.z_top; s.p_in_z=p_z;
                    set(s.h_pin,'XData',s.p_in_x,'YData',s.p_in_y,'ZData',p_z);
                    flow_sp=0.006+0.014*(q_idle/app.P.qmax);
                    p_r=s.p_out_r+flow_sp; p_r(p_r>s.p_rmax)=s.p_rmin; s.p_out_r=p_r;
                    p_ox=p_r.*cos(s.phi_o)+s.p_perp.*(-sin(s.phi_o));
                    p_oy=p_r.*sin(s.phi_o)+s.p_perp.*(cos(s.phi_o));
                    set(s.h_pout,'XData',p_ox,'YData',p_oy,'ZData',s.z_o+s.p_vert);
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
            app.CaMark.XData=NaN; app.CaMark.YData=NaN;
            app.XaMark.XData=NaN; app.XaMark.YData=NaN;
            reset3D(app);
            onSliderRelease(app);
            app.StatusLbl.Text='Ready  —  set conditions and click RUN';
        end

    end
end
