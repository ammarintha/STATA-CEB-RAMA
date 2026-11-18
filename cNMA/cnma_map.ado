program define cnma_map
    syntax [, SAVEgraph(string) name(string asis) TItle(string) ///
              noLAbel LAYout(string) ]
    if !inlist("`e(cmd)'", "cnma", "cnma_dicho") error 301
    if "`layout'" == "" local layout "pentagon"
    if !inlist("`layout'", "pentagon", "hexagon") {
        di as err "layout() must be 'pentagon' or 'hexagon'"
        exit 198
    }

    local comps    `"`e(components)'"'
    local combos   `"`e(combinations)'"'
    local ref      `"`e(reference)'"'
    local nc : word count `comps'

    if `nc' < 2 {
        di as err "Need at least 2 components for a network map."
        exit 498
    }

    // Assign angular positions.
    // Pentagon: ref at center (0,0); components on unit circle clockwise from top.
    //   Formula 90 + (ci-1)*360/nc goes counter-clockwise in math space,
    //   which reads clockwise visually (ci=1 at top, then right, etc.).
    // Hexagon: ref at top (90 deg); components continue in same clockwise order.
    //   ci=1 is first clockwise after ref (vpos=1),
    //   ci=2..nc wrap: vpos = nc-ci+2  (reverses to match pentagon's visual order).
    if "`layout'" == "pentagon" {
        local px_ref = 0
        local py_ref = 0
        forvalues ci = 1/`nc' {
            local angle = 90 + (`ci' - 1) * 360 / `nc'
            local px_`ci' = cos(`angle' * _pi / 180)
            local py_`ci' = sin(`angle' * _pi / 180)
        }
    }
    else {
        // hexagon: nc+1 total nodes; ref at top; same clockwise order as pentagon
        local n_total = `nc' + 1
        local px_ref = cos(90 * _pi / 180)
        local py_ref = sin(90 * _pi / 180)
        forvalues ci = 1/`nc' {
            if `ci' == 1 local vpos = 1
            else         local vpos = `nc' - `ci' + 2
            local angle = 90 - `vpos' * 360 / `n_total'
            local px_`ci' = cos(`angle' * _pi / 180)
            local py_`ci' = sin(`angle' * _pi / 180)
        }
    }

    // Count component node sizes and edge weights using contrasts file
    local cf `"`e(contrasts_file)'"'
    if `"`cf'"' == "" {
        di as err "Contrasts file not found in e(). Re-run cnma first."
        exit 498
    }
    preserve
    qui use `"`cf'"', clear
    local n_studies = _N

    // Phase 1: create all _has_* indicators first
    forvalues ci = 1/`nc' {
        local comp_ci : word `ci' of `comps'
        qui gen byte _has_`ci' = 0
        qui ds _y_*
        foreach yv of varlist `r(varlist)' {
            local trt = substr("`yv'", 4, .)
            local comp_ci_sn = strtoname("`comp_ci'", 0)
            if strpos("_`trt'_", "_`comp_ci_sn'_") > 0 {
                qui replace _has_`ci' = 1 if !missing(`yv')
            }
        }
        qui su _has_`ci', meanonly
        local node_`ci' = r(sum)
    }

    // Phase 2: component-component edges (all _has_* now exist)
    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            qui gen byte _edge_`ci'_`cj' = _has_`ci' & _has_`cj'
            qui su _edge_`ci'_`cj', meanonly
            local edge_`ci'_`cj' = r(sum)
        }
    }

    // Phase 3: ref-component edges
    // All contrasts are vs ref, so every study with component ci co-occurs with ref
    forvalues ci = 1/`nc' {
        local edge_ref_`ci' = `node_`ci''
    }
    local node_ref = `n_studies'
    restore

    // Find max edge weight for scaling (including ref edges)
    local max_edge = 1
    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            if `edge_`ci'_`cj'' > `max_edge' local max_edge = `edge_`ci'_`cj''
        }
        if `edge_ref_`ci'' > `max_edge' local max_edge = `edge_ref_`ci''
    }

    preserve
    clear

    // Count edge rows: comp-comp + ref-comp
    local n_edges = 0
    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            if `edge_`ci'_`cj'' == 0 continue
            local ++n_edges
        }
        if `edge_ref_`ci'' > 0 local ++n_edges
    }
    if `n_edges' == 0 local n_edges = 1

    // Total obs: edge rows + nc component nodes + 1 ref node
    qui set obs `= `n_edges' + `nc' + 1'
    qui gen double ey1    = .
    qui gen double ex1    = .
    qui gen double ey2    = .
    qui gen double ex2    = .
    qui gen double lw     = .    // line width weight
    qui gen double emx    = .    // edge midpoint x  (for study count label)
    qui gen double emy    = .    // edge midpoint y
    qui gen int    ecount = .    // study count on this edge
    qui gen double nx     = .    // node x
    qui gen double ny     = .    // node y
    qui gen double ns     = .    // node size
    qui gen str40  nlabel = ""
    qui gen int    isnode = 0
    qui gen int    isref_node = 0

    // Fill edge rows: comp-comp first, then ref-comp
    local row = 0
    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            if `edge_`ci'_`cj'' == 0 continue
            local ++row
            qui replace ey1    = `py_`ci''                       in `row'
            qui replace ex1    = `px_`ci''                       in `row'
            qui replace ey2    = `py_`cj''                       in `row'
            qui replace ex2    = `px_`cj''                       in `row'
            qui replace lw     = max(0.3, 3 * `edge_`ci'_`cj'' / `max_edge') in `row'
            qui replace emx    = (`px_`ci'' + `px_`cj'') / 2    in `row'
            qui replace emy    = (`py_`ci'' + `py_`cj'') / 2    in `row'
            qui replace ecount = `edge_`ci'_`cj''               in `row'
        }
    }
    // Ref-component edges
    forvalues ci = 1/`nc' {
        if `edge_ref_`ci'' == 0 continue
        local ++row
        qui replace ey1    = `py_ref'                         in `row'
        qui replace ex1    = `px_ref'                         in `row'
        qui replace ey2    = `py_`ci''                        in `row'
        qui replace ex2    = `px_`ci''                        in `row'
        qui replace lw     = max(0.3, 3 * `edge_ref_`ci'' / `max_edge') in `row'
        qui replace emx    = (`px_ref' + `px_`ci'') / 2      in `row'
        qui replace emy    = (`py_ref' + `py_`ci'') / 2      in `row'
        qui replace ecount = `edge_ref_`ci''                  in `row'
    }

    // String version of edge count for labeling
    qui gen str10 elabel = string(ecount) if ecount != .

    // Node rows start after edge rows
    local ref_row = `n_edges' + 1
    qui replace nx = `px_ref'  in `ref_row'
    qui replace ny = `py_ref'  in `ref_row'
    qui replace ns = max(4, 8 * `node_ref' / `n_studies') in `ref_row'
    qui replace nlabel = "`ref' (ref)" in `ref_row'
    qui replace isnode = 1     in `ref_row'
    qui replace isref_node = 1 in `ref_row'

    // Component nodes
    forvalues ci = 1/`nc' {
        local nrow = `n_edges' + 1 + `ci'
        local comp_ci : word `ci' of `comps'
        qui replace nx     = `px_`ci'' in `nrow'
        qui replace ny     = `py_`ci'' in `nrow'
        qui replace ns     = max(4, 8 * `node_`ci'' / `n_studies') in `nrow'
        qui replace nlabel = "`comp_ci'" in `nrow'
        qui replace isnode = 1          in `nrow'
    }

    if "`title'" == "" local title "Component Network Map (`layout')"
    local grname ""
    if `"`name'"' != "" local grname `"name(`name')"'

    // Label options
    local label_opt ""
    if "`label'" != "nolabel" {
        local label_opt `"mlabel(nlabel) mlabpos(12) mlabsize(small) mlabcolor(black)"'
    }

    // Build spike commands for twoway
    // Comp-comp edges in navy%60, ref-comp edges in cranberry%60
    local spike_cmds ""
    local row2 = 0

    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            if `edge_`ci'_`cj'' == 0 continue
            local ++row2
            local lw_val = max(0.3, 3 * `edge_`ci'_`cj'' / `max_edge')
            local spike_cmds `"`spike_cmds' (pcspike ey1 ex1 ey2 ex2 if _n==`row2', lcolor(navy%60) lwidth(`lw_val'))"'
        }
    }
    // Ref-component spikes
    forvalues ci = 1/`nc' {
        if `edge_ref_`ci'' == 0 continue
        local ++row2
        local lw_val = max(0.3, 3 * `edge_ref_`ci'' / `max_edge')
        local spike_cmds `"`spike_cmds' (pcspike ey1 ex1 ey2 ex2 if _n==`row2', lcolor(cranberry%60) lwidth(`lw_val'))"'
    }

    twoway ///
        `spike_cmds' ///
        (scatter emy emx if ecount!=., msymbol(none) ///
            mlabel(elabel) mlabsize(vsmall) mlabcolor(gs4) mlabpos(0)) ///
        (scatter ny nx if isref_node==1, mcolor(cranberry) msymbol(O) msize(vlarge) ///
            `label_opt') ///
        (scatter ny nx if isnode==1 & isref_node==0, mcolor(navy) msymbol(O) msize(large) ///
            `label_opt') ///
        , xlabel(-1.5 1.5, nolabels noticks) ylabel(-1.5 1.5, nolabels noticks) ///
          xtitle("") ytitle("") ///
          title("`title'", size(medium)) ///
          subtitle("Edge width prop. study co-occurrence  (cranberry=ref edges, numbers=studies)", size(vsmall)) ///
          legend(off) aspect(1) scheme(s1color) `grname'

    if `"`savegraph'"' != "" graph save `"`savegraph'"', replace

    restore
end
