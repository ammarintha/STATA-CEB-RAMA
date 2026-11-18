{smcl}
{* cnma_test.sthlp  05nov2026  Ammarin Thakkinstian}{...}
{hline}
{title:Help for {cmd:cnma_test}}
{hline}

{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{bf:cnma_test} {hline 2}}Post-estimation test of the additivity assumption after {cmd:cnma}{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 17 2}
{cmd:cnma_test}
[{cmd:,}
{opt int:eract(combos)}
{opt lev:el(#)}]


{synoptset 22 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt int:eract(combos)}}After the global additivity test, additionally
  run {helpb cnma_interact} for the specified combination(s).
  Use {cmd:_all} to free all combinations (equivalent to the full sNMA).
  Example: {cmd:interact(FES_NMES TMShigh_NMES)} frees two specific combos.{p_end}
{synopt:{opt lev:el(#)}}Confidence level; default {cmd:level(95)}.
  Also passed to {cmd:cnma_interact} when {opt interact()} is specified.{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:cnma_test} is a post-estimation command for {helpb cnma}.
It tests whether the additivity (component) assumption holds — i.e., whether
the effect of a combination treatment equals the sum of its component effects.

{pstd}
Two test statistics are available depending on the estimation method used in
{cmd:cnma}:

{phang2}
{bf:Likelihood Ratio test} (default for {cmd:method(reml)} and {cmd:method(ml)}):
compares log-likelihoods of the saturated sNMA (all combinations free) and the
additive cNMA.  LR = 2×(ll_sNMA − ll_cNMA) ~ chi²(df), where df = number of
additivity constraints (= number of observed combinations).{p_end}

{phang2}
{bf:FE-GLS Q-difference test} ({cmd:method(fegls)}): compares the Q-statistic
(heterogeneity + inconsistency) between the unconstrained FE-NMA and the
additive FE-cNMA.  Q_diff ~ chi²(df).{p_end}

{pstd}
Failure to reject additivity supports the additive component model.


{title:The interact() option}

{pstd}
When the global test rejects additivity — or when you have a priori
hypotheses about specific combinations — use {opt interact(combos)} to free
individual interaction terms and test them directly.

{pstd}
Internally this calls {helpb cnma_interact} for the listed combinations.
Each freed combination gets its own effect estimate (δ), which represents the
interaction = observed combination effect − sum of component effects.

{pstd}
{opt interact()} can also be called without prior {cmd:cnma_test} output by
using {cmd:cnma_interact} directly:

{phang2}{cmd:. cnma_interact FES_NMES}{p_end}
{phang2}{cmd:. cnma_interact FES_NMES TMShigh_NMES, level(99)}{p_end}
{phang2}{cmd:. cnma_interact _all}{p_end}


{title:Examples}

{pstd}
{ul:Example 1 — Global additivity test only}

{phang2}{stata cnma, study(trial) treat(trt) y(logOR) se(se) comps(PSY PHM) ref(Control)}{p_end}
{phang2}{stata cnma_test}{p_end}

{pstd}
{ul:Example 2 — Global test + interaction test for one combination}

{phang2}{stata cnma_test, interact(PSY_PHM)}{p_end}

{pstd}
{ul:Example 3 — Global test + interaction test for all combinations}

{phang2}{stata cnma_test, interact(_all)}{p_end}

{pstd}
{ul:Example 4 — FMA dataset (continuous outcomes)}

{phang2}{stata cnma, study(studyid) y(y) sd(sd) n(n) trtlist(FES FES_TMShigh NMES NMES_TMShigh NMES_TMSlow NMES_rPMS Rehab TMShigh TMSlow rPMS) ref(Rehab) measure(md)}{p_end}
{phang2}{stata cnma_test}{p_end}
{phang2}{stata cnma_test, interact(FES_TMShigh NMES_TMShigh)}{p_end}


{title:Output}

{pstd}
{cmd:cnma_test} prints:

{phang2}1. The global additivity test table (LR or Q-difference){p_end}
{phang2}2. If {opt interact()} is specified: the interaction table from
{helpb cnma_interact}, showing the freed combination's delta (interaction
estimate), SE, z, p-value, and CI, together with an LR test vs the additive
model.{p_end}


{title:Technical notes}

{pstd}
{bf:REML approximation.} The LR test is approximate under REML because the
sNMA and cNMA models have different numbers of free treatment-effect parameters.
Use {cmd:method(ml)} for an exact LR test.

{pstd}
{bf:FE vs RE.} The Q-difference test is only available for
{cmd:method(fegls)}.  For random-effects models, use the LR test.

{pstd}
{bf:Interaction interpretation.}  A significant delta from {opt interact()}
means the combination acts supra-additively (δ > 0, {opt better(higher)}) or
sub-additively (δ < 0).  This is distinct from testing whether the combination
is effective — both main components and the interaction may each be non-zero.


{title:References}

{phang}
Rücker G, Petropoulou M, Schwarzer G (2020).
Network meta-analysis of multicomponent interventions.
{it:Biometrical Journal} 62(3): 808–821.
{p_end}

{phang}
Madan J, Ades AE, Price M, et al. (2011).
Nonlinear parameterizations of within-trial treatment effect heterogeneity.
{it:Statistics in Medicine} 30(2): 140–155.
{p_end}


{title:Also see}

{psee}
Online: {helpb cnma}, {helpb cnma_interact}, {helpb cnma_rank}, {helpb cnma_map}
{p_end}
