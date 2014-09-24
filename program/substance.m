function s = substance(name)
%SUBSTANCE  Material properties of a substance.
%  S = SUBSTANCE(NAME) returns a struct S that contains functions to calculate
%  material properties for the substance NAME. The functions do not check their
%  range of validity. Look for lines % Range: ... in the source code.
%
%  NAME can be 'butane', 'ethanol', 'isobutane', 'nitrogen', 'propane'.
%
%  The struct S has the following fields:
%  Variables:
%    S.name         Name of the substance
%    S.R            Specific gas constant [J/kgK]
%  Functions, material properties:
%    S.ps(T)        Saturation pressure [Pa], or array [ps dps/dT]
%    S.Ts(p)        Saturation temperature [K]
%    S.rho(T)       Density of the liquid [kg/m3]
%    S.v(T,p)       Specific volume of the vapor [m3/kg]
%    S.hvap(T)      Specific enthalpy of vaporization, from C.-C. [J/kg]
%    S.cpg(T,p)     Specific heat capacity at const. pressure of the gas [J/kgK]
%    S.mul(T)       Dynamic viscosity of the liquid [Pas]
%    S.mug(T)       Dynamic viscosity of the vapor [Pas]
%    S.kg(T)        Thermal conductivity of the vapor [W/mK]
%    S.kl(T)        Thermal conductivity of the liquid [W/mK]
%    S.cpl(T)       Specific heat capacity at const. pressure of liquid [J/kgK]
%    S.sigma(T)     Surface tension [N/m]
%  Functions depending (internally) on functions above:
%    S.jt(T,p)      Joule-Thomson coefficient [K/Pa]
%    S.dhdp(T,p)    Derivative of the specific enthalpy of the gas [m^3/kg]
%    S.dhcpg(T,p)   Derivative dh/dp and cpg, returns the array [DH/DP CPG]
%    S.drho(T)      Neg. compressibility, [DRHO RHO] 1/rho drho/dT and rho
%    S.dsig(T)      Derivative of sigma, [DSIG SIG] 1/sigma dsigma/dT and sigma
%    S.intjt(T0,p0,p1)  Integral Joule-Thomson coefficient, returns T1 [K]
%    S.intcpl(T0,T1)  Integral of specific heat capacity of the liquid [J/kg]
%    S.S(T,P,X,TR)  Specific entropy with respect to sat. liquid at TR [J/kgK].
%  Auxiliary functions, for convenience:
%    S.nul(T)       Kinematic viscosity of the liquid [m2/s]
%    S.nug(T,p)     Kinematic viscosity of the vapor [m2/s]
%
%  Functions S.ps, S.Ts, S.rho and S.hvap, as well as the depending functions
%  s.drho, s.nul (and ??) do not accept arrays as input.
%  Subfunctions: genericfunc, genericafun, cpperry, cpgas, hvap, virial, ps, Ts,
%  rholandolt, drholandolt, rhoperry, drhoperry, mudaubert, mulucas, kgroy,
%  klatini, cpleq2, icpleq2, sigvdi, dsigvdi, jt, dhdp, intjt, poly2, dpoly2,
%  poly3, dpoly3, ipoly3, poly4, ipoly4, pdiv3, pdiv4, newtony.
%
%  More help text: Try, e.g., HELP SUBSTANCE>PS.

%  Unit conversions are already done when assigning the coefficients. VCOEFFS
%  and CPLEQ2 could be done more elegantly, but these function work and would
%  require quite some work.
%TODO:
%  22. 9. 2014: Old muliquid (mul) of nitrogen - 10^22 at 80 K, what happened?
%  22. 9. 2014: rhoperry, only in nitrogen: Count the coefficients!
%               C(5) is not M, something is wrong here.
%  22. 9. 2014: cpl for nitrogen is not correct, 3.2 instead of 2.1 kJ/kgK.
%
%  TODO: cpl von butane hat sich geandert, siehe Table 153, Perry, 2007
%  entropie-berechnung: v(T) - sqrt konsequent anwenden?
%  Überprüfen der enthalpie-Berechnung; Eventuell structs oder cell-arrays of
%  function handles for, e.g., poly4, ..

%  not implemented yet (if ever).
%  S = SUBSTANCE(NAME,T) returns a struct s that contains material properties
%  at the saturation pressure for the substance NAME at the temperature T.

% Struct constructor. No need to be pedantic here. If not present, struct fields
% are added by assignment anyway.
s = struct('name',name,'R',[],'ps',[],'Ts',[],'rho',[],'v',[],'hvap',[], ...
  'cpg',[],'mul',[],'mug',[],'kg',[],'kl',[],'cpl',[],'sigma',[],'jt',[], ...
  'dhdp',[],'dhcpg',[],'drho',[],'dsig',[],'intjt',[],'intcpl',[], ...
  'nul',[],'nug',[]);

% universal gas constant
R = 8314.4; % J/kmolK

% The data. Data might contain only the correlation coefficients, or the
% coefficients and a function handle to a correlation function. The first case
% happens when all substances use the same function.
% Examples: PS always uses the same function, although within the function it is
% decided, based upon information contained in the coefficients, whether the
% classical or an extended Antoine eq. is used. RHO uses different functions.

% Sources

% PS, Saturation pressure
%
% Landolt-Börnstein, New Series, Group IV: Physical Chemistry. Vapor Pressure of
% Chemicals. J. Dykyj, J. Svoboda, R.C. Wilhoit, M.  Frenkel, K.R. Hall
% Vol. 20A (1999); Vol. 20B (2000); Vol. 20C (2001).
% See also ~/Literatur/pdfs/Landolt/LandoltIV20A1-13.pdf, Introduction.
%
% Landolt-Börnstein gives the coefficients for the classical Antoine or an
% extended Antoine-equation. The classical Antoine-equation is represented by a
% single line in Landolt-Börnstein,
%   A-3  B  C  Dmin/Dmax  Tmin/Tmax
% the extended Antoine-equation is represented by two lines,
%   A-3  B  C  Dmin/Dmax  T0/Tc
%   (n) (E) (F)
% Above, Dmin/Dmax is the temperature range in which data is available, and
% Tmin/Tmax is the recommended range for application of this correlation.
% Since Landolt-Börnstein gives coefficients to obtain the pressure in kPa, here
% 3 must be added to the value of A.
%
% The function S.PS expects the array Acoeffs to consist of at least one row and
% ten columns, e.g.,
% [ Tmax pmax A B C 0 0 0 0 0;... % classical Antoine eq.
%   Tmax pmax A B C T0 Tc n E F]; % extended Antoine eq.
%
% See the copy of the tabular values for propane, below. In the table of
% Landolt-Börnstein, pmax is not listed, but must be computed after setting the
% other values and calling S.PS(Tmax).

% V, specific volume of the gas
%
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Virial Coefficients of Pure Gases and Mixtures, vol. 21A: J H. Dymond,
% K.N. Marsh, R.C. Wilhoit and K.C. Wong (2002).
% See also ~/Literatur/pdfs/Landolt/LandoltIV21A1-22.pdf, Introduction.
%
% Landolt-Börnstein gives the second virial coefficient B in cm^3/mol. This is
% written to vcoeffs, conversion to m^3/kg happens in VIRIAL below (slightly
% hacky).
% B [cm^3/mol] = A + B/T + C/T^2 + D/T^3.
% vcoeffs = [A B C D R M];

switch(name)
case 'isobutane'
% Isobutane. 2-Methylpropane. CAS 75-28-5.

% PS, saturation pressure, coefficients for the Antoine eq.
% Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Vapor Pressure of Chemicals, vol. 20A. J. Dykyj, J. Svoboda, R.C. Wilhoit,
% M. Frenkel, K.R. Hall (1999).
% See also ~/Literatur/pdfs/Landolt/LandoltIV20A14-29.pdf, Hydrocarbons.
% Range:  110 K < T < 408 K
% Tmax, pmax are the values up to which the coeffs. in this line are valid.
% classical Antoine eq.:      [ Tmax pmax A B C 0 0 0 0 0 ]
% line in Landolt-Börnstein:     A-3  B  C  Dmin/Dmax  Tmin/Tmax
% extended Antoine eq.:       [ Tmax pmax A B C T0 Tc n E F ] % Tmax = Tc
% line in Landolt-Börnstein:     A-3  B   C   Dmin/Dmax  T0/Tc
%                                (n)  (E) (F)
% Dmin/Dmax: Range of data points; Tmin/Tmax: recommended temperature range
Acoeffs =  zeros(3,10);
Acoeffs(1,1:5) = [188 1641.9542 8.32368 739.94 -43.15];
Acoeffs(2,1:5) = [268 130286.05 9.00272 947.54 -24.28];
Acoeffs(3,:) = [408 3649825.9 Acoeffs(2,3:5) 268 407.1 2.6705 -19.64 2792];

% RHO, liquid density at saturation
% Range: 188 K < T < 326K.
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Thermodynamic Properties of Organic Compounds and Their Mixtures, vol. 8B.
% R. Wilhoit, K. Marsh, X.  Hong, N. Gadalla and M. Frenkel (1996).
% rhocoeffs:   [Tmax A B C D 0 0]
%  or          [Tmax A B C D Tc rhoc]
M = 58.124; % VDI-Wärmeatlas, siehe unten bei kritischen Größen
rhocoeffs = zeros(2,7);
rhocoeffs(1,1:5) = [326 870.93 -1.36494 2.56419e-3 -5.32743e-6];
rhocoeffs(2,:) = [407.8 0.840589 -0.0242474 3.07814e-4 -1.40048e-6 407.8 224];
rhofun = {@poly3, @rholandolt};

% V, specific volume of the gas
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Virial Coefficients of Pure Gases and Mixtures, vol. 21A: J H. Dymond, K.N.
% Marsh, R.C. Wilhoit and K.C. Wong, Virial Coefficients of Pure Gases and
% Mixtures (2002)
% Landolt-Börnstein gives M = 58.12, see p. 17 in
% ~/Literatur/pdfs/Landolt/LandoltIV21A169-192.pdf
vcoeffs = [[116.25 -1.0293e5 -1.2475e7 -7.0490e9]/1e3 R M];
virialfun = @pdiv3;

% CPID, specific heat capacity in the ideal gas state at constant pressure
% See Table 2-198 in Perry's Chemical Engineer's Handbook, 7th ed. (1997).
% Range: 200 K < T < 1500 K
cpcoeffs = [0.6549e5/M 2.4776e5/M 1.587e3 1.575e5/M -706.99];
cpfun = @cpperry;

% MUL, dynamic viscosity of the liquid
% See Viswanath et al., chap. 4.3.1.3c in Viscosity of Liquids (2007).
% Report correlations by Daubert and Danner, Physical and Thermodynamic Proper-
% ties of Pure Chemicals -- Data Compilation, Design Institute for Physical
% Properties Data, AIChE, Taylor and Francis, Washington DC (1989-1994).
% isobutane
% Range: 190 K < T < 400 K
mulcoeffs = [-18.345 1020.3 1.0978 -6.1e-27 10];
mulfun = @mudaubert;

% MUG, dynamic viscosity of the vapor
% See VDI Wärmeatlas, 9th ed. (2002). A correlation by Lucas (also reported by
% Reid, Prausnitz and Poling, 4th ed., 1987 or by Perry, 7th ed., 1997) is used.
% Critical constants are taken from VDI Wärmeatlas, pages Da 6 - Da 15.
% mugcoeffs = [M Tc pc Zc dipol];
%  Tc [K], pc [Pa] public; mugcoeffs = [Zc, dipol [debye]];
Tc = 408.2; pc = 3.65e6;
mugcoeffs = [0.283 0.1 R M Tc pc];
mugfun = @mulucas;

% KG, thermal conductivity of the vapor [W/mK]
% See p. 498 in Reid, Prausnitz and Poling, 4th ed. (1987).
kgcoeffs = [M Tc pc 9.55];
kgfun = @kgroy;

% KL, thermal conductivity of the liquid [W/mK]
% A correlation by Latini and coworkers (Baroncini et al., 1981) in the form
% kl = A(1-Tr)^0.38/Tr^(1/6).  See pp. 549 in Reid, Prausnitz and Poling, 4th
% ed. (1987). A is determined from VDI-Wärmeatlas 9th ed. (2002).
% kl = 0.105 W/mK at 0°C. (But webbook.nist.gov/chemistry: kl = 0.0986 )
klcoeffs = [Tc .1495];
klfun = @klatini;

% CPL, specific heat capacity at constant pressure of the liquid [J/kgK].
% See Perry, 7th ed. (1997), Table 2-196.
% Range: 113.54 K < T < 380 K
cplcoeffs = [1.7237e5 -1.7839e3 14.759 -4.7909e-2 5.805e-5]/M;
cplfun = @poly4;

% SIGMA, surface tension [N/m].
% Stephan and Hildwein, Recommended data of selected compounds and binary
% mixtures, Chemistry Data Series (DECHEMA, 1987). Their eq. (22).
% Stephan: Tc = 408.15 K, pc = 36.48 bar.
% Range: 113.74 K < T < 408.15 K
% sigcoeffs = [a1 a2 Tc]
sigcoeffs = [0.0505731 1.24412 408.15];
sigfun = @sigstephan22;

case 'butane'
% Butane. n-butane. CAS 106-97-8.

% PS, saturation pressure, coefficients for the Antoine eq.
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Vapor Pressure of Chemicals, vol. 20A. J. Dykyj, J. Svoboda, R.C. Wilhoit,
% M.  Frenkel, K.R. Hall (1999).
% Range: 134.8 K < T < 425.1 K

% classical Antoine eq.: Tmax pmax A B C 0  0  0 0 0
% extended Antoine eq.:  Tmax pmax A B C T0 Tc n E F
Acoeffs =  zeros(3,10);
Acoeffs(1,1:5) = [196 1392.0841 9.0127 961.7 -32.14];
Acoeffs(2,1:5) = [288 175093.793 8.93266 935.773 -34.361];
Acoeffs(3,:) = [425.1 3723052.4 Acoeffs(2,3:5) 288 425.1 2.14767 -175.62 12204];

% RHO, liquid density at saturation
% Range: 134.86 K < T < 425.12 K.
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Thermodynamic Properties of Organic Compounds and Their Mixtures, vol. 8B.
% R. Wilhoit, K. Marsh, X. Hong, N. Gadalla and M. Frenkel (1996).
% rhocoeffs:   [Tmax A B C D 0 0]
%  or          [Tmax A B C D Tc rhoc]
M = 58.124; % VDI-Wärmeatlas, siehe unten bei kritischen Größen
rhocoeffs = zeros(2,7);
rhocoeffs(1,1:5) = [340 892.907 -1.45679 2.87931e-3 -5.35281e-6];
rhocoeffs(2,:) = [425.12 .724403 -.0198517 2.40924e-4 -1.05134e-6 425.12 228];
rhofun = {@poly3, @rholandolt};

% V, specific volume of the gas
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Virial Coefficients of Pure Gases and Mixtures, vol. 21A: J H. Dymond, K.N.
% Marsh, R.C. Wilhoit and K.C. Wong, Virial Coefficients of Pure Gases and
% Mixtures (2002)
% Landolt-Börnstein gives M = 58.12, see p. 15 in
% ~/Literatur/pdfs/Landolt/LandoltIV21A169-192.pdf
vcoeffs = [[227.20 -2.2797e5 2.9855e7 -1.3706e10]/1e3 R M];
virialfun = @pdiv3;

% CPID, specific heat capacity in the ideal gas state at constant pressure
% See Table 2-198 in Perry's Chemical Engineer's Handbook, 7th ed. (1997).
% Range: 200 K < T < 1500 K
cpcoeffs = [0.7134e5/M 2.43e5/M 1.63e3 1.5033e5/M 730.42];
cpfun = @cpperry;

% MUL, dynamic viscosity of the liquid
% See Viswanath et al., chap. 4.3.1.3c in Viscosity of Liquids (2007).
% Report correlations by Daubert and Danner, Physical and Thermodynamic Proper-
% ties of Pure Chemicals -- Data Compilation, Design Institute for Physical
% Properties Data, AIChE, Taylor and Francis, Washington DC (1989-1994).
% Range: 134.86 K < T < 420 K
mulcoeffs = [-7.2471 534.82 -0.57469 -4.6625e-27 10];
mulfun = @mudaubert;

% MUG, dynamic viscosity of the vapor
% See VDI Wärmeatlas, 9th ed. (2002). A correlation by Lucas (also reported by
% Reid, Prausnitz and Poling, 4th ed. (198) or by Perry, 7th ed. (1997) is used.
% Critical constants are taken from VDI Wärmeatlas, pages Da 6 - Da 15.
% mugcoeffs = [M Tc pc Zc dipol];
%  Tc [K], pc [Pa] public; mugcoeffs = [Zc, dipol [debye]];
Tc = 425.2; pc = 3.8e6;
mugcoeffs = [0.274 0 R M Tc pc];
mugfun = @mulucas;

% KG, thermal conductivity of the vapor [W/mK]
% See p. 498 in Reid, Prausnitz and Poling, 4th ed. (1987).
kgcoeffs = [M Tc pc 9.59];
kgfun = @kgroy;

% KL, thermal conductivity of the liquid [W/mK]
% A correlation by Latini and coworkers (Baroncini et al., 1981) in the form
% kl = A(1-Tr)^0.38/Tr^(1/6).  See pp. 549 in Reid, Prausnitz and Poling, 4th
% ed. (1987). A is determined from VDI-Wärmeatlas 9th ed. (2002).
% kl = 0.109 W/mK at 20°C. (But webbook.nist.gov/chemistry: kl = 0.1068 )
klcoeffs = [Tc .1598];
klfun = @klatini;

% CPL, specific heat capacity at constant pressure of the liquid [J/kgK].
% See Perry, 7th ed. (1997), Table 2-196.
% Range: 113.54 K < T < 380 K
cplcoeffs = [64.73 1.6184e5 983.41 -1.4315e3 Tc M];
cplfun = @cpleq2;

% SIGMA, surface tension [N/m].
% Stephan and Hildwein, Recommended data of selected compounds and binary
% mixtures, Chemistry Data Series (DECHEMA, 1987). Their eq. (22).
% Stephan: Tc = 425.16 K, pc = 37.97 bar.
% Range: 134.84 K < T < 425.16 K
% sigcoeffs = [a1 a2 Tc]
sigcoeffs = [0.0513853 1.20933 425.16];
sigfun = @sigstephan22;

case 'ethanol'
% Ethanol. CAS 64-17-5.

% PS, saturation pressure, coefficients for the Antoine eq.
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Vapor Pressure of Chemicals, vol. 20B: J. Dykyj, J. Svoboda, R.C. Wilhoit,
% M.  Frenkel, K.R. Hall (2000).
% Range: 269 K < T < 514 K

% classical Antoine eq.:      [ Tmax pmax A B C 0 0 0 0 0 ]
% extended Antoine eq.:       [ Tmax pmax A B C T0 Tc n E F ]
Acoeffs =  zeros(3,10);
Acoeffs(1,1:5) = [341.2 66637.471 10.33675 1648.22 -42.232];
Acoeffs(2,1:5) = [358 130546.81 9.92365 1410.46 -64.636];
Acoeffs(3,:) = [514 16177606 Acoeffs(2,3:5) 358 513.9 0.434294 -255.71 300056];

% RHO, liquid density at saturation
% Range: 191.5 K < T < 514.1 K.
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Thermodynamic Properties of Organic Compounds and Their Mixtures, vol. 8G.
% M. Frenkel, X.  Hong, R. Wilhoit, K. Hall (2000).
% rhocoeffs:   [Tmax A B C D 0 0]
%  or          [Tmax A B C D Tc rhoc]
M = 46.069; % VDI Wärmeatlas, siehe weiter unten bei critical constants
rhocoeffs = zeros(2,7);
rhocoeffs(1,1:5) = [400 1162.39 -2.25788 5.30621e-3 -6.63070e-6];
rhocoeffs(2,:) = [514.1 1.73318 -358.319 3.19777e-4 -1.03287e-6 514.1 276];
rhofun = {@poly3, @rholandolt};

% V, specific volume of the gas
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Virial Coefficients of Pure Gases and Mixtures, vol. 21A: J H. Dymond, K.N.
% Marsh, R.C. Wilhoit and K.C. Wong, Virial Coefficients of Pure Gases and
% Mixtures (2002)
vcoeffs = [[9.6838e3 -1.3575e7 6.3248e9 -1.0114e12]/1e3 R M];
virialfun = @pdiv3;

% CPID, specific heat capacity in the ideal gas state at constant pressure
% See Table 2-198 in Perry's Chemical Engineer's Handbook, 7th ed. (1997).
% Range: 200 K < T < 1500 K
cpcoeffs = [0.492e5/M 1.4577e5/M 1.6628e3 0.939e5/M 744.7];
cpfun = @cpperry;

% MUL, dynamic viscosity of the liquid
% See Viswanath et al., chap. 4.3.1.3c in Viscosity of Liquids (2007).
% Report correlations by Daubert and Danner, Physical and Thermodynamic Proper-
% ties of Pure Chemicals -- Data Compilation, Design Institute for Physical
% Properties Data, AIChE, Taylor and Francis, Washington DC (1989-1994).
% Range: 240 K < T < 440 K
mulcoeffs = [8.049 776 -3.068 0 0];
mulfun = @mudaubert;

% MUG, dynamic viscosity of the vapor
% See VDI Wärmeatlas, 9th ed. (2002). A correlation by Lucas (also reported by
% Reid, Prausnitz and Poling, 4th ed. (1987) or by Perry, 7th ed. (1997) is
% used.  Critical constants are taken from VDI Wärmeatlas, pages Da 6 - Da 15.
% mugcoeffs = [M Tc pc Zc dipol];
%  Tc [K], pc [Pa] public; mugcoeffs = [Zc, dipol [debye]];
Tc = 513.9; pc = 6.14e6;
mugcoeffs = [0.24 1.7 R M Tc pc];
mugfun = @mulucas;

% KG, thermal conductivity of the vapor at approx. 1 bar [W/mK].
% See Reid, Prausnitz and Poling, 4th ed. (1987). They report a correlation by
% Miller, Shah and Yaws, Chem. Eng. 83, 153 (1976).
% Range: 273 K < T < 1270 K
kgcoeffs = [-7.797e-3 4.167e-5 1.214e-7 -5.184e-11];
kgfun = @poly3;

% KL, thermal conductivity of the liquid [W/mK]
% A correlation by Miller, McGinley and Yaws, Chem. Eng. 83, 133-153 (1976).
% See pp. 546 in Reid, Prausnitz and Poling, 4th ed. (1987).
% Range: 160 K < T < 463 K
klcoeffs = [.2629 -3.847e-4 2.211e-7];
klfun = @poly2;

% CPL, specific heat capacity at constant pressure of the liquid [J/kgK].
% See Perry, 7th ed. (1997), Table 2-196.
% Range: 159.05 K < T < 390 K
cplcoeffs = [1.0264e5 -139.63 -3.0341e-2 2.0386e-3]/M;
cplfun = @poly3;

% SIGMA, surface tension [N/m].
% Stephan and Hildwein, Recommended data of selected compounds and binary
% mixtures, Chemistry Data Series (DECHEMA, 1987). Their eq. (23).
% Stephan: Tc = 513.92 K, pc = 61.37 bar.
% Range: 158.5 K < T < 513.92 K
% sigcoeffs = [a1 a2 a3 Tc]
sigcoeffs = [0.0726009 1.08415 -.524168 513.92];
sigfun = @sigstephan23;

case 'nitrogen'
% Nitrogen. CAS 7727-37-9.

% PS, saturation pressure, coefficients for the Antoine eq.
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Vapor Pressure of Chemicals, vol. 20C: J. Dykyj, J. Svoboda, R.C. Wilhoit,
% M. Frenkel, K.R. Hall (2001).
% Range:  63.5 K < T < 126.2 K
% classical Antoine eq.:      [ Tmax pmax A B C 0 0 0 0 0 ]
% extended Antoine eq.:       [ Tmax pmax A B C T0 Tc n E F ]
Acoeffs =  zeros(2,10);
Acoeffs(1,1:5) = [80 136931.93 8.69633 265.684 -5.366];
Acoeffs(2,:) = [126.2 6069220.85 Acoeffs(1,3:5) 80 126.2 0.434294 15.32 -15.5];

% RHO, liquid density at saturation
% Range: 63.15 K < T < 126.2 K
% See Table 2-30 in Perry's Chemical Engineer's Handbook, 7th ed. (1997).
% Some kind of Rackett equation, i suppose.
M = 28.013;  % VDI-Wärmeatlas, siehe unten bei kritischen Größen
%rhocoeffs = zeros(1,7);
rhocoeffs(1,1:6) = [126.2 3.2091 0.2861 126.2 0.2966 M];
%rhocoeffs(1,1:5) = [126.2*M 3.2091 0.2861 126.2 0.2966];
rhofun{1} = @rhoperry;

% V, specific volume of the gas
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Virial Coefficients of Pure Gases and Mixtures, vol. 21A: J H. Dymond, K.N.
% Marsh, R.C. Wilhoit and K.C. Wong, Virial Coefficients of Pure Gases and
% Mixtures (2002)
vcoeffs = [[40.286 -9.3378e3 -1.4164e6 6.1253e7 -2.7198e9]/1e3 R M];
virialfun = @pdiv4;

% CPID, specific heat capacity in the ideal gas state at constant pressure
% See Table 2-198 in Perry's Chemical Engineer's Handbook, 7th ed. (1997).
% Range: 50 K < T < 1500 K
cpcoeffs = [0.2911e5/M 0.0861e5/M 1.7016e3 100/M 909.79];
cpfun = @cpperry;

% MUL, dynamic viscosity of the liquid
% See Viswanath et al., chap. 4.3.1.3c in Viscosity of Liquids (2007).
% Report correlations by Daubert and Danner, Physical and Thermodynamic Proper-
% ties of Pure Chemicals -- Data Compilation, Design Institute for Physical
% Properties Data, AIChE, Taylor and Francis, Washington DC (1989-1994).
% Range: 63.15 K < T < 125 K
%mulcoeffs = [29.236 496.9 3.9069 -1.08e-21 10];
%mulfun = @mudaubert;
%  GAVE mul = 6.67e22 Pas, 19. Sep. 2014, commit a7b0e08, bf98b90 and before.

% MUL, dynamic viscosity of the liquid [Pas].
% See VDI Wärmeatlas, 11th ed. (2013). D3.1 Flüssigkeiten und Gase: Michael
% Kleiber und Ralph Joh. The caption to Tabelle 7, p. 59, says that mul is given
% in mPas, but the unit really is Pas.
% See also ~/Literatur/pdfs/VDI/VDI2013D3.pdf
mulcoeffs = [2.23392 0.01273 127.145 36.807 1.343e-5];
mulfun = @vdi02;

% MUG, dynamic viscosity of the vapor
% See VDI Wärmeatlas, 9th ed. (2002). A correlation by Lucas, also reported by
% Reid, Prausnitz and Poling, 4th ed. (1987) or by Perry, 7th ed. (1997) is
% used. Critical constants are taken from VDI Wärmeatlas, pages Da 6 - Da 15.
% mugcoeffs = [M Tc pc Zc dipol];
%  Tc [K], pc [Pa] public; mugcoeffs = [Zc, dipol [debye]];
Tc = 126.2; pc = 3.39e6;
mugcoeffs = [0.29 0 R M Tc pc];
mugfun = @mulucas;

% KG, thermal conductivity of the vapor at approx. 1 bar [W/mK].
% See Reid, Prausnitz and Poling, 4th ed. (1987). They report a correlation by
% Miller, Shah and Yaws, Chem. Eng. 83, 153 (1976).
% Range: 115 K < T < 1470 K
kgcoeffs = [3.919e-4 9.816e-5 -5.067e-8 1.504e-11];
kgfun = @poly3;

% KL, thermal conductivity of the liquid [W/mK]
% A correlation by Miller, McGinley and Yaws, Chem. Eng. 83, 133-153 (1976).
% See pp. 546 in Reid, Prausnitz and Poling, 4th ed. (1987).
% Range: 64 K < T < 121 K
klcoeffs = [.2629 -1.545e-3 -9.45e-7];
klfun = @poly2;

% CPL, specific heat capacity at constant pressure of the liquid [J/kgK].
% See Perry, 7th ed. (1997), Table 2-196.
% Range: 159.05 K < T < 390 K
cplcoeffs = [1.0264e5 -139.63 -3.0341e-2 2.0386e-3]/M;
cplfun = @poly3;

% SIGMA, surface tension [N/m].
% A correlation from VDI-Wärmeatlas, eq. (91), p. Da 37, is fit to one data
% point at T = 29.23 K, source 82B3.
sigcoeffs = [2.4954e-07 Tc pc];
sigfun = @sigvdi;

case 'propane'
% Propane. CAS 74-98-6. C_3 H_8

% PS, saturation pressure, coefficients for the Antoine eq.
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Vapor Pressure of Chemicals, vol. 20A: J. Dykyj, J. Svoboda, R.C. Wilhoit,
% M. Frenkel and K.R. Hall (1999).
% See also ~/Literatur/pdfs/Landolt/LandoltIV20A14-29.pdf
% Range:  85.5 K < T < 369.8 K
% classical Antoine eq.:      [ Tmax pmax A B C 0 0 0 0 0 ]
% line in Landolt-Börnstein:     A-3  B  C  Dmin/Dmax  Tmin/Tmax
% extended Antoine eq.:       [ Tmax pmax A B C T0 Tc n E F ]
% line in Landolt-Börnstein:     A-3  B  C  Dmin/Dmax  Tmin/Tmax
%                                (n) (E) (F)
% Table in Landolt-Börnstein
% 9    C3H8            Propane                                           74-98-6
% l-g  6.6956   1030.7   -7.79    101/165  85.5/167 B  231.07/101.325  74-trchc
% l-g  5.92828  803.997  -26.11   270/248  167/237 A                   74-trchc
% l-g  5.92828  803.997  -26.108  248/369  237/369.8 A                 74-trchc
%      (2.55753) (50.655) (-1408.9)
% Does not vectorize.
Acoeffs =  zeros(3,10);
Acoeffs(1,1:5) = [167 1666.32 9.6956 1030.7 -7.79];
Acoeffs(2,1:5) = [237 130581.0 8.92828 803.997 -26.11];
Acoeffs(3,:) = [369.8 4247600 Acoeffs(2,3:5) 237 369.8 2.55753 50.655 -1408.9];

% critical constants, from VDI Wärmeatlas, 2013, Table D3.1
% See also ~/Literatur/pdfs/VDI/VDI2013D3
M = 44.10; Tc = 369.82; % pc = 4.248e6;
% Landolt-Börnstein also gives M = 44.10, see
% ~/Literatur/pdfs/Landolt/LandoltIV21A151-168.pdf

% RHO, liquid density at saturation
% Range:  85.47 K < T < 369.83 K
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Thermodynamic Properties of Organic Compounds and Their Mixtures, vol. 8B:
% R. Wilhoit, K. Marsh, X. Hong, N. Gadalla and M. Frenkel (1996).
% See also ~/Literatur/pdfs/Landold/LandoltIV8B16-44.pdf
% rhocoeffs:   [Tmax A B C D E 0]
%  or          [Tmax A B C D Tc rhoc]
% Does not vectorize.
rhocoeffs = [288 820.464 -1.013 -2.71229e-4 3.32129e-6 -1.12912e-8 0;...
             369.83 .490105 -.0132372 1.66441e-4 -7.6597e-7 369.83 220];
rhofun = {@poly4, @rholandolt};

% V, specific volume of the gas
% Range:  250 K < T
% See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
% Virial Coefficients of Pure Gases and Mixtures, vol. 21A: J H. Dymond,
% K.N. Marsh, R.C. Wilhoit and K.C. Wong (2002).
% See also ~/Literatur/pdfs/Landolt/LandoltIV21A169-192.pdf
% B [cm^3/mol] = A + B/T + C/T^2 + D/T^3.
% vcoeffs = [A B C D R M];
% Vectorizes!
vcoeffs = [[109.71 -8.4673e4 -8.1215e6 -3.4382e9]/1e3 R M];
virialfun = @pdiv3;

% CPID, specific heat capacity in the ideal gas state at constant pressure
% See VDI Wärmeatlas, 11th ed. (2013). D3.1 Flüssigkeiten und Gase: Michael
% Kleiber und Ralph Joh.
% See also ~/Literatur/pdfs/VDI/VDI2013D3.pdf, Tabelle 6, S. 52.
% Tabelle 6 states that J/gK is returned, eq. 10 refers to J/kgK. The latter is
% correct.
% Vectorizes!
cpcoeffs = [1089.3798 4.7246 -1.1767 3.7776 129.3687 -281.4223 216.9425 R/M];
cpfun = @vdi10;

% MUL, dynamic viscosity of the liquid [Pas].
% See VDI Wärmeatlas, 11th ed. (2013). D3.1 Flüssigkeiten und Gase: Michael
% Kleiber und Ralph Joh. The caption to Tabelle 7, p. 59, says that mul is given
% in mPas, but really the unit is Pas.
% See also ~/Literatur/pdfs/VDI/VDI2013D3.pdf
% Vectorizes!
mulcoeffs = [2.56344 0.16137 372.533 38.033 1.751e-5];
mulfun = @vdi02;

% MUG, dynamic viscosity of the vapor [Pas]
% See VDI Wärmeatlas, 11th ed. (2013). D3.1 Flüssigkeiten und Gase: Michael
% Kleiber und Ralph Joh. Tabelle 8 claims to report the viscosity in muPas,
% but really the unit is Pas.
% See also ~/Literatur/pdfs/VDI/VDI2013D3.pdf
% Vectorizes!
mugcoeffs = [7.353e-7 2.0874e-8 2.4208e-11 -3.914e-14 1.784e-17];
mugfun = @poly4;

% KG, thermal conductivity of the vapor at low pressures [W/mK].
% See VDI Wärmeatlas, 11th ed. (2013). D3.1 Flüssigkeiten und Gase: Michael
% Kleiber und Ralph Joh. Tabelle 10.
% See also ~/Literatur/pdfs/VDI/VDI2013D3.pdf
% Vectorizes!
kgcoeffs = [-6.656e-3 5.280e-5 1.01810e-7];
kgfun = @poly2;

% KL, thermal conductivity of the saturated liquid [W/mK]
% See VDI Wärmeatlas, 11th ed. (2013). D3.1 Flüssigkeiten und Gase: Michael
% Kleiber und Ralph Joh. Tabelle 9.
% See also ~/Literatur/pdfs/VDI/VDI2013D3.pdf
% Vectorizes!
klcoeffs = [0.2661 -6.336e-4 5.7e-8 6.55e-10 -7.01e-13];
klfun = @poly4;

% CPL, specific heat capacity at constant pressure of the liquid [J/kgK].
% See VDI Wärmeatlas, 11th ed. (2013). D3.1 Flüssigkeiten und Gase: Michael
% Kleiber und Ralph Joh. Tabelle 5.
% Do not multiply all coefficients by 1000*R/M, only by R/M, although Tabelle 5
% claims to be in J/gK, eq. 8 claims to return J/kgK, which is correct.
% See also ~/Literatur/pdfs/VDI/VDI2013D3.pdf
% Vectorizes!
cplcoeffs = [[0.5219 13.0156 -3.9111 -21.2164 49.1038 -30.2438]*R/M Tc];
cplfun = @vdi08;

% SIGMA, surface tension [N/m].
% See VDI Wärmeatlas, 11th ed. (2013). D3.1 Flüssigkeiten und Gase: Michael
% Kleiber und Ralph Joh. Tabelle 11.  Do not divide coefficient A by 1000;
% Tabelle 11 claims to return surface tension in mN/m, but really returns N/m.
% For two coefficients, eq. 6 is identical to SIGSTEPHAN22.
% Vectorizes!
sigcoeffs = [0.05094 1.22051 Tc];
sigfun = @sigstephan22;

otherwise
error('No substance of this name.')
% water
% MUL, dynamic viscosity of the liquid
% See Viswanath et al., chap. 4.3.1.3c in Viscosity of Liquids (2007).
% Report correlations by Daubert and Danner, Physical and Thermodynamic Proper-
% ties of Pure Chemicals -- Data Compilation, Design Institute for Physical
% Properties Data, AIChE, Taylor and Francis, Washington DC (1989-1994).
% Range: 273.15 K < T < 643.15 K
%mulcoeffs = [-51.964 3670.6 5.7331 -5.349e-29 10];
end
%end case name

% These functions are the same for all substances.

% thermic equations of state
s.R = R/M;
s.ps = @(T) ps(Acoeffs,T);
s.Ts = @(p) Ts(Acoeffs,p);
s.rho = @(T) genericfunc(rhocoeffs,rhofun,T);
s.v = @(T,p) virial('v',vcoeffs,virialfun,T,p);
s.hvap = @(T) hvap(s.ps,s.rho,s.v,T);
% caloric equation of state
% cpid, cpg_cpid - def'd for better readability
cpid = @(T) cpfun(cpcoeffs,T);
% cpg_cpid = cpg(T,p) - cpid; cpid = cp(T,p=0)
cpg_cpid = @(T,p) virial('cp',vcoeffs,virialfun,T,p);
s.cpg = @(T,p) cpgas(cpid(T),cpg_cpid(T,p));
s.mul = @(T) mulfun(mulcoeffs,T);
s.mug = @(T) mugfun(mugcoeffs,T);
s.kg = @(T) kgfun(kgcoeffs,T);
s.kl = @(T) klfun(klcoeffs,T);
s.cpl = @(T) cplfun(cplcoeffs,T);
s.sigma = @(T) sigfun(sigcoeffs,T);
% Derivatives of the thermic equation of state which are equal to
% derivatives of caloric properties are computed in the function virial.
% These helper functions extract the information from the function virial.
s.jt = @(T,p) jt(virial('jt',vcoeffs,virialfun,T,p),cpid(T));
s.dhdp = @(T,p) virial('dhdp',vcoeffs,virialfun,T,p);
s.dhcpg = @(T,p) dhcpg(virial('jt',vcoeffs,virialfun,T,p),cpid(T));
% The functions that return derivatives have a 'd' prepended.
i = length(rhofun);
drhofun = cell(1,i);
for i = 1:i
  drhofun{i} = str2func(['d' func2str(rhofun{i})]);
end
s.drho = @(T) genericafun(rhocoeffs,drhofun,T);
s.dsig = @(T) feval(str2func(['d' func2str(sigfun)]),sigcoeffs,T);
s.intjt = @(T0,p0,p1) intjt(T0,p0,p1,@(p,T) s.jt(T,p));
% Integrals of a function have a 'i' prepended.
s.intcpl = @(T0,T1) feval(str2func(['i' func2str(cplfun)]),cplcoeffs,T0,T1);
intcpl_T = @(T1,T2)feval(str2func(['i' func2str(cplfun) '_x']),cplcoeffs,T1,T2);
s.s = @(T,p,x,Tr) ...
  entropy(T,p,x,Tr,virialfun,vcoeffs,cpid,intcpl_T,s.ps,s.Ts,s.hvap,s.drho);
% Auxiliary functions, for convenience.
s.nul = @(T) s.mul(T)./s.rho(T);
s.nug = @(T,p) s.mug(T).*s.v(T,p);

function y = genericfunc(coeffs,functions,T)
%GENERICFUNC Apply a correlation function at temperature T.
%
%  GENERICFUNC(COEFFS,FUNCTIONS,T) Applies a correlation function in the cell
%  array FUNCTIONS to the correlation coefficients COEFFS. COEFFS(I,1) is the
%  maximum temperature up to which the function FUNCTIONS(I) is valid.

i = find(T <= coeffs(:,1), 1);

% Check of T <= Tc commented out.
%if isempty(i)
  % we are probably at T > Tc
%  y = NaN;
%else
  y = functions{i}(coeffs(i,2:end),T);
%end

function [y1,y2] = genericafun(coeffs,functions,T)
%GENERICAFUN Apply a correlation function at temperature T, returns an array.
%
%  GENERICAFUN(COEFFS,FUNCTIONS,T) Applies a correlation function in the cell
%  array FUNCTIONS to the correlation coefficients COEFFS. COEFFS(I,1) is the
%  maximum temperature up to which the function FUNCTIONS(I) is valid.
%  GENERICAFUN returns two output arguments, in contrast to GENERICFUN.

i = find(T <= coeffs(:,1), 1);

% Check of T <= Tc commented out.
%if isempty(i)
  % we are probably at T > Tc
%  y1 = NaN; y2 = NaN;
%else
  [y1,y2] = functions{i}(coeffs(i,2:end),T);
%end

function cpid = cpperry(C,T)
%CPID       Specific heat capacity at constant pressure in the ideal gas state.
%
%  CPID(CPCOEFFS,T) returns the specific heat capacity at constant pressure in
%  the ideal gas state, [J/kgK]. An equation to Table 2-198 in Perry's Chemical
%  Engineer's Handbook, 7th ed. (1997) is used.

c3t=C(3)./T;
c5t=C(5)./T;

cpid = C(1) + C(2)*(c3t./sinh(c3t)).^2 + C(4)*(c5t./cosh(c5t)).^2;

function cpid = vdi10(C,T)
%VDI10      Specific heat capacity at constant pressure in the ideal gas state.
%
%  VDI10(CPCOEFFS,T) uses eq. 10 in VDI Wärmeatlas, 11th ed. (2013), D3.1
%  Flüssigkeiten und Gase: Michael Kleiber und Ralph Joh, to return
%  the specific heat capacity at constant pressure in the ideal gas state in
%  units of J/kgK. Coefficients are already scaled to return J/kgK. The caption
%  to Tabelle 6 claims to return J/gK, but really J/kgK are returned.

at = T./(C(1) + T);
at2 =at.^2;
cpid = C(8).*( C(2) + (C(3)-C(2)).*at2.*(1.0-(C(1)./(C(1)+T)).*...
       (C(4) + C(5).*at + C(6).*at2 + C(7).*at2.*at)));

function cpg = cpgas(cpid,cpg_cpid)
%CPGAS      Specific heat capacity at constant pressure of the vapor  [J/kgK].
%
%  CPGAS(CPID,CPG_CPID) calculates the specific heat capacity at constant
%  pressure in the gaseous state from
%
%    cpg(T,p) = cpid(T) + 0_int^p (dcp/dp)_T dp,
%
%  where cpid is the specific isobaric heat capacity in the ideal gas state,
%  i.e., p -> 0, 0_int^p is the notation for the definite integral from 0 to p
%  and (df/dx)_y is the partial derivative of f(x,y) with respect to x. The
%  integral above is evaluated in VIRIAL by using the identity
%
%    (dcp/dp)_T = -T (d^2v/dT^2)_p.

% The identity above is obtained from the second law of thermodynamics,
%  Tds = dh - vdp.
% Substituting dh = (dh/dT)_p dT + (dh/dp)_T dp yields
%  ds = (dh/dT)_p/T dT + [(dh/dp)_T - v]/T dp.
% The integrability condition demands
%  (d/dp)_T [(dh/dT)_p/T] = (d/dT)_p {[(dh/dp)_T - v]/T}.
% After differentiation, the terms d^2h/dTdp cancel and we have
%  (dh/dp)_T = v - T(dv/dT)_p.
% Hence, with the definition of cp we obtain
%  (dcp/dp)_T = d^2h/dpdT = (d/dT)_p(dh/dp)_T
%    = (dv/dT)_p - (dv/dT)_p - T(d^2v/dT^2)_p.

% Comparison with nist:
%
%  substance (T [K],p [Pa])      cp(Nist)   cpg
%  butane    (273.15,1.0349e5)   1653.5     1632.8
%  butane    (303.15,2.8383e5)   1849.2     1824.6
%  isobutane (303.15,4.0451e5)   1860.4     1825.7
%  isobutane (353.15,13.427e5)   2456.5     2463.0
%  nitrogen  (77.244,1e5)        1124.3     1121.3

cpg = cpid + cpg_cpid;

function hvap = hvap(ps,rho,v,T)
%HVAP       Specific enthalpy of vaporization [J/kg].
%
%  HVAP(PS,RHO,V,T) returns the specific enthalpy of vaporization calculated by
%  applying Clausius-Clapeyron's equation,
%
%    dps/dT = hvap/(T(v - 1/rho)).
%
%  PS, RHO and V are function handles to functions that return [PS DPS], RHO and
%  V, respectively.

[psat, dpsat] = ps(T);
hvap = dpsat.*T.*(v(T,psat)-1./rho(T));

function v = virial(out,vcoeffs,virialfun,T,p)
%VIRIAL     Specific volume of the vapor [m3/kg].
%
%  VIRIAL('V',VCOEFFS,VIRIALFUN,T,P) calculates the specific volume of the vapor
%  by an virial equation truncated after the first virial coefficient, B(T).
%
%  VIRIAL('CP',VCOEFFS,VIRIALFUN,T,P) returns cpg_cpid = CP(T,P) - CP(T,P->0) by
%  integrating  0_int^p (dcp/dp)_T dp  (see CPG).
%
%  VIRIAL('DHDP',VCOEFFS,VIRIALFUN,T,P) returns the derivative dh/dp.
%
%  VIRIAL('JT',VCOEFFS,VIRIALFUN,T,P) returns the array [dh/dp cpg_cpid] for
%  calculation of the Joule-Thomson coefficient.
%
%  Strings 'V', 'CP', etc. are all lowercase.

%  The virial equation is
%
%    pv/RT = 1 + B/v + O(1/v)^2
%
%  with v being here the molar volume, [v] = m^3/kmol, and R the universal gas
%  constant, [R] = J/kmolK. Chopping off the O(1/v)-term yields
%
%    v = (1/2)RT/p + sqrt( (1/4)(RT/p)^2 + BRT/p ).
%
%  Continuing now with [v] = m^3/kg (v -> v/M),
%
%    vM2p/R = T + sqrt( T^2 + 4BTp/R ), with a = 4p/R yields
%
%    dv/dT M2p/R = 1 + 1/2 (T^2 + aBT)^(-1/2) (2T + aB + aB'T)
%
%    d^2v/dT^2 M2p/R = -1/4 (T^2 + aBT)^(-3/2) (2T + aB + aB'T)^2 + 1/2 (T^2
%      + aBT)^(-1/2) (2 + 2aB' + aB''T)
%      = a^2(-B^2 - (B'T)^2 + 2BB'T + 2B''T^3/a + 2BB''T^2)/ 4(T^2 + aBT)^(3/2).
%                          [(B-B'T)^2 - 2BB''T^2](2/R^2T^2)p - B''T^2/RT
%   -T (d^2v/dT^2)_p M/R = ---------------------------------------------
%                                      (1 + 4pB/RT)^(3/2)
% In[1]:=  (((B[T] - T  B'[T])^2 - 2 B[T] B''[T] T^2)*(2 p/(R T)^2)
%    -  B''[T] T^2/(R T))/(1 + 4 p B[T]/(R T))^(3/2);
% In[2]:=  Simplify[% == -T*D[T/(2*p) + T/(2*p)*Sqrt[1 + 4B[T]p/(R*T)], T, T] ]
%
% Out[2]= True
%
%  With c1 = [(B-B'T)^2 - 2BB''T^2](2/R^2T^2), c2 =  B''T^2/RT, c3 = 4B/RT
%  the indefinite integral is
%   int (c1p-c2)(1+c3p)^(-3/2) dp = (2/c3)(c1p + 2c1/c3 + c2)(1+c3p)^(-1/2).
%  The definite integral yields, with SQR = sqrt(1 + p4B/RT)
%                                       2c1   p + 2/c3   2      2c2    1
%   0_int^p (c1p-c2)(1+c3p)^(-3/2) dp = --- ( -------- - -- ) + --- ( --- - 1 )
%                                        c3    SQR       c3      c3   SQR
% In[3]:=  Simplify[ ((2 c1/c3) * (p/SQR + (1/SQR-1)*2/c3) + (1/SQR-1)*2 c2/c3
%         /.SQR -> Sqrt[1 + c3 p] ) == Integrate[(c1 x - c2)/(1 + c3 x)^(3/2),
%         {x, 0, p},  Assumptions -> (c3 p  >= -1 && p > 0)] ]
%
% Out[3]= True
%
%  Hence,
%   cpg - cpid = (R/M){[(B-B'T)^2 - 2BB''T^2]/BRT}[p/SQR + (RT/2B)(1/SQR - 1)]
%    + (B''T^2/2B)(1/SQR-1).
% In[4]:= (((B[T] - T  B'[T])^2 - 2 B[T] B''[T] T^2)/(B[T] R T))*
%         (p1/SQR + (1/SQR-1)* R T/(2 B[T])) + (1/SQR - 1)*B''[T] T^2/(2 B[T]);
%
% In[5]:= Simplify[( %/.SQR->Sqrt[1 + 4B[T]p1/(R*T)] ) == Integrate[-T*D[T/(2*p)
%         + T/(2*p)*Sqrt[1 + 4B[T]p/(R*T)], T, T], {p, 0, p1},
%         Assumptions -> (Re[R*T/(4 B[T] p1)] <= -1 && p1 > 0)] ]
%
% Out[5]= True

%  Continuing for v = (1/2)RT/p + sqrt( (1/4)(RT/p)^2 + BRT/p ). Unit
%  conversions: VIRIALFUN returns the coefficients for B from Landolt-Börnstein
%  in cm^3/mol, hence B = VIRIALFUN/1000 [m^3/kmol] and V = v/M [m^3/kg].
%  Division by 1000 is already done when assigning coefficients.
%  However, since v is given as a series, I believed the correct expression for
%  v would be
%
%    vold = RT/p + B + O(1/V)^3.
%
%  Mathematica says
%
%    1/vseries = p/RT - B (p/RT)^2
%
%  because
%
%    In = virial = SeriesData[rho, 0, {0, 1, B, C}, 0, 4, 1]
%    Out = rho + B rho^2 + C rho^3 + O[rho]^4
%    In = InverseSeries[virial, LHS]
%    Out = LHS - B LHS^2 + (2B^2-C) LHS^3 + O[LHS]^4
%
%  with LHS = p/RT => 1/v = p/RT - B (p/RT)^2.
%
%  Well, sqrt gave best results:
%
%  substance (T [K],p [Pa])      v(Nist)    vold     vseries    vsqr
%  butane    (273.15,1.0349e5)   0.36159    0.3624   0.3630     0.3618
%  butane    (303.15,2.8383e5)   0.13984    0.1409   0.1417     0.1398
%  isobutane (303.15,4.0451e5)   0.095431   0.0967   0.0976     0.0954
%  isobutane (353.15,13.427e5)   0.027985   0.0301   0.0314     0.0273
%
%  Hence, i simply chop off the higher order terms.

R = vcoeffs(end-1);
M = vcoeffs(end);
%vold = (R*T./p+virialfun(vcoeffs,T)/1000)/M
%v = p./(R*T); % v = LHS, interim use of a variable
%vseries = 1./(M*v.*(1 - v.*virialfun(vcoeffs,T)/1e3))
%Bv = v.*virialfun(vcoeffs,T)/1e3;
%vseries3 = 1./(M*v.*(1 - Bv.*(1-2*Bv))) % also worse than vsqr

if strcmp(out,'v') % case 'v'
  % compute the specific volume; call to virialfun with one nargout
  v = R*T./p; % interim use of variable
  v = (0.5*v + sqrt(0.25*v.^2 + virialfun(vcoeffs,T).*v))/M; %( = vsqr)

else % case 'cp' 'dhdp' 'jt'
  % call to virialfun
  [B, B1, B2] = virialfun(vcoeffs,T);
  % for the assignment v = [v ..] in 'dhdp' construct the output variable
  v = [];

  if strcmp(out,'cp') || strcmp(out,'jt') % case 'cp' 'jt'
    % compute cpg-cpid = (R/M) * {[(B-B'T)^2 - 2BB''T^2]/BRT}
    %  * [p/SQR + (RT/2B)(1/SQR - 1)] + (B''T^2/2B)(1/SQR-1).
    v = sqrt(1 + 4*p.*B./(R*T)); % interim use of variable
    sqr1=(1./v - 1);
    v = ((B-B1).^2-2*B.*B2).*(p./v+R.*T.*sqr1./(2*B))./(B.*R.*T)+B2.*sqr1./(2*B);
    v = v*R./M;
  end

  if strcmp(out,'dhdp') || strcmp(out,'jt') % case 'dhdp' 'jt'
    if p == 0
      v = [0 v];
    else
      % compute dh/dp
      % from above, with b = 4p/RT = a/T, B1 = B'T
      % T dv/dT = ( 2 + (2+b(B+B1))/sqrt(1+bB) ) / bM
      w = 4*p./(R.*T); % next interim variable w, w = b
      dhdp = ( 2 + (2+w.*(B+B1))./sqrt(1+w.*B) )./(w*M); % now dhdp = T dv/dT
      % the volume v, copied from above
      w = 4./w; % v = RT/p = a
      w = (0.5*w + sqrt(0.25*w.^2 + B.*w))/M;
      dhdp = w - dhdp; % now dhdp = dh/dp = v - T dv/dT
      % if v was empty, a scalar dhdp is returned, otherwise an array
      v = [dhdp v];
    end
  end

end

function s12 = entropy(T,p,x,Tr,virialfun,vcoeffs,cpid,intcpl_T,ps,Ts,hvap,drho)
%ENTROPY    Difference of specific entropy [J/kgK].
%
%  S(T,P,X,TR) returns the difference of specific entropy between a state given
%  by the Temperature T [K], Pressure P [Pa] and vapor mass fraction X, and a
%  saturated liquid with Temperature TR, S(T,P,X) - S(TR,PS(TR),0). Arguments
%  can be given as single values or row vectors, e.g., T = [T1 T2 T3 ... Tn ].
%  X = 1 or X = 0 may be used to force a subcooled vapor or overheated liquid,
%  respectively.

% s12 = sl(Tr,ps(Tr),Ts(p),p) + hvap(Ts(p))/Ts(p) + sg(Ts(p),p,T,p);
if isempty(T) || isempty(p) || isempty(x) || isempty(Tr)
  s12 = [];
  return
end
% make all vectors
lT = length(T);
lp = length(p);
lx = length(x);
i = max([lT lp lx]);
if i>1
  if lT == 1
    T(1:i) = T;
  end
  if lp == 1
    p(1:i) = p;
  end
  if lx == 1
    x(1:i) = x;
  end
end

s12(1:i) = 0;
psr = ps(Tr);
hvapr = hvap(Tr);
for j = 1:i
  switch x(j)
    case 1
      % vapor contribution to the saturated vapor Tr, ps(Tr)
      % in sl, make sure p=ps(T1). Ts is, in general, not exact.
%      fprintf('ENTROPY: hvap/T @ %.0f = %.4g J/kgK\n',Tr,hvap(Tr)/Tr);
      s12(j) = sg(virialfun,vcoeffs,cpid,Tr,psr,T(j),p(j)) + hvapr/Tr;
%		+ sl(intcpl_T,Ts,ps,drho,Tr,ps(Tr),T1,ps(T1));
    case 0
      s12(j) = sl(intcpl_T,Ts,ps,drho,Tr,psr,T(j),p(j));
    otherwise
      if x(j) > 1 || x(j) < 0
        error(sprintf('Nonsense input: x = %.3g.',x(j)));
      else % 0<x<1
        if p(j) ~= ps(T(j))
          error('For a two-phase state, p must be equal to ps(T)');
        end
        s12(j) = x(j)*hvap(T(j))/T(j); % ...
	%	+ sl(intcpl_T,Ts,ps,drho,Tr,ps(Tr),T(j),p(j));
      end
  end
end

function s12 = sg(virialfun,vcoeffs,cpid,T1,p1,T2,p2)
%SG         Difference of specific entropy in a gaseous state [J/kgK].
%
%  SG(T1,P1,T2) returns S(T2,P1) - S(T1,P1).
%
%  SG(T1,P1,T2,P2) returns S(T2,P2) - S(T1,P1).

% s12 = (cpid1*T2-cpid2*T1)*log(T2/T1)/(T1-T2) + cpid2 - cpid1 ...
%	+ B'(T1)*p1 - B'(T2)*p2 -R*log(p2/p1)
% the logic below just does not calculate terms that become identically zero
if nargin == 6 || p1 == p2
  if T1 == T2
    s12 = 0;
    return
  else
    % calculate, what is necessary below
    s12 = 0;
    R = vcoeffs(end-1);
    M = vcoeffs(end);
    [B, B2] = virialfun(vcoeffs,T2);
    B2 = B2./T2;
  end
else % p1 ~= p2
  % the contribution  Int_p1^p2 dv/dT dp
  R = vcoeffs(end-1);
  M = vcoeffs(end);
  [B, B2] = virialfun(vcoeffs,T2);
  B2 = B2./T2;
%  fprintf('SG: -R log(p2/p1) = %.4g\n',-R.*log(p2./p1)./M);
  s12 = - R.*log(p2./p1)./M - B2*(p2-p1)./M;
%  fprintf('SG: -R log(p2/p1) - B2 (p2-p1) = %.4g\n',s12);
  % This was to unprecise, dv/dT = R/p. With, from above,
  %   v = (1/2)RT/p + sqrt( (1/4)(RT/p)^2 + BRT/p ), because pv/RT = 1 + B/v,
  %   here v is molar volume,  in mathematica we do
  %
  %   D[(1/2) R*T/p + Sqrt[(1/4) (R*T/p)^2 + B[T]*R*T/p],T]
  %   Integrate[%,{p, p1, p2}, Assumptions -> R > 0 && p1 > 0 && p2 > 0
  %      && T > 0 && 0 < R*T + 4*p*B[T] && (p2 < p1|| p2> p1 )]
  %  (the assumptions p1 < p2 || p1 > p2 seem a bug in mathematica)
  % (R*(2*ArcSinh[1/(2*Sqrt[(p1*B[T])/(R*T)])] -
  %   2*ArcSinh[1/(2*Sqrt[(p2*B[T])/(R*T)])] - Sqrt[1 + (4*p1*B[T])/(R*T)] +
  %   Sqrt[1 + (4*p2*B[T])/(R*T)] + Log[p2/p1]))/2 + ((-Sqrt[R*T*(R*T +
  %   4*p1*B[T])] + Sqrt[R*T*(R*T + 4*p2*B[T])])* Derivative[1][B][T])/(2*B[T])
  % B = B[T2]

  % the seemingly more precise estimate
  %B = B/1000;
  %RT = R*T2;
  %B = -( (R*(2*asinh(1/(2*sqrt(p1*B/RT))) - 2*asinh(1/(2*sqrt(p2*B/RT))) ...
  %	- sqrt(1+4*p1*B/RT) + sqrt(1+4*p2*B/RT) + log(p2/p1)))/2 ...
  %	+ ((-sqrt(RT*(RT+4*p1*B)) + sqrt(RT*(RT+4*p2*B)))*B2)/(2*B) )./M;
  %  fprintf('SG: - Int_p1^p2 dv/dT@T2 dp = %.4g\n',B);
end

if T1 ~= T2
  [B, B1] = virialfun(vcoeffs,T1);
  B1 = B1./T1;
  cpid1 = cpid(T1);
  cpid2 = cpid(T2);
  % The isobaric contribution, int_T1^T2 cpid/T dT
  s12 = s12 + (cpid1.*T2-cpid2.*T1).*log(T2./T1)./(T2-T1) + cpid2 - cpid1;
%  fprintf('SG: isobaric contribution Int cpid/T dT = %.4g\n',s12);
%  fprintf('SG: Int (cpg-cpid)/T dT = %.4g\n',(B1-B2).*p1./M);
  s12 = s12 + (B1-B2).*p1./M;
end

%if nargin == 7 && p1 ~= p2
%  if T1 == T2
%    [B, B1] = virialfun(vcoeffs,T1);
%    B1 = B1./(1000.*T1);
%    fprintf('SG: T=const, Int (dv/dT)/T dp = %.4g\n',B1.*(p1-p2)./M);
%    s12 = s12 + B1.*(p1-p2)./M;
%  else
%    fprintf('SG: Int (dv/dT)/T dp = %.4g\n',(B1.*p1-B2.*p2)./M);
%    s12 = s12 + (B1.*p1-B2.*p2)./M;
%  end
%end

function s12 = sl(intcpl_T,Ts,ps,drho,T1,p1,T2,p2)
%SL         Difference of specific entropy in a liquid state [J/kgK].
%
%  SL(T1,P1,T2) returns S(T2,P1) - S(T1,P1).

if nargin == 7
  p2 = p1;
end

p0 = 101325;
Tb = Ts(p0);
%    S.drho(T)      Neg. compressibility, [DRHO RHO] 1/rho drho/dT and rho
[dr, rho] = drho(T1);
v1 = 1./rho;
dv1 = -dr./rho;

if T1 == T2
  s12 = 0;
  v2 = v1;
  dv2 = dv1;
else
  s12 = intcpl_T(T1,T2);
%  return % DEBUG
  [dr, rho] = drho(T2);
  v2 = 1./rho;
  dv2 = -dr./rho;
end
%fprintf('SL: Int cp/T dT = %.4g\n',s12);

if T1 >= Tb && T2 >= Tb
  ps1 = ps(T1);
  if T1 ~= T2
    ps2 = ps(T2);
    s12 = s12 + dv1.*(p1-ps1) - dv2.*(p2-ps2) - (v2-v1).*(ps2-ps1)./(T2-T1);
  else
    s12 = s12 + dv1.*(p1-p2);
  end
elseif T1 <= Tb && T2 <= Tb
  s12 = s12 + dv1.*(p1-p0) - dv2.*(p2-p0);
else % Tb between T1 and T2
  ps2 = ps(T2);
  [dr, rb] = drho(Tb);
  if abs(T2-Tb) > 0.5
    s12 = s12 + dv1.*(p1-p0) - dv2.*(p2-ps2) - (v2-1./rb).*(ps2-p0)./(T2-Tb);
  else
    s12 = s12 + dv1.*(p1-p0) - dv2.*(p2-ps2);
  end
end
%fprintf('SL: s2 - s1  = %.4g\n',s12);

function [ps, dps] = ps(Acoeffs,T)
%PS         Saturation pressure [Pa].
%
%  PS(ANTOINECOEFFS,T) returns the saturation pressure [Pa].
%
%  [P DP] = PS(ANTOINECOEFFS,T) returns the saturation pressure and the
%  derivative of the saturation pressure with respect to T [Pa, Pa/K].
%
%  For T > Tc, more precisely, no ANTOINECOEFFS are found, PS returns [Inf NaN].
%
%  PS calculates the saturation pressure by applying either the classical or an
%  extended Antoine eq., see Landolt-Börnstein, New Series, Group IV: Physical
%  Chemistry.  Vapor Pressure of Chemicals, vol.  20A: J. Dykyj, J. Svoboda,
%  R.C. Wilhoit, M.  Frenkel, K.R. Hall (1999).  ANTOINECOEFFS is a m-by-10
%  matrix, where m is the number of available equations, ANTOINECOEFFS(m,:) =
%  [Tmax pmax A B C T0 Tc n E F]. Tmax and pmax are the values up to which the
%  equation in this line is valid. If T0 == 0 then only A, B and C are set and
%  the classical Antoine eq. is used,
%
%    ps = 10^(a-b/(c+T)).
%
%  If T0 ~= 0 then the saturation pressure is given by
%
%    p = 10^(a - b/(c+T) + 0.43429*chi^n + E*chi^8 + F*chi^12).
%
%  where chi = (T-T0)/Tc.

% Acoeffs(:,1) holds Tmax
i = find(T <= Acoeffs(:,1),1);

% If we do not find a row in Acoeffs, we are most probably at T > Tc.
if isempty(i)
  ps = Inf; dps = NaN;
  return
end

% simple Antoine eq.
[A, B, C, T0] = deal(Acoeffs(i,3),Acoeffs(i,4),Acoeffs(i,5),Acoeffs(i,6));

ps = 10.^(A-B./(C+T));

if T0 ~= 0
  % extended Antoine eq.
  [Tc, n, E, F] = deal(Acoeffs(i,7),Acoeffs(i,8),Acoeffs(i,9),Acoeffs(i,10));
  chi = (T-T0)/Tc;
  ps = ps.*10.^(0.43429.*chi.^n + E.*chi.^8 + F.*chi.^12);
end

% With two output arguments, the derivative is demanded. Mathematica says:
% In[1]:= D[10.^(A-B/(C+T)+0.43429*chi^n+E*chi^8+F*chi^12)/.
%   chi->(T-T0)/Tc,T]/.T0->T-chi*Tc
% Out[2]//InputForm=
% 2.302585092994046*10.^(A + 0.43429*chi^n + chi^8*E + chi^12*F - B/(C + T))*
%  (B/(C + T)^2 + (8*chi^7*E)/Tc + (12*chi^11*F)/Tc +
%   (0.43429*chi^(-1 + n)*n)/Tc)
if nargout==2
  %ln10 = log(10);
  ln10 = 2.302585092994046;
  dps = ln10.*ps.*B./(C + T).^2;
  if T0 ~= 0
    dps = dps+ln10*ps.*(8*chi.^7.*E+12*chi.^11.*F+0.43429.*n.*chi.^(n-1))./Tc;
  end
end

function Ts = Ts(Acoeffs,p)
%TS(P)      Saturation temperature [K].
%
%  TS(ANTOINECOEFFS,P) returns the saturation temperature by inverting the
%  Antoine equation or by iteratively solving the extended Antoine equation.
%
%  See PS.
%  Calls PS, NEWTON.

% The Antoine eq. underpredicts vapor pressure. Therefore, the temperature
% returned by the Antoine eq., Ta, is higher than the saturation temperature
% that is obtained by using the extended Antoine eq., Ts. Matlab does not have
% Newtonian iteration, therefore we program it ourselves. Otherwise, use fzero
% with the start interval [T0, Ta].
%
% Ps |  ext. Ant.    Ant.
%    |         /   ´
%    | -------/--´
%    |       /:´:
%    |      /´: :
%    |  __-´  : :
%    |________________
%         T0 Ts Ta    Ts

% No Check of T <= Tc commented out.
i = find(p <= Acoeffs(:,2), 1);

% Get the solution or a good inital guess for later iteration.
[A, B, C, T0] = deal(Acoeffs(i,3),Acoeffs(i,4),Acoeffs(i,5),Acoeffs(i,6));

%ps = 10.^(A-B./(C+T));  log(10) = 2.302585092994046;
Ts = B./(A-log(p)/2.302585092994046)-C;

if T0 ~= 0
  % We have an extended Antoine eq.
  % the initial guess might be too large!
  Ts = min(Ts,Acoeffs(i,1));
  Ts = newtony(@(T) ps(Acoeffs,T),Ts,p,1e-5);
end
% RES in NEWTON: With ps ~ 1e5, ps is solved to 7 digits accuracy. Since Ts is
% accurate to RES/dps, and dps > 1e3, for RES = 1e-2 Ts is accurate to 1e-5.

function rho = rholandolt(coeffs,T)
%RHOLANDOLT Liquid density [kg/m3].
%
%  RHOLANDOLT(COEFFS,T) returns the liquid density [kg/m3].
%  See Landolt-Börnstein, New Series, Group IV: Physical Chemistry.
%  Thermodynamic Properties of Organic Compounds and Their Mixtures, vol. 8G.
%  M. Frenkel, X. Hong, R. Wilhoit, K. Hall (2000).
[A, B, C, D, Tc, rhoc] ...
  = deal(coeffs(1),coeffs(2),coeffs(3),coeffs(4),coeffs(5),coeffs(6));
chi = 1 - T/Tc;  phi = Tc - T;
rho=(1+1.75.*chi.^(1/3)+0.75.*chi).*(rhoc+A.*phi+B.*phi.^2+C.*phi.^3+D.*phi.^4);

function [drho, rho] = drholandolt(coeffs,T)
%DRHOLANDOLT Derivative of liquid density, (1/rho) drho/dT [1/K].
%
%  [DRHO RHO] = DROLANDOLT(C,T) returns the first derivative of the liquid
%  density, DRHO = (1/RHO) (DRHO/DT), and the density.
[A, B, C, D, Tc, rhoc] ...
  = deal(coeffs(1),coeffs(2),coeffs(3),coeffs(4),coeffs(5),coeffs(6));
chi = 1 - T/Tc;  phi = Tc - T;
rho = rholandolt(coeffs,T);
drho = (1+1.75.*chi.^(1/3)+0.75.*chi).*(-A -2*B.*phi-3*C.*phi.^2-4*D.*phi.^3)...
-(7./(12*Tc.*chi.^(2/3))+0.75./Tc).*(rhoc+A.*phi+B.*phi.^2+C.*phi.^3+D.*phi.^4);
drho = drho./rho;

function rho = rhoperry(C,T)
%RHOPERRY   Liquid density [kg/m3].
%
%  RHOPERRY(C,T) returns the liquid density [kg/m3].
%  Uses a Rackett(?) equation. See Table 2-30 in Perry's Chemical Engineer's
%  Handbook, 7th ed. (1997).

% C = [C1 C2 C3 C4 M]; C1 = C1*M in the assignment
M = C(5);
rho = C(1)./C(2).^(1 + (1 - T./C(3)).^C(4));
rho = rho.*M;

function [drho, rho] = drhoperry(C,T)
%DRHOPERRY  Derivative of liquid density, (1/rho) drho/dT [1/K].
%
%  [DRHO RHO] = DRHOPERRY(C,T) returns the first derivative of the liquid
%  density, DRHO = (1/RHO) (DRHO/DT), and the density.

% In[2]:= D[C1/C2^(1+(1-T/C3)^C4),T]//InputForm
% Out[2]//InputForm=
%  (C1*C2^(-1 - (1 - T/C3)^C4)*C4*(1 - T/C3)^(-1 + C4)*Log[C2])/C3

rho = rhoperry(C,T);
drho = C(4).*(1-T./C(3)).^(-1+C(4)).*log(C(2))./C(3);

function mul = mudaubert(C,T)
%MUDAUBERT  Dynamic viscosity of the liquid [Pa s].
%
%  MUDAUBERT(C,T) returns the dynamic viscosity of the liquid.
%  See Viswanath et al., chap. 4.3.1.3c in Viscosity of Liquids (2007).
%  Viswanath et al. report correlations by Daubert and Danner, Physical and
%  Thermodynamic Properties of Pure Chemicals -- Data Compilation, Design
%  Institute for Physical Properties Data, AIChE, Taylor and Francis,
%  Washington DC (1989-1994).
%
%  C = [A B C D E]

% if T<C(1) | T>C(2) warning('Liquid viscosity: Out of range.');
if C(4)~=0
  term = C(4).*(T.^C(5));
else
  term = 0;
end
mul = exp( C(1) + C(2)./T + C(3).*log(T) + term );

function mul = vdi02(C,T)
%VDI02      Specific heat capacity at constant pressure in the ideal gas state.
%
%  VDI02(MULCOEFFS,T) uses eq. 2 in VDI Wärmeatlas, 11th ed. (2013), D3.1
%  Flüssigkeiten und Gase: Michael Kleiber und Ralph Joh, to return
%  the dynamic viscosity of the liquid. The equation states units of Pas, the
%  caption of Tabelle 7 refers to mPas. The latter is wrong.
cdt = (C(3) - T)./(T - C(4));
mul = C(5).*exp(nthroot(cdt,3).*(C(1) + C(2).*cdt));

function mug = mulucas(mugcoeffs,T)
%MULUCAS    Dynamic viscosity of the vapor [Pa s].
%
%  MULUCAS(T,M,TC,PC,MUGCOEFFS) returns the dynamic viscosity of the vapor.
%  See VDI Wärmeatlas, pp. 27-28, 9th ed. (2002). The correlation in VDI is
%  proposed by Lucas and reported by Reid, Prausnitz and Poling, 4th ed. (1987)
%  and by Perry, 7th ed. (1997). Not good for, e.g., nitrogen at saturation for
%  T > 80 K (cf. viscosity.pdf).

Z = mugcoeffs(1);  debye = mugcoeffs(2);
R = mugcoeffs(3); M = mugcoeffs(4);
Tc = mugcoeffs(5); pc = mugcoeffs(6);
Navo = 6.02214e26; % Avogadros constant.
k = R/Navo; % Boltzmann number

Tr = T/Tc;
etaxi = 0.807*Tr.^0.618 - 0.357*exp(-0.449*Tr) + 0.34*exp(-4.058*Tr) + 0.018;
xi = (Tc*R*Navo^2/pc^4)^(1/6)/sqrt(M);

if debye > 0
  mur = debye^2*1e-49*pc/(k*Tc)^2;
  if mur < 0.022
    fp = 1;
  elseif mur < 0.075
    fp = 1 + 30.55*(0.292-Z)^1.72;
  else
    fp = 1 + 30.55*(0.292-Z)^1.72*abs(.96+0.1*(Tr-0.7));
  end
else
  fp = 1;
end

mug = etaxi*fp/xi;

function kg = kgroy(kgcoeffs,T)
%KGROY      Thermal conductivity of the vapor [W/mK].
%
%  KGROY(KGCOEFFS,T) returns the thermal conductivity of the vapor. See p. 498
%  in Reid, Prausnitz and Poling, 4th ed. (1987). Instead of
%  gamma = 210(Tc M^3 / Pc^4)^(1/6), Pc in bar, gamma = 0.457e6(..), Pc in Pa
%  is used.

M = kgcoeffs(1); Tc = kgcoeffs(2); pc = kgcoeffs(3); C = kgcoeffs(4);

gamma = 0.457e6*(Tc.*M.^3./pc.^4).^(1/6);
Tr = T./Tc;
CfTr = C*(-0.152.*Tr + 1.191.*Tr.^2 - 0.039.*Tr.^3);
kg = ( 8.757.*(exp(.0464*Tr) - exp(-0.2412*Tr)) + CfTr )./gamma;

function kl = klatini(klcoeffs,T)
%KLATINI    Thermal conductivity of the liquid [W/mK].
%
%  KLATINI(KLCOEFFS,T) returns the thermal conductivity of the vapor, based on
%  a correlation by Latini and coworkers [Baroncini et al., Int. J. Thermophys.
%  1, pp. 21, 1981] in the form kl = A(1-Tr)^0.38/Tr^(1/6). See pp. 549 in
%  Reid, Prausnitz and Poling, 4th ed. (1987). A is determined from a single
%  data point.

% klcoeffs = [Tc A]
Tr = T./klcoeffs(1);
kl = klcoeffs(2).*(1-Tr).^0.38./Tr.^(1/6);

function cpl = cpleq2(C,T)
%CPLEQ2     Evaluate Equation 2 to Table 2-153 in Green & Perry, 8th ed. (2007).
%
%  CPLEQ2(CPLCOEFFS,T) returns the specific heat capacity of the liquid [J/kgK].
%  Equation 2 to Table 2-196, from Perry, 7th ed. (1997), corrected, is used.
%  For the correction see Perry, 8th ed. (2007), Equation 2 to Table 2-153.
%  CPL could be calculated from the real gas cp, from
%   cp = cp(id) + int_0^p (d cp/ dp')_T dp'
%  and with Clausius-Clapeyron, h''-h' = (dps/dT)T(v''-v'), taken the derivative
%  (d/dT) gives
%   cp''-cp' = (d^2ps/dT^2)T(v''-v') + (dps/dT)( (v''-v')+T (dv''/dT-dv'/dT) ).
%  Then, as above, cp = cp' + int_ps^p (d cp/ dp')_T dp'.
%  However, (i) cpl is nearly independent of p and (ii) the second derivative of
%  the saturation pressure (d^2ps/dT^2) is not available in the required
%  accuracy.
Tc = C(5); M = C(6);
x = (1-T./Tc);
cpl = (C(1).^2./x + C(2) - 2.*C(1).*C(3).*x - C(1).*C(4).*x.^2 - ...
  C(3).^2*x.^3./3 - C(3).*C(4).*x.^4./2 - C(4).^2.*x.^5./5 )./M;

function icpl = icpleq2(C,T0,T1)
%ICPLEQ2    Integrate CPLEQ2.
%
%  ICPLEQ2(CPLCOEFFS,T0,T1) returns the difference of the specific enthalpy of
%  the liquid between the temperatures T0 and T1. Corrected on Mai 6, 2013, see
%  substance>cpleq2.
%
%  See also CPLEQ2.

%  From cpl = c1/x + c2 + c3*x + .. + c7*x^5, x = 1-T/Tc, hence dx = -dT/Tc
%  yields for int_T0^T1 cpl dT = -Tc int_x0^x1 cpl dx,
%  int_x0^x1 cpl = c1*log(x1/x0) + c2*(x1-x0) + c3*(x1^2-x0^2)/2 ...
%    +  c7*(x1^6-x0^6)/6;
Tc = C(5); M = C(6);
x0 = (1-T0./Tc); x1 = (1-T1./Tc);

icpl = C(1).^2.*log(x0./x1) - C(2).*(x1-x0) + C(1).*C(3).*(x1.^2-x0.^2) ...
  + C(1).*C(4).*(x1.^3-x0.^3)/3 + C(3).^2.*(x1.^4-x0.^4)/12 ...
  + C(3).*C(4).*(x1.^5-x0.^5)/10 + C(4).^2.*(x1.^6-x0.^6)/30;
icpl = Tc.*icpl./M;

function y = icpleq2_x(C,T1,T2)
%ICPLEQ2_X  Integrate CPL/T dT, CPL given by CPLEQ2 [J/kg K].
%
%  ICPLEQ2_X(CPLCOEFFS,T1,T2) integrates the specific isobaric heat capacity of
%  the liquid over T, Int_T1^T2 CPL/T dT. Used for evaluation of the difference
%  of the specific entropy of the liquid.

% mathematica-Session
%
% Integrate[(C1/x + C2 + C3*x + C4*x^2 + C5*x^3 + C6*x^4 + C7*x^5)/T /.
%   x -> (1 - T/Tc), {T, T1, T2},
%   Assumptions -> T1 > 0 && T2 > 0 && T1 < Tc && T2 < Tc && T1 < T2]
% ...
% % /. {C1 -> D1^2, C3 -> -2*D1*D3, C4 -> -D1*D4, C5 -> D3^2/3,
%    C6 -> -D3*D4/2, C7 -> -D4^2/5}
% ...
% FullSimplify[%]
% ...
% InputForm[%]
%  ((-12*D4^2*(T1^5 - T2^5))/5 + (15*D4*(D3 + 2*D4)*(T1^4 - T2^4)*Tc)/
%     2 + (20*(D3^2 - 6*D3*D4 - 6*D4^2)*(T1^3 - T2^3)*Tc^2)/3 +
%    30*(-D3^2 + 3*D3*D4 + D4*(D1 + 2*D4))*(T1 - T2)*(T1 + T2)*Tc^3 -
%    60*(-D3^2 + 2*D3*D4 + D4^2 + 2*D1*(D3 + D4))*(T1 - T2)*Tc^4 -
%    2*Tc^5*((10*(3*(C2 + D1^2) - 6*D1*D3 + D3^2) -
%        15*(2*D1 + D3)*D4 - 6*D4^2)*Log[T1] +
%      (-10*(3*(C2 + D1^2) - 6*D1*D3 + D3^2) + 15*(2*D1 + D3)*D4 +
%        6*D4^2)*Log[T2] + 30*D1^2*(-Log[-T1 + Tc] + Log[-T2 + Tc])))/
%   (60*Tc^5)
% and Simplify the Logs,
% FullSimplify[% == ...,T1 > 0 && T2 > 0 && Tc > T1 && Tc > T2]
% True
% and, in the editor, replace D1 - D4 by C(1) - C(4), divide by M

Tc = C(5); M = C(6);

y = (  (-12*C(4).^2.*(T1.^5-T2.^5))/5 ...
  +(15*C(4).*(C(3)+2.*C(4)).*(T1.^4-T2.^4).*Tc)/2 ...
  +(20*(C(3).^2-6*C(3).*C(4)-6*C(4).^2).*(T1.^3-T2.^3).*Tc.^2)/3 ...
  +30*(-C(3).^2+3*C(3).*C(4)+C(4).*(C(1)+2*C(4))).*(T1-T2).*(T1+T2).*Tc.^3 ...
  -60*(-C(3).^2+2*C(3).*C(4)+C(4).^2+2*C(1).*(C(3)+C(4))).*(T1-T2).*Tc.^4 ...
  -2*Tc.^5.*(( 10*(3.*(C(2)+C(1).^2)-6*C(1).*C(3)+C(3).^2) ...
  -15*(2*C(1)+C(3)).*C(4)- 6*C(4).^2 ).*(log(T1./T2)) ...
  +30*C(1).^2.*log((Tc-T2)./(Tc-T1)))   )./(M.*60.*Tc.^5);

function cpl = vdi08(C,T)
%VDI08      Specific isobaric heat capacity of the liquid [J/kgK].
%
%  VDI08(C,T) applies eq. 8 from VDI Wärmeatlas, 11th ed. (2013). D3.1
%  Flüssigkeiten und Gase: Michael Kleiber und Ralph Joh, to return the specific
%  isobaric heat capacity of the liquid in units of J/kgK. VDI08 expects
%  coefficients C(1) to C(6), A to F in eq. 8, to already be multiplied with
%  R/M.

% Tc = C(7);
xi = (1-T./C(7));
cpl = C(1)./xi  + C(2) + C(3).*xi + C(4).*xi.^2 + C(5).*xi.^3 + C(6).*xi.^4;

function sig = sigvdi(sigcoeffs,T)
%SIGVDI     Surface tension [N/m].
%
%  SIGVDI(SIGCOEFFS,T) gives the surface tension after a correlation from
%  VDI-Wärmeatlas, eq.(91), p. Da 37.
b = sigcoeffs(1); Tc = sigcoeffs(2); pc = sigcoeffs(3);
sig = b.*(pc.^2.*Tc).^(1/3).*(1-T./Tc).^(11/9);

function [dsig, sig] = dsigvdi(sigcoeffs,T)
%DSIGVDI    Derivative of surface tension, (1/SIG) DSIG/DT [1/K].
%
%  [DSIG SIG] = DSIGVDI(SCOEFFS,T) returns the derivative of the surface
%  tension, normalized with the surface tension, and the surface tension itself.
%
%  See also SIGVDI.

Tc = sigcoeffs(2);
dsig = 11./(9*(T-Tc));
sig = sigvdi(sigcoeffs,T);

function sig = sigstephan22(sigcoeffs,T)
%SIGSTEPHAN22 Surface tension [N/m].
%
%  SIGSTEPHAN22(SIGCOEFFS,T) returns the surface tension from a correlation by
%  Stephan and Hildwein (1987), their eq. (22).

% Check of T <= Tc commented out.
%if T < sigcoeffs(3)
  sig = sigcoeffs(1).*(1-T./sigcoeffs(3)).^sigcoeffs(2);
%else
%  sig = 0;
%end

function [dsig, sig] = dsigstephan22(sigcoeffs,T)
%DSIGSTEPHAN22 Surface tension [N/m].
%
%  [DSIG SIG] = DSIGSTEPHAN22(SCOEFFS,T) returns the derivative of the surface
%  tension, normalized with the surface tension, and the surface tension itself.
%
%  See also SIGSTEPHAN22.

% Check of T <= Tc commented out.
%if T < sigcoeffs(3)
  dsig = sigcoeffs(2)./(T-sigcoeffs(3));
  sig = sigstephan22(sigcoeffs,T);
%else
%  sig = 0; dsig = 0;
%end

function sig = sigstephan23(sigcoeffs,T)
%SIGSTEPHAN23 Surface tension [N/m].
%
%  SIGSTEPHAN23(SIGCOEFFS,T) returns the surface tension from a correlation by
%  Stephan and Hildwein (1987), their eq. (23).

% sigcoeffs = [a1 a2 a3 Tc];
th = 1-T./sigcoeffs(4);
sig = sigcoeffs(1).*th.^sigcoeffs(2).*(1+sigcoeffs(3).*th);

function [dsig, sig] = dsigstephan23(sigcoeffs,T)
%DSIGSTEPHAN23 Surface tension [N/m].
%
%  [DSIG SIG] = DSIGSTEPHAN23(SCOEFFS,T) returns the derivative of the surface
%  tension, normalized with the surface tension, and the surface tension itself.
%
%  See also SIGSTEPHAN23.
th = 1-T./sigcoeffs(4);
sig = sigcoeffs(1).*th.^sigcoeffs(2).*(1+sigcoeffs(3).*th);
dsig = (-sigcoeffs(2) - 1./(1+1./(sigcoeffs(3).*th)))./(th.*sigcoeffs(4));

%function sig = vdi06(C,T)
%VDI06     Surface tension [N/m].
%  VDI06(C,T) applies eq. 6 from VDI Wärmeatlas, 11th ed. (2013). D3.1
%  Flüssigkeiten und Gase: Michael Kleiber und Ralph Joh, to return the surface
%  tension. For two coefficients, equivalent to SIGSTEPHAN22.

function jt = jt(V,cpid)
%JT         Joule-Thomson coefficient [K/Pa].
%
%  JT([DHDP CPG_CPID],CPID) returns the differential Joule-Thomson coefficient,
%    jt = -(dh/dp)/cp.

% jt = -dhdp(T)./cpg(T,p); V = [dhdp cpg_cpid], see VIRIAL.
jt = -V(1)./(cpid+V(2));

function [dhdp, cpg]= dhcpg(V,cpid)
%DHCPG      Derivative of enthalpy by pressure at constant temperature,  dh/dp.
%
%  DHCPG([DHDP CPG_CPID],CPID) returns the array [DHDP CPG].
dhdp = V(1);
cpg = V(2)+cpid;

function T1 = intjt(T0,p0,p1,jtloc)
%INTJT      Integral Joule-Thomson coefficient [K].
%
%  T1 = INTJT(T0,P0,P1,JT) returns the final temperature T1 for an isenthalpic
%  change of state from the initial conditions T0, P0 to the final state P1. JT
%  is a function handle to the Joule-Thomson coefficient, JT(P,T).

if p0 == p1
  T1 = T0;
else
%jtloc = @(p,T) s.jt(T,p);
  [pi, ti] = ode45(jtloc,[p0 p1],T0);
  % for [p0 p1], the solution for all integration steps is returned;
  % fpr [p0 [p1 p2 p3 ..] ], the solution at all specified points is returned.
  if size(p1,2) == 1
    T1 = ti(end);
  else
    T1 = ti(2:end)';
  end
end

function y = poly2(C,x)
%POLY2      Evaluate a polynomial of second order, three coefficients.
%
%  POLY2(C,x) returns C(1) + C(2)*x + C(3)*x^2.
y = C(1) + C(2)*x + C(3)*x.^2;

function [dy, y] = dpoly2(C,x)
%DPOLY2     Evaluate the derivative of a polynomial of third order.
%
%  [DY Y] = DPOLY2(C,X) returns the first derivative, DY = (1/Y) (DY/DX), and
%  the value of the polynomial.
%
%  See also POLY2.
y = poly2(C,x);
dy = (C(2) + 2*C(3)*x)./y;

function y = poly3(C,x)
%POLY3      Evaluate a polynomial of third order, four coefficients.
%
%  POLY3(C,x) returns C(1) + C(2)*x + C(3)*x^2 + C(4)*x^3.
y = C(1) + C(2)*x + C(3)*x.^2 + C(4)*x.^3;

function [dy, y] = dpoly3(C,x)
%DPOLY3     Evaluate the derivative of a polynomial of third order.
%
%  [DY Y] = DPOLY3(C,X) returns the first derivative, DY = (1/Y) (DY/DX), and
%  the value of the polynomial.
%
%  See also POLY3.
y = poly3(C,x);
dy = (C(2) + 2*C(3)*x + 3*C(4)*x.^2 )./y;

function iy = ipoly3(C,x0,x1)
%IPOLY3     Integrate a polynomial of third order.
%
%  IY = IPOLY3(C,X0,X1) integrates a polynomial between X0 and X1.
%
%  See also POLY3.
iy = C(1)*(x1-x0) + C(2)*(x1.^2-x0.^2)/2 + C(3)*(x1.^3-x0.^3)/3 ...
  + C(4)*(x1.^4-x0.^4)/4;

function y = ipoly3_x(C,x0,x1)
%IPOLY3_X   Integrate a polynomial of third order, divided by x.
%
y = C(1).*log(x1./x0) + C(2).*(x1-x0) + C(3).*(x1.^2-x0.^2)/2 ...
    + C(4).*(x1.^3-x0.^3)/3;

function y = poly4(C,x)
%POLY4      Evaluate a polynomial of fourth order, five coefficients.
%
%  POLY4(C,x) returns C(1) + C(2)*x + C(3)*x^2 + C(4)*x^3 + C(5)*x^4.
y = C(1) + C(2)*x + C(3)*x.^2 + C(4)*x.^3 + C(5)*x.^4;

function [dy, y] = dpoly4(C,x)
%DPOLY3     Evaluate the derivative of a polynomial of fourth order.
%
%  [DY Y] = DPOLY4(C,X) returns the first derivative, DY = (1/Y) (DY/DX), and
%  the value of the polynomial.
%
%  See also POLY4.
y = poly4(C,x);
dy = (C(2) + 2*C(3)*x + 3*C(4)*x.^2 + 4*C(5)*x.^3)./y;

function iy = ipoly4(C,x0,x1)
%IPOLY4     Integrate a polynomial of fourth order.
%
%  IY = IPOLY4(C,X0,X1) integrates a polynomial between X0 and X1.
%
%  See also POLY4.
iy = C(1)*(x1-x0) + C(2)*(x1.^2-x0.^2)/2 + C(3)*(x1.^3-x0.^3)/3 ...
  + C(4)*(x1.^4-x0.^4)/4 + C(5)*(x1.^5-x0.^5)/5;

function y = ipoly4_x(C,x0,x1)
%IPOLY4     Integrate a polynomial of fourth order, divided by x.
%
y = C(1).*log(x1./x0) + C(2).*(x1-x0) + C(3).*(x1.^2-x0.^2)/2 ...
    + C(4).*(x1.^3-x0.^3)/3 + C(5).*(x1.^4-x0.^4)/4;

function [y, y1, y2] = pdiv3(C,x)
%PDIV3      Evaluate a polynomial in X^-1 of third order, four coefficients.
%
%  PDIV3(C,x) returns y = C(1) + C(2)/x + C(3)/x^2 + C(4)/x^3.
%
%  [y y1 y2] = PDIV3(C,x) returns y and the first two derivatives,
%  y1 = x*dy/dx = -C(2)/x - 2 C(3)/x^2 - 3 C(4)/x^3 and
%  y2 = x^2 d^2y/dx^2 = 2 C(2)/x + 6 C(3)/x^2 + 12 C(4)/x^3.
y = C(1) + C(2)./x + C(3)./x.^2 + C(4)./x.^3;
if nargout > 1
  y1 =  -C(2)./x - 2*C(3)./x.^2 - 3*C(4)./x.^3;
  y2 =  2*C(2)./x + 6*C(3)./x.^2 + 12*C(4)./x.^3;
end

function [y, y1, y2] = pdiv4(C,x)
%PDIV4      Evaluate a polynomial in X^-1 of fourth order, five coefficients.
%
%  PDIV4(C,x) returns y = C(1) + C(2)/x + C(3)/x^2 + C(4)/x^3 + C(5)/x^4.
%
%  [y y1 y2] = PDIV4(C,x) returns y and the first two derivatives,
%  y1 = x*dy/dx = -C(2)/x - 2 C(3)/x^2 - 3 C(4)/x^3 - 4 C(5)/x^4 and
%  y2 = x^2 d^2y/dx^2 = 2 C(2)/x + 6 C(3)/x^2 + 12 C(4)/x^3 + 20 C(5)/x^4.
y = C(1) + C(2)./x + C(3)./x.^2 + C(4)./x.^3 + C(5)./x.^4;
if nargout > 1
  y1 =  -C(2)./x - 2*C(3)./x.^2 - 3*C(4)./x.^3 - 4*C(5)./x.^4;
  y2 =  2*C(2)./x + 6*C(3)./x.^2 + 12*C(4)./x.^3 + 20*C(5)./x.^4;
end

function x = newtony(fun,x0,y,res,iter)
%NEWTONY    Newton iteration. Controls residual in the function value.
%
%  NEWTONY(FUN,X0) finds a solution to F(X) = 0 by Newton iteration, starting
%  from X = X0. NEWTON expects FUN to be the handle to a function that returns a
%  vector [F(X) DF(X)], where DF is the derivative of F at X.
%
%  NEWTONY(FUN,X0,Y,RES,ITER) finds a solution to F(X) = Y. NEWTONY iterates
%  until ABS( F(X) - Y ) < RES or more than ITER iterations are done. Default
%  values are RES = 1e-6 and ITER = 100.
%
%  The exact X is at a distance of approximately RES/DF from the value returned.
%
%  Example
%    Given
%      function [s ds] = senus(x)
%      s = sin(x); ds = cos(x);
%    should give pi, using a function handle to senus.
%      probablypi = newtony(@senus,3.1,0)
%
%  See also the MATLAB-functions function_handle, feval.

if nargin < 5, iter = 100; end
if nargin < 4, res = 1e-6; end
if nargin < 3, y = 0; end

x = x0;
for i = 1:iter
  [y0, dy] = fun(x);
  fy = y0 - y;
  x = x - fy/dy;
  if abs(fy) < res, return; end
end

% Be verbose if no solution is found.
funname = func2str(fun);
error(['NEWTONY not succesful. Increase RES or ITER. Type help newtony.\n' ...
  '  Function %s, initial guess x0: %g, last found value x: %g,\n' ...
  '  function value %s(x) = %g. Allowed residual: %g, Iterations: %u.'], ...
  funname,x0,x,funname,y0,res,iter)
