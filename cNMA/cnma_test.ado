*! cnma_test  --  Test the additivity (component) assumption
*! post-estimation command for cnma
*! version 1.2  05nov2026  Ammarin Thakkinstian

/* ============================================================================
   cnma_test  --  Test the additivity (component) assumption
   ============================================================================ */
program define cnma_test
    syntax [, INTeract(string) LEVel(cilevel) ]
    if !inlist("`e(cmd)'", "cnma", "cnma_dicho") error 301

    local meth      `"`e(method_test)'"'
    local ref       `"`e(reference)'"'
    local comps     `"`e(components)'"'
    local combos    `"`e(combinations)'"'
    local n_combos  : word count `combos'

    di _n as txt "{hline 78}"

    /* -- LR test (reml / ml) ----------------------------------------------- */
    if inlist("`meth'", "reml", "ml") {
        local LR    = e(LR_add)
        local df    = e(df_LR_add)
        local nc_disp = e(n_comp)
        local pval  = e(p_LR_add)
        local t2s   = e(tau2_sNMA)
        local t2c   = e(tau2_cNMA)
        local lls   = e(ll_sNMA)
        local llc   = e(ll_cNMA)

        if missing(`LR') {
            di as err "LR test statistics not available. Re-run cnma."
            exit 498
        }

        local methlab = upper("`meth'")
        if "`meth'" == "reml" local note "(note: approximate under REML -- sNMA and cNMA have different numbers of free treatment-effect parameters; use method(ml) for an exact test)"
        else                   local note ""

        di as txt " Test of the Additivity Assumption  (Likelihood Ratio test, `methlab')"
        di as txt "{hline 78}"
        di as txt "  Reference  : " as res "`ref'"
        di as txt "  Components : " as res "`comps'"
        di as txt "  Combos     : " as res "`combos'"
        di as txt "{hline 78}"
        di as txt "  " %-28s "Model" %12s "log-lik" %8s "tau^2" %6s "df" %10s "p-value"
        di as txt "  {hline 68}"
        di as txt "  " %-28s "sNMA (unconstrained)" ///
                  as res %12.4f `lls' ///
                  as res %8.4f cond(missing(`t2s'), ., `t2s') ///
                  as res %6.0f `nc_disp' + `n_combos'
        di as txt "  " %-28s "cNMA (additive)" ///
                  as res %12.4f `llc' ///
                  as res %8.4f cond(missing(`t2c'), ., `t2c') ///
                  as res %6.0f `nc_disp'
        di as txt "  {hline 68}"
        di as txt "  " %-28s "LR test (additivity)" ///
                  as res %12.3f `LR' ///
                  as txt %8s "--" ///
                  as res %6.0f `df' ///
                  as res %10.4f `pval'
        di as txt "{hline 78}"
        if !missing(`pval') {
            if `pval' < 0.05 {
                di as txt "  * Additivity assumption REJECTED at 5% (LR=" ///
                    as res %6.3f `LR' as txt ", df=" as res `df' ///
                    as txt ", p=" as res %6.4f `pval' as txt ")"
            }
            else {
                di as txt "  * Additivity assumption NOT rejected at 5% (LR=" ///
                    as res %6.3f `LR' as txt ", df=" as res `df' ///
                    as txt ", p=" as res %6.4f `pval' as txt ")"
            }
        }
        if "`note'" != "" di as txt "  " as txt "{it:`note'}"
        di as txt "  LR = 2x(ll_sNMA - ll_cNMA) ~ chi^2(df),  df = number of additivity constraints"
        di as txt "  Run {cmd:cnma_interact [combos]} or use {opt interact(combos)} to test specific interactions."
    }

    /* -- FE-GLS Q-difference ----------------------------------------------- */
    else {
        local Q_nma   = e(Q_nma_fe)
        local df_nma  = e(df_nma_fe)
        local Q_cnma  = e(Q_cnma_fe)
        local df_cnma = e(df_cnma_fe)
        local Q_add   = e(Q_add)
        local df_add  = e(df_add)
        local p_add   = e(p_add)

        if missing(`Q_nma') {
            di as err "FE-GLS Q statistics not available. Re-run cnma with method(fegls)."
            exit 498
        }

        di as txt " Test of the Additivity Assumption  (FE-GLS Q-difference test)"
        di as txt "{hline 78}"
        di as txt "  Reference  : " as res "`ref'"
        di as txt "  Components : " as res "`comps'"
        di as txt "  Combos     : " as res "`combos'"
        di as txt "{hline 78}"
        di as txt "  " %-30s "Model" %10s "Q" %6s "df" %12s "p-value"
        di as txt "  {hline 62}"
        di as txt "  " %-30s "NMA (unconstrained FE)" ///
                  as res %10.3f `Q_nma'  as res %6.0f `df_nma'
        di as txt "  " %-30s "cNMA (additive FE)" ///
                  as res %10.3f `Q_cnma' as res %6.0f `df_cnma'
        di as txt "  {hline 62}"
        di as txt "  " %-30s "Difference (additivity test)" ///
                  as res %10.3f `Q_add'  as res %6.0f `df_add' ///
                  as res %12.4f `p_add'
        di as txt "{hline 78}"
        if `p_add' < 0.05 {
            di as txt "  * Additivity assumption REJECTED at 5% level (p=" ///
                as res %6.4f `p_add' as txt ")"
        }
        else {
            di as txt "  * Additivity assumption not rejected at 5% level (p=" ///
                as res %6.4f `p_add' as txt ")"
        }
        di as txt "  Q_diff = Q_cNMA - Q_NMA ~ chi^2(df),  df = n_combos"
    }

    /* -- optional: test specified interactions --------------------------------- */
    if `"`interact'"' != "" {
        di _n
        cnma_interact `interact', level(`level')
    }

    di as txt "{hline 78}"
end
