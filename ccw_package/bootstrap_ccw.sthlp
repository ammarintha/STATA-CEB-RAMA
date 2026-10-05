{smcl}
{* *! bootstrap_ccw v5.1  01oct2026  A.Thakkinstian}{...}
{vieweralsosee "create_clones" "help create_clones"}{...}
{vieweralsosee "cast_clones_to_long" "help cast_clones_to_long"}{...}
{vieweralsosee "generate_ccw" "help generate_ccw"}{...}
{viewerjumpto "Syntax" "bootstrap_ccw##syntax"}{...}
{viewerjumpto "Description" "bootstrap_ccw##description"}{...}
{viewerjumpto "Options" "bootstrap_ccw##options"}{...}
{viewerjumpto "Before you run it" "bootstrap_ccw##prelim"}{...}
{viewerjumpto "Method" "bootstrap_ccw##method"}{...}
{viewerjumpto "Output" "bootstrap_ccw##output"}{...}
{viewerjumpto "Remarks" "bootstrap_ccw##remarks"}{...}
{viewerjumpto "Examples" "bootstrap_ccw##examples"}{...}
{viewerjumpto "References" "bootstrap_ccw##references"}{...}
{viewerjumpto "Author" "bootstrap_ccw##author"}{...}

{title:Title}

{phang}
{bf:bootstrap_ccw} {hline 2} Bootstrap inference for the Clone-Censor-Weight (CCW) Cox model


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:bootstrap_ccw}{cmd:,}
{opt cl:uster(varname)}
[{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt cl:uster(varname)}}patient identifier used for resampling; numeric or string{p_end}
{syntab:Optional}
{synopt:{opt pred:ictor(varlist)}}covariates to include in the Cox model besides {cmd:clone}{p_end}
{synopt:{opt rep:s(#)}}number of bootstrap replications; default is {cmd:reps(200)}{p_end}
{synopt:{opt seed(#)}}random-number seed; default is {cmd:seed(0)} (no seed set){p_end}
{synopt:{opt t:start(varname)}}interval start time; default is {cmd:t_start}{p_end}
{synopt:{opt tstop(varname)}}interval stop time; default is {cmd:t_stop}{p_end}
{synopt:{opt f:ailure(varname)}}event indicator; default is {cmd:outcome}{p_end}
{synopt:{opt i:dvar(varname)}}row identifier for {cmd:stset}; default is {cmd:rowid}{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:bootstrap_ccw} is the final step of the CCW pipeline.
It gives bootstrap standard errors and confidence intervals for the effect of
{cmd:clone} (assigned strategy) in the weighted CCW Cox model.

{pstd}
Patients are resampled with probability proportional to their total
inverse probability of censoring weight ({cmd:weight_cox}), which creates weighted
pseudo-samples. The Cox model in each replicate is then fitted without weights,
because the weights are already carried by the number of copies of each patient.

{pstd}
{cmd:bootstrap_ccw} must be run after {helpb generate_ccw}.


{marker options}{...}
{title:Options}

{phang}
{opt cluster(varname)} is required. It gives the {it:name} of the patient identifier
variable, e.g. {cmd:cluster(id)}. The variable can be numeric (e.g. 123) or string
(e.g. "pat1150"). Both clones and all intervals of a patient are resampled together.

{phang}
{opt predictor(varlist)} adds covariates to the Cox model, e.g.
{cmd:predictor(age sex comorbidity)}.

{phang}
{opt reps(#)} sets the number of bootstrap replications. Use {cmd:reps(5)} only to check
that the command runs; use at least {cmd:reps(200)} for results and {cmd:reps(1000)} or more
for publication.

{phang}
{opt seed(#)} sets the random-number seed so results can be reproduced.

{phang}
{opt tstart()}, {opt tstop()}, {opt failure()} and {opt idvar()} name the counting-process
variables. The defaults match the output of {helpb cast_clones_to_long} and
{helpb generate_ccw}.


{marker prelim}{...}
{title:Before you run it}

{pstd}
Run the pipeline in this order:

{p2colset 8 12 14 2}
{p2col:{bf:1.}}{helpb create_clones}{p_end}
{p2col:{bf:2.}}{helpb cast_clones_to_long}{p_end}
{p2col:{bf:3.}}{helpb generate_ccw} (creates {cmd:weight_cox}){p_end}
{p2col:{bf:4.}}{cmd:gen long rowid = _n}{p_end}
{p2colreset}

{pstd}
Variables needed in memory: {cmd:t_start}, {cmd:t_stop}, {cmd:outcome}, {cmd:clone},
{cmd:weight_cox}, {cmd:rowid} (unique for every row) and the patient identifier given in
{cmd:cluster()}.

{pstd}
You do {it:not} need to {cmd:stset} the data first. {cmd:bootstrap_ccw} sets the survival
structure itself (with {cmd:[pw=weight_cox]} for the observed estimate and without weights
for the replicates); any existing {cmd:stset} is replaced.


{marker method}{...}
{title:Method}

{pstd}
{bf:Once, before the replications:}

{p2colset 8 12 14 2}
{p2col:{bf:1.}}Total {cmd:weight_cox} per patient = sum over both clones and all intervals.{p_end}
{p2col:{bf:2.}}Observed estimate: the weighted CCW Cox model on the full data,
{cmd:stset t_stop [pw=weight_cox], id(rowid) failure(outcome) time0(t_start)} and
{cmd:stcox clone [predictor()]}.{p_end}
{p2colreset}

{pstd}
{bf:In each replication:}

{p2colset 8 12 14 2}
{p2col:{bf:1.}}Draw n patients with replacement (n = number of patients), with
P(patient i) proportional to the total {cmd:weight_cox} of patient i. The draw uses
Mata's {cmd:rdiscrete()}, so {cmd:seed()} applies.{p_end}
{p2col:{bf:2.}}Expand each drawn patient by the number of times drawn (pseudo-sample).{p_end}
{p2col:{bf:3.}}Fit {cmd:stcox clone [predictor()]} without weights.{p_end}
{p2col:{bf:4.}}Store the coefficient and hazard ratio for {cmd:clone}.{p_end}
{p2colreset}

{pstd}
{bf:Why the observed model uses pweights and the replicates do not:} both use the same
concept. The pseudo-samples carry the weights through the number of copies of each
patient; the observed model carries them through {cmd:[pw=weight_cox]}. The observed
estimate is therefore the usual weighted CCW hazard ratio, and the bias
(bootstrap mean - observed) compares like with like.

{pstd}
{bf:Fixed weights:} the weights are kept at their full-sample values and are not
re-estimated in each replicate. The bootstrap reflects uncertainty in the Cox model
given these weights, not uncertainty from estimating the weights.


{marker output}{...}
{title:Output}

{pstd}
Results are shown in the style of {cmd:estat bootstrap, all}, for the coefficient
(log hazard ratio) and for the hazard ratio of {cmd:clone}:

{p2colset 8 22 24 2}
{p2col:{bf:Observed}}weighted CCW estimate from the full data ({cmd:[pw=weight_cox]}){p_end}
{p2col:{bf:Bias}}bootstrap mean - observed{p_end}
{p2col:{bf:Std. err.}}bootstrap standard error{p_end}
{p2col:{bf:(N)}}normal-based 95% CI: mean +/- 1.96 x SE{p_end}
{p2col:{bf:(P)}}percentile 95% CI: 2.5th and 97.5th percentiles{p_end}
{p2col:{bf:(BC)}}bias-corrected 95% CI (z0 adjustment){p_end}
{p2colreset}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Number of replications:} the bias-corrected (BC) interval in particular needs many
replications; with very few replications the (P) and (BC) intervals can be identical.

{pstd}
{bf:Data in memory:} the original data are put back in memory when the command finishes,
and also if it stops with an error. No helper variables are left behind.

{pstd}
{bf:Reproducibility:} always specify {cmd:seed()}. To check stability, rerun with
different seeds.


{marker examples}{...}
{title:Examples}

{pstd}Full pipeline, with {cmd:id} as the patient identifier:{p_end}
{phang2}{cmd:. create_clones}{p_end}
{phang2}{cmd:. cast_clones_to_long}{p_end}
{phang2}{cmd:. generate_ccw, predvars(cov1 cov2)}{p_end}
{phang2}{cmd:. gen long rowid = _n}{p_end}
{phang2}{cmd:. bootstrap_ccw, cluster(id) reps(200) seed(12345)}{p_end}

{pstd}With additional covariates in the Cox model:{p_end}
{phang2}{cmd:. bootstrap_ccw, cluster(id) predictor(age sex comorbidity) reps(200) seed(12345)}{p_end}

{pstd}Quick check that the command runs:{p_end}
{phang2}{cmd:. bootstrap_ccw, cluster(id) reps(5) seed(23456)}{p_end}


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
{helpb create_clones}, {helpb cast_clones_to_long}, {helpb generate_ccw}
