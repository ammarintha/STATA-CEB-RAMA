{smcl}
{* cnma_rank.sthlp  15nov2026  Ammarin Thakkinstian}{...}
{hline}
{title:Help for {cmd:cnma_rank}}
{hline}

{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{bf:cnma_rank} {hline 2}}Post-estimation treatment rankings (P-score & SUCRA) after {cmd:cnma}{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 17 2}
{cmd:cnma_rank}
[{cmd:,}
{opt bet:ter(string)}
{opt reps(#)}
{opt seed(#)}
{opt noSUCRA}
{opt noGraph}
{opt sav:egraph(filename)}
{opt name(name, ...)}]


{synoptset 24 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt bet:ter(string)}}Direction of benefit: {cmd:large} (default) or {cmd:small}{p_end}
{synopt:{opt reps(#)}}Monte Carlo replications for SUCRA; default {cmd:reps(200)}{p_end}
{synopt:{opt seed(#)}}Random-number seed for reproducible SUCRA simulation; any non-negative integer fixes the seed before simulation; negative values (default {cmd:-1}) leave the random state unchanged{p_end}
{synopt:{opt noSUCRA}}Suppress SUCRA computation (display P-score only){p_end}
{synopt:{opt noGraph}}Suppress the SUCRA bar chart{p_end}
{synopt:{opt sav:egraph(filename)}}Save bar chart to {it:filename}{cmd:.gph}{p_end}
{synopt:{opt name(name, ...)}}Graph name passed to Stata{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:cnma_rank} is a post-estimation command for {helpb cnma}.
It ranks every treatment (reference, individual components, and observed
combinations) using two complementary measures:

{phang2}{bf:P-score} — closed-form frequentist analogue of SUCRA.
For each treatment {it:t}:{p_end}

{p 12 12 2}
P-score(t) = {1 / (T-1)} x sum_{s != t} Phi( dir x (mu_t - mu_s) / SE(mu_t - mu_s) )

{phang2}{bf:SUCRA} (Surface Under the Cumulative Ranking curve) — estimated
by Monte Carlo simulation with {opt reps(#)} draws from the multivariate
normal distribution of treatment effects.{p_end}

{pstd}
{it:dir} = +1 for {opt better(large)} and -1 for {opt better(small)}.
Treatment effects are additive: the effect of a combination equals the sum
of its component effects from {cmd:e(b)}.  The reference has effect 0
and variance 0.


{title:Output}

{pstd}
A table with one row per treatment (reference, components, combinations):

{phang2}* {bf:P-score} — closed-form probability of superiority{p_end}
{phang2}* {bf:SUCRA}   — simulation-based cumulative ranking probability{p_end}
{phang2}* {bf:Mean rank} — expected rank across replications (1 = best){p_end}

{pstd}
A SUCRA bar chart is drawn by default (suppress with {opt nograph}).


{title:Examples}

{pstd}{ul:Default (larger is better, 200 SUCRA reps)}

{phang2}{stata cnma_rank}{p_end}

{pstd}{ul:Lower is better, 1000 SUCRA reps}

{phang2}{stata cnma_rank, better(small) reps(1000)}{p_end}

{pstd}{ul:Reproducible results (fixed seed, 500 reps)}

{phang2}{stata cnma_rank, reps(500) seed(12345)}{p_end}

{pstd}{ul:P-score only, no graph}

{phang2}{stata cnma_rank, nosucra nograph}{p_end}

{pstd}{ul:Save SUCRA chart}

{phang2}{stata cnma_rank, better(large) savegraph("cnma_rank_sucra")}{p_end}


{title:Technical notes}

{pstd}
{bf:SUCRA simulation.}  At each replication, treatment effects are drawn
from MVN(mu, V).  SUCRA = (1/(T-1)) x sum_{k=1}^{T-1} Pr(rank <= k).

{pstd}
{bf:Default reps.}  reps(200) is adequate for exploratory work.
For publication use reps(500) or higher.

{pstd}
{bf:Reproducibility.}  Specify {opt seed(#)} with any non-negative integer
to set Stata's random-number seed before the SUCRA simulation, ensuring
identical results across runs and across machines.  Omitting {opt seed()}
(or specifying a negative value) leaves the random state unchanged, which
is the default behaviour and preserves backward compatibility.

{pstd}
{bf:Variance propagation.}  Var(mu_t) = c_t' V c_t where V = e(V).
Cross-treatment covariance: Cov(mu_t, mu_s) = c_t' V c_s.


{title:References}

{phang}
Rücker G, Petropoulou M, Schwarzer G (2020).
Network meta-analysis of multicomponent interventions.
{it:Biometrical Journal} 62(3): 808-821.
{p_end}

{phang}
Salanti G, Ades AE, Ioannidis JPA (2011).
Graphical methods and numerical summaries for presenting results from
multiple-treatment meta-analysis.
{it:Journal of Clinical Epidemiology} 64(2): 163-171.
{p_end}


{title:Also see}

{psee}
Online: {helpb cnma}, {helpb cnma_map}, {helpb cnma_test}, {helpb mvmeta}
{p_end}
