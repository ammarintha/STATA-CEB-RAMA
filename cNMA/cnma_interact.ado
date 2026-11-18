*! cnma_interact v1.1 — post-estimation command for cnma
program define cnma_interact, eclass
    syntax [anything] [, LEVel(cilevel) noLRtest ]
    if !inlist("`e(cmd)'", "cnma", "cnma_dicho") error 301

    // Save cnma estimates so we can restore them after mvmeta overwrites e()
    tempname _cnma_ests
    estimates store `_cnma_ests'

    // Capture e(N) now — needed for ereturn post at the end
    local e_N = e(N)
    if missing(`e_N') | `e_N' <= 0 local e_N = 1

    local all_combos `"`e(combinations)'"'
    if `"`all_combos'"' == "" {
        di as txt "No observed combinations -- interaction test not applicable."
        capture estimates drop `_cnma_ests'
        exit 0
    }

    // Parse which combos the user wants to free
    local free_combos ""
    if `"`anything'"' == "" | lower(`"`anything'"') == "_all" {
        local free_combos "`all_combos'"
    }
    else {
        foreach req of local anything {
            local found 0
            foreach c of local all_combos {
                if "`c'" == "`req'" {
                    local found 1
                    local free_combos `"`free_combos' `req'"'
                }
            }
            if !`found' {
                di as err "Combination '`req'' not found in e(combinations): `all_combos'"
                capture estimates drop `_cnma_ests'
                exit 198
            }
        }
    }
    local n_free : word count `free_combos'

    local meth      `"`e(method_test)'"'
    local comps     `"`e(components)'"'
    local nonref    `"`e(nonref_list)'"'
    local ref       `"`e(reference)'"'
    local cf        `"`e(contrasts_file)'"'
    local y_varlist `"`e(nonref_list)'"'  // nonref_list mirrors _y_ col order
    local ll_cNMA    = e(ll_cNMA)
    local ll_sNMA    = e(ll_sNMA)
    local tau2_sNMA  = e(tau2_sNMA)
    local tau2_cNMA  = e(tau2_cNMA)
    local n_combos  : word count `all_combos'

    if "`level'" == "" local level = e(level)
    if missing(`level') local level = c(level)
    local alpha  = (100 - `level') / 100
    local z_crit = invnormal(1 - `alpha' / 2)

    // Reconstruct y_varlist as space-separated _y_TREAT names
    local y_vars ""
    foreach nr of local nonref {
        local y_vars "`y_vars' _y_`nr'"
    }

    if `"`cf'"' == "" | !fileexists(`"`cf'"') {
        di as err "Augmented contrast dataset not found. Re-run cnma."
        exit 498
    }

    // Determine mvmeta method
    local mvmeta_meth = cond("`meth'" == "ml", "ml", "reml")

    preserve
    qui use `"`cf'"', clear

    // Rebuild ALL additivity constraints, then drop those for free_combos
    // Constraint expression for combo C1_C2: [_y_C1_C2]_cons - [_y_C1]_cons - [_y_C2]_cons = 0
    local con_nums_int ""
    local con_n_int = 0

    foreach combo of local all_combos {
        // Is this combo in the free list?
        local is_free 0
        foreach fc of local free_combos {
            if "`fc'" == "`combo'" local is_free 1
        }
        if `is_free' continue   // skip -- free this constraint

        // Build constraint expression
        local parts ""
        local t2 "`combo'"
        while length("`t2'") > 0 {
            local us = strpos("`t2'", "_")
            if `us'==0 {
                local parts `parts' `t2'
                local t2 ""
            }
            else {
                local parts `parts' `=substr("`t2'",1,`us'-1)'
                local t2 = substr("`t2'",`us'+1,.)
            }
        }
        local con_expr "[_y_`combo']_cons"
        foreach part of local parts {
            local con_expr "`con_expr' - [_y_`part']_cons"
        }
        local ++con_n_int
        constraint define `con_n_int' `con_expr' = 0
        local con_nums_int "`con_nums_int' `con_n_int'"
    }

    // Run interaction model (cNMA with freed combos)
    if `con_n_int' > 0 {
        qui mvmeta _y _S, vars(`y_vars') constraints(`con_nums_int') ///
            bscovariance(exch 0.5) longparm suppress(uv mm) ///
            level(`level')
    }
    else {
        // All combos freed = unconstrained sNMA
        qui mvmeta _y _S, vars(`y_vars') ///
            bscovariance(exch 0.5) longparm suppress(uv mm) ///
            level(`level')
    }
    if `con_n_int' > 0 constraint drop `con_nums_int'

    local ll_int  = e(ll)
    local tau2_int = .
    tempname _Sig_int
    capture matrix `_Sig_int' = e(Sigma)
    capture local tau2_int = `_Sig_int'[1,1]

    // LR tests
    local LR_add      = .   // sNMA vs additive cNMA
    local p_LR_add    = .
    local df_add      = `n_combos'
    local LR_sNMA_int = .   // sNMA vs interaction model
    local p_sNMA_int  = .
    local df_sNMA_int = `n_combos' - `n_free'
    local LR_int      = .   // additive cNMA vs interaction model
    local p_LR_int    = .
    if "`lrtest'" != "nolrtest" {
        if !missing(`ll_sNMA') & !missing(`ll_cNMA') {
            local LR_add   = 2 * (`ll_sNMA' - `ll_cNMA')
            local p_LR_add = chi2tail(`df_add', max(0,`LR_add'))
        }
        if !missing(`ll_sNMA') & !missing(`ll_int') {
            local LR_sNMA_int = 2 * (`ll_sNMA' - `ll_int')
            local p_sNMA_int  = chi2tail(`df_sNMA_int', max(0,`LR_sNMA_int'))
        }
        if !missing(`ll_cNMA') & !missing(`ll_int') {
            local LR_int   = 2 * (`ll_int' - `ll_cNMA')
            local p_LR_int = chi2tail(`n_free', max(0,`LR_int'))
        }
    }

    // Extract estimates for freed combos from this interaction model run
    tempname b_int V_int
    matrix `b_int' = e(b)
    matrix `V_int' = e(V)
    local cnames_int : colfullnames `b_int'

    restore

    /* -- Display ----------------------------------------------------------- */
    di _n as txt "{hline 78}"
    di as txt " Component Interaction Model"
    di as txt "{hline 78}"
    di as txt "  Method    : " as res upper("`meth'") ///
              as txt "   Reference : " as res "`ref'"
    di as txt "  Freed combos: " as res "`free_combos'"
    di as txt "  Remaining additivity constraints: " ///
              as res `= wordcount("`all_combos'") - `n_free''
    di as txt "{hline 78}"

    // Per freed combo: delta = b_combo_free - sum(b_components)
    // Get component estimates from interaction model (components still additive)
    di as txt "  Interaction effects (delta = freed combo - sum of components):"
    di as txt "  " %-22s "Combination" %10s "delta" %9s "SE" ///
              %9s "z" %10s "p-value" %20s "[`level'% CI]"
    di as txt "  {hline 82}"

    foreach combo of local free_combos {
        // Find combo col in b_int
        local combo_col = 0
        local col = 0
        foreach cn of local cnames_int {
            local ++col
            local tname = substr("`cn'", 4, strpos("`cn'", ":") - 4)
            if "`tname'" == "`combo'" local combo_col `col'
        }

        // Find component cols
        local parts ""
        local t2 "`combo'"
        while length("`t2'") > 0 {
            local us = strpos("`t2'", "_")
            if `us'==0 {
                local parts `parts' `t2'
                local t2 ""
            }
            else {
                local parts `parts' `=substr("`t2'",1,`us'-1)'
                local t2 = substr("`t2'",`us'+1,.)
            }
        }
        local part_cols ""
        foreach part of local parts {
            local pcol = 0
            local col = 0
            foreach cn of local cnames_int {
                local ++col
                local tname = substr("`cn'", 4, strpos("`cn'", ":") - 4)
                if "`tname'" == "`part'" local pcol `col'
            }
            local part_cols `part_cols' `pcol'
        }

        // delta = b_combo - sum(b_comps)
        local delta = cond(`combo_col'>0, `b_int'[1,`combo_col'], .)
        local np : word count `part_cols'
        forvalues i = 1/`np' {
            local pi : word `i' of `part_cols'
            if `pi' > 0 local delta = `delta' - `b_int'[1, `pi']
        }

        // var(delta)
        local var_d = cond(`combo_col'>0, `V_int'[`combo_col',`combo_col'], 0)
        forvalues i = 1/`np' {
            local pi : word `i' of `part_cols'
            if `pi'==0 continue
            local var_d = `var_d' + `V_int'[`pi',`pi'] - 2*`V_int'[`combo_col',`pi']
            forvalues j = 1/`np' {
                if `j'<=`i' continue
                local pj : word `j' of `part_cols'
                if `pj'==0 continue
                local var_d = `var_d' + 2*`V_int'[`pi',`pj']
            }
        }
        local se_d  = sqrt(max(0, `var_d'))
        local z_d   = cond(`se_d'>0, `delta'/`se_d', .)
        local p_d   = cond(!missing(`z_d'), 2*(1-normal(abs(`z_d'))), .)
        local lb_d  = `delta' - `z_crit'*`se_d'
        local ub_d  = `delta' + `z_crit'*`se_d'

        // Store delta info for e(b)/e(V) augmentation
        local d_val_`combo'   = `delta'
        local d_vd_`combo'    = `var_d'
        local d_ccol_`combo'  = `combo_col'
        local d_pcols_`combo' `part_cols'

        local clabel = subinstr("`combo'", "_", " + ", .)

        di as txt "  " %-22s "`clabel'" ///
            as res %10.4f `delta' %9.4f `se_d' %9.3f `z_d' ///
            %10.4f `p_d' "  " %9.4f `lb_d' " to " %9.4f `ub_d'
    }

    di as txt "  {hline 82}"
    di _n as txt "  Model comparison:"
    di as txt "  " %-30s "Model" %12s "log-lik" %10s "tau^2"
    di as txt "  {hline 54}"
    di as txt "  " %-30s "sNMA (unconstrained)" ///
              as res %12.4f `ll_sNMA' ///
              as res %10.4f cond(missing(`tau2_sNMA'), ., `tau2_sNMA')
    di as txt "  " %-30s "cNMA (additive)" ///
              as res %12.4f `ll_cNMA' ///
              as res %10.4f cond(missing(`tau2_cNMA'), ., `tau2_cNMA')
    di as txt "  " %-30s "Interaction model" ///
              as res %12.4f `ll_int' ///
              as res %10.4f cond(missing(`tau2_int'), ., `tau2_int')
    di as txt "  {hline 54}"

    if "`lrtest'" != "nolrtest" {
        local methlab = cond("`meth'"=="reml","REML (approx.)","ML")
        di _n as txt "  Likelihood ratio tests (`methlab'):"
        di as txt "  " %-38s "Comparison" %8s "LR" %5s "df" %10s "p-value"
        di as txt "  {hline 63}"
        di as txt "  " %-38s "sNMA vs additive cNMA" ///
                  as res %8.3f `LR_add' %5.0f `df_add' %10.4f `p_LR_add'
        di as txt "  " %-38s "sNMA vs interaction cNMA" ///
                  as res %8.3f `LR_sNMA_int' %5.0f `df_sNMA_int' %10.4f `p_sNMA_int'
        di as txt "  " %-38s "Additive cNMA vs interaction cNMA" ///
                  as res %8.3f `LR_int' %5.0f `n_free' %10.4f `p_LR_int'
        di as txt "  {hline 63}"
        if !missing(`p_LR_int') {
            if `p_LR_int' < 0.05 {
                di as txt "  * Interaction(s) statistically significant at 5%."
            }
            else {
                di as txt "  * Interaction(s) not statistically significant at 5%."
            }
        }
    }
    di as txt "{hline 78}"
    di as txt "  delta > 0: combination more effective than sum of components"
    di as txt "  delta < 0: combination less effective than sum of components"
    if "`meth'" == "reml" {
        di as txt "  Note: Both models treat treatment effects as fixed and study"
        di as txt "        deviations as random (tau^2).  The LR test is approximate"
        di as txt "        under REML because sNMA and cNMA have different numbers"
        di as txt "        of free treatment-effect parameters; REML partials these"
        di as txt "        out before estimating tau^2, making the likelihoods not"
        di as txt "        strictly comparable.  Use method(ml) for an exact test."
    }
    local ex_combo : word 1 of `free_combos'
    di as txt "  Interaction deltas in e(b) as [interact]<combo>;"
    di as txt "  e.g.:  lincom [interact]`ex_combo'"
    di as txt "{hline 78}"

    /* -- Build delta b and V matrices for lincom support ------------------- */
    // delta_i = b_combo_i - sum(b_components_i)
    // cov(delta_i, delta_j) computed via delta method from V_int
    tempname b_delta V_delta

    // Delta coefficient vector (1 x n_free)
    matrix `b_delta' = J(1, `n_free', .)
    local idx = 0
    foreach combo of local free_combos {
        local ++idx
        matrix `b_delta'[1, `idx'] = `d_val_`combo''
    }

    // Delta VCV matrix (n_free x n_free)
    matrix `V_delta' = J(`n_free', `n_free', 0)

    // Diagonal
    local idx = 0
    foreach combo of local free_combos {
        local ++idx
        matrix `V_delta'[`idx', `idx'] = max(0, `d_vd_`combo'')
    }

    // Off-diagonal: cov(delta_i, delta_j) using V_int
    // = V[cA,cB] - sum_k V[cA,pkB] - sum_k V[pkA,cB] + sum_{k,l} V[pkA,plB]
    local ii = 0
    foreach combo_i of local free_combos {
        local ++ii
        local jj = 0
        foreach combo_j of local free_combos {
            local ++jj
            if `jj' <= `ii' continue
            local cci = `d_ccol_`combo_i''
            local ccj = `d_ccol_`combo_j''
            local cov_ij = 0
            if `cci' > 0 & `ccj' > 0 local cov_ij = `V_int'[`cci', `ccj']
            foreach pk of local d_pcols_`combo_j' {
                if `pk' > 0 & `cci' > 0 {
                    local cov_ij = `cov_ij' - `V_int'[`cci', `pk']
                }
            }
            foreach pk of local d_pcols_`combo_i' {
                if `pk' > 0 & `ccj' > 0 {
                    local cov_ij = `cov_ij' - `V_int'[`pk', `ccj']
                }
            }
            foreach pki of local d_pcols_`combo_i' {
                if `pki' == 0 continue
                foreach pkj of local d_pcols_`combo_j' {
                    if `pkj' == 0 continue
                    local cov_ij = `cov_ij' + `V_int'[`pki', `pkj']
                }
            }
            matrix `V_delta'[`ii', `jj'] = `cov_ij'
            matrix `V_delta'[`jj', `ii'] = `cov_ij'
        }
    }

    // Set equation = "interact", variable = combo name
    // Use coleq + colnames separately (avoids colon-syntax parser issues)
    local eq_list "interact"
    local idx = 1
    foreach combo of local free_combos {
        if `idx' > 1 local eq_list "`eq_list' interact"
        local ++idx
    }
    matrix coleq   `b_delta' = `eq_list'
    matrix colnames `b_delta' = `free_combos'
    matrix roweq   `V_delta' = `eq_list'
    matrix rownames `V_delta' = `free_combos'
    matrix coleq   `V_delta' = `eq_list'
    matrix colnames `V_delta' = `free_combos'

    // Drop saved cnma estimates — all needed info already in locals
    capture estimates drop `_cnma_ests'

    // Post delta estimates fresh.
    // Using ereturn post (not repost) avoids any conformability conflict
    // with cnma's internal e() structure.
    // After this:  lincom [interact]FES_TMShigh
    //              lincom [interact]FES_TMShigh - [interact]NMES_TMShigh
    ereturn post `b_delta' `V_delta', obs(`e_N')

    // Restore key e() metadata
    ereturn local cmd            "cnma"
    ereturn local combinations   "`all_combos'"
    ereturn local components     "`comps'"
    ereturn local nonref_list    "`nonref'"
    ereturn local reference      "`ref'"
    ereturn local method_test    "`meth'"
    ereturn local contrasts_file `"`cf'"'

    // Log-likelihoods for all three models
    ereturn scalar ll_int    = `ll_int'
    ereturn scalar ll_sNMA   = `ll_sNMA'
    ereturn scalar ll_cNMA   = `ll_cNMA'
    ereturn scalar tau2_sNMA = `tau2_sNMA'
    ereturn scalar tau2_cNMA = `tau2_cNMA'
end
