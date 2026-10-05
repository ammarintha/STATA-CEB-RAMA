{smcl}
{* *! generate_ccw v1.0  27sep2026  A.Thakkinstian}{...}
{vieweralsosee "create_clones" "help create_clones"}{...}
{vieweralsosee "cast_clones_to_long" "help cast_clones_to_long"}{...}
{vieweralsosee "bootstrap_ccw" "help bootstrap_ccw"}{...}
{viewerjumpto "Syntax" "generate_ccw##syntax"}{...}
{viewerjumpto "Description" "generate_ccw##description"}{...}
{viewerjumpto "Options" "generate_ccw##options"}{...}
{viewerjumpto "Method" "generate_ccw##method"}{...}
{viewerjumpto "Weighted Cox regression" "generate_ccw##cox"}{...}
{viewerjumpto "Stored results" "generate_ccw##stored"}{...}
{viewerjumpto "Examples" "generate_ccw##examples"}{...}
{viewerjumpto "References" "generate_ccw##references"}{...}
{viewerjumpto "Author" "generate_ccw##author"}{...}

{title:Title}

{phang}
{bf:generate_ccw} {hline 2} Generate IPCW clone-censor weights for CCW analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:generate_ccw}{cmd:,}
{opt predvars(varlist)}
[{opt winsorize(lo hi)}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt predvars(varlist)}}baseline covariates for the censoring hazard model{p_end}
{syntab:Optional}
{synopt:{opt winsorize(lo hi)}}winsorise weights at the {it:lo}th and {it:hi}th percentiles (e.g. {cmd:winsorize(10 90)}){p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:generate_ccw} is Step 6 of the CCW pipeline.
It computes Inverse Probability of Censoring Weights (IPCW) — also called
clone-censor weights — that correct for the informative artificial censoring
introduced in {helpb create_clones}.

{pstd}
The weights are used in the Cox regression (Step 7) to give each clone-patient
a weight inversely proportional to the probability that the patient has
{it:not} been artificially censored up to time t.

{pstd}
{cmd:generate_ccw} must be run after {helpb cast_clones_to_long} and before
{helpb stcox}.  Run {helpb bootstrap_ccw} afterwards for valid confidence intervals.


{marker options}{...}
{title:Options}

{phang}
{opt predvars(varlist)} specifies the baseline covariates included in the
discrete-time pooled logistic hazard model for artificial censoring.
These should be the same variables that predict treatment initiation.
Example: {cmd:predvars(age female comorbidity_score)}.

{phang}
{opt winsorize(lo hi)} trims extreme weights at the {it:lo}th percentile
(floor) and {it:hi}th percentile (cap).  Winsorization controls instability
from near-zero censoring survival probabilities.
Typical values: {cmd:winsorize(5 95)} or {cmd:winsorize(10 90)}.
By default no winsorization is applied; inspect the weight distribution
with {cmd:sum weight_cox, detail} before deciding.


{marker method}{...}
{title:Method}

{pstd}
{cmd:generate_ccw} fits a {it:discrete-time pooled logistic} hazard model for the
probability of artificial censoring at each interval, separately for each clone group.
This mirrors {cmd:generate_ccw(predvars = ...)} in the R package {it:survivalCCW}.

{pstd}
The steps are:

{p2colset 6 10 12 2}
{p2col:{bf:1.}}{cmd:logit censor t_stop predvars if clone == 1} — censoring model for clone 1{p_end}
{p2col:{bf:2.}}{cmd:logit censor t_stop predvars if clone == 0} — censoring model for clone 0{p_end}
{p2col:{bf:3.}}{cmd:p_surv = 1 - P(censor)} at each interval (conditional survival){p_end}
{p2col:{bf:4.}}{cmd:S_c(t) = exp(sum(log(p_surv)))} running cumulative product per clone-patient{p_end}
{p2col:{bf:5.}}{cmd:weight_cox = 1 / S_c(t)}{p_end}
{p2colreset}

{pstd}
The log-sum formula in Step 4 avoids floating-point underflow from multiplying
many small probabilities.  A small floor (10^-8) guards against log(0) when any
predicted censoring probability equals 1.


{marker cox}{...}
{title:Weighted Cox regression (Step 7)}

{pstd}
After {cmd:generate_ccw}, fit the weighted Cox model as follows:

{phang2}{cmd:. gen long rowid = _n}{p_end}
{phang2}{cmd:. stset t_stop [pw=weight_cox], id(rowid) failure(outcome) time0(t_start)}{p_end}
{phang2}{cmd:. stcox clone, vce(cluster stid)}{p_end}

{pstd}
{bf:Why rowid?}  {helpb stset} with {cmd:[pw=weight_cox]} requires the weight to be
constant within each {cmd:id()} value.  IPCW weights vary across intervals within each
clone-patient ({cmd:stid}).  Assigning a unique {cmd:rowid} per row makes each interval
its own "subject" with a trivially constant weight, while {cmd:time0(t_start)} preserves
the correct counting-process risk sets.  {cmd:vce(cluster stid)} then accounts for
within-clone-patient correlation.

{pstd}
{bf:Note on inference:}  Standard errors and p-values from this single-fit Cox model
are approximate.  For bootstrap confidence intervals use {helpb bootstrap_ccw}, which
resamples patients with probability proportional to {cmd:weight_cox} (pseudo-samples);
the weights are kept at their full-sample values and are not re-estimated.


{marker stored}{...}
{title:Variables created}

{p2colset 8 18 20 2}
{p2col:{cmd:p_c}}        predicted P(artificially censored) at each interval{p_end}
{p2col:{cmd:p_surv}}     1 - p_c  (conditional survival through this interval){p_end}
{p2col:{cmd:surv_c}}     cumulative S_c(t) per clone-patient{p_end}
{p2col:{cmd:weight_cox}} IPCW clone-censor weight = 1 / S_c(t){p_end}
{p2colreset}


{marker examples}{...}
{title:Examples}

{pstd}Step 6 — basic:{p_end}
{phang2}{cmd:. generate_ccw, predvars(cov1 cov2)}{p_end}

{pstd}Step 6 — with weight winsorization at 5th and 95th percentile:{p_end}
{phang2}{cmd:. generate_ccw, predvars(cov1 cov2) winsorize(5 95)}{p_end}

{pstd}Inspect weight distribution:{p_end}
{phang2}{cmd:. sum weight_cox, detail}{p_end}
{phang2}{cmd:. tabstat weight_cox, by(clone) stats(n mean sd min p25 p75 max)}{p_end}

{pstd}Step 7 — weighted Cox after generate_ccw:{p_end}
{phang2}{cmd:. gen long rowid = _n}{p_end}
{phang2}{cmd:. stset t_stop [pw=weight_cox], id(rowid) failure(outcome) time0(t_start)}{p_end}
{phang2}{cmd:. stcox clone, vce(cluster stid)}{p_end}
{phang2}{cmd:. stcox, hr noshow}{p_end}


{marker references}{...}
{title:References}

{phang}
Gaber CE, Ghazarian AA, Strassle PD, Ribeiro TB, Salas M, Maringe C, Garcia-Albeniz X, Wyss R, Du W, Lund JL.
{it:De-Mystifying the Clone-Censor-Weight Method for Causal Research Using Observational Data: A Primer for Cancer Researchers.}
Cancer Medicine, 2024; 13(23):e70461.
{browse "https://doi.org/10.1002/cam4.70461"}

{phang}
Maringe C, Beswick S, Goldsbury D, Pogson Z, Salim A, Naicker N, Gurrin L, Lawlor R, Morris M, White I, Rachet B.
{it:Reflection on modern methods: trial emulation in the presence of immortal-time bias.}
International Journal of Epidemiology, 2020; 49(5):1719-1731.

{phang}
Hernan MA, Brumback B, Robins JM.
{it:Marginal structural models to estimate the joint causal effect of nonrandomized treatments.}
Journal of the American Statistical Association, 2001; 96(454):440-448.

{phang}
R package: survivalCCW (Genentech).
{browse "https://github.com/Genentech/survivalCCW"}


{marker author}{...}
{title:Author}

{pstd}
Ammarin Thakkinstian{break}
Department of Clinical Epidemiology and Biostatistics (CEB), Faculty of Medicine Ramathibodi Hospital, Mahidol University{break}
{browse "mailto:ammarin.tha@mahidol.ac.th":ammarin.tha@mahidol.ac.th}

{pstd}
{bf:See also:}
{helpb create_clones}, {helpb cast_clones_to_long}, {helpb bootstrap_ccw}
