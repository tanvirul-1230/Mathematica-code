(* ::Package:: *)

(* ======================================================================= *)
(* FAST Q1 FIGURE GENERATOR -- PARALLEL + TRICOMI-U + NR100-STABLE RIS      *)
(*                                                                         *)
(* Lines   = YOUR analytical closed forms (unchanged):                     *)
(*           RIS   : two-branch Erlang closed form                         *)
(*           Relay : T-series Tricomi-U/Tricomi-U-equivalent closed form               *)
(* Markers = MONTE CARLO ON THE PLAN PDF MODEL (unchanged):                *)
(*           RIS   : Gamma amplitude A, gamma = rho A^2                     *)
(*           Relay : exponential hops, gamma = g1 g2/(g1+g2), 1/2 pre-log   *)
(*                                                                         *)
(* Plan model from: Boulogeorgos & Alexiou, "Performance Analysis of RIS-  *)
(* Assisted Wireless Systems and Comparison With Relaying," IEEE Access.    *)
(*                                                                         *)
(* HOW TO TUNE: edit the COMMON block and the THREE FIGURE CONFIG blocks.   *)
(* Each figure is fully independent. Nothing else needs editing.           *)
(* ======================================================================= *)

ClearAll["Global`*"];
$HistoryLength = 0;
$MaxExtraPrecision = 100000;
Quiet@Check[SetSystemOptions["ParallelOptions" -> "MKLThreadNumber" -> 1], Null];
ClearSystemCache[];
ln2 = Log[2];

(* ============================ COMMON ================================== *)
(* Shared by all three figures (engine settings + the one fixed-SNR knob). *)

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

(* Q1/IEEE marker tuning: small hollow markers, sharp thick border. *)
mcMarkerSize = 13;
mcMarkerOutlineThickness = 1.8;

rhoEdBCommon = 0;                 (* fixed eavesdropper SNR (dB), default   *)
                                  (* for all figures (override per fig)     *)
snrDdBCommon = Range[0, 40, 5];   (* analytical destination/main SNR sweep *)
snrDdBMCCommon = Range[0, 40, 5]; (* MC marker grid; keep 5 dB for visible validation *)

mcTrials   = 40000;               (* Monte Carlo samples per marker         *)
mcChunk    = 5000;                (* chunked MC (memory)                    *)
mcSeedBase = 2101097;

workPrecRIS   = 200;              (* default RIS closed-form precision       *)
risHighNRPrecision = workPrecRIS;  (* keep original FinalCode precision for NR>=50 *)
risDirectKernelThreshold = 700;        (* high-degree RIS uses exact closed-form J-kernel table *)
workPrecRelay = 300;              (* relay precision DEFAULT (per-fig override)*)
TseriesRelay  = 120;              (* relay truncation DEFAULT (per-fig override)*)
(* The relay closed form builds a degree (M*Trelay) polynomial with sign-   *)
(* alternating coefficients, so it needs precRelay ~ 2.5*M*Trelay digits to *)
(* avoid cancellation. At high M keep Trelay small and precRelay large, and *)
(* set both per figure via the config fields "Trelay" and "precRelay".      *)

$font = "Times New Roman";
$outputDPI = 600;

(* NOTE on "alpha": the RIS Laguerre shape a is NOT a free knob; it is set  *)
(* by the element count via  a + 1 = NR*Pi^2/(16-Pi^2),  b = (16-Pi^2)/(2Pi)*)
(* So tune the shape through NRd / NRe.                                     *)

(* ===================== FIGURE 1 : RIS vs AF relay ==================== *)
(* sweepVar="none" -> one RIS curve + one relay curve.                     *)
f1Config = <|
   "name"      -> "Fig1_RIS_vs_AFRelay",
   "rhoEdB"    -> rhoEdBCommon,        (* fixed eavesdropper SNR (dB)       *)
   "snrDdB"    -> snrDdBCommon,        (* rho_d sweep (x-axis), dB          *)
   "snrDdBMC"  -> snrDdBMCCommon,
   "M"         -> 10,                  (* legitimate multicast users        *)
   "L"         -> 5,                   (* eavesdroppers                     *)
   "NRd"       -> 4,                   (* RIS elements, destination link    *)
   "NRe"       -> 4,                   (* RIS elements, eavesdropper link   *)
   "hopSplit"  -> "full",             (* relay: "full" or "half"            *)
   "Trelay"    -> 40,                  (* relay Bessel-series truncation     *)
   "precRelay" -> 1000,                (* relay precision (>= ~2.5*M*Trelay) *)
   "sweepVar"  -> "none",
   "sweepList" -> {},
   "showRIS"   -> True,
   "showRelay" -> True,
   "showAsy"   -> True,                (* draw RIS + relay high-SNR asymptotes*)
   "legendPos" -> {0.03, 0.97},        (* boxed legend anchor, inside axes   *)
   "annotations" -> {}                 (* e.g. {groupTag[30,4,6,1.5,"text",{22,7}]} *)
|>;

(* ============ FIGURE 2 : effect of RIS element count ================= *)
(* sweepVar="NR" -> sweeps Bob AND Eve elements together (NRd=NRe=NR),     *)
(* consistent with the worst-case coherent eavesdropper (one shared RIS).  *)
(* For the alternative "Eve aperture capped" study, use sweepVar="NRd"     *)
(* and set a fixed "NRe".                                                  *)
f2Config = <|
   "name"      -> "Fig2_RIS_Element_Count",
   "rhoEdB"    -> rhoEdBCommon,
   "snrDdB"    -> snrDdBCommon,
   "snrDdBMC"  -> snrDdBMCCommon,
   "M"         -> 5,
   "L"         -> 3,
   "NRd"       -> 4,                   (* ignored when sweepVar="NR"        *)
   "NRe"       -> 4,                   (* ignored when sweepVar="NR"        *)
   "hopSplit"  -> "full",
   "Trelay"    -> 120,                 (* M=2 is light, full T is fine       *)
   "precRelay" -> 300,
   "sweepVar"  -> "NR",               (* sweep Bob AND Eve elements together*)
   "sweepList" -> {1, 2, 5, 10, 100},
   "showRIS"   -> True,
   "showRelay" -> True,                (* single relay benchmark line        *)
   "showAsy"   -> False,
   "legendPos" -> {0.03, 0.97},
   "annotations" -> {}
|>;

(* ============ FIGURE 3 : effect of multicast users M ================= *)
(* sweepVar="M" -> RIS curve + relay curve for each user count.            *)
f3Config = <|
   "name"      -> "Fig3_User_Loading_M",
   "rhoEdB"    -> rhoEdBCommon,
   "snrDdB"    -> snrDdBCommon,
   "snrDdBMC"  -> snrDdBMCCommon,
   "M"         -> 5,                   (* ignored (swept)                   *)
   "L"         -> 3,
   "NRd"       -> 4,
   "NRe"       -> 4,
   "hopSplit"  -> "full",
   "Trelay"    -> 25,                  (* low T: figure includes M=20        *)
   "precRelay" -> 1400,                (* >= ~2.5*Mmax*Trelay = 2.5*20*25     *)
   "sweepVar"  -> "M",                (* sweep number of users              *)
   "sweepList" -> {1, 2, 8, 20},
   "showRIS"   -> True,
   "showRelay" -> True,
   "showAsy"   -> False,
   "legendPos" -> {0.03, 0.97},
   "annotations" -> {}
|>;

(* Other valid sweepVar values you can use in any figure:                  *)
(*   "none" | "NR" | "NRd" | "NRe" | "M" | "L" | "rhoEdB"                   *)
(*   "NR"        : sweep Bob AND Eve elements together (NRd=NRe), worst case *)
(*   "NRd"/"NRe" : sweep one link's elements only (RIS family + relay ref)   *)
(*   "M"/"L"/"rhoEdB" : sweep both systems as paired families.              *)

(* Output folder *)
$scriptDir = If[StringQ[$InputFileName] && $InputFileName =!= "",
   DirectoryName[$InputFileName], Quiet@Check[NotebookDirectory[], Directory[]]];
If[!StringQ[$scriptDir] || $scriptDir === "", $scriptDir = Directory[]];
$outDir = FileNameJoin[{$scriptDir, "Q1_FAST_Parallel_Output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir, CreateIntermediateDirectories -> True]];
Print["Output folder: ", $outDir];

(* ======================================================================= *)
(* ENGINE A: RIS TWO-BRANCH ERLANG CLOSED FORM  (unchanged)                *)
(* ======================================================================= *)
ClearAll[shapeFromNR, scaleRayleighRIS, rhoLin];
shapeFromNR[NR_?NumericQ, prec_: workPrecRIS] := N[NR Pi^2/(16 - Pi^2), prec];
scaleRayleighRIS[prec_: workPrecRIS] := N[(16 - Pi^2)/(2 Pi), prec];
rhoLin[rhoDB_?NumericQ, prec_: workPrecRIS] := SetPrecision[10^(rhoDB/10), prec];

ClearAll[twoBranchParams];
twoBranchParams[s_?NumericQ, b_?NumericQ, prec_: workPrecRIS] := Module[
  {ss = SetPrecision[s, prec], bb = SetPrecision[b, prec], m0, P, lam},
  m0 = Ceiling[N[ss, 30]];
  P = N[(m0 - Sqrt[ss*m0*(ss + 1 - m0)])/(ss + 1), prec];
  lam = N[(m0 - P)/(ss*bb), prec];
  If[P < 0 && Abs[P] < 10^-30, P = 0];
  If[P > 1 && Abs[P - 1] < 10^-30, P = 1];
  <|"s" -> ss, "b" -> bb, "m0" -> m0, "P" -> P, "lambda" -> lam|>];

ClearAll[survivalPolyCoeffs];
survivalPolyCoeffs[params_Association, rho_?NumericQ, prec_: workPrecRIS] := Module[
  {m0 = params["m0"], P = SetPrecision[params["P"], prec],
   lam = SetPrecision[params["lambda"], prec], alpha, coeffs, r},
  alpha = N[lam/Sqrt[SetPrecision[rho, prec]], prec];
  coeffs = ConstantArray[0, m0];
  Do[coeffs[[r + 1]] = N[alpha^r/Factorial[r], prec], {r, 0, Max[m0 - 2, 0]}];
  coeffs[[m0]] = N[(1 - P)*alpha^(m0 - 1)/Factorial[m0 - 1], prec];
  <|"alpha" -> alpha, "coeffs" -> coeffs|>];

ClearAll[polyMul, polyPower, sortedTotal, safeReal];

(* IMPORTANT: manual coefficient convolution is intentionally used here.
   Do NOT replace this by ListConvolve. The single NR=100 script that works
   uses this exact coefficient ordering. ListConvolve changes the effective
   coefficient ordering for the indexing convention used in the closed-form
   sums and can make the high-degree NR=100 RIS curve collapse to zero. *)
polyMul[a_List, b_List] := Module[{c, i, j, la = Length[a], lb = Length[b]},
  c = ConstantArray[0, la + lb - 1];
  Do[c[[i + j - 1]] = c[[i + j - 1]] + a[[i]] b[[j]], {i, 1, la}, {j, 1, lb}];
  c
];

(* exponentiation by squaring; no global memoization, no worker lock contention *)
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

(* Exact scalar kernel from the boxed RIS closed form:
   J_n(c)=Integral_0^Infinity t^n Exp[-c t]/(1+t^2) dt.
   This is NOT numerical integration. It is the closed-form incomplete-gamma
   expression used in the original FinalCode.wl. *)
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

(* Fast recurrence kernel table. Good for low/moderate RIS polynomial degree. *)
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

(* Stable high-degree kernel table. This is what fixed the NR=100-only script.
   It evaluates every J_n by the exact incomplete-gamma closed form. No integral,
   no fallback, no bypass. *)
JKernelVectorDirect[maxN_Integer?NonNegative, c_?NumericQ, prec_: workPrecRIS] :=
  Table[JKernelDirectExact[n, c, prec], {n, 0, maxN}];

(* Hybrid closed-form kernel selector:
   - low/moderate polynomial degree: recurrence for speed;
   - high degree (NR=100): exact direct table for stability.
   Both paths are the same closed-form J_n(c), only evaluated differently. *)
JKernelVector[maxN_Integer?NonNegative, c_?NumericQ, prec_: workPrecRIS] :=
  If[maxN >= risDirectKernelThreshold,
     JKernelVectorDirect[maxN, c, prec],
     JKernelVectorRecurrence[maxN, c, prec]
  ];

(* Scalar wrapper used by the RIS asymptote formulas. *)
ClearAll[JKernel];
JKernel[n_Integer?NonNegative, c_?NumericQ, prec_: workPrecRIS] := JKernelVector[n, c, prec][[n + 1]];

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

   (* Convolution optimization: the old double sum over p and q is replaced by
      conv_h = Sum_{p+q=h} d_p e_q. Then Sum_h conv_h J_{h+1}(c). *)
   terms = Table[
     ePow = polyPower[sePoly["coeffs"], n];
     c = M*ad + n*ae;
     conv = polyMul[dPow, ePow];
     kernels = JKernelVector[Length[conv], c, prec];
     (-1)^n Binomial[L, n] stableTotal[Table[conv[[h + 1]]*kernels[[h + 2]], {h, 0, Length[conv] - 1}], prec],
     {n, 0, L}];
   val = (2/ln2)*stableTotal[terms, prec];
   If[NRd >= 50 || NRe >= 50,
     Print["RIS high-NR closed form: NRd=", NRd, ", NRe=", NRe,
       ", rhoD=", rhoDDB, " dB, raw=", ScientificForm[N[Re[val], 8]]]
   ];
   Max[0, N[Re[val], 30]]
];

(* ======================================================================= *)
(* ENGINE B: RELAY T-SERIES CORRECTED TRICOMI-U CLOSED FORM  (unchanged)    *)
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

ClearAll[polyPowerCoeffs, stableTotal];
polyPowerCoeffs[b_List, m_Integer?NonNegative] := polyPower[b, m];
stableTotal[terms_List, prec_Integer?Positive] := N[Total[SortBy[N[terms, prec], Abs]], prec];

ClearAll[relayParams, IkerTricomiU, IkerListTricomiU];
relayParams[rho1_, rho2_, prec_Integer?Positive] := Module[{rho1p, rho2p, beta, aa, delta},
  rho1p = SetPrecision[rho1, prec]; rho2p = SetPrecision[rho2, prec];
  beta = 2/Sqrt[rho1p rho2p]; aa = 1/rho1p + 1/rho2p; delta = aa + beta;
  <|"beta" -> N[beta, prec], "a" -> N[aa, prec], "delta" -> N[delta, prec]|>];

(* Correct scalar kernel: G_{1,2}^{2,1}(z | -m ; 0,-m)
   = Gamma[m+1] HypergeometricU[m+1,m+1,z]. This bypasses slow MeijerG. *)
IkerTricomiU[m_Integer?NonNegative, z_, prec_Integer?Positive] :=
  Block[{$MaxExtraPrecision = 100000},
    N[Gamma[m + 1] HypergeometricU[m + 1, m + 1, SetPrecision[z, prec]], prec]
  ];
IkerListTricomiU[maxM_Integer?NonNegative, z_, prec_Integer?Positive] :=
  Table[IkerTricomiU[m, z, prec], {m, 0, maxM}];

ClearAll[CsRelaySeriesMeijerG];
CsRelaySeriesMeijerG[M_Integer?Positive, L_Integer?NonNegative,
   rho1d_, rho2d_, rho1e_, rho2e_, T_Integer?NonNegative, prec_Integer?Positive] := Module[
  {av, pd, pe, betaD, betaE, deltaD, deltaE, bd, be, Ad, Ae, conv, kernels, z, n, total, block, raw, warnThresh = 10^-8},
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
  If[raw < -warnThresh, Print["WARNING: negative relay raw result ", raw,
     " for M=", M, ", L=", L, ", T=", T]];
  Max[0, N[Re[raw], 30]]];

(* ======================================================================= *)
(* RIS ADAPTIVE PRECISION FOR VERY LARGE NR                                 *)
(* Pure boxed closed-form evaluation only. No numerical integration or      *)
(* bypass is used anywhere in the analytical curves.                        *)
(* ======================================================================= *)
ClearAll[risAdaptivePrecision];
risAdaptivePrecision[NRd_?NumericQ, NRe_?NumericQ, M_Integer?Positive, L_Integer?Positive] :=
  If[Max[NRd, NRe] >= 50, Max[workPrecRIS, risHighNRPrecision], workPrecRIS];

(* ======================================================================= *)
(* WRAPPERS  (closed form + plan-PDF Monte Carlo)                          *)
(* ======================================================================= *)
ClearAll[hopSNRs];
hopSNRs[rtDB_?NumericQ, reDB_?NumericQ, split_String, prec_: workPrecRelay] := Module[{rD, rE, f},
  rD = SetPrecision[10^(rtDB/10), prec];
  rE = SetPrecision[10^(reDB/10), prec];
  f = If[split === "half", 1/2, 1];          (* legitimate hops split; eve full *)
  <|"rho1d" -> f rD, "rho2d" -> f rD, "rho1e" -> rE, "rho2e" -> rE|>];

ClearAll[esmcRIScf, esmcRelaycf];
esmcRIScf[rtDB_?NumericQ, M_Integer?Positive, L_Integer?Positive,
   NRd_Integer?Positive, NRe_Integer?Positive, reDB_?NumericQ] := Module[{prec},
  prec = risAdaptivePrecision[NRd, NRe, M, L];
  Quiet@Check[CsTwoBranchErlang[NRd, NRe, rtDB, reDB, M, L, prec], Indeterminate]
];
esmcRelaycf[rtDB_?NumericQ, M_Integer?Positive, L_Integer?Positive,
   reDB_?NumericQ, split_String, T_Integer?Positive, prec_Integer?Positive] :=
  Module[{h = hopSNRs[rtDB, reDB, split, prec]},
  CsRelaySeriesMeijerG[M, L, h["rho1d"], h["rho2d"], h["rho1e"], h["rho2e"], T, prec]];

ClearAll[positiveMean, esmcRISmcPlan, esmcRelaymcPlan];
positiveMean[v_List] := N[Mean[Clip[v, {0, Infinity}]]];

esmcRISmcPlan[rtDB_?NumericQ, M_Integer?Positive, L_Integer?Positive,
   NRd_Integer?Positive, NRe_Integer?Positive, reDB_?NumericQ] := Module[
  {rhoD, rhoE, sd, se, b, remain, ns, total = 0., Ad, Ae, gd, ge, cs},
  rhoD = N[10^(rtDB/10)]; rhoE = N[10^(reDB/10)];
  sd = N[shapeFromNR[NRd, 40]]; se = N[shapeFromNR[NRe, 40]]; b = N[scaleRayleighRIS[40]];
  BlockRandom[
    SeedRandom[mcSeedBase + Abs[Hash[{"RIS_PLAN_MC", rtDB, M, L, NRd, NRe, reDB}]]];
    remain = mcTrials;
    While[remain > 0,
      ns = Min[mcChunk, remain];
      Ad = RandomVariate[GammaDistribution[sd, b], {ns, M}];
      Ae = RandomVariate[GammaDistribution[se, b], {ns, L}];
      gd = rhoD*(Min /@ Ad)^2; ge = rhoE*(Max /@ Ae)^2;
      cs = Log2[(1 + gd)/(1 + ge)];
      total += Total[Clip[cs, {0, Infinity}]]; remain -= ns;];];
  N[total/mcTrials]];

esmcRelaymcPlan[rtDB_?NumericQ, M_Integer?Positive, L_Integer?Positive,
   reDB_?NumericQ, split_String] := Module[
  {h, remain, ns, total = 0., g1, g2, e1, e2, gd, ge, cs},
  h = hopSNRs[rtDB, reDB, split];
  BlockRandom[
    SeedRandom[mcSeedBase + Abs[Hash[{"RELAY_PLAN_MC", rtDB, M, L, reDB, split}]]];
    remain = mcTrials;
    While[remain > 0,
      ns = Min[mcChunk, remain];
      g1 = RandomVariate[ExponentialDistribution[1/N[h["rho1d"]]], {ns, M}];
      g2 = RandomVariate[ExponentialDistribution[1/N[h["rho2d"]]], {ns, M}];
      gd = Min /@ (g1*g2/(g1 + g2));
      e1 = RandomVariate[ExponentialDistribution[1/N[h["rho1e"]]], {ns, L}];
      e2 = RandomVariate[ExponentialDistribution[1/N[h["rho2e"]]], {ns, L}];
      ge = Max /@ (e1*e2/(e1 + e2));
      cs = (1/2) Log2[(1 + gd)/(1 + ge)];
      total += Total[Clip[cs, {0, Infinity}]]; remain -= ns;];];
  N[total/mcTrials]];

(* ======================================================================= *)
(* SPEC BUILDER (turns a figure config into a list of curves)              *)
(* ======================================================================= *)
ClearAll[palette, mkSpec, buildSpecs, cfOf, mcPlanOf];
professionalPalette = {
  RGBColor[0.000, 0.270, 0.600],  (* deep blue *)
  RGBColor[0.850, 0.325, 0.098],  (* burnt orange *)
  RGBColor[0.000, 0.500, 0.200],  (* forest green *)
  RGBColor[0.494, 0.184, 0.556],  (* purple *)
  RGBColor[0.466, 0.674, 0.188],
  RGBColor[0.301, 0.745, 0.933],
  RGBColor[0.635, 0.078, 0.184],
  RGBColor[0.200, 0.200, 0.200]
};
palette[1] := {professionalPalette[[1]]};
palette[k_Integer?Positive] := Table[professionalPalette[[Mod[i - 1, Length[professionalPalette]] + 1]], {i, k}];

mkSpec[cfg_Association, risQ_, overrides_Association, color_, label_] :=
  Join[<|"risQ" -> risQ, "M" -> cfg["M"], "L" -> cfg["L"],
         "NRd" -> cfg["NRd"], "NRe" -> cfg["NRe"], "rhoEdB" -> cfg["rhoEdB"],
         "split" -> cfg["hopSplit"], "Trelay" -> cfg["Trelay"], "precRelay" -> cfg["precRelay"],
         "color" -> color, "label" -> label|>, overrides];

buildSpecs[cfg_Association] := Module[{sv = cfg["sweepVar"], sl = cfg["sweepList"], cols, specs},
  Which[
   sv === "none",
     specs = {};
     If[TrueQ@cfg["showRIS"], AppendTo[specs, mkSpec[cfg, True, <||>, Blue,
        "RIS (N_R,d=" <> ToString[cfg["NRd"]] <> ", N_R,e=" <> ToString[cfg["NRe"]] <> ")"]]];
     If[TrueQ@cfg["showRelay"], AppendTo[specs, mkSpec[cfg, False, <||>, Red, "AF relay"]]];
     specs,
   sv === "NR",                                       (* worst-case: sweep Bob AND Eve together *)
     cols = palette[Length[sl]];
     specs = Table[mkSpec[cfg, True, <|"NRd" -> sl[[i]], "NRe" -> sl[[i]]|>, cols[[i]],
        "RIS N_R=" <> ToString[sl[[i]]]], {i, Length[sl]}];
     If[TrueQ@cfg["showRelay"], AppendTo[specs, mkSpec[cfg, False, <||>, Black, "AF relay (ref)"]]];
     specs,
   MemberQ[{"NRd", "NRe"}, sv],                       (* RIS-only sweep, one link's elements *)
     cols = palette[Length[sl]];
     specs = Table[mkSpec[cfg, True, <|sv -> sl[[i]]|>, cols[[i]],
        "RIS " <> sv <> "=" <> ToString[sl[[i]]]], {i, Length[sl]}];
     If[TrueQ@cfg["showRelay"], AppendTo[specs, mkSpec[cfg, False, <||>, Black, "AF relay (ref)"]]];
     specs,
   MemberQ[{"M", "L", "rhoEdB"}, sv],                 (* both systems depend on it *)
     cols = palette[Length[sl]];
     specs = Table[mkSpec[cfg, True, <|sv -> sl[[i]], "skey" -> sl[[i]]|>, cols[[i]],
        "RIS " <> sv <> "=" <> ToString[sl[[i]]]], {i, Length[sl]}];
     If[TrueQ@cfg["showRelay"],
        specs = Join[specs, Table[mkSpec[cfg, False, <|sv -> sl[[i]], "skey" -> sl[[i]]|>, cols[[i]],
           "Relay " <> sv <> "=" <> ToString[sl[[i]]]], {i, Length[sl]}]]];
     specs,
   True, Print["Unknown sweepVar: ", sv]; {}]];

cfOf[s_Association, rt_?NumericQ] := If[s["risQ"],
   esmcRIScf[rt, s["M"], s["L"], s["NRd"], s["NRe"], s["rhoEdB"]],
   esmcRelaycf[rt, s["M"], s["L"], s["rhoEdB"], s["split"], s["Trelay"], s["precRelay"]]];
mcPlanOf[s_Association, rt_?NumericQ] := If[s["risQ"],
   esmcRISmcPlan[rt, s["M"], s["L"], s["NRd"], s["NRe"], s["rhoEdB"]],
   esmcRelaymcPlan[rt, s["M"], s["L"], s["rhoEdB"], s["split"]]];

(* ======================================================================= *)
(* HIGH-SNR ASYMPTOTES  (from the two derivation PDFs)                      *)
(*   RIS  : Step-8a full expression; slope = log2(rho_d) ~ 0.332 bits/dB.   *)
(*   Relay: A1 high-SNR slope (1/2)log2(rho_d) ~ 0.166 bits/dB. The PDF     *)
(*          leaves the O(1) offset unspecified, so it is anchored to the    *)
(*          exact relay closed form at the top SNR of the sweep.            *)
(* ======================================================================= *)
ClearAll[esmcRISasy, esmcRelayAsy];
esmcRISasy[rtDB_?NumericQ, M_Integer?Positive, K_Integer?Positive,
   NRd_Integer?Positive, NRe_Integer?Positive, reDB_?NumericQ] := Module[
  {prec = workPrecRIS, sd, se, b, rhoD, rhoE, pd, pe, lamD, Gd, gdPow,
   ElnA, sePoly, deltaE, ePow, eMax, p, q, n},
  sd = shapeFromNR[NRd, prec]; se = shapeFromNR[NRe, prec]; b = scaleRayleighRIS[prec];
  rhoD = rhoLin[rtDB, prec]; rhoE = rhoLin[reDB, prec];
  pd = twoBranchParams[sd, b, prec]; pe = twoBranchParams[se, b, prec];
  lamD = pd["lambda"];
  Gd = survivalPolyCoeffs[pd, 1, prec]["coeffs"];           (* amplitude-domain survival poly *)
  gdPow = polyPower[Gd, M];
  ElnA = gdPow[[1]] (-EulerGamma - Log[M lamD])
     + Sum[gdPow[[p + 1]] Gamma[p]/(M lamD)^p, {p, 1, Length[gdPow] - 1}];
  sePoly = survivalPolyCoeffs[pe, rhoE, prec]; deltaE = sePoly["alpha"];
  eMax = (2/ln2) Sum[
     ePow = polyPower[sePoly["coeffs"], n];
     (-1)^(n + 1) Binomial[K, n] sortedTotal[Table[
        ePow[[q + 1]] JKernel[q + 1, n deltaE, prec], {q, 0, Length[ePow] - 1}]],
     {n, 1, K}];
  N[Log2[rhoD] + (2/ln2) ElnA - eMax, 30]];
esmcRelayAsy[rtDB_?NumericQ, anchorDB_?NumericQ, anchorVal_?NumericQ] :=
  0.5 Log2[10^(rtDB/10)] + (anchorVal - 0.5 Log2[10^(anchorDB/10)]);

(* ======================================================================= *)
(* PLOTTING (IEEE style) AND EXPORT                                        *)
(*   - boxed legend INSIDE the axes (Inset)                                 *)
(*   - color + dash scheme (solid / long-dash / dot / dash-dot / ...)       *)
(*   - asymptote overlay (thin dotted) when cfg["showAsy"]=True             *)
(*   - groupTag[] : arrow + ellipse callout; add via cfg["annotations"]     *)
(* ======================================================================= *)
xlab = "Destination SNR  \!\(\*SubscriptBox[\(\[Rho]\),\(d\)]\)  (dB)";
ylab = "ESMC  (bits/s/Hz)";

famPalette = professionalPalette;
dashCycle  = {AbsoluteDashing[{}], AbsoluteDashing[{12, 6}], AbsoluteDashing[{2, 5}],
              AbsoluteDashing[{14, 5, 2, 5}], AbsoluteDashing[{18, 5, 2, 5, 2, 5}], AbsoluteDashing[{8, 4}]};
colOf[i_]  := famPalette[[Mod[i - 1, Length[famPalette]] + 1]];
dashOf[i_] := dashCycle[[Mod[i - 1, Length[dashCycle]] + 1]];

ClearAll[markerShapeFor, hollowMarker, groupTag, buildLegendInset, exportRows, buildFig];
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

(* arrow + ellipse callout (no caption).
   xc      = dB position of the group
   ylo,yhi = y-span of the curves to encircle there
   rx      = ellipse half-width in dB
   label   = text string
   labelPt = {x,y} where the text sits; arrow runs label -> ellipse.        *)
groupTag[xc_, ylo_, yhi_, rx_, label_, labelPt_] := {
   Black, AbsoluteThickness[1.3],
   Circle[{xc, (ylo + yhi)/2}, {rx, (yhi - ylo)/2 + 0.3}],
   Arrowheads[0.022], Arrow[{labelPt, {xc, (ylo + yhi)/2}}],
   Text[Style[label, 13, FontFamily -> $font, Background -> White], labelPt]};

ClearAll[paramTextForFigure];
paramTextForFigure[cfg_Association] := Module[{sv = cfg["sweepVar"], nrText},
  nrText = If[cfg["NRd"] === cfg["NRe"],
     "fixed N_R=" <> ToString[cfg["NRd"]],
     "fixed N_R,d=" <> ToString[cfg["NRd"]] <> ", N_R,e=" <> ToString[cfg["NRe"]]
  ];
  Which[
    sv === "none",
      "M=" <> ToString[cfg["M"]] <> ", K=" <> ToString[cfg["L"]] <>
        ", \!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\)=" <> ToString[cfg["rhoEdB"]] <> " dB",
    sv === "NR" || sv === "NRd" || sv === "NRe",
      "M=" <> ToString[cfg["M"]] <> ", K=" <> ToString[cfg["L"]] <>
        ", \!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\)=" <> ToString[cfg["rhoEdB"]] <> " dB",
    sv === "M",
      nrText <> ", K=" <> ToString[cfg["L"]] <>
        ", \!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\)=" <> ToString[cfg["rhoEdB"]] <> " dB",
    True,
      "K=" <> ToString[cfg["L"]] <>
        ", \!\(\*SubscriptBox[\(\[Rho]\), \(e\)]\)=" <> ToString[cfg["rhoEdB"]] <> " dB"
  ]
];

buildLegendInset[entries_, pos_] := Module[{rows},
  rows = Map[Function[e,
     If[e[[1]] === "text",
       {Graphics[{}, ImageSize -> {34, 13}, PlotRange -> {{0, 1}, {0, 1}}, PlotRangePadding -> 0],
        Style[e[[2]], 10.3, FontFamily -> $font, Bold]},
       {Graphics[If[e[[1]] === "marker",
          {Inset[hollowMarker[e[[6]], e[[2]], 12, 1.7], {0.5, 0.5}]},
          {e[[2]], e[[3]], AbsoluteThickness[1.6], Line[{{0, 0.5}, {1, 0.5}}]}],
         ImageSize -> {34, 13}, PlotRange -> {{0, 1}, {0, 1}}, PlotRangePadding -> 0],
        Style[e[[5]], 10.5, FontFamily -> $font]}
     ]], entries];
  Inset[Framed[Grid[rows, Alignment -> {Left, Center}, Spacings -> {0.28, 0.32}],
     Background -> White, FrameStyle -> Directive[GrayLevel[0.20], AbsoluteThickness[0.65]],
     RoundingRadius -> 0, FrameMargins -> 5], Scaled[pos], {Left, Top}]
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
  jobs = Flatten[Table[{i, j, gridMC[[j]]}, {i, Length[specs]}, {j, Length[gridMC]}], 1];
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
  {specs, grid, gridMC, baseName = cfg["name"], cfData, mcData, n, risIdx, relIdx, paired,
   skeys, ukeys, kColor, lineStyles, mkColors, mkSyms, ymax, asyData, asyStyles,
   dashFor, legEntries, legPos, ann, base, mkPlot, asyPlot, fig, rows, header,
   pdfPath, pngPath, csvPath, notesPath, asyGrid, anchorDB, anchorVal, cfmcMax, asyMax, t0},
  specs = buildSpecs[cfg]; grid = cfg["snrDdB"]; gridMC = Lookup[cfg, "snrDdBMC", grid]; n = Length[specs];
  Print["\n============================================================"];
  Print["Building ", baseName, " with ", n, " curves and ", Length[grid]*n, " closed-form tasks"];
  Print["=== ", baseName, " : parallel closed-form lines ==="];
  t0 = AbsoluteTime[];
  cfData = evaluateCFDataParallel[specs, grid];
  Print["Closed-form time: ", NumberForm[AbsoluteTime[] - t0, {8, 2}], " s"];
  Print["=== ", baseName, " : parallel PLAN Monte Carlo markers ==="];
  t0 = AbsoluteTime[];
  mcData = evaluateMCDataParallel[specs, gridMC];
  Print["MC marker time: ", NumberForm[AbsoluteTime[] - t0, {8, 2}], " s"];
  Do[Print["MC markers for curve ", i, " (", specs[[i]]["label"], "): ", Length[mcData[[i]]]], {i, n}];
  Do[If[! specs[[i]]["risQ"],
     Module[{bad = Select[Range[Length[grid]],
        (cfData[[i, #, 2]] <= 10.^-9 && mcData[[i, #, 2]] > 0.02) &]},
       If[bad =!= {}, Print["  *** WARNING: ", specs[[i]]["label"],
          " relay closed form collapsed to 0 at rho_d=", grid[[bad]],
          " dB. Lower Trelay / raise precRelay."]]]], {i, n}];
  risIdx = Select[Range[n], specs[[#]]["risQ"] &];
  relIdx = Select[Range[n], ! specs[[#]]["risQ"] &];
  paired = (Length[risIdx] > 0 && Length[risIdx] == Length[relIdx]);
  skeys = Table[Lookup[specs[[i]], "skey", i], {i, n}];
  ukeys = DeleteDuplicates[skeys];
  kColor = AssociationThread[ukeys -> (colOf /@ Range[Length[ukeys]])];
  mkColors = Table[If[! paired && ! specs[[i]]["risQ"], Black, kColor[skeys[[i]]]], {i, n}];
  dashFor[i_] := If[specs[[i]]["risQ"], AbsoluteDashing[{}], AbsoluteDashing[{12, 6}]];
  lineStyles = Table[Directive[mkColors[[i]], AbsoluteThickness[1.6], dashFor[i]], {i, n}];
  mkSyms = Table[hollowMarker[markerShapeFor[i], mkColors[[i]], mcMarkerSize, mcMarkerOutlineThickness], {i, n}];
  asyData = {}; asyStyles = {};
  If[TrueQ@Lookup[cfg, "showAsy", False],
   asyGrid = grid;                                    (* full SNR range so the line is visible *)
   Do[If[specs[[i]]["risQ"],
       AppendTo[asyData, ({#, esmcRISasy[#, specs[[i]]["M"], specs[[i]]["L"],
          specs[[i]]["NRd"], specs[[i]]["NRe"], specs[[i]]["rhoEdB"]]} & /@ asyGrid)],
       anchorDB = Last[grid]; anchorVal = cfData[[i, -1, 2]];
       AppendTo[asyData, ({#, esmcRelayAsy[#, anchorDB, anchorVal]} & /@ asyGrid)]];
     AppendTo[asyStyles, Directive[mkColors[[i]], AbsoluteThickness[1.65], AbsoluteDashing[{1.2, 3.0}]]],
    {i, n}]];
  cfmcMax = Max[Flatten[{cfData[[All, All, 2]], mcData[[All, All, 2]]}]];
  asyMax = If[asyData === {}, 0.,
     Module[{vv = Select[Flatten[asyData[[All, All, 2]]], Positive]},
       If[vv === {}, 0., Min[Max[vv], 1.5 cfmcMax]]]];
  ymax = 1.12 Max[0.05, cfmcMax, asyMax];
  legEntries = Prepend[
     Table[{"line", mkColors[[i]], dashFor[i], specs[[i]]["risQ"], specs[[i]]["label"], markerShapeFor[i]}, {i, n}],
     {"text", paramTextForFigure[cfg]}
  ];
  AppendTo[legEntries, {"marker", GrayLevel[0.15], None, True, "Simulation (MC)", "Circle"}];
  If[TrueQ@Lookup[cfg, "showAsy", False],
     AppendTo[legEntries, {"line", GrayLevel[0.15], AbsoluteDashing[{1.2, 3.0}], True, "Asymptote"}]];
  legPos = Lookup[cfg, "legendPos", {0.03, 0.97}];
  ann = Lookup[cfg, "annotations", {}];
  base = ListLinePlot[cfData, PlotStyle -> lineStyles, InterpolationOrder -> 2,
     Frame -> True, Axes -> False, Background -> White, GridLines -> Automatic,
     GridLinesStyle -> Directive[GrayLevel[0.88], AbsoluteDashing[{1.2, 3.0}], AbsoluteThickness[0.45]],
     FrameLabel -> {Style[xlab, 15, FontFamily -> $font], Style[ylab, 15, FontFamily -> $font]},
     FrameStyle -> Directive[Black, AbsoluteThickness[1.2]],
     FrameTicksStyle -> Directive[Black, 11, FontFamily -> $font],
     BaseStyle -> {FontFamily -> $font, FontSize -> 12},
     PlotRange -> {{Min[grid], Max[grid]}, {0, ymax}},
     ImageSize -> 620, ImagePadding -> {{66, 18}, {50, 14}}];
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
  notesPath = FileNameJoin[{$outDir, baseName <> "_Notes.txt"}];
  Export[pdfPath, fig];
  Export[pngPath, Rasterize[fig, "Image", ImageResolution -> $outputDPI, Background -> White]];
  Export[csvPath, Prepend[rows, header]];
  Export[notesPath, StringRiffle[{baseName,
     "Lines=user closed form. Markers=MC on PLAN PDF. Asymptotes from derivation PDFs. No figure caption/title is inserted by the plotting code.",
     "RIS asy=Step-8a full expression. Relay asy=A1 slope 1/2, offset anchored at top SNR.",
     "Fixes: RIS asymptote uses JKernelVector wrapper; high-degree NR=100 uses exact incomplete-gamma closed-form kernel table and manual coefficient convolution copied from the working NR100-only script. No numerical integration or bypass is used.",
     "Config: " <> ToString[cfg]}, "\n"], "Text"];
  Print["Saved: ", pdfPath]; Print["Saved: ", pngPath]; Print["Saved: ", csvPath];
  If[TrueQ[showFiguresInNotebook], Print[fig]];
  fig];

(* ======================================================================= *)
(* BUILD THE THREE FIGURES                                                 *)
(* ======================================================================= *)
runFig1 = True;
runFig2 = True;
runFig3 = True;

figList = {};
If[TrueQ[runFig1], fig1 = buildFig[f1Config]; AppendTo[figList, fig1]];
If[TrueQ[runFig2], fig2 = buildFig[f2Config]; AppendTo[figList, fig2]];
If[TrueQ[runFig3], fig3 = buildFig[f3Config]; AppendTo[figList, fig3]];

combined = Column[figList, Spacings -> 2, Background -> White];
Export[FileNameJoin[{$outDir, "CombinedPreview.pdf"}], combined];
Export[FileNameJoin[{$outDir, "CombinedPreview.png"}],
  Rasterize[combined, "Image", ImageResolution -> $outputDPI, Background -> White]];

Print["============================================================"];
Print["DONE. Output folder: ", $outDir];
Print["============================================================"];
combined





