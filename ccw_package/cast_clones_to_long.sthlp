{smcl}
{* *! cast_clones_to_long v1.1  27sep2026  A.Thakkinstian}{...}
{vieweralsosee "create_clones" "help create_clones"}{...}
{vieweralsosee "generate_ccw" "help generate_ccw"}{...}
{vieweralsosee "bootstrap_ccw" "help bootstrap_ccw"}{...}
{viewerjumpto "Syntax" "cast_clones_to_long##syntax"}{...}
{viewerjumpto "Description" "cast_clones_to_long##description"}{...}
{viewerjumpto "Method" "cast_clones_to_long##method"}{...}
{viewerjumpto "Stored results" "cast_clones_to_long##stored"}{...}
{viewerjumpto "Examples" "cast_clones_to_long##examples"}{...}
{viewerjumpto "References" "cast_clones_to_long##references"}{...}
{viewerjumpto "Author" "cast_clones_to_long##author"}{...}

{title:Title}

{phang}
{bf:cast_clones_to_long} {hline 2} Convert clone dataset to counting-process (long) format for CCW analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:cast_clones_to_long} [{cmd:,} {opt verbose}]

{synoptset 12 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt verbose}}print the number of unique cut-points collected{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{cmd:cast_clones_to_long} requires no variable options; it reads all variable
names and the Clinical Eligibility Duration (CED) (or grace period) value from the dataset characteristics stored by
{helpb create_clones}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:cast_clones_to_long} is Step 5 of the CCW pipeline.
It converts the wide clone dataset (one row per clone-patient, created by
{helpb create_clones}) into {it:counting-process long format}, with one row
per time interval per clone-patient.

{pstd}
This format is required for {helpb stcox} with {cmd:time0()} entry, and
corresponds to {cmd:cast_clones_to_long()} in the R package
{it:survivalCCW} (Genentech).

{pstd}
{cmd:cast_clones_to_long} must be run immediately after {helpb create_clones},
before any {cmd:stset} or data restructuring.
Run {helpb generate_ccw} next to compute IPCW weights.


{marker method}{...}
{title:Method — how the split is performed}

{pstd}
The split points (cut-points) are the union of:

{p2colset 8 18 20 2}
{p2col:1.} All unique values of {it:timetoevent} across both clones.{p_end}
{p2col:2.} All unique values of {it:timetoexposure} (non-missing) across both clones.{p_end}
{p2col:3.} The CED boundary — added only when a finite CED was specified ({cmd:ced(#)}).{p_end}
{p2col:4.} Zero — prepended as the origin so the first interval starts at 0.{p_end}
{p2colreset}

{pstd}
The unique sorted cut-points define adjacent intervals
[t_start, t_stop).
A Cartesian join ({cmd:cross using}) expands each clone-patient to one row per interval,
then the dataset is trimmed to each patient's actual follow-up window.

{pstd}
{it:Note:} Unlike {cmd:stsplit}, this approach requires no {cmd:stset} call and
handles time-varying exposure times correctly.

{pstd}
Outcome and artificial-censor flags are set to 1 only on the {it:last} row for
each clone-patient; all earlier rows carry 0.


{marker stored}{...}
{title:Variables created}

{p2colset 8 20 22 2}
{p2col:{cmd:stid}}   unique numeric ID per clone-patient pair (for {cmd:stset id()}){p_end}
{p2col:{cmd:fu_end}} end of follow-up for each clone (corrected formula){p_end}
{p2col:{cmd:t_start}}interval start time (entry time for counting-process){p_end}
{p2col:{cmd:t_stop}} interval stop  time (exit  time for counting-process){p_end}
{p2colreset}

{pstd}
The existing variables {cmd:outcome} and {cmd:censor} are updated:
each takes the value 1 only on the final row of its clone-patient.

{pstd}
{bf:fu_end formula:}

{p2colset 8 20 22 2}
{p2col:{cmd:censor == 0}} {cmd:fu_end = fup_outcome} (follow to actual event/censoring){p_end}
{p2col:{cmd:censor == 1}} {cmd:fu_end = fup_censor}  (stop at artificial censoring time){p_end}
{p2colreset}

{pstd}
Using {cmd:min(fup_outcome, fup_censor)} would incorrectly truncate
clone-0 patients who remain unexposed and survive beyond CED.


{marker examples}{...}
{title:Examples}

{pstd}Full CCW pipeline (Steps 1–6):{p_end}

{phang2}{cmd:. use dummy_table.dta, clear}{p_end}
{phang2}{cmd:. create_clones, id(id) event(event) timetoevent(timetoevent) ///}{p_end}
{phang2}{cmd:      exposure(exposure) timetoexposure(timetoexposure) ced(100)}{p_end}
{phang2}{cmd:. cast_clones_to_long}{p_end}
{phang2}{cmd:. generate_ccw, predvars(cov1 cov2)}{p_end}

{pstd}With verbose output (shows cut-point count):{p_end}
{phang2}{cmd:. cast_clones_to_long, verbose}{p_end}

{pstd}Verify long format for specific patients:{p_end}
{phang2}{cmd:. list id clone t_start t_stop outcome censor if id == "pat1040", sepby(stid)}{p_end}

{pstd}After {cmd:cast_clones_to_long}, the data summary should show:{p_end}
{phang2}{cmd:. di "Rows in long format: " _N}{p_end}
{phang2}{cmd:. count if outcome == 1}{p_end}


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
{helpb create_clones}, {helpb generate_ccw}, {helpb bootstrap_ccw}
