(* ::Package:: *)

(* ======================================================================= *)
(* Plan model from: Boulogeorgos & Alexiou, "Performance Analysis of RIS-  *)
(* Assisted Wireless Systems and Comparison With Relaying," IEEE Access.    *)
(*                                                                         *)
(* HOW TO TUNE: edit the COMMON block and the THREE FIGURE CONFIG blocks.   *)
(* Each figure is fully independent. Nothing else needs editing.           *)
(* ======================================================================= *)

ClearAll["Global`*"];
$MaxExtraPrecision = 100000;
ln2 = Log[2];

(* ============================ COMMON ================================== *)
(* Shared by all three figures (engine settings + the one fixed-SNR knob). *)

rhoEdBCommon = 0;                 (* fixed eavesdropper SNR (dB), default   *)
                                  (* for all figures (override per fig)     *)
snrDdBCommon = Range[0, 40, 5];   (* default destination/main SNR sweep     *)

mcTrials   = 40000;               (* Monte Carlo samples per marker         *)
mcChunk    = 5000;                (* chunked MC (memory)                    *)
mcSeedBase = 2101097;

workPrecRIS   = 200;              (* RIS closed-form precision.             *)
                                  (* >=160 needed once NRd >~ 16 so the     *)
                                  (* scalar J-kernel does not underflow.    *)
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
$outDir = FileNameJoin[{$scriptDir, "PlanMC_on_UserClosedForm_Output"}];
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
polyMul[a_List, b_List] := Module[{c, i, j},
  c = ConstantArray[0, Length[a] + Length[b] - 1];
  Do[c[[i + j - 1]] = c[[i + j - 1]] + a[[i]] b[[j]],
    {i, 1, Length[a]}, {j, 1, Length[b]}]; c];
polyPower[a_List, n_Integer?NonNegative] := Module[{res = {1}, i},
  If[n == 0, Return[{1}]]; Do[res = polyMul[res, a], {i, 1, n}]; res];
sortedTotal[list_List] := Module[{terms},
  terms = DeleteCases[Flatten[list], 0 | 0.];
  If[Length[terms] == 0, 0, Plus @@ SortBy[terms, Abs]]];
safeReal[z_] := Module[{zz = N[z, 40]},
  If[! NumericQ[zz], Return[$Failed]];
  If[Abs[Im[zz]] > 10^-17 Max[1, Abs[Re[zz]]], Return[$Failed]]; Re[zz]];

ClearAll[JKernel];
JKernel[n_Integer?NonNegative, c_?NumericQ, prec_: workPrecRIS] :=
 JKernel[n, ToString[NumberForm[N[c, 35], 45]], prec] = Module[
   {cc = SetPrecision[c, prec], val, rr},
   val = Quiet@Check[
      Re@N[Gamma[n + 1]/(2 I)*(((-I)^n) Exp[-I cc] Gamma[-n, -I cc] -
          (I^n) Exp[I cc] Gamma[-n, I cc]), prec], $Failed];
   rr = If[val === $Failed, $Failed, safeReal[val]];
   If[rr === $Failed || ! NumericQ[rr],
     Print["WARNING: RIS closed-form JKernel failed at n=", n, ", c=", N[c, 10],
           ". Returned 0 (raise workPrecRIS)."]; 0,
     Max[0, rr]]];

ClearAll[CsTwoBranchErlang];
CsTwoBranchErlang[NRd_?NumericQ, NRe_?NumericQ, rhoDDB_?NumericQ, rhoEDB_?NumericQ,
   M_Integer?Positive, L_Integer?Positive, prec_: workPrecRIS] := Module[
   {sd, se, b, rhoD, rhoE, pd, pe, sdPoly, sePoly, ad, ae, dPow, ePow, n, p, q, c, terms, val},
   sd = shapeFromNR[NRd, prec]; se = shapeFromNR[NRe, prec]; b = scaleRayleighRIS[prec];
   rhoD = rhoLin[rhoDDB, prec]; rhoE = rhoLin[rhoEDB, prec];
   pd = twoBranchParams[sd, b, prec]; pe = twoBranchParams[se, b, prec];
   sdPoly = survivalPolyCoeffs[pd, rhoD, prec]; sePoly = survivalPolyCoeffs[pe, rhoE, prec];
   ad = sdPoly["alpha"]; ae = sePoly["alpha"];
   dPow = polyPower[sdPoly["coeffs"], M];
   terms = Table[
     ePow = polyPower[sePoly["coeffs"], n]; c = M*ad + n*ae;
     (-1)^n Binomial[L, n]*sortedTotal[Table[
         dPow[[p + 1]]*ePow[[q + 1]]*JKernel[p + q + 1, c, prec],
         {p, 0, Length[dPow] - 1}, {q, 0, Length[ePow] - 1}]],
     {n, 0, L}];
   val = (2/ln2)*sortedTotal[terms];
   Max[0, N[Re[val], 30]]];

(* ======================================================================= *)
(* ENGINE B: RELAY T-SERIES CORRECTED MEIJER-G CLOSED FORM  (unchanged)    *)
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
polyPowerCoeffs[b_List, m_Integer?NonNegative] := Module[{res = {1}},
  Do[res = polyMul[res, b], {m}]; res];
stableTotal[terms_List, prec_Integer?Positive] := N[Total[SortBy[N[terms, prec], Abs]], prec];

ClearAll[relayParams, IkerMeijerG, IkerListMeijerG];
relayParams[rho1_, rho2_, prec_Integer?Positive] := Module[{rho1p, rho2p, beta, aa, delta},
  rho1p = SetPrecision[rho1, prec]; rho2p = SetPrecision[rho2, prec];
  beta = 2/Sqrt[rho1p rho2p]; aa = 1/rho1p + 1/rho2p; delta = aa + beta;
  <|"beta" -> N[beta, prec], "a" -> N[aa, prec], "delta" -> N[delta, prec]|>];
IkerMeijerG[m_Integer?NonNegative, z_, prec_Integer?Positive] :=
 IkerMeijerG[m, ToString[NumberForm[N[z, 60], 80]], prec] =
  Block[{$MaxExtraPrecision = 100000},
    N[MeijerG[{{-m}, {}}, {{0, -m}, {}}, SetPrecision[z, prec]], prec]];
IkerListMeijerG[maxM_Integer?NonNegative, z_, prec_Integer?Positive] :=
  Table[IkerMeijerG[m, z, prec], {m, 0, maxM}];

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
    kernels = IkerListMeijerG[Length[conv] - 1, z, prec];
    block = stableTotal[conv*kernels, prec];
    total = N[total + (-1)^n Binomial[L, n] block, prec]];
  raw = N[total/(2 Log[2]), 30];
  If[raw < -warnThresh, Print["WARNING: negative relay raw result ", raw,
     " for M=", M, ", L=", L, ", T=", T]];
  Max[0, N[Re[raw], 30]]];

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
   NRd_Integer?Positive, NRe_Integer?Positive, reDB_?NumericQ] :=
  CsTwoBranchErlang[NRd, NRe, rtDB, reDB, M, L, workPrecRIS];
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
      gd = Min /@ (rhoD Ad^2); ge = Max /@ (rhoE Ae^2);
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
palette[1] := {Blue};
palette[k_Integer?Positive] := Table[ColorData["DarkRainbow"][(i - 1)/(k - 1)], {i, k}];

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
        "RIS (NRd=" <> ToString[cfg["NRd"]] <> ",NRe=" <> ToString[cfg["NRe"]] <> ")"]]];
     If[TrueQ@cfg["showRelay"], AppendTo[specs, mkSpec[cfg, False, <||>, Red, "AF relay"]]];
     specs,
   sv === "NR",                                       (* worst-case: sweep Bob AND Eve together *)
     cols = palette[Length[sl]];
     specs = Table[mkSpec[cfg, True, <|"NRd" -> sl[[i]], "NRe" -> sl[[i]]|>, cols[[i]],
        "RIS NR=" <> ToString[sl[[i]]]], {i, Length[sl]}];
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
ylab = "Positive ESMC  (bits/s/Hz)";

famPalette = {RGBColor[0.13, 0.36, 0.85], RGBColor[0.85, 0.16, 0.13], RGBColor[0.10, 0.58, 0.24],
              RGBColor[0.93, 0.55, 0.0], RGBColor[0.50, 0.16, 0.66], RGBColor[0.0, 0.62, 0.72],
              RGBColor[0.45, 0.30, 0.12]};
dashCycle  = {AbsoluteDashing[{}], AbsoluteDashing[{12, 6}], AbsoluteDashing[{2, 5}],
              AbsoluteDashing[{14, 5, 2, 5}], AbsoluteDashing[{18, 5, 2, 5, 2, 5}], AbsoluteDashing[{8, 4}]};
colOf[i_]  := famPalette[[Mod[i - 1, Length[famPalette]] + 1]];
dashOf[i_] := dashCycle[[Mod[i - 1, Length[dashCycle]] + 1]];

ClearAll[mcSym, groupTag, buildLegendInset, exportRows, buildFig];
mcSym[risQ_] := If[risQ, "\[EmptyCircle]", "\[EmptySquare]"];

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

buildLegendInset[entries_, pos_] := Module[{rows},
  rows = Map[Function[e, {
     Graphics[If[e[[1]] === "marker",
        {e[[2]], Text[Style[mcSym[e[[4]]], 17, e[[2]]], {0.5, 0.5}]},
        {e[[2]], e[[3]], AbsoluteThickness[2.6], Line[{{0, 0.5}, {1, 0.5}}]}],
       ImageSize -> {40, 14}, PlotRange -> {{0, 1}, {0, 1}}, PlotRangePadding -> 0],
     Style[e[[5]], 12, FontFamily -> $font]}], entries];
  Inset[Framed[Grid[rows, Alignment -> {Left, Center}, Spacings -> {0.4, 0.5}],
     Background -> White, FrameStyle -> GrayLevel[0.45], RoundingRadius -> 4,
     FrameMargins -> 7], Scaled[pos], {Left, Top}]];

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

buildFig[cfg_Association] := Module[
  {specs, grid, baseName = cfg["name"], cfData, mcData, n, risIdx, relIdx, paired,
   skeys, ukeys, kColor, lineStyles, mkColors, mkSyms, ymax, asyData, asyStyles,
   dashFor, legEntries, legPos, ann, base, mkPlot, asyPlot, fig, rows, header,
   pdfPath, pngPath, csvPath, notesPath, asyGrid, anchorDB, anchorVal, cfmcMax, asyMax},
  specs = buildSpecs[cfg]; grid = cfg["snrDdB"]; n = Length[specs];
  Print["=== ", baseName, " : closed-form lines ==="];
  cfData = Table[Print["  CF: ", s["label"]]; ({#, cfOf[s, #]} & /@ grid), {s, specs}];
  Print["=== ", baseName, " : PLAN Monte Carlo markers ==="];
  mcData = Table[Print["  MC: ", s["label"]]; ({#, mcPlanOf[s, #]} & /@ grid), {s, specs}];
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
  lineStyles = Table[Directive[mkColors[[i]], AbsoluteThickness[2.6], dashFor[i]], {i, n}];
  mkSyms = Table[{mcSym[specs[[i]]["risQ"]], 14}, {i, n}];
  asyData = {}; asyStyles = {};
  If[TrueQ@Lookup[cfg, "showAsy", False],
   asyGrid = grid;                                    (* full SNR range so the line is visible *)
   Do[If[specs[[i]]["risQ"],
       AppendTo[asyData, ({#, esmcRISasy[#, specs[[i]]["M"], specs[[i]]["L"],
          specs[[i]]["NRd"], specs[[i]]["NRe"], specs[[i]]["rhoEdB"]]} & /@ asyGrid)],
       anchorDB = Last[grid]; anchorVal = cfData[[i, -1, 2]];
       AppendTo[asyData, ({#, esmcRelayAsy[#, anchorDB, anchorVal]} & /@ asyGrid)]];
     AppendTo[asyStyles, Directive[Black, AbsoluteThickness[2.0], AbsoluteDashing[{2, 5}]]],
    {i, n}]];
  cfmcMax = Max[Flatten[{cfData[[All, All, 2]], mcData[[All, All, 2]]}]];
  asyMax = If[asyData === {}, 0.,
     Module[{vv = Select[Flatten[asyData[[All, All, 2]]], Positive]},
       If[vv === {}, 0., Min[Max[vv], 1.5 cfmcMax]]]];
  ymax = 1.12 Max[0.05, cfmcMax, asyMax];
  legEntries = Table[{"line", mkColors[[i]], dashFor[i], specs[[i]]["risQ"], specs[[i]]["label"]}, {i, n}];
  AppendTo[legEntries, {"marker", GrayLevel[0.2], None, True, "Simulation (MC)"}];
  If[TrueQ@Lookup[cfg, "showAsy", False],
     AppendTo[legEntries, {"line", Black, AbsoluteDashing[{2, 5}], True, "Asymptote"}]];
  legPos = Lookup[cfg, "legendPos", {0.03, 0.97}];
  ann = Lookup[cfg, "annotations", {}];
  base = ListLinePlot[cfData, PlotStyle -> lineStyles, InterpolationOrder -> 2,
     Frame -> True, Axes -> False, Background -> White, GridLines -> Automatic,
     GridLinesStyle -> Directive[GrayLevel[0.86], AbsoluteDashing[{1.5, 3}]],
     FrameLabel -> {Style[xlab, 18, FontFamily -> $font], Style[ylab, 18, FontFamily -> $font]},
     FrameStyle -> Directive[Black, AbsoluteThickness[1.2]],
     FrameTicksStyle -> Directive[Black, 13, FontFamily -> $font],
     BaseStyle -> {FontFamily -> $font, FontSize -> 14},
     PlotRange -> {{Min[grid], Max[grid]}, {0, ymax}},
     ImageSize -> 780, ImagePadding -> {{84, 22}, {64, 18}}];
  mkPlot = ListPlot[mcData, PlotStyle -> mkColors, PlotMarkers -> mkSyms];
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
     "Lines=user closed form. Markers=MC on PLAN PDF. Asymptotes from derivation PDFs.",
     "RIS asy=Step-8a full expression. Relay asy=A1 slope 1/2, offset anchored at top SNR.",
     "Config: " <> ToString[cfg]}, "\n"], "Text"];
  Print["Saved: ", pdfPath]; Print["Saved: ", pngPath]; Print["Saved: ", csvPath];
  fig];

(* ======================================================================= *)
(* BUILD THE THREE FIGURES                                                 *)
(* ======================================================================= *)
fig1 = buildFig[f1Config];
fig2 = buildFig[f2Config];
fig3 = buildFig[f3Config];

combined = Column[{fig1, fig2, fig3}, Spacings -> 2, Background -> White];
Export[FileNameJoin[{$outDir, "CombinedPreview.pdf"}], combined];
Export[FileNameJoin[{$outDir, "CombinedPreview.png"}],
  Rasterize[combined, "Image", ImageResolution -> $outputDPI, Background -> White]];

Print["============================================================"];
Print["DONE. Output folder: ", $outDir];
Print["============================================================"];
combined



