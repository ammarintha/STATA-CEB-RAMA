{smcl}
{* cnma_dicho.sthlp  15nov2026  Ammarin Thakkinstian}{...}
{vieweralsosee "cnma" "help cnma"}{...}
{vieweralsosee "cnma_rank" "help cnma_rank"}{...}
{vieweralsosee "cnma_test" "help cnma_test"}{...}
{vieweralsosee "cnma_map" "help cnma_map"}{...}
{vieweralsosee "mvmeta" "help mvmeta"}{...}
{vieweralsosee "network" "help network"}{...}

{title:Title}

{phang}{bf:cnma_dicho} {hline 2} Component Network Meta-Analysis for Binary Outcomes (OR/RR/RD/HR)


{title:Syntax}

{p 8 16 2}
{cmd:cnma_dicho} {ifin} {cmd:,}
  {opth stu:dy(varname)}
  {opth ref:erence(string)}
  {it:data_format_options}
  [{it:model_options}]
  [{it:output_options}]

{synoptset 30 tabbed}{...}
{synopthdr:data_format_options}{...}
{synoptline}

{syntab:Format A -- Long arm-level with event counts (one row per study-arm)}
{synopt:{opth tre:at(varname)}}variable holding the treatment name for each arm{p_end}
{synopt:{opth d(varname)}}number of events (or alias {cmd:y()}){p_end}
{synopt:{opth n(varname)}}total sample size{p_end}

{syntab:Format B -- Wide arm-level with event counts (one row per study)}
{synopt:{opth tvar(string)}}arm-treatment stub: columns {it:stub}1, {it:stub}2, ... hold treatment names{p_end}
{synopt:{opth d(string)}}events stub: columns {it:stub}1, {it:stub}2, ... hold event counts{p_end}
{synopt:{opth n(string)}}sample-size stub: columns {it:stub}1, {it:stub}2, ... hold arm sizes{p_end}

{syntab:Format C -- Pre-computed contrasts (one row per study-arm)}
{synopt:{opth tre:at(varname)}}treatment name for this arm (non-reference arms only){p_end}
{synopt:{opth y(varname)}}pre-computed log effect size (e.g. log OR, log RR){p_end}
{synopt:{opth se(varname)}}standard error of the log effect size{p_end}
{synoptline}

{synoptset 30 tabbed}{...}
{synopthdr:model_options}{...}
{synoptline}
{synopt:{opth mea:sure(string)}}effect measure: {bf:or} (default), {bf:rr}, {bf:rd}, {bf:hr}{p_end}
{synopt:{opth meth:od(string)}}estimation method: {bf:reml} (default), {bf:ml}, {bf:fegls}{p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:c(level)} (usually 95){p_end}
{synoptline}

{synoptset 30 tabbed}{...}
{synopthdr:output_options}{...}
{synoptline}
{synopt:{opt coef}}display log-scale coefficients (suppress exponentiation for OR/RR/HR){p_end}
{synopt:{opt noh:eader}}suppress the header block{p_end}
{synopt:{opth savec:ontrasts(filename)}}save augmented contrast dataset to {it:filename}{p_end}
{synopt:{opt replace}}overwrite existing file specified in {cmd:savecontrasts()}{p_end}
{synoptline}
{p2colreset}{...}

{p 4 6 2}
{cmd:study()}, {cmd:reference()}, and either {cmd:treat()} or {cmd:tvar()} are always
required.  For event-count inputs ({cmd:d}/n), {cmd:n()} is also required.{p_end}


{title:Description}

{pstd}
{cmd:cnma_dicho} fits a frequentist component network meta-analysis (cNMA) under
an additive model for {ul:binary outcomes}.  For continuous outcomes use
{helpb cnma}.

{pstd}
Combination treatments are named by joining component names with an underscore
(e.g. {it:antib_anti-inf}).  The model assumes that the effect of a combination
equals the {ul:sum} of the log-scale component effects:

{p 12 12 2}
log ES(T) = alpha(C1) + alpha(C2){p_end}

{pstd}
Estimation uses {cmd:mvmeta} (Ian White) with the network contrast structure and
multi-arm covariance handled by {cmd:network setup} (Ian White).  Continuity
correction (0.5 by default) is applied automatically to zero cells when
using event-count input.

{pstd}
{ul:Hyphenated component names} such as {it:anti-inf} or {it:fin-preg} are fully
supported.  The hyphen is treated as part of the component name (not as a
separator), and the command applies {cmd:strtoname()} internally when constructing
the mvmeta coefficient columns.

{pstd}
After {cmd:cnma_dicho} you may call {helpb cnma_rank}, {helpb cnma_test}, and
{helpb cnma_map} without re-running the main command.


{title:Data formats}

{dlgtab:Format A -- Long arm-level with event counts}

{pstd}
One row per arm.  Provide the treatment name, event count, and total N:

{col 4}{it:study}{col 14}{it:treat}{col 26}{it:d}{col 34}{it:n}
{col 4}1{col 14}placebo{col 26}3{col 34}120
{col 4}1{col 14}antib{col 26}1{col 34}118
{col 4}2{col 14}placebo{col 26}6{col 34}80
{col 4}2{col 14}antib{col 26}2{col 34}76
{col 4}2{col 14}anti-inf{col 26}1{col 34}79

{phang2}{cmd:. cnma_dicho, study(study) treat(treat) d(d) n(n) ref(placebo) measure(or)}{p_end}

{dlgtab:Format B -- Wide arm-level with event counts}

{pstd}
One row per study.  Arm information is stored in stub-numbered columns:

{col 4}{it:study}{col 14}{it:t1}{col 26}{it:t2}{col 38}{it:t3}{col 50}{it:d1}{col 60}{it:d2}{col 70}{it:d3}{col 80}{it:n1}{col 90}{it:n2}{col 100}{it:n3}
{col 4}1{col 14}placebo{col 26}antib{col 38}.{col 50}3{col 60}1{col 70}.{col 80}120{col 90}118{col 100}.
{col 4}2{col 14}placebo{col 26}antib{col 38}anti-inf{col 50}6{col 60}2{col 70}1{col 80}80{col 90}76{col 100}79

{phang2}{cmd:. cnma_dicho, study(study) tvar(t) d(d) n(n) ref(placebo) measure(or)}{p_end}

{dlgtab:Format C -- Pre-computed contrasts}

{pstd}
One row per arm (non-reference arms only).  Provide the log effect size and its SE:

{col 4}{it:study}{col 14}{it:treat}{col 26}{it:logor}{col 38}{it:se_logor}
{col 4}1{col 14}antib{col 26}-0.831{col 38}0.655
{col 4}2{col 14}antib{col 26}-1.040{col 38}0.620
{col 4}2{col 14}anti-inf{col 26}-1.386{col 38}0.730

{phang2}{cmd:. cnma_dicho, study(study) treat(treat) y(logor) se(se_logor) ref(placebo)}{p_end}


{title:Options}

{dlgtab:Data format}

{phang}
{opth study(varname)} Study identifier (numeric or string).  Required.

{phang}
{opth treat(varname)} Variable containing the treatment name for each arm.
Required for Formats A and C (long layouts).

{phang}
{opth tvar(string)} Stub for arm-treatment columns in Format B (wide layout).
Columns {it:stub}1, {it:stub}2, etc. hold the treatment name for each arm.

{phang}
{opth d(varname)} or {opth y(varname)} Event count per arm.  For Format A/B
(event-count input) this is the number of events.  {cmd:d()} and {cmd:y()}
are synonymous.

{phang}
{opth se(varname)} SE of the log effect size.  Required for Format C
(pre-computed contrast input).  When {cmd:se()} is provided, {cmd:d()}/{cmd:y()}
is interpreted as a log-scale effect size, not an event count.

{phang}
{opth n(varname)} Total sample size per arm.  Required for event-count input
(Formats A and B).

{dlgtab:Model}

{phang}
{opth measure(string)} Binary effect measure.  Options are {bf:or} (odds ratio,
default), {bf:rr} (risk ratio), {bf:rd} (risk difference), {bf:hr}
(hazard ratio).  For {cmd:or}, {cmd:rr}, and {cmd:hr}, effects are estimated
on the log scale and displayed exponentiated by default.  Optional when
using Format C (pre-computed log scale input).

{phang}
{opth method(string)} Estimation method passed to {cmd:mvmeta}.
{bf:reml} (restricted maximum likelihood, default), {bf:ml} (maximum
likelihood), or {bf:fegls} (fixed-effects GLS).

{phang}
{opt level(#)} Confidence level for intervals.  Default is {cmd:c(level)}.

{dlgtab:Output}

{phang}
{opt coef} Suppress exponentiation.  For OR, RR, and HR, the results are
displayed on the log scale (log OR, log RR, log HR) instead of being
exponentiated.  Useful for inspecting the raw mvmeta coefficients and for
directly using {cmd:lincom} expressions.  For {bf:rd} this option has no
effect.

{phang}
{opt noheader} Suppress the header block (study/treatment/component counts,
measure, method, tau2).

{phang}
{opth savecontrasts(filename)} Save the augmented pairwise-contrast dataset
(the intermediate data passed to {cmd:mvmeta}) to {it:filename}{cmd:.dta}.

{phang}
{opt replace} Overwrite an existing file when {cmd:savecontrasts()} is used.


{title:Examples}

{pstd}{ul:Long format -- odds ratio}

{phang2}{cmd:. cnma_dicho, study(study) treat(treat) d(d) n(n) ref(placebo) measure(or)}{p_end}

{pstd}{ul:Long format -- risk ratio, 90% CI}

{phang2}{cmd:. cnma_dicho, study(study) treat(treat) d(d) n(n) ref(placebo) measure(rr) level(90)}{p_end}

{pstd}{ul:Wide format -- odds ratio}

{phang2}{cmd:. cnma_dicho, study(study) tvar(t) d(d) n(n) ref(placebo) measure(or)}{p_end}

{pstd}{ul:Pre-computed log OR + SE}

{phang2}{cmd:. cnma_dicho, study(study) treat(treat) y(logor) se(selogor) ref(placebo)}{p_end}

{pstd}{ul:Display log-scale coefficients (suppress exponentiation)}

{phang2}{cmd:. cnma_dicho, study(study) treat(treat) d(d) n(n) ref(placebo) measure(or) coef}{p_end}

{pstd}{ul:Replay with log scale}

{phang2}{cmd:. cnma_dicho, coef}{p_end}

{pstd}{ul:Post-estimation: treatment rankings}

{phang2}{cmd:. cnma_rank, better(small)}{p_end}

{pstd}{ul:Post-estimation: additivity test}

{phang2}{cmd:. cnma_test}{p_end}

{pstd}{ul:Post-estimation: component network map}

{phang2}{cmd:. cnma_map}{p_end}

{pstd}{ul:Post-estimation: combination effect via lincom}

{phang2}{cmd:. lincom _b[antib] + _b[anti-inf], eform}{p_end}
{phang2}{cmd:. lincom _b[antib] + _b[fin-preg], eform}{p_end}


{title:Stored results}

{pstd}
{cmd:cnma_dicho} stores the following in {cmd:e()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of observations (study-arms) used in estimation{p_end}
{synopt:{cmd:e(n_studies)}}number of studies{p_end}
{synopt:{cmd:e(n_treat)}}number of treatments (reference + components + combinations){p_end}
{synopt:{cmd:e(n_comp)}}number of components (excludes reference and pure combinations){p_end}
{synopt:{cmd:e(level)}}confidence level used{p_end}
{synopt:{cmd:e(ll)}}log likelihood (REML/ML only){p_end}
{synopt:{cmd:e(converged)}}1 if mvmeta converged, 0 otherwise{p_end}
{synopt:{cmd:e(tau2)}}estimated between-study variance (tau-squared){p_end}
{synopt:{cmd:e(Q)}}Cochran Q heterogeneity statistic{p_end}
{synopt:{cmd:e(Q_df)}}degrees of freedom for Q{p_end}
{synopt:{cmd:e(p_Q)}}p-value for Q{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:cnma_dicho}{p_end}
{synopt:{cmd:e(method)}}{cmd:frequentist (mvmeta)}{p_end}
{synopt:{cmd:e(model)}}{cmd:additive}{p_end}
{synopt:{cmd:e(inputmode)}}{cmd:long_dn}, {cmd:wide_dn}, or {cmd:long_se}{p_end}
{synopt:{cmd:e(measure)}}effect measure: {cmd:or}, {cmd:rr}, {cmd:rd}, or {cmd:hr}{p_end}
{synopt:{cmd:e(reference)}}name of the reference treatment{p_end}
{synopt:{cmd:e(components)}}space-separated list of component names{p_end}
{synopt:{cmd:e(combinations)}}space-separated list of combination names{p_end}
{synopt:{cmd:e(studyvar)}}name of the study identifier variable{p_end}
{synopt:{cmd:e(treatvar)}}name of the treatment variable (Formats A, C){p_end}
{synopt:{cmd:e(yvar)}}name of the outcome variable{p_end}
{synopt:{cmd:e(sevar)}}name of the SE variable (Format C only){p_end}
{synopt:{cmd:e(sdvar)}}name of the SD variable (Format B, continuous only){p_end}
{synopt:{cmd:e(nvar)}}name of the N variable{p_end}
{synopt:{cmd:e(tvar)}}name of the arm-treatment stub (Format B){p_end}
{synopt:{cmd:e(method_test)}}estimation method (copy stored for post-estimation){p_end}

{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}row vector of estimated component log effects{p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix of the estimates{p_end}

{p2col 5 22 26 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}marks the estimation sample{p_end}
{p2colreset}{...}


{title:Notes on combinations and components}

{pstd}
{ul:Naming convention.}  A combination treatment is named by joining the component
names with an underscore: {it:compA_compB}.  An underscore in a name is always
interpreted as a combination separator.  Component names themselves must not
contain underscores but may contain hyphens (e.g. {it:anti-inf}, {it:fin-preg}).

{pstd}
{ul:Additivity.}  The model constrains the effect of each combination to equal the
sum of its component effects on the log scale (log OR, log RR, log HR) or on
the linear scale (RD).  Equivalently, on the exponentiated scale, the
combination OR/RR/HR equals the {ul:product} of the component OR/RR/HRs.

{pstd}
{ul:Reference treatment.}  The reference is excluded from {cmd:e(b)};
its effect is constrained to zero.  Post-estimation {cmd:lincom} can recover
contrasts against any treatment (see Examples above).

{pstd}
{ul:Continuity correction.}  When using event-count input (Formats A/B), a
0.5 continuity correction is applied automatically to arms with zero events
or zero non-events (the default of {cmd:network setup}).

{pstd}
{ul:Difference from {cmd:cnma}.}  {cmd:cnma_dicho} is for binary outcomes only
(OR, RR, RD, HR).  For continuous outcomes (MD, SMD) use {helpb cnma}.
Both commands share the same post-estimation suite ({cmd:cnma_rank},
{cmd:cnma_test}, {cmd:cnma_map}).


{title:Author}

{pstd}Ammarin Thakkinstian{p_end}
{pstd}Department of Epidemiology, Faculty of Medicine Ramathibodi Hospital{p_end}
{pstd}Mahidol University, Bangkok, Thailand{p_end}
{pstd}{browse "mailto:ammarin.tha@mahidol.ac.th":ammarin.tha@mahidol.ac.th}{p_end}


{title:References}

{phang}
Rucker G, Petropoulou M, Schwarzer G (2020).  Network meta-analysis of
multicomponent interventions.  {it:Biometrical Journal} 62:808-821.

{phang}
White IR (2011).  Multivariate random-effects meta-regression: Updates to
{cmd:mvmeta}.  {it:Stata Journal} 11(2):255-270.

{phang}
White IR, Barrett JK, Jackson D, Higgins JPT (2012).  Consistency and
inconsistency in network meta-analysis: model estimation using multivariate
meta-regression.  {it:Research Synthesis Methods} 3(2):111-125.


{title:Also see}

{psee}
Manual: {bf:[R] meta}
{p_end}
{psee}
Online: {helpb cnma}, {helpb cnma_rank}, {helpb cnma_test}, {helpb cnma_map},
{helpb mvmeta}, {helpb network}
{p_end}
