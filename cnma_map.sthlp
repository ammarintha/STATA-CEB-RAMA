{smcl}
{* *! version 1.1  14nov2026}{...}
{vieweralsosee "cnma" "help cnma"}{...}
{vieweralsosee "cnma_test" "help cnma_test"}{...}
{vieweralsosee "cnma_rank" "help cnma_rank"}{...}
{title:Title}

{phang}{bf:cnma_map} {hline 2} Component network map after {cmd:cnma}


{title:Syntax}

{p 8 17 2}
{cmd:cnma_map}
[{cmd:,}
{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt ti:tle(string)}}graph title; default is {it:Component Network Map}{p_end}
{synopt:{opt sa:vegraph(filename)}}save graph to {it:filename}.gph{p_end}
{synopt:{opt name(name[, replace])}}Stata graph name; passed to {cmd:twoway}{p_end}
{synopt:{opt noLA:bel}}suppress node labels{p_end}
{synopt:{opt sh:ape(symbol)}}node marker shape: {bf:O} (circle, default), {bf:pentagon},
  {bf:hexagon}, {bf:diamond}, {bf:triangle}, {bf:square}{p_end}
{synoptline}
{p2colreset}{...}


{title:Description}

{pstd}
{cmd:cnma_map} draws a component network map after {cmd:cnma}.
Components detected by {cmd:cnma} are shown as nodes arranged on a circle
(triangle for 3 components, square for 4, pentagon for 5, hexagon for 6, etc.).
The reference treatment appears as a central node.

{pstd}
An edge connects two component nodes when at least one combination treatment
contains both components.  Edge width is proportional to the number of
combination treatments linking that pair.  Node size is proportional to the
number of combination treatments in which each component appears.

{pstd}
{cmd:cnma_map} works with all data formats (Format A wide, Format B long,
Format C pre-computed contrasts) and may be called after {cmd:cnma_test} or
{cmd:cnma_rank} without re-running {cmd:cnma}.
It reads only from {cmd:e()} -- the original dataset does not need to be in memory.


{title:Options}

{phang}
{opt title(string)} sets the main graph title.
Default is {bf:Component Network Map}.

{phang}
{opt savegraph(filename)} saves the graph to {it:filename}{bf:.gph}.

{phang}
{opt name(name [, replace])} passes a name to Stata's {cmd:twoway}
for use with {cmd:graph display}, {cmd:graph export}, etc.

{phang}
{opt nolabel} suppresses node labels.
Useful when labels overlap in dense networks.

{phang}
{opt shape(symbol)} sets the marker symbol for all nodes.
Accepted values: {bf:O} (filled circle, default), {bf:pentagon},
{bf:hexagon}, {bf:diamond}, {bf:triangle}, {bf:square}.
Standard Stata marker symbols (e.g. {bf:D}, {bf:T}, {bf:S}) are also accepted.


{title:Remarks}

{pstd}
{cmd:cnma_map} requires that {cmd:cnma} has been run in the current session.
It reads {cmd:e(components)}, {cmd:e(combinations)}, and {cmd:e(reference)}.
No data variables are needed.

{pstd}
Nodes are arranged automatically in a regular polygon with as many sides as
there are components (3 components = triangle layout, 5 = pentagon, 6 = hexagon, etc.).

{pstd}
Edge width is scaled so the thickest edge corresponds to the pair of
components with the most linking combination treatments.
Pairs that never co-occur in any combination produce no edge.

{pstd}
The reference node (cranberry) is placed at the centre.
Component nodes (navy) are placed on the polygon perimeter.


{title:Examples}

{pstd}Basic use:{p_end}
{phang2}{cmd:. cnma, study(studyid) treat(treat) y(y) sd(sd) n(n) ref(Rehab) measure(md)}{p_end}
{phang2}{cmd:. cnma_map}{p_end}

{pstd}Pentagon node symbols, save graph:{p_end}
{phang2}{cmd:. cnma_map, shape(pentagon) savegraph(mymap) title("Stroke rehabilitation")}{p_end}

{pstd}Call after {cmd:cnma_test} -- no need to re-run {cmd:cnma}:{p_end}
{phang2}{cmd:. cnma_test}{p_end}
{phang2}{cmd:. cnma_map}{p_end}

{pstd}Binary outcome:{p_end}
{phang2}{cmd:. cnma, study(id) treat(treat) d(d) n(n) ref(Placebo) measure(or)}{p_end}
{phang2}{cmd:. cnma_map, shape(hexagon)}{p_end}


{title:Stored results}

{pstd}
{cmd:cnma_map} stores nothing in {cmd:e()} or {cmd:r()}.


{title:Author}

{pstd}
Ammarin Thakkinstian, Faculty of Medicine, Ramathibodi Hospital,
Mahidol University, Bangkok, Thailand.


{title:Also see}

{psee}
{helpb cnma}, {helpb cnma_test}, {helpb cnma_rank}
{p_end}
