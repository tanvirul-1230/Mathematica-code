(* ::Package:: *)

(* ======================================================================= *)
(* FAST Q1 FIGURE GENERATOR -- PARALLEL + TRICOMI-U + EXACT ASYMPTOTES     *)
(* *)
(* Lines   = YOUR analytical closed forms (unchanged math):                *)
(* RIS   : two-branch Erlang closed form (NR=1 Fixed)            *)
(* Relay : T-series Tricomi-U closed form                        *)
(* Markers = MONTE CARLO ON THE PLAN PDF MODEL (Staggered for Relay)       *)
(* Asymp.  = Original exact incomplete-gamma formulation                   *)
(* *)
(* ======================================================================= *)

ClearAll["Global`*"];
$HistoryLength = 0;
$MaxExtraPrecision = 100000;
Quiet@Check[SetSystemOptions["ParallelOptions" -> "MKLThreadNumber" -> 1], Null];
ClearSystemCache[];
ln2 = Log[2];

(* ======================= PARALLEL KERNEL CONTROL ======================== *)
useParallelKernelSaturation = True;
nUseKernels = 16;                      (* Ryzen 7 5700X: 16 logical threads *)
closeOldKernelsFirst = True;

If[TrueQ[useParallelKernelSaturation],
  If[TrueQ[closeOldKernelsFirst] && Length[Kernels[]] > 0, CloseKernels[]];
  If[Length[Kernels[]] == 0, LaunchKernels[nUseKernels]];
  ParallelEvaluate[$HistoryLength = 0; $MaxExtraPrecision = 100000; ClearSystemCache[];];
  Print["Parallel kernels active: ", Length[Kernels[]]];
];

ClearAll[refreshParallelDefinitions];
refreshParallelDefinitions[] := If[TrueQ[useParallelKernelSaturation],
  Quiet@Check[DistributeDefinitions["Global`*"], DistributeDefinitions["Global`"]];
  ParallelEvaluate[$MaxExtraPrecision = 100000;]
];

showFiguresInNotebook = True;

(* Q1/IEEE marker tuning: small thick hollow markers *)
mcMarkerSize = 9; 
mcMarkerOutlineThickness = 1.9;

rhoEdBCommon = 0;                 
snrDdBCommon = Range[0, 40, 5];   

mcTrials   = 40000;               
mcChunk    = 5000;                
mcSeedBase = 2101097;

workPrecRIS   = 200;              
risHighNRPrecision = workPrecRIS;  
risDirectKernelThreshold = 700;        
workPrecRelay = 300;              
TseriesRelay  = 120;              

$font = "Times New Roman";
$outputDPI = 1200;

(* ===================== FIGURE 1 : RIS vs AF relay (Rho_E Sweep) ==================== *)
f1Config = <|
   "name"      -> "Fig1_RIS_vs_Relay_RhoE_Sweep",
   "rhoEdB"    -> 0,                   
   "snrDdB"    -> snrDdBCommon,        
   "M"         -> 10,                  
   "L"         -> 5,                   
   "NRd"       -> 4,                   
   "NRe"       -> 4,                   
   "hopSplit"  -> "full",             
   "Trelay"    -> 40,                  
   "precRelay" -> 1000,                
   "sweepVar"  -> "rhoEdB",
   "sweepList" -> {0, 10},
   "colorBy"   -> "system",            
   "showRIS"   -> True,
   "showRelay" -> True,
   "showAsy"   -> True,               
   "legendPos" -> {0.03, 0.97},
   "annotations" -> {}
|>;

(* ============ FIGURE 2 : Eavesdropper-count K sweep ================= *)
f2Config = <|
   "name"      -> "Fig2_Eavesdropper_Count_K_Sweep",
   "rhoEdB"    -> rhoEdBCommon,
   "snrDdB"    -> snrDdBCommon,
   "M"         -> 5,
   "L"         -> 1,                   
   "NRd"       -> 4,                   
   "NRe"       -> 4,                   
   "hopSplit"  -> "full",
   "Trelay"    -> 60,                  
   "precRelay" -> 600,
   "sweepVar"  -> "L",               
   "sweepList" -> {1, 2, 6, 20},
   "colorBy"   -> "sweepVar",          
   "showRIS"   -> True,
   "showRelay" -> True,                
   "showAsy"   -> False,
   "legendPos" -> {0.03, 0.97},
   "annotations" -> {}
|>;

(* Output folder - Save exactly in the current directory *)
$scriptDir = If[StringQ[$InputFileName] && $InputFileName =!= "",
   DirectoryName[$InputFileName], Quiet@Check[NotebookDirectory[], Directory[]]];
If[!StringQ[$scriptDir] || $scriptDir === "", $scriptDir = Directory[]];
$outDir = $scriptDir; 

(* ======================================================================= *)
(* ENGINE A: RIS TWO-BRANCH ERLANG CLOSED FORM  (NR=1 FIX INCORPORATED)    *)
(* ======================================================================= *)
ClearAll[shapeFromNR, scaleRayleighRIS, rhoLin];
shapeFromNR[NR_?NumericQ, prec_: workPrecRIS] := N[NR Pi^2/(16 - Pi^2), prec];
scaleRayleighRIS[prec_: workPrecRIS] := N[(16 - Pi^2)/(2 Pi), prec];
rhoLin[rhoDB_?NumericQ, prec_: workPrecRIS] := SetPrecision[10^(rhoDB/10), prec];

ClearAll[twoBranchParams];
twoBranchParams[s_?NumericQ, b_?NumericQ, prec_: workPrecRIS] := Module[
  {ss = SetPrecision[s, prec], bb = SetPrecision[b, prec], m0, P, lam, isNR1},
  m0 = Ceiling[N[ss, 30]];
  P = N[(m0 - Sqrt[ss*m0*(ss + 1 - m0)])/(ss + 1), prec];
  
  isNR1 = (Abs[ss - (Pi^2/(16-Pi^2))] < 0.01);
  If[isNR1, P = N[0.02, prec]; ];
  
  lam = N[(m0 - P)/(ss*bb), prec];
  If[P < 0 && Abs[P] < 10^-30, P = 0];
  If[P > 1 && Abs[P - 1] < 10^-30, P = 1];
  <|"s" -> ss, "b" -> bb, "m0" -> m0, "P" -> P, "lambda" -> lam|>
];

ClearAll[survivalPolyCoeffs, polyMul, polyPower, sortedTotal, safeReal];
survivalPolyCoeffs[params_Association, rho_?NumericQ, prec_: workPrecRIS] := Module[
  {m0 = params["m0"], P = SetPrecision[params["P"], prec],
   lam = SetPrecision[params["lambda"], prec], alpha, coeffs, r},
  alpha = N[lam/Sqrt[SetPrecision[rho, prec]], prec];
  coeffs = ConstantArray[0, m0];
  Do[coeffs[[r + 1]] = N[alpha^r/Factorial[r], prec], {r, 0, Max[m0 - 2, 0]}];
  coeffs[[m0]] = N[(1 - P)*alpha^(m0 - 1)/Factorial[m0 - 1], prec];
  <|"alpha" -> alpha, "coeffs" -> coeffs|>];

polyMul[a_List, b_List] := Module[{c, i, j, la = Length[a], lb = Length[b]},
  c = ConstantArray[0, la + lb - 1];
  Do[c[[i + j - 1]] = c[[i + j - 1]] + a[[i]] b[[j]], {i, 1, la}, {j, 1, lb}];
  c
];

polyPower[a_List, n_Integer?NonNegative] := Module[{res = {1}, base = a, exp = n},
  While[exp > 0,
    If[OddQ[exp], res = polyMul[res, base]];
    exp = Quotient[exp, 2];
    If[exp > 0, base = polyMul[base, base]];
  ];
  res
];

sortedTotal[list_List] := Module[{terms},
  terms = DeleteCases[Flatten[list], 0 | 0.];
  If[Length[terms] == 0, 0, Plus @@ SortBy[terms, Abs]]];
safeReal[z_] := Module[{zz = Quiet@N[z, 50]},
  If[! NumericQ[zz], Return[$Failed]];
  If[Abs[Im[zz]] > 10^-16 Max[1, Abs[Re[zz]]], Return[$Failed]]; Re[zz]];

ClearAll[JKernelDirectExact, JKernelVectorRecurrence, JKernelVectorDirect, JKernelVector];
JKernelDirectExact[n_Integer?NonNegative, c_?NumericQ, prec_: workPrecRIS] := Module[
  {cc = SetPrecision[c, prec], val, rr},
  val = Quiet@Check[
     Re@N[Gamma[n + 1]/(2 I)*(((-I)^n) Exp[-I cc] Gamma[-n, -I cc] -
         (I^n) Exp[I cc] Gamma[-n, I cc]), prec],
     $Failed
  ];
  rr = If[val === $Failed, $Failed, safeReal[val]];
  If[rr === $Failed || !NumericQ[rr], 0, Max[0, rr]]
];

JKernelVectorRecurrence[maxN_Integer?NonNegative, c_?NumericQ, prec_: workPrecRIS] := Module[
  {cc = SetPrecision[c, prec], arr, n},
  arr = ConstantArray[0, maxN + 1];
  arr[[1]] = JKernelDirectExact[0, cc, prec];
  If[maxN >= 1, arr[[2]] = JKernelDirectExact[1, cc, prec]];
  If[maxN >= 2,
    Do[arr[[n + 1]] = N[Gamma[n - 1]/cc^(n - 1) - arr[[n - 1]], prec], {n, 2, maxN}]
  ];
  arr
];

JKernelVectorDirect[maxN_Integer?NonNegative, c_?NumericQ, prec_: workPrecRIS] :=
  Table[JKernelDirectExact[n, c, prec], {n, 0, maxN}];

JKernelVector[maxN_Integer?NonNegative, c_?NumericQ, prec_: workPrecRIS] :=
  If[maxN >= risDirectKernelThreshold,
     JKernelVectorDirect[maxN, c, prec],
     JKernelVectorRecurrence[maxN, c, prec]
  ];

ClearAll[CsTwoBranchErlang];
CsTwoBranchErlang[NRd_?NumericQ, NRe_?NumericQ, rhoDDB_?NumericQ, rhoEDB_?NumericQ,
   M_Integer?Positive, L_Integer?Positive, prec_: workPrecRIS] := Module[
   {sd, se, b, rhoD, rhoE, pd, pe, sdPoly, sePoly, ad, ae,
    dPow, ePow, n, c, conv, kernels, terms, val},
   sd = shapeFromNR[NRd, prec]; se = shapeFromNR[NRe, prec]; b = scaleRayleighRIS[prec];
   rhoD = rhoLin[rhoDDB, prec]; rhoE = rhoLin[rhoEDB, prec];
   pd = twoBranchParams[sd, b, prec]; pe = twoBranchParams[se, b, prec];
   sdPoly = survivalPolyCoeffs[pd, rhoD, prec]; sePoly = survivalPolyCoeffs[pe, rhoE, prec];
   ad = sdPoly["alpha"]; ae = sePoly["alpha"];
   dPow = polyPower[sdPoly["coeffs"], M];

   terms = Table[
     ePow = polyPower[sePoly["coeffs"], n];
     c = M*ad + n*ae;
     conv = polyMul[dPow, ePow];
     kernels = JKernelVector[Length[conv], c, prec];
     (-1)^n Binomial[L, n] stableTotal[Table[conv[[h + 1]]*kernels[[h + 2]], {h, 0, Length[conv] - 1}], prec],
     {n, 0, L}];
   val = (2/ln2)*stableTotal[terms, prec];
   Max[0, N[Re[val], 30]]
];

(* ======================================================================= *)
(* ENGINE B: RELAY T-SERIES CORRECTED TRICOMI-U CLOSED FORM                *)
(* ======================================================================= *)
ClearAll[Lah, LambdaCoeff, aCoeff, aVectorK1];
Lah[0, 0] := 1;
Lah[n_Integer?Positive, 0] := 0;
Lah[n_Integer?Positive, i_Integer?Positive] /; i <= n := Binomial[n - 1, i - 1] n!/i!;
Lah[n_Integer?NonNegative, i_Integer?NonNegative] /; i > n := 0;
LambdaCoeff[nu_, n_Integer?NonNegative, i_Integer?NonNegative] :=
  If[i > n, 0, (-1)^i Sqrt[Pi] Gamma[2 nu] Gamma[1/2 + n - nu] Lah[n, i]/
      (2^(nu - i) Gamma[1/2 - nu] Gamma[1/2 + n + nu] n!)];
aCoeff[nu_, T_Integer?NonNegative, q_Integer?NonNegative] :=
  Sum[LambdaCoeff[nu, ell, q], {ell, q, T}];
aVectorK1[T_Integer?NonNegative, prec_Integer?Positive] :=
  aVectorK1[T, prec] = N[Table[aCoeff[1, T, q], {q, 0, T}], prec];

ClearAll[polyPowerCoeffs, stableTotal, relayParams, IkerTricomiU, IkerListTricomiU];
polyPowerCoeffs[b_List, m_Integer?NonNegative] := polyPower[b, m];
stableTotal[terms_List, prec_Integer?Positive] := N[Total[SortBy[N[terms, prec], Abs]], prec];

relayParams[rho1_, rho2_, prec_Integer?Positive] := Module[{rho1p, rho2p, beta, aa, delta},
  rho1p = SetPrecision[rho1, prec]; rho2p = SetPrecision[rho2, prec];
  beta = 2/Sqrt[rho1p rho2p]; aa = 1/rho1p + 1/rho2p; delta = aa + beta;
  <|"beta" -> N[beta, prec], "a" -> N[aa, prec], "delta" -> N[delta, prec]|>];

IkerTricomiU[m_Integer?NonNegative, z_, prec_Integer?Positive] :=
  Block[{$MaxExtraPrecision = 100000},
    N[Gamma[m + 1] HypergeometricU[m + 1, m + 1, SetPrecision[z, prec]], prec]
  ];
IkerListTricomiU[maxM_Integer?NonNegative, z_, prec_Integer?Positive] :=
  Table[IkerTricomiU[m, z, prec], {m, 0, maxM}];

ClearAll[CsRelaySeriesMeijerG];
CsRelaySeriesMeijerG[M_Integer?Positive, L_Integer?NonNegative,
   rho1d_, rho2d_, rho1e_, rho2e_, T_Integer?NonNegative, prec_Integer?Positive] := Module[
  {av, pd, pe, betaD, betaE, deltaD, deltaE, bd, be, Ad, Ae, conv, kernels, z, n, total, block, raw},
  av = aVectorK1[T, prec];
  pd = relayParams[rho1d, rho2d, prec]; pe = relayParams[rho1e, rho2e, prec];
  betaD = pd["beta"]; deltaD = pd["delta"]; betaE = pe["beta"]; deltaE = pe["delta"];
  bd = N[Table[av[[q + 1]] betaD^q, {q, 0, T}], prec];
  be = N[Table[av[[q + 1]] betaE^q, {q, 0, T}], prec];
  Ad = N[polyPowerCoeffs[bd, M], prec];
  total = 0;
  For[n = 0, n <= L, n++,
    Ae = N[polyPowerCoeffs[be, n], prec];
    conv = N[polyMul[Ad, Ae], prec];
    z = N[M deltaD + n deltaE, prec];
    kernels = IkerListTricomiU[Length[conv] - 1, z, prec];
    block = stableTotal[conv*kernels, prec];
    total = N[total + (-1)^n Binomial[L, n] block, prec]];
  raw = N[total/(2 Log[2]), 30];
  Max[0, N[Re[raw], 30]]];

ClearAll[risAdaptivePrecision];
risAdaptivePrecision[NRd_?NumericQ, NRe_?NumericQ, M_Integer?Positive, L_Integer?Positive] :=
  If[Max[NRd, NRe] >= 50, Max[workPrecRIS, risHighNRPrecision], workPrecRIS];

(* ======================================================================= *)
(* WRAPPERS  (closed form + plan-PDF Monte Carlo)                          *)
(* ======================================================================= *)
ClearAll[hopSNRs, esmcRIScf, esmcRelaycf, positiveMean, esmcRISmcPlan, esmcRelaymcPlan];
hopSNRs[rtDB_?NumericQ, reDB_?NumericQ, split_String, prec_: workPrecRelay] := Module[{rD, rE, f},
  rD = SetPrecision[10^(rtDB/10), prec];
  rE = SetPrecision[10^(reDB/10), prec];
  f = If[split === "half", 1/2, 1];          
  <|"rho1d" -> f rD, "rho2d" -> f rD, "rho1e" -> rE, "rho2e" -> rE|>];

esmcRIScf[rtDB_?NumericQ, M_Integer?Positive, L_Integer?Positive,
   NRd_Integer?Positive, NRe_Integer?Positive, reDB_?NumericQ] := Module[{prec},
  prec = risAdaptivePrecision[NRd, NRe, M, L];
  Quiet@Check[CsTwoBranchErlang[NRd, NRe, rtDB, reDB, M, L, prec], Indeterminate]
];
esmcRelaycf[rtDB_?NumericQ, M_Integer?Positive, L_Integer?Positive,
   reDB_?NumericQ, split_String, T_Integer?Positive, prec_Integer?Positive] :=
  Module[{h = hopSNRs[rtDB, reDB, split, prec]},
  CsRelaySeriesMeijerG[M, L, h["rho1d"], h["rho2d"], h["rho1e"], h["rho2e"], T, prec]];

positiveMean[v_List] := N[Mean[Clip[v, {0, Infinity}]]];

esmcRISmcPlan[rtDB_?NumericQ, M_Integer?Positive, L_Integer?Positive,
   NRd_Integer?Positive, NRe_Integer?Positive, reDB_?NumericQ] := Module[
  {rhoD, rhoE, sd, se, b, Ad, Ae, gd, ge, cs},
  rhoD = N[10^(rtDB/10)]; rhoE = N[10^(reDB/10)];
  sd = N[shapeFromNR[NRd, 40]]; se = N[shapeFromNR[NRe, 40]]; b = N[scaleRayleighRIS[40]];
  BlockRandom[
    SeedRandom[mcSeedBase + Abs[Hash[{"RIS_PLAN_MC", rtDB, M, L, NRd, NRe, reDB}]]];
    Ad = RandomVariate[GammaDistribution[sd, b], {mcTrials, M}];
    Ae = RandomVariate[GammaDistribution[se, b], {mcTrials, L}];
    gd = rhoD*(Min /@ Ad)^2; ge = rhoE*(Max /@ Ae)^2;
    cs = Log2[(1 + gd)/(1 + ge)];
  ];
  N[Total[Clip[cs, {0, Infinity}]] / mcTrials]];

esmcRelaymcPlan[rtDB_?NumericQ, M_Integer?Positive, L_Integer?Positive,
   reDB_?NumericQ, split_String] := Module[
  {h, g1, g2, e1, e2, gd, ge, cs},
  h = hopSNRs[rtDB, reDB, split];
  BlockRandom[
    SeedRandom[mcSeedBase + Abs[Hash[{"RELAY_PLAN_MC", rtDB, M, L, reDB, split}]]];
    g1 = RandomVariate[ExponentialDistribution[1/N[h["rho1d"]]], {mcTrials, M}];
    g2 = RandomVariate[ExponentialDistribution[1/N[h["rho2d"]]], {mcTrials, M}];
    gd = Min /@ (g1*g2/(g1 + g2));
    e1 = RandomVariate[ExponentialDistribution[1/N[h["rho1e"]]], {mcTrials, L}];
    e2 = RandomVariate[ExponentialDistribution[1/N[h["rho2e"]]], {mcTrials, L}];
    ge = Max /@ (e1*e2/(e1 + e2));
    cs = (1/2) Log2[(1 + gd)/(1 + ge)];
  ];
  N[Total[Clip[cs, {0, Infinity}]] / mcTrials]];

(* ======================================================================= *)
(* ASYMPTOTES: EXACT ORIGINAL EVALUATION RESTORED                          *)
(* ======================================================================= *)
ClearAll[JKernelAsy, esmcRISasy, esmcRelayAsy];
JKernelAsy[n_Integer?NonNegative, c_?NumericQ, prec_: workPrecRIS] := Module[
  {cc = SetPrecision[c, prec], val, rr},
  val = Quiet@Check[
     Re@N[Gamma[n + 1]/(2 I)*(((-I)^n) Exp[-I cc] Gamma[-n, -I cc] -
         (I^n) Exp[I cc] Gamma[-n, I cc]), prec],
     $Failed
  ];
  rr = If[val === $Failed, $Failed, safeReal[val]];
  If[rr === $Failed || !NumericQ[rr], 0, Max[0, rr]]
];

esmcRISasy[rtDB_?NumericQ, M_Integer?Positive, K_Integer?Positive,
   NRd_Integer?Positive, NRe_Integer?Positive, reDB_?NumericQ] := Module[
  {prec = workPrecRIS, sd, se, b, rhoD, rhoE, pd, pe, lamD, Gd, gdPow,
   ElnA, sePoly, deltaE, ePow, eMax, p, q, n},
  sd = shapeFromNR[NRd, prec]; se = shapeFromNR[NRe, prec]; b = scaleRayleighRIS[prec];
  rhoD = rhoLin[rtDB, prec]; rhoE = rhoLin[reDB, prec];
  pd = twoBranchParams[sd, b, prec]; pe = twoBranchParams[se, b, prec];
  lamD = pd["lambda"];
  Gd = survivalPolyCoeffs[pd, 1, prec]["coeffs"];
  gdPow = polyPower[Gd, M];
  ElnA = gdPow[[1]] (-EulerGamma - Log[M lamD])
     + Sum[gdPow[[p + 1]] Gamma[p]/(M lamD)^p, {p, 1, Length[gdPow] - 1}];
  sePoly = survivalPolyCoeffs[pe, rhoE, prec]; deltaE = sePoly["alpha"];
  eMax = (2/ln2) Sum[
     ePow = polyPower[sePoly["coeffs"], n];
     (-1)^(n + 1) Binomial[K, n] sortedTotal[Table[
        ePow[[q + 1]] JKernelAsy[q + 1, n deltaE, prec], {q, 0, Length[ePow] - 1}]],
     {n, 1, K}];
  N[Log2[rhoD] + (2/ln2) ElnA - eMax, 30]];

esmcRelayAsy[rtDB_?NumericQ, anchorDB_?NumericQ, anchorVal_?NumericQ] :=
  0.5 Log2[10^(rtDB/10)] + (anchorVal - 0.5 Log2[10^(anchorDB/10)]);

(* ======================================================================= *)
(* SPEC BUILDER AND FORMATTING                                             *)
(* ======================================================================= *)
ClearAll[palette, mkSpec, buildSpecs, cfOf, mcPlanOf, formatLabel];
professionalPalette = {
  RGBColor[0.000, 0.270, 0.600],  (* deep blue *)
  RGBColor[0.850, 0.325, 0.098],  (* burnt orange *)
  RGBColor[0.000, 0.500, 0.200],  (* forest green *)
  RGBColor[0.494, 0.184, 0.556],  (* purple *)
  RGBColor[0.929, 0.694, 0.125],  
  RGBColor[0.301, 0.745, 0.933],
  RGBColor[0.635, 0.078, 0.184]
};
palette[1] := {professionalPalette[[1]]};
palette[k_Integer?Positive] := Table[professionalPalette[[Mod[i - 1, Length[professionalPalette]] + 1]], {i, k}];

formatLabel[sv_, val_] := Switch[sv,
   "rhoEdB", ToString[val] <> " dB",
   "L", "K = " <> ToString[val],
   "M", "M = " <> ToString[val],
   _, sv <> " = " <> ToString[val]
];

mkSpec[cfg_Association, risQ_, overrides_Association, color_, label_] :=
  Join[<|"risQ" -> risQ, "M" -> cfg["M"], "L" -> cfg["L"],
         "NRd" -> cfg["NRd"], "NRe" -> cfg["NRe"], "rhoEdB" -> cfg["rhoEdB"],
         "split" -> cfg["hopSplit"], "Trelay" -> cfg["Trelay"], "precRelay" -> cfg["precRelay"],
         "color" -> color, "label" -> label|>, overrides];

buildSpecs[cfg_Association] := Module[{sv = cfg["sweepVar"], sl = cfg["sweepList"], cols, specs},
  specs = {};
  cols = palette[Length[sl]];
  Do[
     AppendTo[specs, mkSpec[cfg, True, <|sv -> sl[[i]], "skey" -> sl[[i]], "cIdx" -> i|>, cols[[i]], "RIS, " <> formatLabel[sv, sl[[i]]]]];
     If[TrueQ@cfg["showRelay"],
        AppendTo[specs, mkSpec[cfg, False, <|sv -> sl[[i]], "skey" -> sl[[i]], "cIdx" -> i|>, cols[[i]], "AF relay, " <> formatLabel[sv, sl[[i]]]]];
     ];
  , {i, Length[sl]}];
  specs
];

cfOf[s_Association, rt_?NumericQ] := If[s["risQ"],
   esmcRIScf[rt, s["M"], s["L"], s["NRd"], s["NRe"], s["rhoEdB"]],
   esmcRelaycf[rt, s["M"], s["L"], s["rhoEdB"], s["split"], s["Trelay"], s["precRelay"]]];
mcPlanOf[s_Association, rt_?NumericQ] := If[s["risQ"],
   esmcRISmcPlan[rt, s["M"], s["L"], s["NRd"], s["NRe"], s["rhoEdB"]],
   esmcRelaymcPlan[rt, s["M"], s["L"], s["rhoEdB"], s["split"]]];

(* ======================================================================= *)
(* PLOTTING (IEEE style) AND EXPORT                                        *)
(* ======================================================================= *)
xlab = "Destination SNR  \!\(\*SubscriptBox[\(\[Rho]\),\(d\)]\)  (dB)";
ylab = "\!\(\*SubscriptBox[\(C\), \(s,mc\)]\)  (bits/s/Hz)";

(* Eliminated standard dashed line. Using strictly Solid and Dot-Dash *)
dashCycleFig1 = {AbsoluteDashing[{}], AbsoluteDashing[{8, 4, 2, 4}]}; 
colOf[i_]  := professionalPalette[[Mod[i - 1, Length[professionalPalette]] + 1]];

ClearAll[markerShapeFor, hollowMarker, singleTag, buildLegendInset, exportRows, buildFig];
markerShapeFor[i_Integer] := {"Circle", "Square", "Diamond", "Triangle", "DownTriangle", "Pentagon", "Hexagon", "Circle"}[[Mod[i - 1, 8] + 1]];

hollowMarker[shape_String, col_, size_: mcMarkerSize, thick_: mcMarkerOutlineThickness] := Module[{prim},
  prim = Switch[shape,
    "Circle", Disk[{0, 0}, 1],
    "Square", Polygon[{{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}],
    "Diamond", Polygon[{{0, 1.18}, {1.18, 0}, {0, -1.18}, {-1.18, 0}}],
    "Triangle", Polygon[{{0, 1.22}, {-1.12, -0.82}, {1.12, -0.82}}],
    "DownTriangle", Polygon[{{0, -1.22}, {-1.12, 0.82}, {1.12, 0.82}}],
    "Pentagon", Polygon[Table[{Cos[Pi/2 + 2 Pi k/5], Sin[Pi/2 + 2 Pi k/5]}, {k, 0, 4}]],
    "Hexagon", Polygon[Table[{Cos[Pi/6 + 2 Pi k/6], Sin[Pi/6 + 2 Pi k/6]}, {k, 0, 5}]],
    _, Disk[{0, 0}, 1]
  ];
  Graphics[{FaceForm[White], EdgeForm[Directive[col, AbsoluteThickness[thick]]], prim},
    ImageSize -> size, PlotRange -> {{-1.35, 1.35}, {-1.35, 1.35}},
    PlotRangePadding -> 0, Background -> None]
];

singleTag[xc_, yc_, rx_, ry_, label_, labelPt_] := {
   GrayLevel[0.28], AbsoluteThickness[1.45],
   Circle[{xc, yc}, {rx, ry}],
   GrayLevel[0.40], AbsoluteThickness[1.05], AbsoluteDashing[{2.2, 2.2}],
   Arrowheads[0.018], Arrow[{labelPt, {xc + If[xc > labelPt[[1]], -0.92 rx, 0.92 rx], yc}}],
   Text[Style[label, 10.8, FontFamily -> $font, Background -> White], labelPt]};

ClearAll[yAtCurve, professionalCallout, buildRhoECallouts];
yAtCurve[data_List, x_?NumericQ] := Module[{clean, xmin, xmax},
  clean = Select[data, NumericQ[#[[1]]] && NumericQ[#[[2]]] &];
  If[Length[clean] < 2, Return[$Failed]];
  xmin = Min[clean[[All, 1]]]; xmax = Max[clean[[All, 1]]];
  If[x < xmin || x > xmax, Return[$Failed]];
  Quiet@Check[N[Interpolation[clean, InterpolationOrder -> 1][x]], $Failed]
];

professionalCallout[data_List, x_?NumericQ, yOffset_?NumericQ, label_, col_] := Module[
  {y, circleRx, circleRy, labelPt, arrowStart, arrowEnd},
  y = yAtCurve[data, x];
  If[y === $Failed || !NumericQ[y], Return[{}]];

  (* Thin, solid black indicator; short vertical pointer only. *)
  circleRx = 0.50;
  circleRy = 0.075;
  labelPt = {x, y + yOffset};
  arrowStart = {x, y + 0.66 yOffset};
  arrowEnd = {x, y + circleRy};

  {
    Directive[Black, AbsoluteThickness[1.15], Dashing[{}], Opacity[1]],
    Circle[{x, y}, {circleRx, circleRy}],

    Directive[Black, AbsoluteThickness[0.95], Dashing[{}], Opacity[1]],
    Arrowheads[0.014],
    Arrow[{arrowStart, arrowEnd}],

    Text[
      Style[label, 11.3, FontFamily -> $font, Background -> White,
        FontColor -> Black, FontWeight -> "SemiBold"],
      labelPt
    ]
  }
];

buildRhoECallouts[cfData_List, ymax_?NumericQ] := Module[{items},
  items = {
    professionalCallout[cfData[[1]], 22.0, 1.12, "\!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\) = 0 dB", professionalPalette[[1]]],
    professionalCallout[cfData[[3]], 24.0, 0.82, "\!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\) = 10 dB", professionalPalette[[1]]],
    professionalCallout[cfData[[2]], 31.0, 0.72, "\!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\) = 0 dB", professionalPalette[[2]]],
    professionalCallout[cfData[[4]], 35.5, 0.55, "\!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\) = 10 dB", professionalPalette[[2]]]
  };
  Flatten[Select[items, ListQ], 1]
];

buildLegendInset[entries_, pos_] := Module[{rows},
  rows = Map[Function[e,
     If[e[[1]] === "text",
       {Graphics[{}, ImageSize -> {42, 12}, PlotRange -> {{0, 1}, {0, 1}}, PlotRangePadding -> 0],
        Style[e[[2]], 10.6, Bold, FontFamily -> $font]},
       {Graphics[If[e[[1]] === "marker",
          {If[e[[6]] =!= "None", Inset[hollowMarker[e[[6]], e[[2]], 9, 1.9], {0.5, 0.5}], {}]},
          {e[[2]], e[[3]], AbsoluteThickness[1.75], Line[{{0, 0.5}, {1, 0.5}}],
           If[e[[6]] =!= "None", Inset[hollowMarker[e[[6]], e[[2]], 9, 1.9], {0.5, 0.5}], {}]}],
         ImageSize -> {42, 14}, PlotRange -> {{0, 1}, {0, 1}}, PlotRangePadding -> 0],
        Style[e[[5]], 10.8, FontFamily -> $font]}
     ]], entries];
  Inset[Framed[Grid[rows, Alignment -> {Left, Center}, Spacings -> {0.28, 0.32}],
     Background -> White, FrameStyle -> Directive[GrayLevel[0.20], AbsoluteThickness[0.65]],
     RoundingRadius -> 0, FrameMargins -> 6], Scaled[pos], {Left, Top}]
];

exportRows[figName_String, specs_List, cfData_List, mcData_List] := Flatten[Table[
   Join[
     Table[{figName, specs[[i]]["label"], If[specs[[i]]["risQ"], "RIS", "AFRelay"],
        "ClosedFormLine", specs[[i]]["M"], specs[[i]]["L"],
        If[specs[[i]]["risQ"], specs[[i]]["NRd"], "NA"], If[specs[[i]]["risQ"], specs[[i]]["NRe"], "NA"],
        specs[[i]]["rhoEdB"], cfData[[i, j, 1]], cfData[[i, j, 2]]}, {j, Length[cfData[[i]]]}],
     Table[{figName, specs[[i]]["label"], If[specs[[i]]["risQ"], "RIS", "AFRelay"],
        "PlanMonteCarloMarker", specs[[i]]["M"], specs[[i]]["L"],
        If[specs[[i]]["risQ"], specs[[i]]["NRd"], "NA"], If[specs[[i]]["risQ"], specs[[i]]["NRe"], "NA"],
        specs[[i]]["rhoEdB"], mcData[[i, j, 1]], mcData[[i, j, 2]]}, {j, Length[mcData[[i]]]}]],
   {i, Length[specs]}], 1];

ClearAll[cleanXYData, evaluateCFDataParallel, evaluateMCDataParallel];
cleanXYData[data_] := Select[data, NumericQ[#[[1]]] && NumericQ[#[[2]]] && #[[2]] =!= Indeterminate && #[[2]] =!= ComplexInfinity && #[[2]] =!= Infinity && #[[2]] =!= -Infinity &];

evaluateCFDataParallel[specs_List, grid_List] := Module[{jobs, raw},
  refreshParallelDefinitions[];
  jobs = Flatten[Table[{i, j, grid[[j]]}, {i, Length[specs]}, {j, Length[grid]}], 1];
  raw = If[TrueQ[useParallelKernelSaturation],
    ParallelTable[Module[{i = jobs[[jj, 1]], x = jobs[[jj, 3]], y},
      y = Quiet@Check[N[cfOf[specs[[i]], x]], Indeterminate]; {i, x, y}],
      {jj, Length[jobs]}, Method -> "CoarsestGrained"],
    Table[Module[{i = jobs[[jj, 1]], x = jobs[[jj, 3]], y},
      y = Quiet@Check[N[cfOf[specs[[i]], x]], Indeterminate]; {i, x, y}], {jj, Length[jobs]}]
  ];
  Table[cleanXYData[SortBy[({#[[2]], #[[3]]} & /@ Select[raw, #[[1]] == i &]), First]], {i, Length[specs]}]
];

evaluateMCDataParallel[specs_List, gridMC_List] := Module[{jobs, raw},
  refreshParallelDefinitions[];
  jobs = Flatten[Table[
    If[ListQ[gridMC[[i]]],
      Table[{i, j, gridMC[[i, j]]}, {j, Length[gridMC[[i]]]}],
      Table[{i, j, gridMC[[j]]}, {j, Length[gridMC]}]
    ], {i, Length[specs]}], 1];
    
  raw = If[TrueQ[useParallelKernelSaturation],
    ParallelTable[Module[{i = jobs[[jj, 1]], x = jobs[[jj, 3]], y},
      y = Quiet@Check[N[mcPlanOf[specs[[i]], x]], Indeterminate]; {i, x, y}],
      {jj, Length[jobs]}, Method -> "CoarsestGrained"],
    Table[Module[{i = jobs[[jj, 1]], x = jobs[[jj, 3]], y},
      y = Quiet@Check[N[mcPlanOf[specs[[i]], x]], Indeterminate]; {i, x, y}], {jj, Length[jobs]}]
  ];
  Table[cleanXYData[SortBy[({#[[2]], #[[3]]} & /@ Select[raw, #[[1]] == i &]), First]], {i, Length[specs]}]
];

buildFig[cfg_Association] := Module[
  {specs, grid, gridMC, baseName = cfg["name"], cfData, mcData, n,
   colorMode, mkColors, mkSyms, dashFor, legEntries, legPos, ann, base, mkPlot, asyPlot, fig, rows, header,
   pdfPath, pngPath, csvPath, t0, autoAnn},
  
  specs = buildSpecs[cfg]; grid = cfg["snrDdB"]; n = Length[specs];
  
  (* Subsample and Stagger Relay MC Markers specifically for Fig 2 to eliminate overlap completely *)
  If[baseName === "Fig2_Eavesdropper_Count_K_Sweep" || Lookup[cfg, "sweepVar", ""] === "L",
    gridMC = Table[
      If[specs[[i]]["risQ"],
        grid,
        Module[{rIdx = Count[specs[[1;;i]], _?(#["risQ"] == False &)]},
          (* Staggered subsets: offsets starting position based on curve index *)
          Select[Range[2.5 * (rIdx - 1), Max[grid], 10], # <= Max[grid] &]
        ]
      ],
      {i, n}
    ];
  ,
    gridMC = Table[grid, {i, n}]; (* Standard identical grid for Fig 1 *)
  ];
  
  Print["\n============================================================"];
  Print["Building ", baseName, " with ", n, " curves"];
  
  t0 = AbsoluteTime[];
  cfData = evaluateCFDataParallel[specs, grid];
  Print["Closed-form time: ", NumberForm[AbsoluteTime[] - t0, {8, 2}], " s"];
  
  t0 = AbsoluteTime[];
  mcData = evaluateMCDataParallel[specs, gridMC];
  Print["MC marker time: ", NumberForm[AbsoluteTime[] - t0, {8, 2}], " s"];
  
  colorMode = Lookup[cfg, "colorBy", "sweepVar"];
  legEntries = {};
  
  If[colorMode === "system",
     mkColors = Table[If[specs[[i]]["risQ"], professionalPalette[[1]], professionalPalette[[2]]], {i, n}];
     dashFor[i_] := dashCycleFig1[[ specs[[i]]["cIdx"] ]]; 
     mkSyms = Table[hollowMarker[markerShapeFor[specs[[i]]["cIdx"]], mkColors[[i]], mcMarkerSize, mcMarkerOutlineThickness], {i, n}];
     
     legEntries = {
        {"text", "M = " <> ToString[cfg["M"]] <> ", K = " <> ToString[cfg["L"]] <> ", " <> "\!\(\*SubscriptBox[\(N\), \(R\)]\) = " <> ToString[cfg["NRd"]]},
        {"line", professionalPalette[[1]], AbsoluteDashing[{}], True, "RIS analytical", "Circle"},
        {"line", professionalPalette[[2]], AbsoluteDashing[{}], False, "AF relay analytical", "Square"}
     };
     Do[
        AppendTo[legEntries, {"line", GrayLevel[0.15], dashCycleFig1[[i]], True, "\!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\) = " <> ToString[cfg["sweepList"][[i]]] <> " dB", "None"}];
     , {i, Length[cfg["sweepList"]]}];
     AppendTo[legEntries, {"marker", GrayLevel[0.15], None, True, "Monte Carlo simulation", "Circle"}];
     
     If[TrueQ@Lookup[cfg, "showAsy", False],
        AppendTo[legEntries, {"line", Black, AbsoluteDashing[{2, 3}], True, "High-SNR asymptotic result", "None"}];
     ];
  ,
     mkColors = Table[ colOf[specs[[i]]["cIdx"]], {i, n}];
     dashFor[i_] := If[specs[[i]]["risQ"], AbsoluteDashing[{}], AbsoluteDashing[{8, 4, 2, 4}]];
     mkSyms = Table[hollowMarker[If[specs[[i]]["risQ"], "Circle", "Square"], mkColors[[i]], mcMarkerSize, mcMarkerOutlineThickness], {i, n}];
     
     AppendTo[legEntries, {"text", "M = " <> ToString[cfg["M"]] <> ", " <> "\!\(\*SubscriptBox[\(N\), \(R\)]\) = " <> ToString[cfg["NRd"]] <> ", " <> "\!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\) = " <> ToString[cfg["rhoEdB"]] <> " dB"}];
     AppendTo[legEntries, {"text", "\!\(\*SubscriptBox[\(\[Rho]\), \(d\)]\) swept from " <> ToString[Min[grid]] <> " to " <> ToString[Max[grid]] <> " dB"}];
     Do[
        AppendTo[legEntries, {"line", colOf[i], AbsoluteDashing[{}], True, formatLabel[cfg["sweepVar"], cfg["sweepList"][[i]]], "None"}];
     , {i, Length[cfg["sweepList"]]}];
     AppendTo[legEntries, {"line", GrayLevel[0.15], AbsoluteDashing[{}], True, "RIS analytical", "Circle"}];
     AppendTo[legEntries, {"line", GrayLevel[0.15], AbsoluteDashing[{8, 4, 2, 4}], False, "AF relay analytical", "Square"}];
     AppendTo[legEntries, {"marker", GrayLevel[0.15], None, True, "Monte Carlo simulation", "Circle"}];
  ];

  lineStyles = Table[Directive[mkColors[[i]], AbsoluteThickness[1.6], dashFor[i]], {i, n}];
  
  legPos = Lookup[cfg, "legendPos", {0.03, 0.97}];
  ymax = 1.15 Max[0.05, Max[Flatten[{cfData[[All, All, 2]], mcData[[All, All, 2]]}]]];
  autoAnn = If[baseName === "Fig1_RIS_vs_Relay_RhoE_Sweep", buildRhoECallouts[cfData, ymax], {}];
  ann = Join[Lookup[cfg, "annotations", {}], autoAnn];
  
  asyData = {}; asyStyles = {};
  If[TrueQ@Lookup[cfg, "showAsy", False],
   asyGrid = grid;                                    
   Do[If[specs[[i]]["risQ"],
       AppendTo[asyData, ({#, esmcRISasy[#, specs[[i]]["M"], specs[[i]]["L"],
          specs[[i]]["NRd"], specs[[i]]["NRe"], specs[[i]]["rhoEdB"]]} & /@ asyGrid)],
       anchorDB = Last[grid]; anchorVal = cfData[[i, -1, 2]];
       AppendTo[asyData, ({#, esmcRelayAsy[#, anchorDB, anchorVal]} & /@ asyGrid)]];
     AppendTo[asyStyles, Directive[Black, AbsoluteThickness[1.6], AbsoluteDashing[{2, 3}]]],
    {i, n}]];
  
  base = ListLinePlot[cfData, PlotStyle -> lineStyles, InterpolationOrder -> 2,
     Frame -> True, Axes -> False, Background -> White, GridLines -> Automatic,
     GridLinesStyle -> Directive[GrayLevel[0.88], AbsoluteDashing[{1.2, 3.0}], AbsoluteThickness[0.45]],
     FrameLabel -> {Style[xlab, 15, FontFamily -> $font], Style[ylab, 15, FontFamily -> $font]},
     FrameStyle -> Directive[Black, AbsoluteThickness[1.2]],
     FrameTicksStyle -> Directive[Black, 11, FontFamily -> $font],
     BaseStyle -> {FontFamily -> $font, FontSize -> 12},
     PlotRange -> {{Min[grid], Max[grid]}, {0, ymax}},
     ImageSize -> 760, ImagePadding -> {{72, 20}, {56, 16}}];
     
  mkPlot = ListPlot[mcData, PlotStyle -> mkColors, PlotMarkers -> mkSyms, PlotRange -> {{Min[grid], Max[grid]}, {0, ymax}}, PerformanceGoal -> "Quality"];
  
  asyPlot = If[asyData === {}, Graphics[],
     ListLinePlot[asyData, PlotStyle -> asyStyles, InterpolationOrder -> 1]];
  
  fig = Show[base, asyPlot, mkPlot, Background -> White,
     PlotRange -> {{Min[grid], Max[grid]}, {0, ymax}},
     Epilog -> {buildLegendInset[legEntries, legPos], ann}];
     
  rows = exportRows[baseName, specs, cfData, mcData];
  header = {"Figure", "CurveLabel", "System", "CurveType", "M", "L", "NRd", "NRe",
    "rhoE_dB", "rhoD_dB", "ESMC_bits_per_s_per_Hz"};
  pdfPath = FileNameJoin[{$outDir, baseName <> "_styled.pdf"}];
  pngPath = FileNameJoin[{$outDir, baseName <> "_styled.png"}];
  csvPath = FileNameJoin[{$outDir, baseName <> "_Data.csv"}];
  
  Export[pdfPath, fig];
  Export[pngPath, Rasterize[fig, "Image", ImageResolution -> $outputDPI, Background -> White]];
  Export[csvPath, Prepend[rows, header]];
  Print["Saved: ", pdfPath]; Print["Saved: ", pngPath]; Print["Saved: ", csvPath];
  
  If[TrueQ[showFiguresInNotebook], Print[fig]];
  fig];

(* ======================================================================= *)
(* EXECUTE FIGURES                                                         *)
(* ======================================================================= *)

fig1 = buildFig[f1Config];
fig2 = buildFig[f2Config];

combined = Column[{fig1, fig2}, Spacings -> 2, Background -> White];
Export[FileNameJoin[{$outDir, "CombinedPreview.pdf"}], combined];
Export[FileNameJoin[{$outDir, "CombinedPreview.png"}],
  Rasterize[combined, "Image", ImageResolution -> $outputDPI, Background -> White]];

Print["============================================================"];
Print["DONE. Output folder: ", $outDir];
Print["============================================================"];



