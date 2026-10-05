{smcl}
{* *! create_clones v1.1  27sep2026  A.Thakkinstian}{...}
{vieweralsosee "cast_clones_to_long" "help cast_clones_to_long"}{...}
{vieweralsosee "generate_ccw" "help generate_ccw"}{...}
{vieweralsosee "bootstrap_ccw" "help bootstrap_ccw"}{...}
{viewerjumpto "Syntax" "create_clones##syntax"}{...}
{viewerjumpto "Description" "create_clones##description"}{...}
{viewerjumpto "Options" "create_clones##options"}{...}
{viewerjumpto "Artificial censoring rules" "create_clones##rules"}{...}
{viewerjumpto "Stored results" "create_clones##stored"}{...}
{viewerjumpto "Examples" "create_clones##examples"}{...}
{viewerjumpto "References" "create_clones##references"}{...}
{viewerjumpto "Author" "create_clones##author"}{...}

{title:Title}

{phang}
{bf:create_clones} {hline 2} Clone creation and artificial censoring for Clone-Censor-Weight (CCW) analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:create_clones}{cmd:,}
{opt id(varname)}
{opt event(varname)}
{opt timetoevent(varname)}
{opt exposure(varname)}
{opt timetoexposure(varname)}
{opt ced(#|.)}

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}unique patient identifier{p_end}
{synopt:{opt event(varname)}}binary outcome indicator (1=event, 0=censored){p_end}
{synopt:{opt timetoevent(varname)}}time to event or administrative censoring{p_end}
{synopt:{opt exposure(varname)}}binary exposure status (1=exposed, 0=unexposed){p_end}
{synopt:{opt timetoexposure(varname)}}time from baseline to exposure initiation; missing (.) if never exposed{p_end}
{synopt:{opt ced(#|.)}}clinical eligibility duration (grace period) in the same time units as {it:timetoevent}; use {cmd:.} for no grace-period limit{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:create_clones} is the first step in Clone-Censor-Weight (CCW) analysis.
It duplicates each patient into two {it:clones}, one assigned to each treatment strategy:

{p2colset 8 28 30 2}
{p2col:{bf:clone = 1}}Assigned-{it:exposed} strategy: the patient initiates treatment within the grace period (CED).{p_end}
{p2col:{bf:clone = 0}}Assigned-{it:unexposed} strategy: the patient never initiates treatment.{p_end}
{p2colreset}

{pstd}
For each clone, artificial censoring is applied whenever the patient's observed behaviour
deviates from the strategy to which the clone is assigned.
The deviation time determines the follow-up end for that clone.

{pstd}
The program stores variable names and the CED value as dataset characteristics
({bf:_dta[ccw_*]}) so that {helpb cast_clones_to_long} and {helpb generate_ccw}
can retrieve them automatically without re-specifying options.

{pstd}
After {cmd:create_clones}, run {helpb cast_clones_to_long} to convert the wide
clone dataset to counting-process (long) format.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the variable uniquely identifying each patient.
May be string or numeric.

{phang}
{opt event(varname)} is a binary (0/1) outcome indicator.
1 = the event occurred; 0 = administratively censored.

{phang}
{opt timetoevent(varname)} is the time from baseline to the event or
administrative censoring.  Must be positive and non-missing for all patients.

{phang}
{opt exposure(varname)} is a binary (0/1) treatment variable.
1 = patient received the treatment at some point; 0 = never treated.

{phang}
{opt timetoexposure(varname)} is the time from baseline to treatment initiation.
Set to missing (.) for patients who never initiated treatment.

{phang}
{opt ced(#)} sets the Clinical Eligibility Duration (grace period): the maximum
time from baseline within which the assigned-exposed clone must have initiated
treatment to be considered adherent.
Use {opt ced(.)} to impose no time limit (internally treated as max follow-up + 1).


{marker rules}{...}
{title:Artificial censoring rules}

{pstd}{bf:Clone 1 — Assigned-exposed strategy}

{p2colset 8 18 20 2}
{p2col:{it:Condition}}                              {it:Action}{p_end}
{p2col:Exposed within CED}                         No artificial censoring; keep original outcome.{p_end}
{p2col:Exposed after CED, or never exposed}        Artificially censor at CED.{p_end}
{p2col:Unexposed; event/censor within CED}         No artificial censoring.{p_end}
{p2col:Unexposed; survives beyond CED}             Artificially censor at CED.{p_end}
{p2colreset}

{pstd}{bf:Clone 0 — Assigned-unexposed strategy}

{p2colset 8 18 20 2}
{p2col:{it:Condition}}                              {it:Action}{p_end}
{p2col:Never exposed (within or beyond CED)}       No artificial censoring; keep original outcome.{p_end}
{p2col:Exposed within CED}                         Artificially censor at exposure time.{p_end}
{p2col:Exposed at or beyond CED}                   Treated as never exposed; keep original outcome.{p_end}
{p2colreset}


{marker stored}{...}
{title:Stored results}

{pstd}{cmd:create_clones} stores the following dataset characteristics ({cmd:char _dta[]}):

{p2colset 8 30 32 2}
{p2col:{cmd:_dta[ccw_id]}}         name of the id variable{p_end}
{p2col:{cmd:_dta[ccw_event]}}      name of the event variable{p_end}
{p2col:{cmd:_dta[ccw_timetoevent]}}name of the timetoevent variable{p_end}
{p2col:{cmd:_dta[ccw_exposure]}}   name of the exposure variable{p_end}
{p2col:{cmd:_dta[ccw_timetoexposure]}}name of the timetoexposure variable{p_end}
{p2col:{cmd:_dta[ccw_ced]}}        numeric CED value used internally{p_end}
{p2col:{cmd:_dta[ccw_ced_input]}}  CED as supplied by the user{p_end}
{p2col:{cmd:_dta[ccw_ced_type]}}   {cmd:fixed} (numeric CED) or {cmd:none} (unlimited){p_end}
{p2colreset}

{pstd}New variables created:

{p2colset 8 22 24 2}
{p2col:{cmd:clone}}       0 = assigned-unexposed, 1 = assigned-exposed{p_end}
{p2col:{cmd:ced}}         CED value (constant){p_end}
{p2col:{cmd:outcome}}     outcome indicator for this clone{p_end}
{p2col:{cmd:fup_outcome}} follow-up time to outcome for this clone{p_end}
{p2col:{cmd:censor}}      artificial-censor indicator (1 = censored){p_end}
{p2col:{cmd:fup_censor}}  follow-up time to artificial censoring{p_end}
{p2col:{cmd:exposure2}}   actual exposure status for this clone{p_end}
{p2colreset}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. use dummy_table.dta, clear}{p_end}

{pstd}Basic use with a 100-day grace period:{p_end}
{phang2}{cmd:. create_clones, id(id) event(event) timetoevent(timetoevent) ///}{p_end}
{phang2}{cmd:      exposure(exposure) timetoexposure(timetoexposure) ced(100)}{p_end}

{pstd}No grace-period limit:{p_end}
{phang2}{cmd:. create_clones, id(id) event(event) timetoevent(timetoevent) ///}{p_end}
{phang2}{cmd:      exposure(exposure) timetoexposure(timetoexposure) ced(.)}{p_end}

{pstd}Check the artificial-censoring cross-tabulation:{p_end}
{phang2}{cmd:. tab clone censor}{p_end}

{pstd}Then continue the pipeline:{p_end}
{phang2}{cmd:. cast_clones_to_long}{p_end}
{phang2}{cmd:. generate_ccw, predvars(cov1 cov2)}{p_end}


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
{helpb cast_clones_to_long}, {helpb generate_ccw}, {helpb bootstrap_ccw}
