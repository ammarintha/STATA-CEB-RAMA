*! bootstrap_ccw v5.1  01oct2026  Ammarin Thakkinstian
*! Department of Clinical Epidemiology and Biostatistics (CEB), Faculty of Medicine Ramathibodi Hospital, Mahidol University
*! Bootstrap for CCW Cox model with weighted resampling
*!
*!  Resamples clusters (patients) with probability proportional to IPCW weight.
*!  Returns mean, SE, 95% CI (percentile), IQR, and bias correction.

capture program drop bootstrap_ccw
program define bootstrap_ccw
    version 16

    syntax [, PREDictor(string) CLuster(varname) REPs(integer 200) SEED(integer 0) ///
             Tstart(varname) Tstop(varname) Failure(varname) Idvar(varname)]

    if "`cluster'" == "" {
        di as err "bootstrap_ccw: cluster(varname) is required"
        exit 198
    }

    capture confirm variable `cluster'
    if _rc {
        di as err "bootstrap_ccw: cluster variable '`cluster'' not found"
        exit 111
    }

    if `reps' <= 0 {
        di as err "reps() must be positive"
        exit 198
    }
    if `seed' < 0 {
        di as err "seed() must be non-negative"
        exit 198
    }

    if `seed' != 0 set seed `seed'

    * Use defaults for stset variables (from standard CCW pipeline)
    if "`tstart'" == "" local tstart "t_start"
    if "`tstop'" == "" local tstop "t_stop"
    if "`failure'" == "" local failure "outcome"
    if "`idvar'" == "" local idvar "rowid"

    * Verify required variables exist
    foreach v in `cluster' `tstart' `tstop' `failure' clone weight_cox {
        capture confirm variable `v'
        if _rc {
            di as err "bootstrap_ccw: required variable '`v'' not found"
            exit 111
        }
    }

    * Save original data
    tempfile original cluster_weights results_file draws
    tempvar bsfreq
    quietly save `original'

    * Everything below runs inside -capture noisily- so that, if anything
    * fails, the user's original data are put back in memory.
    capture noisily {

        * ---- Weight per cluster (one row per cluster) ----
        quietly collapse (sum) _weight_sum=weight_cox, by(`cluster')
        local n_clusters = _N
        quietly save `cluster_weights'

        * ---- Results holder with exactly `reps' rows ----
        quietly {
            clear
            set obs `reps'
            gen double _bs_coef = .
            gen double _bs_hr = .
            save `results_file'
        }

        * ---- Observed coefficient: weighted CCW estimate on full data ----
        * (pweight = weight_cox; same concept as the pseudo-samples below)
        quietly use `original', clear
        quietly stset `tstop' [pw=weight_cox], id(`idvar') failure(`failure') time0(`tstart')
        quietly stcox clone `predictor', noshow
        local obs_coef = _b[clone]
        local obs_hr = exp(`obs_coef')

        * ---- Bootstrap replications ----
        forvalues b = 1/`reps' {

            * Draw n_clusters clusters with probability proportional to
            * cluster weight (Mata; works for string or numeric cluster IDs)
            quietly use `cluster_weights', clear
            mata: _bcw_draw(`n_clusters', "_weight_sum", "`bsfreq'")
            quietly keep if `bsfreq' > 0
            keep `cluster' `bsfreq'
            quietly save `draws', replace

            * Build the bootstrap sample
            quietly use `original', clear
            quietly stset `tstop', id(`idvar') failure(`failure') time0(`tstart')
            quietly merge m:1 `cluster' using `draws', keep(match) nogenerate
            quietly expand `bsfreq'
            drop `bsfreq'

            * Fit Cox model (no explicit weights - they're in the resampling)
            quietly stcox clone `predictor', noshow
            local coef = _b[clone]
            local hr = exp(`coef')

            * Store results
            quietly use `results_file', clear
            quietly replace _bs_coef = `coef' in `b'
            quietly replace _bs_hr = `hr' in `b'
            quietly save `results_file', replace
        }
    }
    local rc = _rc
    if `rc' {
        set output proc
        quietly use `original', clear
        di as err "bootstrap_ccw: stopped with error r(`rc'); original data restored"
        exit `rc'
    }

    set output proc

    * Display simple results
    quietly use `results_file', clear
    keep if _n <= `reps'

    * Calculate statistics for coefficient
    quietly {
        summarize _bs_coef
        local mean_coef = r(mean)
        local sd_coef = r(sd)

        _pctile _bs_coef, p(2.5 25 50 75 97.5)
        local ci_coef_lo = r(r1)
        local q1_coef = r(r2)
        local med_coef = r(r3)
        local q3_coef = r(r4)
        local ci_coef_hi = r(r5)
        local iqr_coef = `q3_coef' - `q1_coef'
        local bias_coef = `mean_coef' - `obs_coef'
    }

    * Calculate statistics for hazard ratio
    quietly {
        summarize _bs_hr
        local mean_hr = r(mean)
        local sd_hr = r(sd)

        _pctile _bs_hr, p(2.5 25 50 75 97.5)
        local ci_hr_lo = r(r1)
        local q1_hr = r(r2)
        local med_hr = r(r3)
        local q3_hr = r(r4)
        local ci_hr_hi = r(r5)
        local iqr_hr = `q3_hr' - `q1_hr'
        local bias_hr = `mean_hr' - `obs_hr'
    }

    * Calculate normal-based 95% CI (mean ± 1.96*SE)
    local z_crit = 1.96
    local ci_normal_coef_lo = `mean_coef' - `z_crit' * `sd_coef'
    local ci_normal_coef_hi = `mean_coef' + `z_crit' * `sd_coef'
    local ci_normal_hr_lo = `mean_hr' - `z_crit' * `sd_hr'
    local ci_normal_hr_hi = `mean_hr' + `z_crit' * `sd_hr'

    * Calculate bias-corrected CI using z0 correction
    quietly {
        * Count proportion of bootstrap estimates below observed
        count if _bs_coef < `obs_coef'
        local n_below_coef = r(N)
        local p_below_coef = `n_below_coef' / `reps'

        count if _bs_hr < `obs_hr'
        local n_below_hr = r(N)
        local p_below_hr = `n_below_hr' / `reps'
    }

    * Calculate z0 bias correction factor
    if `p_below_coef' > 0 & `p_below_coef' < 1 {
        local z0_coef = invnormal(`p_below_coef')
    }
    else {
        local z0_coef = 0
    }
    if `p_below_hr' > 0 & `p_below_hr' < 1 {
        local z0_hr = invnormal(`p_below_hr')
    }
    else {
        local z0_hr = 0
    }

    * Adjusted percentiles for BC CI: alpha_lo and alpha_hi
    local alpha_lo_coef = normal(`z0_coef' + ((`z0_coef' - `z_crit') / (1 - 0))) * 100
    local alpha_hi_coef = normal(`z0_coef' + ((`z0_coef' + `z_crit') / (1 - 0))) * 100
    local alpha_lo_hr = normal(`z0_hr' + ((`z0_hr' - `z_crit') / (1 - 0))) * 100
    local alpha_hi_hr = normal(`z0_hr' + ((`z0_hr' + `z_crit') / (1 - 0))) * 100

    * Ensure percentiles are within [0.5, 99.5] range for _pctile
    local alpha_lo_coef = max(0.5, min(99.5, `alpha_lo_coef'))
    local alpha_hi_coef = max(0.5, min(99.5, `alpha_hi_coef'))
    local alpha_lo_hr = max(0.5, min(99.5, `alpha_lo_hr'))
    local alpha_hi_hr = max(0.5, min(99.5, `alpha_hi_hr'))

    * Get BC percentiles
    quietly {
        _pctile _bs_coef, p(`alpha_lo_coef' `alpha_hi_coef')
        local ci_bc_coef_lo = r(r1)
        local ci_bc_coef_hi = r(r2)

        _pctile _bs_hr, p(`alpha_lo_hr' `alpha_hi_hr')
        local ci_bc_hr_lo = r(r1)
        local ci_bc_hr_hi = r(r2)
    }

    * Display results table matching estat bootstrap, all format
    di as txt ""
    di as txt "Bootstrap results (CCW Cox model)                Number of obs = " as res `reps'
    di as txt ""
    di as txt "Coefficient for clone (log hazard ratio):"
    di as txt "-----------|----------------------------------------------"
    di as txt "      clone|    Observed               Bootstrap"
    di as txt "           | coefficient       Bias    std. err.  [95% conf. interval]"
    di as txt "-----------+----------------------------------------------"
    di as txt "           |" %12.6f `obs_coef' %12.6f `bias_coef' %12.6f `sd_coef' %12.6f `ci_normal_coef_lo' %12.6f `ci_normal_coef_hi' "   (N)"
    di as txt "           |" _skip(33) %12.6f `ci_coef_lo' %12.6f `ci_coef_hi' "   (P)"
    di as txt "           |" _skip(33) %12.6f `ci_bc_coef_lo' %12.6f `ci_bc_coef_hi' "  (BC)"
    di as txt ""
    di as txt "Hazard Ratio for clone (exp[coef]):"
    di as txt "-----------|----------------------------------------------"
    di as txt "      clone|    Observed               Bootstrap"
    di as txt "           |         HR        Bias    std. err.  [95% conf. interval]"
    di as txt "-----------+----------------------------------------------"
    di as txt "           |" %12.6f `obs_hr' %12.6f `bias_hr' %12.6f `sd_hr' %12.6f `ci_normal_hr_lo' %12.6f `ci_normal_hr_hi' "   (N)"
    di as txt "           |" _skip(33) %12.6f `ci_hr_lo' %12.6f `ci_hr_hi' "   (P)"
    di as txt "           |" _skip(33) %12.6f `ci_bc_hr_lo' %12.6f `ci_bc_hr_hi' "  (BC)"
    di as txt ""

    * Restore original data to memory
    quietly use `original', clear

end


* ---- Mata helper: weighted draw of clusters with replacement ----
capture mata: mata drop _bcw_draw()
mata:
void _bcw_draw(real scalar n, string scalar wvar, string scalar fvar)
{
    real colvector w, idx, f
    real scalar i

    w   = st_data(., wvar)
    idx = rdiscrete(n, 1, w :/ sum(w))
    f   = J(rows(w), 1, 0)
    for (i = 1; i <= n; i++) f[idx[i]] = f[idx[i]] + 1
    (void) st_addvar("long", fvar)
    st_store(., fvar, f)
}
end
