*! generate_ccw v1.0  27sep2026  Ammarin Thakkinstian
*! Department of Clinical Epidemiology and Biostatistics (CEB), Faculty of Medicine Ramathibodi Hospital, Mahidol University
*! Replicates survivalCCW::generate_ccw() from R (Genentech)
*
*  Generates IPCW (clone-censor) weights via discrete-time pooled logistic
*  hazard models, fitted separately for each clone group.
*
*  Method:
*    1. logit P(censor=1 | t_stop, predvars)  fitted per clone (0 and 1)
*    2. p_surv(t) = 1 - predicted P(censor=1 at t)
*    3. S_c(t)    = cumulative product of p_surv over intervals 0..t
*                 = exp( sum of log(p_surv) )   [log-sum for stability]
*    4. weight_cox = 1 / S_c(t)
*
*  Must be run AFTER cast_clones_to_long.
*
*  Syntax:
*    generate_ccw, predvars(varlist) [winsorize(# #)]
*
*  Options:
*    predvars(varlist)   : baseline covariates for the censoring model
*    winsorize(lo hi)    : winsorise weights at the lo-th and hi-th percentiles
*                          (e.g. winsorize(10 90)); default = no winsorisation
*
*  Outputs (new variables):
*    p_c        : predicted P(artificially censored) at each interval
*    p_surv     : 1 - p_c  (conditional survival through this interval)
*    surv_c     : cumulative S_c(t) per clone-patient
*    weight_cox : IPCW weight = 1 / S_c(t)
*
*  See also: create_clones, cast_clones_to_long

program define generate_ccw
    version 16
    syntax , predvars(varlist) [winsorize(numlist max=2 ascending)]

    * ---- Check prerequisites -------------------------------------------
    foreach v in clone stid t_stop censor {
        capture confirm variable `v'
        if _rc {
            di as err "generate_ccw: variable `v' not found."
            di as err "  Run cast_clones_to_long first."
            exit 198
        }
    }

    * ---- 6.1 Initialise predicted-probability variable -----------------
    foreach v in p_c p_surv surv_c weight_cox {
        capture drop `v'
    }
    gen double p_c = .
    label var p_c "Predicted P(artificially censored) at this interval"

    * ---- 6.2 Pooled logistic model for clone == 1 (exposed strategy) ---
    di as txt _newline "Fitting censoring model for clone == 1 (assigned-exposed)..."
    logit censor t_stop `predvars' if clone == 1
    predict double temp_p if clone == 1, pr
    replace p_c = temp_p if clone == 1
    drop temp_p

    * ---- 6.3 Pooled logistic model for clone == 0 (unexposed strategy) --
    di as txt _newline "Fitting censoring model for clone == 0 (assigned-unexposed)..."
    logit censor t_stop `predvars' if clone == 0
    predict double temp_p if clone == 0, pr
    replace p_c = temp_p if clone == 0
    drop temp_p

    * ---- 6.4 Conditional survival probability at each interval ----------
    gen double p_surv = 1 - p_c
    replace p_surv = max(p_surv, 1e-8)   // safeguard against log(0)
    label var p_surv "P(not artificially censored) at this interval"

    * ---- 6.5 Cumulative survival S_c(t) ---------------------------------
    *     Running log-sum per clone-patient, sorted by t_stop.
    *     log-sum form avoids underflow from many small multiplications.
    bysort stid (t_stop): gen double surv_c = exp(sum(log(p_surv)))
    label var surv_c "Cumulative S_c(t) = P(not ac-censored through t)"

    * ---- 6.6 IPCW weight ------------------------------------------------
    gen double weight_cox = 1 / surv_c
    label var weight_cox "IPCW clone-censor weight (1/S_c)"

    * ---- 6.7 Optional winsorisation ------------------------------------
    *     Equivalent to winsorize_ccw_weights(quantiles = c(lo/100, hi/100))
    if "`winsorize'" != "" {
        local lo : word 1 of `winsorize'
        local hi : word 2 of `winsorize'
        centile weight_cox, c(`lo' `hi')
        local wlo = r(c_1)
        local whi = r(c_2)
        replace weight_cox = `wlo' if weight_cox < `wlo'
        replace weight_cox = `whi' if weight_cox > `whi'
        di as txt _newline "  Winsorized at [`lo'th, `hi'th percentile]:"
        di as txt "    Floor = `wlo', Cap = `whi'"
    }

    * ---- Summary --------------------------------------------------------
    qui sum weight_cox
    di as txt _newline "generate_ccw complete:"
    di as txt "  N rows    : " r(N)
    di as txt "  Mean wt   : " %7.4f r(mean)
    di as txt "  Min  wt   : " %7.4f r(min)
    di as txt "  Max  wt   : " %7.4f r(max)
    di as txt "  Next: stset t_stop, id(stid) failure(outcome) time0(t_start)"
    di as txt "        stcox clone [pweight=weight_cox], vce(robust)"

end
