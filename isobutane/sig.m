function sig = sig(T)
%SIG(T)     Surface tension [N/m].
%
%  Ethanol.
%  Valid for 340K < T < 415K.
%  From Landolt-B�rnstein: Group IV, vol. 16 (1997).

% the data
%t=[  340;   345;   350;   355;   360;   365;   370;   375;   380;  385;...
%   390;   395;  400;   405;   410;   415];
%s=[18.45;17.986;17.517;17.042;16.562;16.076;15.585;15.089;14.587;14.08;...
%13.568;13.051;12.53;12.004;11.473;10.938]*0.001;
%sig = interp1q(t,s,T')';

% a polynomial fit:
%psig = polyfit(t,s,2)
sig = 3.8028e-2 - 2.2643e-5*T - 1.0275e-7*T.^2;
