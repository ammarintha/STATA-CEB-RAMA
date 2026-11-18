{smcl}
{* *! version 2.1  02nov2026}{...}
{vieweralsosee "cnma_rank" "help cnma_rank"}{...}
{vieweralsosee "cnma_test" "help cnma_test"}{...}
{vieweralsosee "cnma_map" "help cnma_map"}{...}
{vieweralsosee "mvmeta" "help mvmeta"}{...}
{vieweralsosee "network" "help network"}{...}
{title:Title}

{phang}{bf:cnma} {hline 2} Component Network Meta-Analysis (Frequentist, Additive Model)


{title:Syntax}

{p 8 16 2}
{cmd:cnma} {ifin} {cmd:,}
  {opth study(varname)}
  {opth ref:erence(string)}
  {opth y(varname_or_stub)}
  [{it:data_format_options}]
  [{it:model_options}]
  [{it:output_options}]

{synoptset 28 tabbed}{...}
{synopthdr:data_format_options}{...}
{synoptline}
{syntab:Format A -- Wide treatment-named (one row per study)}
{synopt:{opth trtlist(string)}}space-separated list of all treatment names{p_end}
{synopt:{opth y(string)}}stub prefix; columns y{it:TreatName}, e.g. yFES, yNMES, yFES_TMShigh{p_end}
{synopt:{opth sd(string)}}stub prefix for SD columns -- continuous only{p_end}
{synopt:{opth n(string)}}stub prefix for N columns{p_end}

{syntab:Format B -- Long arm-level (one row per study-arm)}
{synopt:{opth treat(varname)}}variable holding treatment name{p_end}
{synopt:{opth y(varname)}}outcome variable (mean for continuous; event count for binary){p_end}
{synopt:{opth d(varname)}}event count variable (binary outcomes) -- alias for {cmd:y()}{p_end}
{synopt:{opth sd(varname)}}SD variable -- continuous outcomes only{p_end}
{synopt:{opth n(varname)}}sample size variable{p_end}

{syntab:Format C -- Precomputed contrasts (one row per study-arm)}
{synopt:{opth treat(varname)}}treatment name for this arm (non-reference arms only){p_end}
{synopt:{opth y(varname)}}pre-computed effect size (vs. reference){p_end}
{synopt:{opth se(varname)}}standard error of the effect size{p_end}
{synoptline}

{synoptset 26 tabbed}{...}
{synopthdr:model_options}{...}
{synoptline}
{synopt:{opth mea:sure(string)}}effect measure: {bf:md} (default), {bf:smd}, {bf:or}, {bf:rr}, {bf:rd}, {bf:hr}; optional when {cmd:se()} is supplied (Format C){p_end}
{synopt:{opth meth:od(string)}}estimation method: {bf:reml} (default), {bf:ml}, {bf:fegls}{p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:c(level)}{p_end}
{synoptline}

{synoptset 26 tabbed}{...}
{synopthdr:output_options}{...}
{synoptline}
{synopt:{opt noh:eader}}suppress header block{p_end}
{synopt:{opth savec:ontrasts(filename)}}save augmented contrast dataset to file{p_end}
{synopt:{opt replace}}overwrite existing file in {cmd:savecontrasts()}{p_end}
{synoptline}
{p2colreset}{...}

{p 4 6 2}{cmd:ref()} and {cmd:y()} are always required ({cmd:d()} may be used instead of {cmd:y()} for binary event counts).{p_end}


{title:Description}

{pstd}
{cmd:cnma} fits a frequentist component network meta-analysis (cNMA) under an
additive model.  For a combination treatment T = C1_C2 the model assumes the
effect equals the sum of the individual component effects:
mu(T) = alpha(C1) + alpha(C2).  Components are detected
automatically from treatment names: two names joined by an underscore
(e.g. {it:DrugA_DrugB}) define a combination.

{pstd}
Estimation uses {cmd:mvmeta} (multivariate meta-analysis) with exchangeable
between-study covariance (bscovariance exch 0) and REML by default.
Additivity constraints are passed as linear constraints on the fixed effects.
The command requires {cmd:network} and {cmd:mvmeta} to be installed.

{pstd}
After {cmd:cnma} you may call {help cnma_rank} to compute surface-under-the-
cumulative-ranking-curve (SUCRA) for components, {help cnma_test} to test
the additivity assumption, and {help cnma_map} to draw a component network map.
These post-estimation commands can be called in any order after {cmd:cnma}
without re-running {cmd:cnma}.


{title:Data formats}

{pstd}
{cmd:cnma} accepts three input layouts.  Format A has one row per
study; Formats B and C have one row per study-arm.

{dlgtab:Format A -- Wide treatment-named (one row per study)}

{pstd}
Each study occupies one row.  Each treatment has its own set of columns.
Two column-naming conventions are recognised automatically:

{pstd}{bf:Convention 1 -- treatment name as suffix}
(e.g. {it:y}FES, {it:sd}FES, {it:n}FES, {it:y}FES_TMShigh, {it:sd}FES_TMShigh, {it:n}FES_TMShigh, ...):

{col 4}{it:studyid}{col 14}{it:yFES}{col 22}{it:sdFES}{col 30}{it:nFES}{col 40}{it:yFES_TMShigh}{col 55}{it:sdFES_TMShigh}{col 70}{it:nFES_TMShigh}{col 84}{it:yNMES}{col 92}{it:...}
{col 4}1{col 14}.{col 22}.{col 30}.{col 40}.{col 55}.{col 70}.{col 84}.{col 92}...
{col 4}2{col 14}.{col 22}.{col 30}.{col 40}.{col 55}.{col 70}.{col 84}19.3{col 92}...
{col 4}5{col 14}.{col 22}.{col 30}.{col 40}.{col 55}.{col 70}.{col 84}.{col 92}...
{col 4}8{col 14}43.3{col 22}10.28{col 30}10{col 40}40.1{col 55}9.49{col 70}10{col 84}.{col 92}...

{pstd}{bf:Convention 2 -- single-letter treatment code as suffix}
(treatments sorted alphabetically, A = first treatment, B = second, C = third, ...):

{col 4}{it:studyid}{col 14}{it:yA}{col 22}{it:sdA}{col 30}{it:nA}{col 38}{it:yB}{col 46}{it:sdB}{col 54}{it:nB}{col 62}{it:yC}{col 70}{it:sdC}{col 78}{it:nC}{col 86}{it:...}
{col 4}1{col 14}15.77{col 22}18.85{col 30}13{col 38}.{col 46}.{col 54}.{col 62}11.67{col 70}16.82{col 78}19{col 86}...
{col 4}2{col 14}.{col 22}.{col 30}.{col 38}24.90{col 46}3.00{col 54}24{col 62}.{col 70}.{col 78}.{col 86}...
{col 4}5{col 14}43.3{col 22}10.28{col 30}10{col 38}19.3{col 46}2.40{col 54}20{col 62}.{col 70}.{col 78}.{col 86}...

{pstd}Command (same syntax for both conventions):

{phang2}{cmd:. cnma, study(studyid) y(y) sd(sd) n(n) }{break}
{cmd:  trtlist(FES FES_TMShigh NMES NMES_TMShigh NMES_TMSlow Rehab TMShigh TMSlow rPMS) ref(Rehab) measure(md)}{p_end}

{pstd}
{it:Note}: {cmd:cnma} checks automatically whether column {it:y}A exists; if so,
Convention 2 (letter codes) is assumed; otherwise Convention 1 (treatment-name
suffixes) is expected.  In both cases, missing (.) indicates a treatment was not
used in that study.  All treatment names must be listed in {cmd:trtlist()}.


{dlgtab:Format B -- Long arm-level (one row per study-arm)}

{pstd}
One row per arm within each study.  The treatment name and arm-level
summary statistics are each in their own variable.  Two sub-variants
are supported depending on outcome type:

{pstd}{bf:Format B (continuous)} -- requires {cmd:y()}, {cmd:sd()}, and {cmd:n()}:

{col 4}{it:studyid}{col 14}{it:arm}{col 20}{it:t}{col 32}{it:y}{col 42}{it:sd}{col 52}{it:n}
{col 4}1{col 14}1{col 20}rPMS{col 32}15.77{col 42}18.85{col 52}13
{col 4}1{col 14}2{col 20}Rehab{col 32}16.50{col 42}21.18{col 52}13
{col 4}2{col 14}1{col 20}NMES_rPMS{col 32}24.90{col 42}3.00{col 52}24
{col 4}2{col 14}2{col 20}NMES{col 32}19.30{col 42}2.40{col 52}20
{col 4}5{col 14}1{col 20}rPMS{col 32}11.67{col 42}16.82{col 52}19
{col 4}5{col 14}2{col 20}Rehab{col 32}7.33{col 42}7.86{col 52}25

{phang2}{cmd:. cnma, study(studyid) treat(t) y(y) sd(sd) n(n) ref(Rehab) measure(md)}{p_end}

{pstd}{bf:Format B (binary)} -- requires event counts in {cmd:d()} and {cmd:n()}; no {cmd:sd()}:

{col 4}{it:id}{col 12}{it:treat}{col 26}{it:n}{col 34}{it:d}
{col 4}1{col 12}Placebo{col 26}100{col 34}12
{col 4}1{col 12}DrugA{col 26}102{col 34}25
{col 4}2{col 12}Placebo{col 26}98{col 34}10
{col 4}2{col 12}DrugB{col 26}99{col 34}22

{phang2}{cmd:. cnma, study(id) treat(treat) d(d) n(n) ref(Placebo) measure(or)}{p_end}

{pstd}
{it:Note}: Supply event counts in {cmd:d()} and total N in {cmd:n()}; omit {cmd:sd()}.
{cmd:cnma} computes log-OR (or log-RR / RD) internally with a continuity correction
(+0.5 / +1) for zero-event cells.  You may also use {cmd:y()} in place of {cmd:d()}
if your event-count variable is already named in {cmd:y()}.



{dlgtab:Format C -- Precomputed contrasts (one row per study-arm)}

{pstd}
Pre-computed effect sizes and standard errors.  One row per non-reference
arm.  This format uses {cmd:treat()} to identify the treatment and {cmd:se()}
in place of {cmd:sd()} + {cmd:n()}.  The outcome variable {cmd:y()} contains
the effect size relative to the reference treatment.

{p 8 8 2}Required variables:{p_end}
{p 12 12 2}{it:study}   -- study identifier{p_end}
{p 12 12 2}{it:treat}   -- treatment name (non-reference arms only){p_end}
{p 12 12 2}{it:y}       -- pre-computed effect size vs. reference{p_end}
{p 12 12 2}{it:se}      -- standard error of the effect size{p_end}

{pstd}Example data layout:

{col 4}{it:id}{col 12}{it:treat}{col 28}{it:y}{col 40}{it:se}
{col 4}1{col 12}DrugA{col 28}2.3{col 40}0.45
{col 4}1{col 12}DrugB{col 28}2.6{col 40}0.52
{col 4}2{col 12}DrugA{col 28}2.5{col 40}0.48
{col 4}3{col 12}DrugA_DrugB{col 28}4.9{col 40}0.61

{pstd}Command:

{phang2}{cmd:. cnma, study(id) treat(treat) y(y) se(se) ref(Placebo)}{p_end}

{pstd}
{it:Note}: Reference-treatment rows are omitted -- only non-reference arms are
included (effect = 0 for the reference by definition).  {cmd:measure()} is
{bf:not required} for Format C: you decide the scale of your pre-computed
effect size (log-OR, SMD, HR, etc.).  If supplied, {cmd:measure()} is used
only for the display header and stored in {cmd:e(measure)}.


{title:Options}

{dlgtab:Data}

{phang}{opth study(varname)} identifies the study (required in all formats).

{phang}{opth ref:erence(string)} specifies the reference treatment name (required).
All effect sizes are computed relative to this treatment.

{phang}{opth y(string)} specifies the outcome variable or variable stub.
For binary outcomes this is the event-count variable (Formats B and C).

{phang}{opth d(varname)} specifies the event-count variable for binary outcomes
(Format B) -- a convenience alias for {cmd:y()}.  Use {cmd:d()} or {cmd:y()},
not both.

{phang}{opth treat(varname)} specifies the variable holding treatment names
(Formats B and C).

{phang}{opth trtlist(string)} specifies the space-separated list of all treatment
names (Format A only).  Columns must be named {it:stub}{it:TreatName}, e.g.
{cmd:y(y)} with {cmd:trtlist(FES NMES Rehab)} expects variables {it:yFES},
{it:yNMES}, {it:yRehab}.

{phang}{opth se(string)} specifies the variable holding pre-computed standard errors
(Format C only).  Mutually exclusive with {cmd:sd()} and {cmd:n()}.

{phang}{opth sd(string)} specifies the SD variable or stub (Formats A and B,
continuous outcomes only).  Not used with binary measures or Format C.

{phang}{opth n(string)} specifies the sample-size variable or stub (Formats A
and B).  Required for binary outcomes (with {cmd:measure(or)}, {cmd:measure(rr)},
etc.) and continuous outcomes.  Not used with Format C ({cmd:se()} data).

{dlgtab:Model}

{phang}{opth mea:sure(string)} specifies the effect measure.  Options are
{bf:md} (mean difference, default for arm-level data), {bf:smd} (standardised
mean difference, Hedges' g), {bf:or} (odds ratio, log scale), {bf:rr} (risk
ratio, log scale), {bf:rd} (risk difference), and {bf:hr} (hazard ratio, log
scale).  {bf:Optional when {cmd:se()} is supplied (Format C)} -- the user is
responsible for the scale of pre-computed effect sizes; {cmd:measure()} is
used only for the display header in that case.

{phang}{opth meth:od(string)} specifies the estimation method passed to
{cmd:mvmeta}: {bf:reml} (restricted maximum likelihood, default), {bf:ml}
(maximum likelihood), or {bf:fegls} (fixed-effects GLS).

{phang}{opt level(#)} sets the confidence level; default is {cmd:c(level)}.

{dlgtab:Output}

{phang}{opt noh:eader} suppresses the header block above the results table.

{phang}{opth savec:ontrasts(filename)} saves the augmented contrast dataset
(the wide dataset passed to {cmd:mvmeta}) to {it:filename}.dta.

{phang}{opt replace} allows overwriting an existing file when used with
{cmd:savecontrasts()}.


{title:Component detection}

{pstd}
Components are identified automatically by inspecting treatment names.  A
treatment name containing an underscore is interpreted as a combination of the
substrings split by the underscore.  For example:

{p2colset 9 30 30 2}{...}
{p2col:Treatment name}Interpretation{p_end}
{p2line}
{p2col:{it:DrugA}}Pure component: DrugA{p_end}
{p2col:{it:DrugB}}Pure component: DrugB{p_end}
{p2col:{it:DrugA_DrugB}}Combination of DrugA + DrugB{p_end}
{p2col:{it:DrugA_DrugB_DrugC}}Combination of DrugA + DrugB + DrugC{p_end}
{p2line}
{p2colreset}{...}

{pstd}
Additivity constraints are added for each combination treatment.  Components
that appear only in combination treatments (no single-component arm observed
in any study) generate a warning and their constraints are omitted.


{title:Estimation}

{pstd}
After converting the data to the augmented format (one row per study; outcome
variables _y_TRT and variance-covariance variables _S_TRT and _S_TRT1_TRT2),
{cmd:cnma} calls:

{phang2}{cmd:mvmeta _y _S, vars(...)}{break}
{cmd:bscovariance(exch 0) constraints(...) longparm suppress(uv mm)}{break}
{cmd:method(reml)}

{pstd}
The between-study heterogeneity parameter tau^2 (a single scalar under
exchangeable covariance) is the REML estimate of the between-study variance.


{title:Stored results}

{pstd}{cmd:cnma} stores the following in {cmd:e()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:e(n_studies)}}number of studies{p_end}
{synopt:{cmd:e(n_treat)}}number of treatments{p_end}
{synopt:{cmd:e(n_comp)}}number of components{p_end}
{synopt:{cmd:e(tau2)}}between-study variance (tau^2){p_end}
{synopt:{cmd:e(ll)}}log-likelihood (cNMA){p_end}
{synopt:{cmd:e(converged)}}convergence flag{p_end}
{synopt:{cmd:e(Q)}}Cochran Q statistic (heterogeneity){p_end}
{synopt:{cmd:e(Q_df)}}degrees of freedom for Q{p_end}
{synopt:{cmd:e(p_Q)}}p-value for Q{p_end}
{synopt:{cmd:e(Q_add)}}FE additivity test Q statistic{p_end}
{synopt:{cmd:e(df_add)}}degrees of freedom for FE additivity test{p_end}
{synopt:{cmd:e(p_add)}}p-value for FE additivity test{p_end}
{synopt:{cmd:e(ll_sNMA)}}log-likelihood (standard NMA){p_end}
{synopt:{cmd:e(tau2_sNMA)}}tau^2 from standard NMA{p_end}
{synopt:{cmd:e(ll_cNMA)}}log-likelihood (component NMA){p_end}
{synopt:{cmd:e(tau2_cNMA)}}tau^2 from component NMA{p_end}
{synopt:{cmd:e(LR_add)}}LR test statistic (additivity){p_end}
{synopt:{cmd:e(df_LR_add)}}degrees of freedom for LR test{p_end}
{synopt:{cmd:e(p_LR_add)}}p-value for LR test (additivity){p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}cnma{p_end}
{synopt:{cmd:e(method)}}frequentist (mvmeta){p_end}
{synopt:{cmd:e(model)}}additive{p_end}
{synopt:{cmd:e(inputmode)}}input format description{p_end}
{synopt:{cmd:e(measure)}}effect measure (md, smd, or, rr, rd, hr){p_end}
{synopt:{cmd:e(reference)}}reference treatment name{p_end}
{synopt:{cmd:e(components)}}detected component names{p_end}
{synopt:{cmd:e(combinations)}}detected combination treatment names{p_end}
{synopt:{cmd:e(studyvar)}}study variable name{p_end}
{synopt:{cmd:e(nonref_list)}}non-reference treatment names{p_end}
{synopt:{cmd:e(method_test)}}estimation method used{p_end}
{synopt:{cmd:e(contrasts_file)}}name of saved contrasts file (if savecontrasts() used){p_end}

{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}component effect-size estimates{p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix of component effects{p_end}
{synopt:{cmd:e(b_full)}}all treatment effect estimates (components + combinations){p_end}
{synopt:{cmd:e(V_full)}}variance-covariance for all treatments{p_end}


{title:Post-estimation}

{pstd}
All post-estimation commands below can be run in any order after {cmd:cnma}
without re-running {cmd:cnma}. Running {cmd:cnma_test} does not overwrite
the {cmd:cnma} results, so {cmd:cnma_map} and {cmd:cnma_rank} remain usable
immediately after {cmd:cnma_test}.{p_end}

{phang}{cmd:cnma_rank} [{it:options}] -- compute SUCRA for components; type
{cmd:help cnma_rank} for details.{p_end}

{phang}{cmd:cnma_test} [{it:options}] -- test the additivity assumption via
likelihood-ratio and fixed-effects tests; type {cmd:help cnma_test} for
details.{p_end}

{phang}{cmd:cnma_map} [{it:options}] -- draw a component network map showing
which components co-occur across studies; type {cmd:help cnma_map} for
details.{p_end}


{title:Examples}

{pstd}{bf:Example 1 -- Format A (wide treatment-named, one row per study)}

{pstd}
Columns named {it:y}TreatName, {it:sd}TreatName, {it:n}TreatName; all treatment names in {cmd:trtlist()}.

{phang2}{cmd:. cnma, study(studyid) y(y) sd(sd) n(n) }{break}
{cmd:  trtlist(FES FES_TMShigh NMES NMES_TMShigh NMES_TMSlow Rehab TMShigh TMSlow rPMS) ref(Rehab) measure(md)}{p_end}


{pstd}{bf:Example 2 -- Format B (long arm-level, one row per study-arm)}

{pstd}
Variables: {it:studyid}, {it:arm} (arm index), {it:t} (treatment name), {it:y} (outcome mean),
{it:sd} (SD), {it:n} (sample size).  Combination treatments use underscore as separator
(e.g. NMES_rPMS = NMES combined with rPMS).

{col 4}{it:studyid}{col 14}{it:arm}{col 20}{it:t}{col 32}{it:y}{col 42}{it:sd}{col 52}{it:n}
{col 4}1{col 14}1{col 20}rPMS{col 32}15.77{col 42}18.85{col 52}13
{col 4}1{col 14}2{col 20}Rehab{col 32}16.50{col 42}21.18{col 52}13
{col 4}2{col 14}1{col 20}NMES_rPMS{col 32}24.90{col 42}3.00{col 52}24
{col 4}2{col 14}2{col 20}NMES{col 32}19.30{col 42}2.40{col 52}20
{col 4}5{col 14}1{col 20}rPMS{col 32}11.67{col 42}16.82{col 52}19
{col 4}5{col 14}2{col 20}Rehab{col 32}7.33{col 42}7.86{col 52}25

{phang2}{cmd:. cnma, study(studyid) treat(t) y(y) sd(sd) n(n) ref(Rehab) measure(md)}{p_end}


{pstd}{bf:Example 2b -- Format B binary (one row per study-arm)}

{pstd}
Variables: {it:id} (study), {it:treat} (treatment name), {it:n} (sample size), {it:d} (events).
Use {cmd:d()} for the event-count variable and {cmd:n()} for sample size; omit {cmd:sd()}.

{col 4}{it:id}{col 12}{it:treat}{col 26}{it:n}{col 34}{it:d}
{col 4}1{col 12}Placebo{col 26}100{col 34}12
{col 4}1{col 12}DrugA{col 26}102{col 34}25
{col 4}2{col 12}Placebo{col 26}98{col 34}10
{col 4}2{col 12}DrugB{col 26}99{col 34}22
{col 4}3{col 12}Placebo{col 26}95{col 34}8
{col 4}3{col 12}DrugA_DrugB{col 26}100{col 34}30

{phang2}{cmd:. cnma, study(id) treat(treat) d(d) n(n) ref(Placebo) measure(or)}{p_end}


{pstd}{bf:Example 3 -- Format A (wide treatment-named, one row per study)}

{pstd}
Columns named {it:y}TreatName, {it:sd}TreatName, {it:n}TreatName.  Missing values (.) indicate
a treatment was not in that study.  Treatment names with underscores (e.g. FES_TMShigh)
are combination treatments and are allowed as column-name suffixes.

{phang2}{cmd:. cnma, study(studyid) y(y) sd(sd) n(n) }{break}
{cmd:  trtlist(FES FES_TMShigh NMES NMES_TMShigh Rehab TMShigh rPMS) ref(Rehab) measure(md)}{p_end}

{pstd}
Data layout (Convention 1 -- treatment name suffix); missing (.) = treatment not in study:

{col 4}{it:studyid}{col 14}{it:yFES}{col 22}{it:sdFES}{col 30}{it:nFES}{col 40}{it:yFES_TMShigh}{col 55}{it:sdFES_TMShigh}{col 70}{it:nFES_TMShigh}{col 84}{it:yNMES}{col 92}{it:...}
{col 4}1{col 14}.{col 22}.{col 30}.{col 40}.{col 55}.{col 70}.{col 84}.{col 92}...
{col 4}2{col 14}.{col 22}.{col 30}.{col 40}.{col 55}.{col 70}.{col 84}19.3{col 92}...
{col 4}5{col 14}.{col 22}.{col 30}.{col 40}.{col 55}.{col 70}.{col 84}.{col 92}...
{col 4}8{col 14}43.3{col 22}10.28{col 30}10{col 40}40.1{col 55}9.49{col 70}10{col 84}.{col 92}...


{pstd}{bf:Example 4 -- Format C (pre-computed contrasts, one row per arm)}

{phang2}{cmd:. cnma, study(id) treat(treat) y(y) se(se) ref(Placebo)}{p_end}


{pstd}{bf:Example 5 -- Save augmented contrast dataset and test additivity}

{phang2}{cmd:. cnma, study(studyid) treat(t) y(y) sd(sd) n(n) ref(Rehab) }{break}
{cmd:  measure(md) savecontrasts(mydata_contrasts) replace}{p_end}
{phang2}{cmd:. cnma_test}{p_end}
{phang2}{cmd:. cnma_rank}{p_end}

{pstd}
The saved file ({it:mydata_contrasts.dta}) is the wide augmented contrast dataset
that {cmd:cnma} passes internally to {cmd:mvmeta}.  It has one row per study and
contains a {it:_design} variable (letter-pair code for the treatments compared) plus
outcome variables {it:_y_A}, {it:_S_A_A}, {it:_y_B}, {it:_S_B_B}, ... named by
the letter code assigned alphabetically to each non-reference treatment:

{col 4}{it:studyid}{col 14}{it:_design}{col 26}{it:_y_A}{col 38}{it:_S_A_A}{col 52}{it:_y_B}{col 64}{it:_S_B_B}{col 78}{it:...}
{col 4}1{col 14}G J{col 26}.{col 38}.{col 52}.{col 64}.{col 78}...
{col 4}2{col 14}C F{col 26}.{col 38}.{col 52}-3.05{col 64}743802{col 78}...
{col 4}8{col 14}A B{col 26}1.60{col 38}9771334{col 52}-1.60{col 64}9771332{col 78}...


{pstd}{bf:Example 6 -- ML estimation (for exact likelihood-ratio test)}

{phang2}{cmd:. cnma, study(id) treat(treat) y(y) sd(sd) n(n) ref(Placebo) method(ml)}{p_end}
{phang2}{cmd:. cnma_test}{p_end}


{title:Remarks}

{pstd}{bf:Component naming convention}{p_end}
{pstd}
Component names must not contain underscores themselves.  Use camelCase or
abbreviations if a component name contains multiple words (e.g. {it:TMShigh}
rather than {it:TMS_high}).  An underscore in a treatment name is the delimiter
that tells {cmd:cnma} the treatment is a combination.

{pstd}{bf:Format A column naming}{p_end}
{pstd}
Format A requires one column per treatment for each of {cmd:y()}, {cmd:sd()}, and
{cmd:n()}, named {it:stub}{it:TreatName} using the exact spelling from {cmd:trtlist()}.
Combination treatment names (e.g. FES_TMShigh) are allowed as column-name suffixes --
Stata variable names may contain underscores.  Missing (.) means that treatment was
not included in that study.  Specify all treatments in {cmd:trtlist()}, in any order.

{pstd}{bf:Reference treatment}{p_end}
{pstd}
The reference treatment must appear in the data.  For combinations, the
reference can be a pure treatment ({it:Placebo}, {it:Rehab}) or a combination;
specifying a component name that only appears as part of combinations will
cause an error.

{pstd}{bf:Exchangeable between-study covariance}{p_end}
{pstd}
{cmd:mvmeta} is called with {cmd:bscovariance(exch 0)}, which assumes a single
common tau^2 across all outcomes.  For complex networks with many treatments
this is a regularising assumption that aids convergence.

{pstd}{bf:REML and the additivity LR test}{p_end}
{pstd}
{cmd:cnma} reports a likelihood-ratio test of additivity comparing the
log-likelihoods of the standard NMA (sNMA) and the component NMA (cNMA).
Under REML, this test is approximate because the two models have different
numbers of fixed-effect parameters (treatment effects are partitioned before
tau^2 is estimated), making the restricted log-likelihoods not strictly
comparable.  For an exact LR test use {cmd:method(ml)}.

{pstd}{bf:FE additivity test}{p_end}
{pstd}
A fixed-effects (FE) additivity test is also reported.  Under FE (no
between-study heterogeneity), the test is exact and based on a chi-squared
distribution with degrees of freedom equal to the number of combinations minus
the number of components plus one.


{title:References}

{phang}
Rucker G, Petropoulou M, Schwarzer G (2020).  Component network meta-analysis:
methods and illustration in three systematic reviews.  {it:Res Synth Methods},
11(3):360-374.  doi:10.1002/jrsm.1397

{phang}
White IR (2011).  Multivariate random-effects meta-regression: Updates to
mvmeta.  {it:Stata J}, 11(2):255-270.

{phang}
White IR, Barrett JK, Jackson D, Higgins JP (2012).  Consistency and
inconsistency in network meta-analysis: model estimation using multivariate
meta-regression.  {it:Res Synth Methods}, 3(2):111-125.


{title:Author}

{pstd}
Ammarin Thakkinstian, Faculty of Medicine, Ramathibodi Hospital, Mahidol
University, Bangkok, Thailand.  ammarin.tha@mahidol.ac.th


{title:Also see}

{psee}
Online: {helpb cnma_rank}, {helpb cnma_test}, {helpb mvmeta}, {helpb network}
{p_end}
