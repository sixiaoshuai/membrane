function mu = mul(T)
%MUL(T)     Dynamic viscosity of the liquid [Pas].
%
%  Ethanol.
%  Valid for 230.15K < T < 411.7K.
%  From Landolt-B�rnstein: Group IV, vol. 18B (2002).

t = [230.15;240.15;250.15;260.15;270.15;280.15;290.15;300.15;310.15;320.15;...
338.2;343.2;348.2;358.2;368.2;373.2;378.0;392.2;411.7];

m = [5.0666;3.8739;3.0152;2.3834;1.9096;1.5482;1.2684;1.0488;0.8744;0.7344;...
0.628;0.584;0.529;0.482;0.407;0.405;0.354;0.291;0.216]...
*10^(-3);

mu = interp1q(t,m,T')';  
