classdef rxKinetics
    % rxKinetics  Single source of truth for the reactor kinetics.
    %   Every reactor window (Batch / CSTR / PFR / Comparison) computes
    %   concentrations through these helpers, so the physics stays
    %   identical everywhere and only has to be corrected in one place.
    %
    %   P is the parameter struct assembled by the hub (ReactorDesignExplorer):
    %     P.C0  initial concentration of A (mol/L)
    %     P.Ea  activation energy (J/mol)
    %     P.A   Arrhenius pre-exponential factor
    %     P.order  reaction order (1 or 2)
    %     P.Vr  reactor volume (L)        P.tmax  batch horizon (min)
    %     P.Tmin/Tmax  temperature range  P.qmin/qmax  flow-rate range

    properties (Constant)
        Rg = 8.314            % ideal gas constant, J/mol/K
    end

    methods (Static)

        function P = defaultParams()
            % defaultParams  Fallback parameters when a window is opened
            %   directly (not launched from the hub).
            P.C0=0.1; P.Ea=43790; P.A=1.11e8; P.order=2;
            P.Vr=1.0; P.tmax=20;
            P.Tmin=298; P.Tmax=450; P.qmin=0.02; P.qmax=0.50;
        end

        function k = rateConstant(P, T)
            % rateConstant  Arrhenius rate constant k = A*exp(-Ea/RT).
            %   T may be a scalar or a vector.
            k = P.A .* exp(-P.Ea ./ (rxKinetics.Rg .* T));
        end

        function Ca = caBatch(P, k, t)
            % caBatch  Concentration of A in a batch reactor after time t.
            if P.order == 1
                Ca = P.C0 .* exp(-k .* t);
            else
                Ca = P.C0 ./ (1 + k .* P.C0 .* t);
            end
        end

        function Ca = caCSTR(P, k, tau)
            % caCSTR  Exit concentration of A in a CSTR, residence time tau.
            if P.order == 1
                Ca = P.C0 ./ (1 + k .* tau);
            else
                % Numerically stable form of the 2nd-order root.  It is
                % algebraically equal to (-1+sqrt(1+4*k*tau*C0))/(2*k*tau)
                % but never divides by k, so as k -> 0 it returns C0
                % (no conversion) instead of evaluating 0/0 = NaN.
                Ca = 2 .* P.C0 ./ (1 + sqrt(1 + 4 .* k .* tau .* P.C0));
            end
        end

        function Ca = caPFR(P, k, V, q)
            % caPFR  Exit concentration of A in a PFR of volume V at flow q.
            if P.order == 1
                Ca = P.C0 .* exp(-k .* V ./ q);
            else
                Ca = P.C0 ./ (1 + k .* P.C0 .* V ./ q);
            end
        end

    end
end
