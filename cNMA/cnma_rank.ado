*! cnma_rank  --  P-score and SUCRA ranking after cnma
*! post-estimation command for cnma
*! version 1.10  15nov2026  Ammarin Thakkinstian

program define cnma_rank, rclass
    syntax [, Reps(integer 200) BEtter(string) SAVEgraph(string) ///
              name(string asis) noSUCRA noGraph SEed(integer -1)]
    if !inlist("`e(cmd)'", "cnma", "cnma_dicho") error 301

    if "`better'" == "" local better "large"
    if !inlist("`better'", "large", "small") {
        di as err "better() must be 'large' or 'small'"
        exit 198
    }

    // Set random-number seed for reproducibility (omit to use current state)
    if `seed' >= 0 set seed `seed'

    local comps  `"`e(components)'"'
    local combos `"`e(combinations)'"'
    local ref    `"`e(reference)'"'
    local level  = e(level)
    if missing(`level') local level = c(level)

    tempname bmat Vmat
    matrix `bmat' = e(b)
    matrix `Vmat' = e(V)

    // nc from actual e(b) dimensions — robust even if e(components) count differs
    local cnames `"`e(components)'"'
    local nc = colsof(`bmat')

    local all_treats "`ref'"
    foreach comp of local cnames {
        local all_treats "`all_treats' `comp'"
    }
    foreach combo of local combos {
        local all_treats "`all_treats' `combo'"
    }
    local ncombo : word count `combos'
    local n_all2 = 1 + `nc' + `ncombo'

    // Build combo indicator matrix in Mata
    tempname combo_Z
    if `ncombo' > 0 {
        local combo_str ""
        foreach combo of local combos {
            local combo_str "`combo_str'|`combo'"
        }
        local comp_str ""
        foreach cn of local cnames {
            local comp_str "`comp_str'|`cn'"
        }
        mata: _cnma_buildZ("`combo_str'", "`comp_str'", `ncombo', `nc', "`combo_Z'")
    }

    // Compute P-scores and SUCRA
    tempname rank_mat
    if `ncombo' > 0 {
        mata: _cnma_rank2("`bmat'", "`Vmat'", "`combo_Z'", `reps', "`better'", "`rank_mat'")
    }
    else {
        mata: _cnma_rank2("`bmat'", "`Vmat'", "", `reps', "`better'", "`rank_mat'")
    }

    // Display results
    di _n as txt "{hline 78}"
    di as txt " Treatment Rankings  (Component Network Meta-Analysis)"
    di as txt "{hline 78}"
    di as txt "  Reference  : " as res "`ref'"
    di as txt "  Direction  : better = " as res "`better'" as txt " values"
    di as txt "  SUCRA reps : " as res `reps'
    di as txt "{hline 78}"
    di as txt "  " %-22s "Treatment" %10s "P-score" %10s "SUCRA" %10s "Mean rank"
    di as txt "  {hline 55}"

    di as txt "  " %-22s "`ref' (ref)" ///
              as res %10.4f `rank_mat'[1,1] ///
              as res %10.4f `rank_mat'[1,2] ///
              as res %10.2f `rank_mat'[1,3]

    di as txt "  {hline 55}"
    di as txt "  Components:"
    forvalues i = 1/`nc' {
        local comp : word `i' of `cnames'
        di as txt "  " %-22s "`comp'" ///
                  as res %10.4f `rank_mat'[`i'+1, 1] ///
                  as res %10.4f `rank_mat'[`i'+1, 2] ///
                  as res %10.2f `rank_mat'[`i'+1, 3]
    }

    if `ncombo' > 0 {
        di as txt "  {hline 55}"
        di as txt "  Combinations (additive):"
        local ki = 0
        foreach combo of local combos {
            local ++ki
            local clabel = subinstr("`combo'", "_", " + ", .)
            local r = `nc' + 1 + `ki'
            di as txt "  " %-22s "`clabel'" ///
                      as res %10.4f `rank_mat'[`r', 1] ///
                      as res %10.4f `rank_mat'[`r', 2] ///
                      as res %10.2f `rank_mat'[`r', 3]
        }
    }

    di as txt "  {hline 55}"
    di as txt "{hline 78}"
    di as txt "  P-score: mean probability that treatment i is better than each other treatment in the network (0=worst, 1=best)"
    di as txt "  SUCRA  : Surface Under Cumulative RAnking curve (simulation, `reps' reps)"
    di as txt "  Combination effects = sum of component effects (additive model)"

    // SUCRA bar chart
    if "`graph'" != "nograph" & "`sucra'" != "nosucra" {
        preserve
        clear
        qui set obs `n_all2'
        qui gen str40 trt    = ""
        qui gen double sucra_v = .

        qui replace trt     = "`ref'"          in 1
        qui replace sucra_v = `rank_mat'[1, 2] in 1
        forvalues i = 1/`nc' {
            local comp : word `i' of `cnames'
            qui replace trt     = "`comp'"              in `=`i'+1'
            qui replace sucra_v = `rank_mat'[`i'+1, 2]  in `=`i'+1'
        }
        if `ncombo' > 0 {
            local ki = 0
            foreach combo of local combos {
                local ++ki
                local clabel2 = subinstr("`combo'", "_", "+", .)
                local r = `nc' + 1 + `ki'
                qui replace trt     = "`clabel2'"         in `r'
                qui replace sucra_v = `rank_mat'[`r', 2]  in `r'
            }
        }

        gsort -sucra_v

        local grname ""
        if `"`name'"' != "" local grname `"name(`name')"'

        graph hbar sucra_v, ///
            over(trt, sort(sucra_v) descending label(angle(0))) ///
            ytitle("SUCRA") ///
            title("SUCRA Rankings", size(medium)) ///
            bar(1, fcolor(navy%70) lcolor(navy)) ///
            yline(0.5, lcolor(gs8) lpattern(dash)) ///
            scheme(s1color) `grname'

        if `"`savegraph'"' != "" graph save `"`savegraph'"', replace

        restore
    }

    return scalar n_treat = `n_all2'
    return local  better  = "`better'"
    return local  ref     = "`ref'"
end


/* ============================================================
   Mata helper: build combo indicator matrix Z (ncombo x nc)
   ============================================================ */
mata:
void _cnma_buildZ(string scalar combo_str,
                  string scalar comp_str,
                  real scalar   ncombo,
                  real scalar   nc,
                  string scalar out_name)
{
    combos = tokens(combo_str, "|")
    combos = select(combos, combos :!= "|" :& combos :!= "")
    comps  = tokens(comp_str,  "|")
    comps  = select(comps,  comps  :!= "|" :& comps  :!= "")

    Z = J(ncombo, nc, 0)
    for (k=1; k<=ncombo; k++) {
        parts = tokens(combos[k], "_")
        parts = select(parts, parts :!= "_" :& parts :!= "")
        for (p=1; p<=cols(parts); p++) {
            for (j=1; j<=nc; j++) {
                if (parts[p] == comps[j]) Z[k,j] = 1
            }
        }
    }
    st_matrix(out_name, Z)
}
end


/* ============================================================
   Mata: _cnma_rank2  --  P-score + SUCRA
   Named _cnma_rank2 to avoid conflict with _cnma_rank in cnma.ado
   ============================================================ */
mata:
void _cnma_rank2(string scalar bmat_name,
                 string scalar Vmat_name,
                 string scalar Zcombo_name,
                 real scalar   reps,
                 string scalar direction,
                 string scalar out_name)
{
    b    = st_matrix(bmat_name)      // 1 x nc
    V    = st_matrix(Vmat_name)      // nc x nc
    nc   = cols(b)

    real scalar sign
    if (direction == "large") sign = 1
    else                      sign = -1

    ncombo  = 0
    Z_combo = J(0, nc, 0)
    if (Zcombo_name != "") {
        Z_combo = st_matrix(Zcombo_name)
        ncombo  = rows(Z_combo)
    }

    n_all = 1 + nc + ncombo

    // mu_full: 1 x n_all  (ref=0, comps=b, combos=Z*b')
    if (ncombo == 0) {
        mu_full = (0, b)
    }
    else {
        mu_full = (0, b, (Z_combo * b')')
    }

    // V_full: n_all x n_all
    if (ncombo == 0) {
        V_full = (J(1,n_all,0)) \ (J(nc,1,0), V)
    }
    else {
        ZV     = Z_combo * V
        V_full = (J(1,n_all,0)) \
                 (J(nc,1,0), V, ZV') \
                 (J(ncombo,1,0), ZV, ZV * Z_combo')
    }
    V_full = makesymmetric(V_full)

    // -----------------------------------------------------------------
    // P-scores (closed form)
    //   P_i = 1/(T-1) * sum_{j!=i} Phi( sign*(mu_i - mu_j)/SE_ij )
    //
    // Build D[i,j] = sign*(mu_i - mu_j) correctly:
    //   mu_col (n_all x 1):  mu_col[i] = mu_i
    //   mu_col * ones'  -> n_all x n_all matrix where row i = mu_i (all cols)
    //   ones * mu_full  -> n_all x n_all matrix where col j = mu_j (all rows)
    //   D[i,j] = sign * (mu_i - mu_j)
    // -----------------------------------------------------------------
    mu_col  = mu_full'                       // n_all x 1
    Vd      = diagonal(V_full)               // n_all x 1
    ones    = J(n_all, 1, 1)

    // D[i,j] = sign*(mu_i - mu_j)
    D       = sign :* (mu_col * ones' - ones * mu_full)

    // Var_m[i,j] = Vd[i] + Vd[j] - 2*V_full[i,j]
    Vd_mat  = Vd * ones'                     // [i,j] = Vd[i]
    Var_m   = Vd_mat + Vd_mat' - 2 :* V_full
    Var_m   = Var_m :* (Var_m :> 0)         // floor numerical noise at 0

    SE_m    = sqrt(Var_m :+ 1e-12)
    Phi_m   = normal(D :/ SE_m)
    for (i=1; i<=n_all; i++) Phi_m[i,i] = 0
    pscore  = rowsum(Phi_m) :/ (n_all - 1)

    // -----------------------------------------------------------------
    // SUCRA via MVN simulation: all reps in one rnormal() call
    // -----------------------------------------------------------------
    Lmat   = cholesky(makesymmetric(V) + 1e-9*I(nc))
    Z_draw = rnormal(nc, reps, 0, 1)         // nc x reps
    B_all  = b' :+ Lmat * Z_draw             // nc x reps

    if (ncombo == 0) {
        Mu_all = J(1, reps, 0) \ B_all
    }
    else {
        Mu_all = J(1, reps, 0) \ B_all \ (Z_combo * B_all)
    }
    Eff_all = sign :* Mu_all                 // n_all x reps (higher = better)

    rank_acc = J(n_all, 1, 0)
    for (r=1; r<=reps; r++) {
        ord_r = order(Eff_all[,r], -1)       // descending: rank 1 = highest
        rnk_r = J(n_all, 1, 0)
        for (k=1; k<=n_all; k++) rnk_r[ord_r[k]] = k
        rank_acc = rank_acc + rnk_r
    }
    mean_rnk = rank_acc / reps
    sucra    = (n_all :- mean_rnk) :/ (n_all - 1)

    st_matrix(out_name, (pscore, sucra, mean_rnk))
}
end
