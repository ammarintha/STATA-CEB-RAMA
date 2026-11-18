*! cnma version 3.1  14nov2026
*! Frequentist Component Network Meta-Analysis using mvmeta
*!
*! Author : Ammarin Thakkinstian
*!          Department of Epidemiology, Faculty of Medicine Ramathibodi Hospital
*!          Mahidol University, Bangkok, Thailand
*!          ammarin.tha@mahidol.ac.th
*!
*! Method : Additive component model estimated via multivariate meta-analysis
*!          (mvmeta, Ian White).  Network contrast structure and multi-arm
*!          covariance are handled by network setup (Ian White).
*!
*! v3.0.0 : Fully automatic component detection from treatment names using '_'
*!          as the combination separator.  No component mapping required.
*!          Three input formats:
*!            A) Wide data        : tvar(stub) y(stub) sd(stub) n(stub)
*!                                  One row per study; arm variables t1,t2,t3...
*!                                  Raw data (outcome, SD, N per arm)
*!            B) Long data        : treat(varname) y(var) sd(var) n(var)
*!                                  One row per study-arm; raw outcome data
*!            C) Precomputed data : treat(varname) y(var) se(var)
*!                                  One row per study-arm; pre-computed effect
*!                                  sizes (MD+SE, lnOR+selnOR, SMD+SE, etc.)
*!          Combination treatments are named with _ joining components,
*!          e.g. FES_TMShigh, NMES_rPMS.  Individual component names must
*!          NOT contain underscores.
*!
*! Required packages (install via SSC):
*!   ssc install network
*!   ssc install mvmeta
*!
*! References:
*!   Rucker G et al (2020).  Component network meta-analysis.  Methods.
*!   White IR (2011).  Multivariate random-effects meta-regression.  Stata J.
*!   White IR et al (2012).  Network meta-analysis in Stata.  Stata J.

cap program drop cnma
cap program drop cnma_Display
cap program drop cnma_test
cap program drop cnma_interact
cap program drop cnma_forest
cap program drop cnma_map
cap program drop cnma_rank

program define cnma, eclass
    version 14.0

    /* -- Replay ----------------------------------------------------------- */
    if !strpos(lower(`"`0'"'), "study(") & !strpos(lower(`"`0'"'), "stu(") {
        if `"`e(cmd)'"' != "cnma" {
            di as err "Last estimation results not found or not from cnma"
            error 301
        }
        syntax [, LEVel(cilevel) NOHEADer]
        if "`level'" == "" local level = e(level)
        if "`noheader'" == "" cnma_Display, level(`level')
        exit
    }

    /* -- Syntax ------------------------------------------------------------ */
    syntax [if] [in] , ///
        STUdy(varname)              ///  Study identifier
        [                           ///
        TREat(varname)              ///  Treatment name variable -- Format B (long) or C (precomputed)
        TVAR(string)                ///  Arm-treatment stub (t1,t2,t3...) -- Format A (wide)
        Y(string asis)              ///  Outcome variable or stub (required)
        D(string asis)              ///  Events variable - alias for y() for binary outcomes
        SE(string asis)             ///  SE variable -- Format C: pre-computed effect size SE
        SD(string asis)             ///  SD variable or stub -- Formats A and B
        N(string asis)              ///  N variable or stub -- Formats A and B
        TRTList(string asis)        ///  Treatment names -- alternative wide-by-treatment layout
        REFerence(string)           ///  Reference treatment name (REQUIRED)
        MEAsure(string)             ///  md (default) | smd | or | rr | hr
        METHod(string)              ///  reml (default) | ml | fegls
        INTERaction                 ///  (reserved for future use)
        LEVel(cilevel)              ///
        NOHEADer                    ///
        SAVEcontrasts(string asis)  ///  Save contrast dataset to file
        REPLACE                     ///
        ]

    /* -- Defaults ---------------------------------------------------------- */
    if "`level'"   == "" local level = c(level)
    if "`measure'" == "" local measure "md"
    if "`method'"  == "" local method "reml"
    local method = lower("`method'")
    if !inlist("`method'", "reml", "ml", "fegls") {
        di as err "method() must be one of: reml (default) | ml | fegls"
        exit 198
    }
    // mvmeta method string (fegls uses reml for estimation, fegls only for test)
    local mvmeta_method = cond("`method'" == "ml", "ml", "reml")
    local measure = lower("`measure'")
    if !inlist("`measure'", "md", "smd", "or", "rr", "rd", "hr") {
        di as err "measure() must be one of: md smd or rr rd hr"
        exit 198
    }
    if `"`reference'"' == "" {
        di as err "ref() is required: specify the reference (control) treatment name."
        exit 198
    }

    /* -- d() as alias for y() (binary outcome convenience option) ----------- */
    if `"`d'"' != "" & `"`y'"' != "" {
        di as err "Specify either y() or d() for the outcome, not both."
        exit 198
    }
    if `"`d'"' != "" local y `"`d'"'

    if `"`y'"' == "" {
        di as err "y() or d() is required: specify the outcome variable or stub."
        exit 198
    }

    /* -- Format detection -------------------------------------------------- */
    //  Format A (wide data)        : tvar() specified
    //                                One row per study; raw arm data (y/sd/n stubs)
    //  Format B (long data)        : treat() specified, sd()/n() provided
    //                                One row per study-arm; raw outcome data
    //  Format C (precomputed data) : treat() specified, se() provided (no sd/n)
    //                                One row per study-arm; MD+SE, lnOR+selnOR, etc.
    local fmtA = ("`tvar'"  != "")
    local fmtB = ("`treat'" != "")
    local fmtC = (!`fmtA' & !`fmtB')
    local useSE = ("`se'" != "")

    /* -- Cross-option validation ------------------------------------------- */
    if `fmtA' & `fmtB' {
        di as err "Specify either tvar() for wide-by-arm OR treat() for long format, not both."
        exit 198
    }
    if `fmtC' & `"`trtlist'"' == "" {
        di as err "No format detected.  Specify one of:"
        di as err "  treat(varname)        long format (one row per arm)"
        di as err "  tvar(stub)            wide-by-arm (t1, t2, t3, ...)"
        di as err "  trtlist(names)        wide-by-treatment (yA sdA nA, ...)"
        exit 198
    }
    if `useSE' & ("`sd'" != "" | "`n'" != "") {
        di as err "se() and sd()/n() are mutually exclusive."
        exit 198
    }
    local _is_binary = inlist("`measure'", "or", "rr", "rd", "hr")
    if !`useSE' & !`_is_binary' & ("`sd'" == "" | "`n'" == "") {
        di as err "Provide sd() and n() for arm-level summary data,"
        di as err "   or se() for pre-computed contrasts."
        exit 198
    }
    if !`useSE' & `_is_binary' & "`n'" == "" {
        di as err "Provide n() for binary arm-level data (measure=`measure')."
        exit 198
    }
    if `fmtA' & `useSE' {
        di as err "Wide-by-arm format (tvar) requires sd() and n(), not se()."
        exit 198
    }
    if `fmtC' & `useSE' {
        di as err "Wide-by-treatment format (trtlist) requires sd() and n(), not se()."
        exit 198
    }

    /* -- Dependency check -------------------------------------------------- */
    foreach pkg in network mvmeta {
        capture which `pkg'
        if _rc {
            di as err "cnma requires the {cmd:`pkg'} package."
            di as err "Install it with:  {stata ssc install `pkg'}"
            exit 198
        }
    }

    /* -- Mark sample ------------------------------------------------------- */
    marksample touse
    qui count if `touse'
    if r(N) == 0 error 2000

    /* ======================================================================
       SAVE ORIGINAL DATA TO TEMPFILE
       We use tempfile + save/use instead of preserve/restore to avoid
       r(621) "already preserved" when network setup calls preserve internally.
       ====================================================================== */

    tempfile _cnma_origdata
    qui save `_cnma_origdata'
    qui keep if `touse'

    /* ======================================================================
       CONVERT ALL FORMATS TO INTERNAL LONG FORMAT
       Internal variables (created in working copy of data):
         _cnma_study  -- study identifier
         _cnma_treat  -- treatment name (string, combinations use _)
         _cnma_y      -- outcome
         _cnma_sd     -- SD       ]  arm-level mode
         _cnma_n      -- N        ]
         _cnma_se     -- SE       ]  contrast mode
       ====================================================================== */

    /* ---------------------------------------------------------------------
       FORMAT A: wide-by-arm  (t1 t2 t3 ... , y1 y2 y3 ... , etc.)
       --------------------------------------------------------------------- */
    if `fmtA' {
        // Count arm columns
        local max_arms 0
        forvalues arm = 1/50 {
            capture confirm variable `tvar'`arm'
            if _rc {
                local max_arms = `arm' - 1
                continue, break
            }
            local max_arms `arm'
        }
        if `max_arms' == 0 {
            di as err "No variables found matching stub '`tvar''1, '`tvar''2, ..."
            di as err "Check tvar() stub name."
            qui use `_cnma_origdata', clear
            exit 111
        }

        // Keep only needed variables
        local keep_vars "`study'"
        forvalues arm = 1/`max_arms' {
            foreach stub in `tvar' `y' `sd' `n' {
                capture confirm variable `stub'`arm'
                if !_rc local keep_vars "`keep_vars' `stub'`arm'"
            }
        }
        keep `keep_vars'

        // Reshape to long
        qui reshape long `tvar' `y' `sd' `n', i(`study') j(_cnma_arm)
        drop if missing(`tvar') | strtrim(`tvar') == ""
        drop _cnma_arm

        // Rename to internal names
        rename `study' _cnma_study
        rename `tvar'  _cnma_treat
        rename `y'     _cnma_y
        if `"`sd'"' != "" rename `sd' _cnma_sd
        rename `n'     _cnma_n

        local inputmode "wide-arm"
    }

    /* ---------------------------------------------------------------------
       FORMAT B: long  (one row per arm, treat() is a string variable)
       --------------------------------------------------------------------- */
    else if `fmtB' {
        // Check treat variable type
        capture confirm string variable `treat'
        if _rc {
            // Numeric treatment variable -- decode to string
            capture confirm numeric variable `treat'
            if _rc {
                di as err "treat(): variable '`treat'' not found."
                qui use `_cnma_origdata', clear
                exit 111
            }
            capture decode `treat', gen(_cnma_treat)
            if _rc {
                di as err "treat(): could not decode '`treat'' to string."
                di as err "Apply: label define ... and label values ... first, or use a string variable."
                qui use `_cnma_origdata', clear
                exit 111
            }
        }
        else {
            clonevar _cnma_treat = `treat'
        }

        // Outcome
        capture confirm numeric variable `y'
        if _rc {
            di as err "y(): variable '`y'' not found or not numeric."
            qui use `_cnma_origdata', clear
            exit 111
        }
        clonevar _cnma_y = `y'

        // SE or SD+N
        if `useSE' {
            capture confirm numeric variable `se'
            if _rc {
                di as err "se(): variable '`se'' not found or not numeric."
                qui use `_cnma_origdata', clear
                exit 111
            }
            clonevar _cnma_se = `se'
        }
        else {
            // SD required only for MD/SMD; binary measures (or/rr/rd) need y+n only
            local _need_sd = inlist("`measure'", "md", "smd")
            if `_need_sd' & `"`sd'"' == "" {
                di as err "sd() is required for measure(`measure')."
                di as err "For binary outcomes use measure(or), measure(rr), or measure(rd)."
                qui use `_cnma_origdata', clear
                exit 198
            }
            capture confirm numeric variable `n'
            if _rc {
                di as err "n(): variable '`n'' not found or not numeric."
                qui use `_cnma_origdata', clear
                exit 111
            }
            if `_need_sd' & `"`sd'"' != "" {
                capture confirm numeric variable `sd'
                if _rc {
                    di as err "sd(): variable '`sd'' not found or not numeric."
                    qui use `_cnma_origdata', clear
                    exit 111
                }
                clonevar _cnma_sd = `sd'
            }
            clonevar _cnma_n = `n'
        }

        rename `study' _cnma_study

        if `useSE' local inputmode "long-se"
        else        local inputmode "long-ysdN"
    }

    /* ---------------------------------------------------------------------
       FORMAT C: wide-by-treatment  (yA sdA nA yB sdB nB ...)
                 trtlist() gives treatment names.
                 Columns are y{letter} where letter = A for 1st in sorted
                 trtlist, B for 2nd, etc.  Or y{name} if using actual names.
       --------------------------------------------------------------------- */
    else {
        local trt_words `trtlist'
        local nt_c : word count `trt_words'
        if `nt_c' < 2 {
            di as err "trtlist() must list at least 2 treatment names."
            qui use `_cnma_origdata', clear
            exit 198
        }

        // Check whether columns use letter codes (yA, yB...) or actual names (yFES...)
        capture confirm variable `y'A
        local use_letters = (!_rc)

        if `use_letters' {
            // Sort trtlist alphabetically -> assign A, B, C ...
            local sorted "`trt_words'"
            local swapped 1
            while `swapped' {
                local swapped 0
                local new_sorted ""
                local prev_word ""
                local cnt 0
                foreach w of local sorted {
                    local ++cnt
                    if `cnt' == 1 {
                        local prev_word "`w'"
                        continue
                    }
                    if `"`prev_word'"' > `"`w'"' {
                        local new_sorted "`new_sorted' `w' `prev_word'"
                        local swapped 1
                        local prev_word ""
                        local cnt 0
                    }
                    else {
                        local new_sorted "`new_sorted' `prev_word'"
                        local prev_word "`w'"
                    }
                }
                if `"`prev_word'"' != "" local new_sorted "`new_sorted' `prev_word'"
                local sorted = strtrim("`new_sorted'")
            }

            // Assign letters: A=1st, B=2nd, ...
            local letters "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z"
            local ntc : word count `sorted'
            if `ntc' > 26 {
                di as err "Wide-by-treatment format supports up to 26 treatments (A-Z)."
                qui use `_cnma_origdata', clear
                exit 198
            }

            // Keep only columns for this format
            local keep_vars_c "`study'"
            forvalues i = 1/`ntc' {
                local let : word `i' of `letters'
                capture confirm variable `y'`let'
                if _rc {
                    di as err "Variable `y'`let' not found for treatment `: word `i' of `sorted''."
                    qui use `_cnma_origdata', clear
                    exit 111
                }
                local keep_vars_c "`keep_vars_c' `y'`let' `sd'`let' `n'`let'"
            }
            keep `keep_vars_c'

            // Reshape to long
            qui gen _cnma_study = `study'
            drop `study'
            qui gen _obsn = _n
            qui reshape long `y' `sd' `n', i(_obsn) j(_cnma_letter) string
            rename `y'  _cnma_y
            rename `sd' _cnma_sd
            rename `n'  _cnma_n

            // Map letter -> treatment name from sorted list
            qui gen _cnma_treat = ""
            forvalues i = 1/`ntc' {
                local let  : word `i' of `letters'
                local tnam : word `i' of `sorted'
                qui replace _cnma_treat = `"`tnam'"' if _cnma_letter == "`let'"
            }
            drop if missing(_cnma_y) | _cnma_treat == ""
            drop _obsn _cnma_letter
        }
        else {
            // Name-coded columns: y{name}, sd{name}, n{name}
            local keep_vars_c "`study'"
            foreach tnam of local trt_words {
                capture confirm variable `y'`tnam'
                if _rc {
                    di as err "Variable `y'`tnam' not found."
                    qui use `_cnma_origdata', clear
                    exit 111
                }
                local keep_vars_c "`keep_vars_c' `y'`tnam' `sd'`tnam' `n'`tnam'"
            }
            keep `keep_vars_c'

            // Rename study and save wide-format data to tempfile for iterative loading
            qui gen _cnma_study = `study'
            drop `study'

            tempfile _cnma_wide_c _cnma_long_c
            qui save `_cnma_wide_c', replace

            local first 1
            local _need_sd_c = inlist("`measure'", "md", "smd")
            foreach tnam of local trt_words {
                qui use `_cnma_wide_c', clear
                if `_need_sd_c' & `"`sd'"' != "" {
                    keep _cnma_study `y'`tnam' `sd'`tnam' `n'`tnam'
                }
                else {
                    keep _cnma_study `y'`tnam' `n'`tnam'
                }
                qui rename `y'`tnam' _cnma_y
                if `_need_sd_c' & `"`sd'"' != "" {
                    qui rename `sd'`tnam' _cnma_sd
                }
                qui rename `n'`tnam' _cnma_n
                qui gen _cnma_treat = "`tnam'"
                if `first' {
                    qui save `_cnma_long_c', replace
                    local first 0
                }
                else {
                    qui append using `_cnma_long_c'
                    qui save `_cnma_long_c', replace
                }
            }
            qui use `_cnma_long_c', clear
            drop if missing(_cnma_y) | _cnma_treat == ""
        }

        local inputmode "wide-trt"
    }

    /* ======================================================================
       NOW IN INTERNAL LONG FORMAT
       Clean treatment names and validate
       ====================================================================== */

    // Trim whitespace
    qui replace _cnma_treat = strtrim(_cnma_treat)

    // Drop missing treatment rows
    drop if missing(_cnma_treat) | _cnma_treat == ""

    // No spaces allowed in treatment names
    qui count if strpos(_cnma_treat, " ") > 0
    if r(N) > 0 {
        di as err "Treatment names must not contain spaces."
        di as err "Replace spaces with _ in treatment name values."
        qui use `_cnma_origdata', clear
        exit 198
    }

    /* -- Get all unique treatment names ------------------------------------ */
    qui levelsof _cnma_treat, local(all_trts)
    local nt : word count `all_trts'

    if `nt' < 2 {
        di as err "At least 2 distinct treatments required; found `nt'."
        qui use `_cnma_origdata', clear
        exit 198
    }

    /* -- Validate reference ------------------------------------------------ */
    local ref_cat "`reference'"
    local ref_found 0
    foreach t of local all_trts {
        if `"`t'"' == `"`ref_cat'"' local ref_found 1
    }
    if !`ref_found' {
        di as err "Reference treatment '`ref_cat'' not found in the data."
        di as err "Found treatments: `all_trts'"
        qui use `_cnma_origdata', clear
        exit 198
    }

    /* -- Count studies ----------------------------------------------------- */
    qui levelsof _cnma_study, local(study_list)
    local n_stud : word count `study_list'

    /* ======================================================================
       AUTO-DETECT COMPONENTS
       Split each non-reference treatment name by '_'.
       Unique tokens across all non-reference treatments = components.
       Reference treatment gets all-zero component coding automatically.
       ====================================================================== */

    local comp_list ""

    foreach trt of local all_trts {
        if `"`trt'"' == `"`ref_cat'"' continue   // reference -> skip

        // Split treatment name by underscore
        local tname "`trt'"
        while length("`tname'") > 0 {
            local us = strpos("`tname'", "_")
            if `us' == 0 {
                local part "`tname'"
                local tname ""
            }
            else {
                local part = substr("`tname'", 1, `us' - 1)
                local tname = substr("`tname'", `us' + 1, .)
            }
            if `"`part'"' == "" continue

            // Add to comp_list if not already present
            local already 0
            foreach c of local comp_list {
                if `"`c'"' == `"`part'"' local already 1
            }
            if !`already' local comp_list `comp_list' `part'
        }
    }

    local nc : word count `comp_list'
    if `nc' == 0 {
        di as err "No components detected from treatment names."
        di as err "Ensure combination treatments use '_' separator (e.g. FES_TMShigh)."
        di as err "Individual component names must not contain '_'."
        qui use `_cnma_origdata', clear
        exit 198
    }

    di as txt "(`nc' components auto-detected: `comp_list')"

    /* ======================================================================
       BUILD COMPONENT CODING for each treatment
       ====================================================================== */

    local tidx = 0
    foreach trt of local all_trts {
        local ++tidx
        local _cnma_trt`tidx' "`trt'"

        // Split treatment name by underscore to get its parts
        local parts ""
        local tname "`trt'"
        while length("`tname'") > 0 {
            local us = strpos("`tname'", "_")
            if `us' == 0 {
                local parts `parts' `tname'
                local tname ""
            }
            else {
                local p = substr("`tname'", 1, `us' - 1)
                local parts `parts' `p'
                local tname = substr("`tname'", `us' + 1, .)
            }
        }

        // Assign 0/1 for each component
        local k = 0
        foreach comp of local comp_list {
            local ++k
            local found 0
            foreach part of local parts {
                if `"`part'"' == `"`comp'"' local found 1
            }
            local _cnma_code_t`tidx'_k`k' `found'
        }
    }

    // Reference treatment index
    local ref_idx 0
    forvalues tidx = 1/`nt' {
        if `"`_cnma_trt`tidx''"' == `"`ref_cat'"' local ref_idx `tidx'
    }

    /* ======================================================================
       PRE-COMPUTE CONTRASTS (for SMD / binary measures)
       MD  -> arm-level (y, sd, n) passed directly to network setup, which
             computes mean differences internally (handles multi-arm
             within-study covariance automatically).
       SMD -> compute Hedges' g per arm vs reference, derive SE.
       OR / RR / RD -> compute from arm-level events+N vs reference arm;
             continuity correction (+0.5) applied when any cell = 0.
       All non-MD paths switch to the useSE=1 (contrast-level) path after.
       NOTE: within-study covariance for multi-arm trials is handled exactly
       only for MD; for other measures the diagonal approximation is used.
       ====================================================================== */

    if !`useSE' & "`measure'" != "md" {

        /* Ensure _cnma_se variable exists */
        cap confirm var _cnma_se
        if _rc qui gen double _cnma_se = .

        /* Reference arm indicator */
        tempvar _is_ref
        qui gen byte `_is_ref' = (_cnma_treat == "`ref_cat'")

        /* Reference arm y and n broadcast to all rows of same study */
        tempvar _yref _nref
        qui bysort _cnma_study: egen double `_yref' = total(_cnma_y * `_is_ref')
        qui bysort _cnma_study: egen double `_nref' = total(_cnma_n * `_is_ref')

        /* -- SMD ----------------------------------------------------------- */
        if "`measure'" == "smd" {
            tempvar _ss_num _ss_den _sdpool _smd
            qui bysort _cnma_study: ///
                egen double `_ss_num' = total((_cnma_n - 1) * _cnma_sd^2)
            qui bysort _cnma_study: ///
                egen double `_ss_den' = total(_cnma_n - 1)
            qui gen double `_sdpool' = sqrt(`_ss_num' / `_ss_den')
            qui gen double `_smd'    = (_cnma_y - `_yref') / `_sdpool'
            /* SE -- Hedges approximation */
            qui replace _cnma_se = sqrt((`_nref' + _cnma_n) / (`_nref' * _cnma_n) + ///
                                        `_smd'^2 / (2 * (`_nref' + _cnma_n - 2)))
            qui replace _cnma_y  = `_smd'
        }

        /* -- Binary: OR, RR, RD ------------------------------------------- */
        else if inlist("`measure'", "or", "rr", "rd") {
            /* Continuity correction if any zero cell in the study */
            tempvar _cellmin _cc _ek _nk _er _nr
            qui bysort _cnma_study: ///
                egen `_cellmin' = min(min(_cnma_y, _cnma_n - _cnma_y))
            qui gen byte `_cc' = (`_cellmin' == 0)
            qui gen double `_ek' = _cnma_y + 0.5 * `_cc'
            qui gen double `_nk' = _cnma_n + 1.0 * `_cc'
            qui bysort _cnma_study: ///
                egen double `_er' = total(`_ek' * `_is_ref')
            qui bysort _cnma_study: ///
                egen double `_nr' = total(`_nk' * `_is_ref')

            if "`measure'" == "or" {
                qui replace _cnma_y  = log(`_ek' * (`_nr' - `_er') / ///
                                           (`_er' * (`_nk' - `_ek')))
                qui replace _cnma_se = sqrt(1/`_ek' + 1/(`_nk' - `_ek') + ///
                                            1/`_er' + 1/(`_nr' - `_er'))
            }
            else if "`measure'" == "rr" {
                qui replace _cnma_y  = log((`_ek'/`_nk') / (`_er'/`_nr'))
                qui replace _cnma_se = sqrt(1/`_ek' - 1/`_nk' + ///
                                            1/`_er' - 1/`_nr')
            }
            else {   /* rd */
                tempvar _pk _pr
                qui gen double `_pk' = `_ek' / `_nk'
                qui gen double `_pr' = `_er' / `_nr'
                qui replace _cnma_y  = `_pk' - `_pr'
                qui replace _cnma_se = sqrt(`_pk'*(1-`_pk')/`_nk' + ///
                                            `_pr'*(1-`_pr')/`_nr')
            }
        }

        /* Drop reference-arm rows (contrast vs itself = 0) */
        qui drop if `_is_ref'

        /* Switch to contrast-level path */
        local useSE 1
    }

    /* ======================================================================
       CALL network setup
       (network setup uses preserve internally; since we are NOT inside a
        preserve block here, there is no nesting conflict.)
       ====================================================================== */

    if `useSE' {
        qui network setup _cnma_y _cnma_se, ///
            studyvar(_cnma_study)            ///
            trtvar(_cnma_treat)              ///
            ref(`"`ref_cat'"')               ///
            nocodes                          ///
            armvars(drop)
    }
    else {
        /* else branch = MD only (SMD/OR/RR/RD all set useSE=1 above) */
        qui network setup _cnma_y _cnma_sd _cnma_n, ///
            studyvar(_cnma_study)                    ///
            trtvar(_cnma_treat)                      ///
            ref(`"`ref_cat'"')                       ///
            nocodes                                  ///
            md                                       ///
            armvars(drop)
    }

    /* -- Identify _y_* outcome variables (augmented format after network setup) */
    qui ds _y_*
    local y_varlist `r(varlist)'

    if "`y_varlist'" == "" {
        di as err "No _y_* variables found after network setup."
        di as err "Check that treatment names are valid Stata variable name suffixes."
        qui use `_cnma_origdata', clear
        exit 198
    }

    /* ======================================================================
       IDENTIFY PURE COMPONENT TREATMENTS
       A treatment whose name has no underscore is "pure" -- it has exactly
       one component whose name equals the treatment name (e.g., "FES").
       Map component index k -> treatment name for constraint building.
       NOTE: component names must not themselves contain '_'.
       ====================================================================== */

    forvalues k = 1/`nc' {
        local pure_trt_`k' ""
    }

    forvalues tidx = 1/`nt' {
        local trt "`_cnma_trt`tidx''"
        if `"`trt'"' == `"`ref_cat'"' continue

        // Count underscores: 0 means single-component (pure) treatment
        local us_count = length("`trt'") - length(subinstr("`trt'", "_", "", .))
        if `us_count' == 0 {
            // Treatment name IS the component name
            local k = 0
            foreach comp of local comp_list {
                local ++k
                if `"`comp'"' == `"`trt'"' {
                    local pure_trt_`k' "`trt'"
                }
            }
        }
    }

    // Warn about components with no pure single-component treatment
    forvalues k = 1/`nc' {
        local comp : word `k' of `comp_list'
        if `"`pure_trt_`k''"' == "" {
            di as txt "Warning: component '`comp'' has no single-component treatment."
            di as txt "         Additivity constraints involving '`comp'' will be omitted."
        }
    }

    /* ======================================================================
       BUILD ADDITIVITY CONSTRAINTS
       For each multi-component treatment T = C1_C2_... (2+ parts):
         constraint N  [_y_T]_cons - [_y_C1]_cons - [_y_C2]_cons - ... = 0
       Only defined when every component Ci has its own pure treatment.
       ====================================================================== */

    constraint drop _all    // clear any pre-existing constraints

    local con_nums  ""
    local con_n     = 0
    local combo_list ""   // multi-component (combination) treatments, in order

    forvalues tidx = 1/`nt' {
        local trt "`_cnma_trt`tidx''"
        if `"`trt'"' == `"`ref_cat'"' continue

        // Skip pure (single-component) treatments
        local us_count = length("`trt'") - length(subinstr("`trt'", "_", "", .))
        if `us_count' == 0 continue

        // Record this as a combination treatment
        local combo_list `combo_list' `trt'

        // Parse component parts (split on _)
        local parts ""
        local t2 "`trt'"
        while length("`t2'") > 0 {
            local us = strpos("`t2'", "_")
            if `us' == 0 {
                local parts `parts' `t2'
                local t2 ""
            }
            else {
                local p = substr("`t2'", 1, `us'-1)
                local parts `parts' `p'
                local t2 = substr("`t2'", `us'+1, .)
            }
        }

        // Build constraint: [_y_T]_cons - [_y_C1]_cons - [_y_C2]_cons - ... = 0
        local can_constrain 1
        local con_expr "[_y_`trt']_cons"
        foreach part of local parts {
            local fk = 0
            local k = 0
            foreach comp of local comp_list {
                local ++k
                if `"`comp'"' == `"`part'"' local fk `k'
            }
            if `fk' > 0 & `"`pure_trt_`fk''"' != "" {
                local con_expr "`con_expr' - [_y_`pure_trt_`fk'']_cons"
            }
            else {
                local can_constrain 0
                di as txt "Note: skipping constraint for `trt'" ///
                    " (component `part' has no pure single-component treatment)."
            }
        }

        if `can_constrain' {
            local ++con_n
            constraint `con_n' `con_expr' = 0
            local con_nums `con_nums' `con_n'
        }
    }

    di as txt "(`con_n' additivity constraint(s) applied)"

    /* ======================================================================
       RUN mvmeta (constraint-based cNMA)
       Augmented format: y-stub = _y, S-stub = _S
       bscovariance(exch 0.5): exchangeable between-study covariance
       longparm: return all treatment parameters in e(b)
       suppress(uv mm): suppress univariate and MM output
       ====================================================================== */

    // Optional: save the augmented dataset before mvmeta
    if `"`savecontrasts'"' != "" {
        qui save `"`savecontrasts'"', `replace'
        di as txt "(Augmented dataset saved to `savecontrasts')"
    }

    /* -- Save augmented dataset for cnma_interact (persistent temp file) -- */
    local _cnma_cf "`c(tmpdir)'/_cnma_aug_data.dta"
    qui save "`_cnma_cf'", replace

    /* -- mvmeta method option: only pass when non-default (ml) ------------- */
    /* Older mvmeta versions do not accept method(); reml is the default.    */
    local _meth_opt = cond("`mvmeta_method'" == "ml", "method(ml)", "")

    /* -- Unconstrained sNMA (needed for LR test) --------------------------- */
    local ll_sNMA  = .
    local tau2_sNMA = .
    if "`method'" != "fegls" {
        qui mvmeta _y _S, vars(`y_varlist') ///
            bscovariance(exch 0.5) longparm suppress(uv mm) ///
            `_meth_opt' level(`level')
        local ll_sNMA = e(ll)
        tempname _Sig_sNMA
        capture matrix `_Sig_sNMA' = e(Sigma)
        capture local tau2_sNMA = `_Sig_sNMA'[1,1]
    }

    /* -- Constrained cNMA -------------------------------------------------- */
    if `"`con_nums'"' != "" {
        qui mvmeta _y _S, vars(`y_varlist') constraints(`con_nums') ///
            bscovariance(exch 0.5) longparm suppress(uv mm) ///
            `_meth_opt' level(`level')
    }
    else {
        qui mvmeta _y _S, vars(`y_varlist') ///
            bscovariance(exch 0.5) longparm suppress(uv mm) ///
            `_meth_opt' level(`level')
    }

    // Drop the transient constraints we defined
    if `con_n' > 0 constraint drop `con_nums'

    /* -- Capture cNMA log-likelihood and tau2 ------------------------------ */
    local ll_cNMA  = e(ll)
    local tau2_cNMA = .
    tempname _Sig_cNMA
    capture matrix `_Sig_cNMA' = e(Sigma)
    capture local tau2_cNMA = `_Sig_cNMA'[1,1]

    /* -- LR test statistics ------------------------------------------------ */
    local LR_add  = .
    local df_LR_add = .
    local p_LR_add  = .
    if "`method'" != "fegls" & !missing(`ll_sNMA') & !missing(`ll_cNMA') {
        local LR_add    = 2 * (`ll_sNMA' - `ll_cNMA')
        // df = n_nonref - n_components = number of additivity constraints applied
        local df_LR_add = `con_n'
        if `df_LR_add' > 0 {
            local p_LR_add = chi2tail(`df_LR_add', `LR_add')
        }
    }

    /* -- Capture all results before restoring data ------------------------- */
    tempname b_full V_full Sigma_mat
    matrix `b_full' = e(b)
    matrix `V_full' = e(V)
    capture matrix `Sigma_mat' = e(Sigma)

    local mvmeta_N    = e(N)
    local mvmeta_ll   = e(ll)
    local mvmeta_conv = e(converged)

    // Tau^2 from first diagonal of between-study covariance matrix e(Sigma)
    local mvmeta_tau2 = .
    capture local mvmeta_tau2 = `Sigma_mat'[1,1]

    // Q heterogeneity test (captured safely; scalar names vary across mvmeta versions)
    local mvmeta_Q   = .
    local mvmeta_Qdf = .
    local mvmeta_pQ  = .
    capture local mvmeta_Q   = e(Q)
    capture local mvmeta_Qdf = e(Q_df)
    if missing(`mvmeta_Qdf') capture local mvmeta_Qdf = e(Qdf)
    capture local mvmeta_pQ  = e(p_Q)
    if missing(`mvmeta_pQ') & !missing(`mvmeta_Q') & !missing(`mvmeta_Qdf') {
        capture local mvmeta_pQ = chi2tail(`mvmeta_Qdf', `mvmeta_Q')
    }

    /* -- Extract component effects from pure-component treatment coefficients */
    // Find the column index in b_full for each component's pure treatment
    local cnames_full : colfullnames `b_full'

    local valid_cidx  ""   // column indices in b_full (one per found component)
    local valid_comps ""   // component names for those found

    local k = 0
    foreach comp of local comp_list {
        local ++k
        local ptrt "`pure_trt_`k''"
        if `"`ptrt'"' == "" continue

        local cidx = 0
        local col  = 0
        foreach cn of local cnames_full {
            local ++col
            if `"`cn'"' == "_y_`ptrt':_cons" {
                local cidx `col'
            }
        }
        if `cidx' > 0 {
            local valid_cidx  `valid_cidx'  `cidx'
            local valid_comps `valid_comps' `comp'
        }
    }

    local nc_found : word count `valid_comps'

    // Build b (1 x nc_found) and V (nc_found x nc_found) for ereturn post
    tempname b V
    if `nc_found' > 0 {
        matrix `b' = J(1, `nc_found', 0)
        matrix `V' = J(`nc_found', `nc_found', 0)
        forvalues i = 1/`nc_found' {
            local ci : word `i' of `valid_cidx'
            matrix `b'[1, `i'] = `b_full'[1, `ci']
            forvalues j = 1/`nc_found' {
                local cj : word `j' of `valid_cidx'
                matrix `V'[`i', `j'] = `V_full'[`ci', `cj']
            }
        }
        // Label coefficients by component name (use for ereturn display & lincom)
        local comp_cnames ""
        foreach comp of local valid_comps {
            local comp_cnames `comp_cnames' `comp'
        }
        matrix colnames `b' = `comp_cnames'
        matrix rownames `V' = `comp_cnames'
        matrix colnames `V' = `comp_cnames'
    }
    else {
        // Fallback: post full mvmeta output if component extraction failed
        matrix `b' = `b_full'
        matrix `V' = `V_full'
    }

    /* -- Build nonref_list (order matches columns in b_full / V_full) ---- */
    local nonref_list ""
    foreach yv of local y_varlist {
        local nonref_list `nonref_list' `= substr("`yv'", 4, .)'
    }

    /* -- FE-GLS additivity Q statistics (continuous outcomes only) ----------- */
    qui ds _S_*
    local _S_varlist "`r(varlist)'"
    tempname _qres
    local Q_nma_fe  = .
    local df_nma_fe = .
    local Q_cnma_fe = .
    local df_cnma_fe= .
    local Q_add     = .
    local df_add    = .
    local p_add     = .
    local _is_binary = inlist("`measure'", "or", "rr", "rd", "hr")
    if !`_is_binary' {
        capture mata: st_matrix("`_qres'", ///
            _cnma_Q_gls("`nonref_list'", "`comp_list'", "`_S_varlist'"))
        if !_rc {
            local Q_nma_fe   = `_qres'[1,1]
            local df_nma_fe  = `_qres'[1,2]
            local Q_cnma_fe  = `_qres'[1,3]
            local df_cnma_fe = `_qres'[1,4]
            local Q_add      = `_qres'[1,5]
            local df_add     = `_qres'[1,6]
            local p_add      = `_qres'[1,7]
        }
    }

    /* ======================================================================
       RESTORE ORIGINAL DATA
       (We must restore before ereturn post so that esample() refers to
        observations in the user's original dataset.)
       ====================================================================== */

    qui use `_cnma_origdata', clear

    /* ======================================================================
       STORE ereturn RESULTS
       ====================================================================== */

    ereturn post `b' `V', obs(`mvmeta_N') esample(`touse') depname("component effect")

    ereturn local  cmd         "cnma"
    ereturn local  method      "frequentist (mvmeta)"
    ereturn local  model       "additive"
    ereturn local  inputmode   "`inputmode'"
    ereturn local  measure     "`measure'"
    ereturn local  reference   `"`ref_cat'"'
    ereturn local  components    "`comp_list'"
    ereturn local  combinations  "`combo_list'"
    ereturn local  studyvar    "`study'"
    if `fmtB' {
        ereturn local  treatvar "`treat'"
        if `useSE' {
            ereturn local sevar "`se'"
        }
        else {
            ereturn local sdvar "`sd'"
            ereturn local nvar  "`n'"
        }
        ereturn local  yvar    "`y'"
    }
    else if `fmtA' {
        ereturn local  tvar  "`tvar'"
        ereturn local  yvar  "`y'"
        ereturn local  sdvar "`sd'"
        ereturn local  nvar  "`n'"
    }
    ereturn scalar n_comp    = `nc'
    ereturn scalar n_studies = `n_stud'
    ereturn scalar n_treat   = `nt'
    ereturn scalar level     = `level'
    if "`mvmeta_ll'"   != "" ereturn scalar ll        = `mvmeta_ll'
    if "`mvmeta_conv'" != "" ereturn scalar converged = `mvmeta_conv'
    if "`mvmeta_tau2'" != "" ereturn scalar tau2      = `mvmeta_tau2'
    if !missing(`mvmeta_Q')   ereturn scalar Q         = `mvmeta_Q'
    if !missing(`mvmeta_Qdf') ereturn scalar Q_df      = `mvmeta_Qdf'
    if !missing(`mvmeta_pQ')  ereturn scalar p_Q       = `mvmeta_pQ'

    // Estimation method
    ereturn local  method_test  "`method'"
    ereturn local  contrasts_file "`_cnma_cf'"

    // Additivity Q statistics (fegls method)
    if !missing(`Q_nma_fe')   ereturn scalar Q_nma_fe  = `Q_nma_fe'
    if !missing(`df_nma_fe')  ereturn scalar df_nma_fe = `df_nma_fe'
    if !missing(`Q_cnma_fe')  ereturn scalar Q_cnma_fe = `Q_cnma_fe'
    if !missing(`df_cnma_fe') ereturn scalar df_cnma_fe= `df_cnma_fe'
    if !missing(`Q_add')      ereturn scalar Q_add     = `Q_add'
    if !missing(`df_add')     ereturn scalar df_add    = `df_add'
    if !missing(`p_add')      ereturn scalar p_add     = `p_add'

    // LR test statistics (ml / reml methods)
    if !missing(`ll_sNMA')    ereturn scalar ll_sNMA   = `ll_sNMA'
    if !missing(`tau2_sNMA')  ereturn scalar tau2_sNMA = `tau2_sNMA'
    if !missing(`ll_cNMA')    ereturn scalar ll_cNMA   = `ll_cNMA'
    if !missing(`tau2_cNMA')  ereturn scalar tau2_cNMA = `tau2_cNMA'
    if !missing(`LR_add')     ereturn scalar LR_add    = `LR_add'
    if !missing(`df_LR_add')  ereturn scalar df_LR_add = `df_LR_add'
    if !missing(`p_LR_add')   ereturn scalar p_LR_add  = `p_LR_add'

    // Full mvmeta matrices and nonref list (needed by cnma_interact)
    ereturn matrix b_full    = `b_full'
    ereturn matrix V_full    = `V_full'
    ereturn local  nonref_list "`nonref_list'"

    /* -- Display ----------------------------------------------------------- */
    if "`noheader'" == "" {
        cnma_Display, level(`level')
    }

end  // end cnma


/* ============================================================================
   Display subroutine  -- R-style output with component + combination tables
   ============================================================================ */
program define cnma_Display
    syntax [, LEVel(cilevel)]
    if "`level'" == "" local level = c(level)

    local alpha  = (100 - `level') / 100
    local z_crit = invnormal(1 - `alpha' / 2)

    local imode `"`e(inputmode)'"'
    local meas  `"`e(measure)'"'
    if "`meas'" == "" local meas "md"
    local ref `"`e(reference)'"'

    local instr ""
    if      "`imode'" == "long-se"   local instr "pre-computed y, SE (contrasts)"
    else if "`imode'" == "long-ysdN" local instr "arm-level y, SD, N  [measure: `meas']"
    else if "`imode'" == "wide-arm"  local instr "wide-by-arm stubs  [measure: `meas']"
    else if "`imode'" == "wide-trt"  local instr "wide-by-treatment stubs  [measure: `meas']"
    else                             local instr "`imode'"

    /* -- Header -------------------------------------------------------- */
    di _n as txt "{hline 78}"
    di as txt " Component Network Meta-Analysis  (Additive Model, Frequentist)"
    di as txt "{hline 78}"
    di as txt "  Method       : mvmeta (multivariate meta-analysis)"
    di as txt "  Input        : " as res "`instr'"
    di as txt "  Reference    : " as res `"`ref'"'
    di as txt "  Components (`e(n_comp)')  : " as res "`e(components)'"
    di as txt "  Studies      : " as res e(n_studies) ///
             as txt "    Treatments : " as res e(n_treat)
    di as txt "  tau^2           : " ///
        as res %8.4f cond(missing(e(tau2)), ., e(tau2))
    if !missing(e(Q)) {
        local i2 = max(0, (e(Q) - e(Q_df)) / e(Q) * 100)
        di as txt "  Q (df=" as res e(Q_df) as txt ")     : " ///
            as res %8.4f e(Q) as txt "   p=" as res %6.4f e(p_Q) ///
            as txt "   I^2=" as res %5.1f `i2' as txt "%"
    }
    di as txt "{hline 78}"

    /* -- Get posted matrices ------------------------------------------- */
    tempname bmat Vmat
    matrix `bmat' = e(b)
    matrix `Vmat' = e(V)
    local cnames : colnames `bmat'
    local nc : word count `cnames'

    /* -- Component effects table --------------------------------------- */
    di _n as txt "  Effect sizes for single components vs. `ref' (additive `meas'):"
    di as txt "  {hline 78}"
    di as txt "  " %14s "Component" ///
              "  " %9s  "ES" ///
              "  " %9s  "SE" ///
              "  " %7s  "z" ///
              "  " %7s  "p-value" ///
              "  " %20s "[`level'% CI]"
    di as txt "  {hline 78}"

    forvalues i = 1/`nc' {
        local comp : word `i' of `cnames'
        local est  = `bmat'[1, `i']
        local se   = sqrt(`Vmat'[`i', `i'])
        local z    = `est' / `se'
        local p    = 2 * (1 - normal(abs(`z')))
        local lb   = `est' - `z_crit' * `se'
        local ub   = `est' + `z_crit' * `se'

        di as txt "  " as res %-14s "`comp'" ///
            as res "  " %9.4f `est' ///
            as res "  " %9.4f `se' ///
            as res "  " %7.3f `z' ///
            as res "  " %7.4f `p' ///
            as res "  " %9.4f `lb' " to " %9.4f `ub'
    }
    di as txt "  {hline 78}"

    /* -- Combination effects table ------------------------------------- */
    local combos `"`e(combinations)'"'
    if `"`combos'"' != "" {
        di _n as txt "  Effect sizes for observed combinations vs. `ref' (additive `meas'):"
        di as txt "  {hline 78}"
        di as txt "  " %21s "Combination" ///
                  "  " %9s  "ES" ///
                  "  " %9s  "SE" ///
                  "  " %7s  "z" ///
                  "  " %7s  "p-value" ///
                  "  " %20s "[`level'% CI]"
        di as txt "  {hline 78}"

        foreach combo of local combos {
            // Parse component parts (split on _)
            local parts ""
            local t2 "`combo'"
            while length("`t2'") > 0 {
                local us = strpos("`t2'", "_")
                if `us' == 0 {
                    local parts `parts' `t2'
                    local t2 ""
                }
                else {
                    local pp = substr("`t2'", 1, `us' - 1)
                    local parts `parts' `pp'
                    local t2 = substr("`t2'", `us' + 1, .)
                }
            }

            // Find column index in bmat for each part
            local combo_valid 1
            local pidx_list ""
            foreach part of local parts {
                local pidx = 0
                local j = 0
                foreach cn of local cnames {
                    local ++j
                    if "`cn'" == "`part'" local pidx `j'
                }
                if `pidx' == 0 {
                    local combo_valid 0
                }
                else {
                    local pidx_list `pidx_list' `pidx'
                }
            }
            if !`combo_valid' continue

            // ES = sum of component effects; Var = sum over all pairs (incl. covariances)
            local est = 0
            local var = 0
            local np : word count `pidx_list'
            forvalues i = 1/`np' {
                local pi : word `i' of `pidx_list'
                local est = `est' + `bmat'[1, `pi']
                forvalues j = 1/`np' {
                    local pj : word `j' of `pidx_list'
                    local var = `var' + `Vmat'[`pi', `pj']
                }
            }
            local se  = sqrt(`var')
            local z   = `est' / `se'
            local p   = 2 * (1 - normal(abs(`z')))
            local lb  = `est' - `z_crit' * `se'
            local ub  = `est' + `z_crit' * `se'

            local clabel = subinstr("`combo'", "_", " + ", .)

            di as txt "  " as res %-21s "`clabel'" ///
                as res "  " %9.4f `est' ///
                as res "  " %9.4f `se' ///
                as res "  " %7.3f `z' ///
                as res "  " %7.4f `p' ///
                as res "  " %9.4f `lb' " to " %9.4f `ub'
        }
        di as txt "  {hline 78}"
    }

    di _n as txt "Notes:"
    di as txt "  * ES = additive effect size vs. reference (`ref')."
    di as txt "  * Combination ES = sum of its component effects (additivity assumption)."
    di as txt "  * Use {cmd:lincom comp1 + comp2} for any combination not listed above."
    di as txt "  * Run {cmd:cnma_rank} to rank components and combinations."
    di as txt "  * Run {cmd:cnma_test} to test the additivity assumption."
end  // end cnma_Display


/* ============================================================================
   Mata: FE-GLS additivity Q statistics
   Returns row vector (Q_nma, df_nma, Q_cnma, df_cnma, Q_diff, df_diff, p_diff)
   ============================================================================ */
mata:
real rowvector _cnma_Q_gls(string scalar nonref_str,
                            string scalar comp_str,
                            string scalar S_varlist_str)
{
    /*STUB1*/
    return(J(1, 7, 0))
}
end

/* ============================================================================
   cnma_test  --  Test the additivity (component) assumption
   ============================================================================ */
program define cnma_test
    if "`e(cmd)'" != "cnma" error 301

    /* Save cnma estimates so post-estimation commands still work after cnma_test */
    tempname _cnma_est_saved
    estimates store `_cnma_est_saved'

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
                  as res %6.0f `df' + `n_combos'
        di as txt "  " %-28s "cNMA (additive)" ///
                  as res %12.4f `llc' ///
                  as res %8.4f cond(missing(`t2c'), ., `t2c') ///
                  as res %6.0f `df' + `n_combos' - `df'
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
        di as txt "  Run {cmd:cnma_interact [combos]} to test specific interactions."
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

    di as txt "{hline 78}"

    /* Restore cnma estimates so post-estimation commands still work */
    estimates restore `_cnma_est_saved'
    cap estimates drop `_cnma_est_saved'
end


/* ============================================================================
   cnma_interact  --  Interaction model: user specifies which combos to free
   Drops additivity constraint(s) for listed combo(s), re-runs mvmeta,
   reports delta = b_combo_free - Sigmab_comps with LR test vs additive cNMA.
   Usage:
       cnma_interact FES_NMES                    // free one combo
       cnma_interact FES_NMES TMShigh_NMES_TMSlow // free two combos
       cnma_interact _all                         // free all (= sNMA)
   ============================================================================ */
program define cnma_interact
    syntax [anything] [, LEVel(cilevel) noLRtest ]
    if "`e(cmd)'" != "cnma" error 301

    local all_combos `"`e(combinations)'"'
    if `"`all_combos'"' == "" {
        di as txt "No observed combinations -- interaction test not applicable."
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
                if "`c'" == "`req'" { local found 1; local free_combos `"`free_combos' `req'"' }
            }
            if !`found' {
                di as err "Combination '`req'' not found in e(combinations): `all_combos'"
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
    local ll_cNMA   = e(ll_cNMA)

    if "`level'" == "" local level = e(level)
    if missing(`level') local level = c(level)
    local alpha  = (100 - `level') / 100
    local z_crit = invnormal(1 - `alpha' / 2)

    // Reconstruct y_varlist as space-separated _y_TREAT names
    local y_vars ""
    foreach nr of local nonref { local y_vars "`y_vars' _y_`nr'" }

    if `"`cf'"' == "" | !fileexists(`"`cf'"') {
        di as err "Augmented contrast dataset not found. Re-run cnma."
        exit 498
    }

    // Determine mvmeta method
    local mvmeta_meth = cond("`meth'" == "ml", "ml", "reml")
    local _meth_opt_int = cond("`mvmeta_meth'" == "ml", "method(ml)", "")

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
            if `us'==0 { local parts `parts' `t2'; local t2 "" }
            else { local parts `parts' `=substr("`t2'",1,`us'-1)'; local t2=substr("`t2'",`us'+1,.) }
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
            `_meth_opt_int' level(`level')
    }
    else {
        // All combos freed = unconstrained sNMA
        qui mvmeta _y _S, vars(`y_vars') ///
            bscovariance(exch 0.5) longparm suppress(uv mm) ///
            `_meth_opt_int' level(`level')
    }
    if `con_n_int' > 0 constraint drop `con_nums_int'

    local ll_int  = e(ll)
    local tau2_int = .
    tempname _Sig_int
    capture matrix `_Sig_int' = e(Sigma)
    capture local tau2_int = `_Sig_int'[1,1]

    // LR test: interaction model vs additive cNMA
    local LR_int  = .
    local p_LR_int = .
    if "`lrtest'" != "nolrtest" & !missing(`ll_cNMA') & !missing(`ll_int') {
        local LR_int   = 2 * (`ll_int' - `ll_cNMA')
        local p_LR_int = chi2tail(`n_free', `LR_int')
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
        local combo_col = 0; local col = 0
        foreach cn of local cnames_int {
            local ++col
            local tname = substr("`cn'", 4, strpos("`cn'", ":") - 4)
            if "`tname'" == "`combo'" local combo_col `col'
        }

        // Find component cols
        local parts ""; local t2 "`combo'"
        while length("`t2'") > 0 {
            local us = strpos("`t2'", "_")
            if `us'==0 { local parts `parts' `t2'; local t2 "" }
            else { local parts `parts' `=substr("`t2'",1,`us'-1)'; local t2=substr("`t2'",`us'+1,.) }
        }
        local part_cols ""
        foreach part of local parts {
            local pcol=0; local col=0
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
        local clabel = subinstr("`combo'", "_", " + ", .)

        di as txt "  " %-22s "`clabel'" ///
            as res %10.4f `delta' %9.4f `se_d' %9.3f `z_d' ///
            %10.4f `p_d' "  " %9.4f `lb_d' " to " %9.4f `ub_d'
    }

    di as txt "  {hline 82}"
    di _n as txt "  Model comparison (interaction vs additive cNMA):"
    di as txt "  " %-28s "Model" %12s "log-lik" %8s "tau^2" %6s "df"
    di as txt "  {hline 56}"
    di as txt "  " %-28s "cNMA (additive)" ///
              as res %12.4f `ll_cNMA' ///
              as res %8.4f cond(missing(e(tau2_cNMA)), ., e(tau2_cNMA))
    di as txt "  " %-28s "Interaction model" ///
              as res %12.4f `ll_int' ///
              as res %8.4f cond(missing(`tau2_int'), ., `tau2_int') ///
              as res %6.0f `n_free'

    if "`lrtest'" != "nolrtest" & !missing(`LR_int') {
        local methlab = cond("`meth'"=="reml","REML (approx.)","ML")
        di as txt "  {hline 56}"
        di as txt "  LR test (`methlab'): " ///
            as res %6.3f `LR_int' as txt "  (chi^2(" as res `n_free' as txt "), p=" ///
            as res %6.4f `p_LR_int' as txt ")"
        if `p_LR_int' < 0.05 {
            di as txt "  * Interaction(s) statistically significant at 5%."
        }
        else {
            di as txt "  * Interaction(s) not statistically significant at 5%."
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
end


/* ============================================================================
   cnma_forest  --  Forest plot of component (and optionally combination) effects
   ============================================================================ */
program define cnma_forest
    syntax [, COMBinations SAVEgraph(string) LEVel(cilevel) ///
              TItle(string) name(string asis) ]
    if "`e(cmd)'" != "cnma" error 301

    if "`level'" == "" local level = e(level)
    if missing(`level') local level = c(level)
    local alpha  = (100 - `level') / 100
    local z_crit = invnormal(1 - `alpha' / 2)

    local ref   `"`e(reference)'"'
    local comps  `"`e(components)'"'
    local combos `"`e(combinations)'"'

    tempname bmat Vmat
    matrix `bmat' = e(b)
    matrix `Vmat' = e(V)
    local cnames : colnames `bmat'
    local nc : word count `cnames'

    // Build dataset for forest plot
    preserve
    clear

    // Components
    local nrows = `nc'
    if "`combinations'" != "" local nrows = `nrows' + `: word count `combos''
    local nrows = `nrows' + 1   // reference row

    qui set obs `nrows'
    qui gen str40 label = ""
    qui gen double est   = .
    qui gen double lb    = .
    qui gen double ub    = .
    qui gen int    iscomp= 0
    qui gen int    isref = 0
    qui gen double ypos  = .

    local row = 0

    // Components (sorted top to bottom)
    forvalues i = 1/`nc' {
        local ++row
        local comp : word `i' of `cnames'
        local est  = `bmat'[1, `i']
        local se   = sqrt(`Vmat'[`i', `i'])
        qui replace label  = "`comp'"  in `row'
        qui replace est    = `est'     in `row'
        qui replace lb     = `est' - `z_crit' * `se' in `row'
        qui replace ub     = `est' + `z_crit' * `se' in `row'
        qui replace iscomp = 1         in `row'
        qui replace ypos   = `nc' + 2 - `row' in `row'
    }

    // Combinations (if requested)
    if "`combinations'" != "" & `"`combos'"' != "" {
        foreach combo of local combos {
            local ++row
            local parts ""
            local t2 "`combo'"
            while length("`t2'") > 0 {
                local us = strpos("`t2'", "_")
                if `us'==0 { local parts `parts' `t2'; local t2 "" }
                else {
                    local parts `parts' `=substr("`t2'",1,`us'-1)'
                    local t2=substr("`t2'",`us'+1,.)
                }
            }
            local est2 = 0; local var2 = 0
            local pidx_list ""
            foreach part of local parts {
                local pidx = 0; local j = 0
                foreach cn of local cnames {
                    local ++j
                    if "`cn'" == "`part'" local pidx `j'
                }
                local pidx_list `pidx_list' `pidx'
            }
            local np : word count `pidx_list'
            forvalues i = 1/`np' {
                local pi : word `i' of `pidx_list'
                local est2 = `est2' + `bmat'[1, `pi']
                forvalues j = 1/`np' {
                    local pj : word `j' of `pidx_list'
                    local var2 = `var2' + `Vmat'[`pi', `pj']
                }
            }
            local se2  = sqrt(max(0, `var2'))
            local clabel = subinstr("`combo'", "_", "+", .)
            qui replace label = "`clabel'" in `row'
            qui replace est   = `est2'     in `row'
            qui replace lb    = `est2' - `z_crit' * `se2' in `row'
            qui replace ub    = `est2' + `z_crit' * `se2' in `row'
            qui replace ypos  = `nc' + 2 - `row' in `row'
        }
    }

    // Reference
    local ++row
    qui replace label  = "`ref' (ref)" in `row'
    qui replace est    = 0             in `row'
    qui replace lb     = 0             in `row'
    qui replace ub     = 0             in `row'
    qui replace isref  = 1             in `row'
    qui replace ypos   = 1             in `row'

    local ntotal = `row'

    // Y-axis labels
    qui levelsof ypos, local(yvals)
    local ylabel_str ""
    foreach y of local yvals {
        qui su label if ypos == `y', meanonly
        // cannot use su on string -- use separate approach
    }
    // Build ylabel from dataset
    qui gen ylab_str = label + " " if ypos != .
    local ylabel_str ""
    forvalues r = 1/`ntotal' {
        local lbl = label[`r']
        local yp  = ypos[`r']
        if !missing(`yp') {
            local ylabel_str `"`ylabel_str' `yp' "`lbl'""'
        }
    }

    if "`title'" == "" local title "Component Effects vs. `ref'"

    // Determine axis range
    qui su lb, meanonly; local axis_min = r(min)
    qui su ub, meanonly; local axis_max = r(max)
    local axis_pad = (`axis_max' - `axis_min') * 0.1
    local axis_min = `axis_min' - `axis_pad'
    local axis_max = `axis_max' + `axis_pad'

    local grname ""
    if `"`name'"' != "" local grname `"name(`name')"'

    twoway ///
        (rcap lb ub ypos if isref==0,  horizontal lcolor(navy) lwidth(medium)) ///
        (scatter ypos est if iscomp==1, mcolor(navy) msymbol(D) msize(medium)) ///
        (scatter ypos est if iscomp==0 & isref==0, mcolor(dkorange) msymbol(S) msize(medium)) ///
        (scatter ypos est if isref==1,  mcolor(gs10) msymbol(O) msize(medium)) ///
        , xline(0, lcolor(gs8) lpattern(dash)) ///
          ylabel(`ylabel_str', angle(0) labsize(small)) ///
          xlabel(, format(%6.3f)) ///
          xtitle("Effect size (vs. `ref')") ///
          ytitle("") ///
          title("`title'", size(medium)) ///
          legend(order(2 "Component" 3 "Combination" 4 "Reference") ///
                 cols(3) size(small)) ///
          scheme(s1color) `grname'

    if `"`savegraph'"' != "" graph save `"`savegraph'"', replace

    restore
end


/* ============================================================================
   cnma_map  --  Component network map
   Nodes = components; edges = co-occurrence in >=1 study
   ============================================================================ */
program define cnma_map
    syntax [, SAVEgraph(string) name(string asis) TItle(string) ///
              noLAbel SHape(string) ]
    if "`e(cmd)'" != "cnma" error 301

    local comps  `"`e(components)'"'
    local combos `"`e(combinations)'"'
    local ref    `"`e(reference)'"'
    local nc : word count `comps'

    if `nc' < 2 {
        di as err "Need at least 2 components for a network map."
        exit 498
    }

    /* ------------------------------------------------------------------
       Build edge weights purely from e(combinations) -- no data needed.
       Uses LINEAR INDEX eidx = (ci-1)*nc + cj to avoid triple-nested
       macro expansion.  nw_ci = node weight, ew_eidx = edge weight.
    ------------------------------------------------------------------ */
    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            local eidx = (`ci' - 1) * `nc' + `cj'
            local ew_`eidx' = 0
        }
        local nw_`ci' = 0
    }

    local n_combos : word count `combos'
    forvalues k = 1/`n_combos' {
        local combo_k : word `k' of `combos'
        forvalues ci = 1/`nc' {
            local comp_ci : word `ci' of `comps'
            if strpos("_`combo_k'_", "_`comp_ci'_") > 0 {
                local nw_`ci' = `nw_`ci'' + 1
                forvalues cj = 1/`nc' {
                    if `cj' <= `ci' continue
                    local comp_cj : word `cj' of `comps'
                    if strpos("_`combo_k'_", "_`comp_cj'_") > 0 {
                        local eidx = (`ci' - 1) * `nc' + `cj'
                        local ew_`eidx' = `ew_`eidx'' + 1
                    }
                }
            }
        }
    }

    // Max edge/node weight for scaling
    local max_edge = 1
    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            local eidx = (`ci' - 1) * `nc' + `cj'
            if `ew_`eidx'' > `max_edge' local max_edge = `ew_`eidx''
        }
    }
    local max_node = 1
    forvalues ci = 1/`nc' {
        if `nw_`ci'' > `max_node' local max_node = `nw_`ci''
    }

    /* ------------------------------------------------------------------
       Node positions: equally spaced on unit circle
    ------------------------------------------------------------------ */
    forvalues ci = 1/`nc' {
        local angle = (`ci' - 1) * 360 / `nc'
        local px_`ci' = cos(`angle' * c(pi) / 180)
        local py_`ci' = sin(`angle' * c(pi) / 180)
    }

    /* ------------------------------------------------------------------
       Node marker symbol
    ------------------------------------------------------------------ */
    if "`shape'" == "" local shape "O"
    if "`shape'" == "pentagon"  local shape "Oh"
    if "`shape'" == "hexagon"   local shape "Dh"
    if "`shape'" == "diamond"   local shape "D"
    if "`shape'" == "triangle"  local shape "T"
    if "`shape'" == "square"    local shape "S"

    /* ------------------------------------------------------------------
       Count edges then build graph dataset
    ------------------------------------------------------------------ */
    local n_edges = 0
    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            local eidx = (`ci' - 1) * `nc' + `cj'
            if `ew_`eidx'' > 0 local ++n_edges
        }
    }
    local n_edge_rows = max(1, `n_edges')

    preserve
    clear

    qui set obs `= `n_edge_rows' + `nc' + 1'
    qui gen double ey1    = .
    qui gen double ex1    = .
    qui gen double ey2    = .
    qui gen double ex2    = .
    qui gen double nx     = .
    qui gen double ny     = .
    qui gen double ns     = .
    qui gen str80  nlabel = ""
    qui gen int    isnode = 0
    qui gen int    isref  = 0

    // Edge rows
    local row = 0
    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            local eidx = (`ci' - 1) * `nc' + `cj'
            if `ew_`eidx'' == 0 continue
            local ++row
            qui replace ey1 = `py_`ci'' in `row'
            qui replace ex1 = `px_`ci'' in `row'
            qui replace ey2 = `py_`cj'' in `row'
            qui replace ex2 = `px_`cj'' in `row'
        }
    }

    // Reference node at centre
    local ref_row = `n_edge_rows' + 1
    qui replace nx     = 0   in `ref_row'
    qui replace ny     = 0   in `ref_row'
    qui replace ns     = 8   in `ref_row'
    qui replace nlabel = "`ref' (ref)" in `ref_row'
    qui replace isnode = 1   in `ref_row'
    qui replace isref  = 1   in `ref_row'

    // Component nodes
    forvalues ci = 1/`nc' {
        local nrow = `n_edge_rows' + 1 + `ci'
        local comp_ci : word `ci' of `comps'
        qui replace nx     = `px_`ci''                        in `nrow'
        qui replace ny     = `py_`ci''                        in `nrow'
        qui replace ns     = max(4, 8 * `nw_`ci'' / `max_node') in `nrow'
        qui replace nlabel = "`comp_ci'"                      in `nrow'
        qui replace isnode = 1                                in `nrow'
    }

    if "`title'" == "" local title "Component Network Map"
    local grname ""
    if `"`name'"' != "" local grname `"name(`name')"'

    local label_opt ""
    if "`label'" != "nolabel" {
        local label_opt `"mlabel(nlabel) mlabpos(12) mlabsize(small) mlabcolor(black)"'
    }

    // Edge lines (one pcspike per edge, variable width)
    local spike_cmds ""
    local row2 = 0
    forvalues ci = 1/`nc' {
        forvalues cj = 1/`nc' {
            if `cj' <= `ci' continue
            local eidx = (`ci' - 1) * `nc' + `cj'
            if `ew_`eidx'' == 0 continue
            local ++row2
            local lw_num = max(0.3, 3 * `ew_`eidx'' / `max_edge')
            local spike_cmds `"`spike_cmds' (pcspike ey1 ex1 ey2 ex2 if _n==`row2', lcolor(navy) lwidth(`lw_num'))"'
        }
    }

    twoway ///
        `spike_cmds' ///
        (scatter ny nx if isref==1, mcolor(cranberry) msymbol(`shape') msize(vlarge) ///
            `label_opt') ///
        (scatter ny nx if isnode==1 & isref==0, mcolor(navy) msymbol(`shape') msize(large) ///
            `label_opt') ///
        , xlabel(-1.5 1.5, nolabels noticks) ylabel(-1.5 1.5, nolabels noticks) ///
          xtitle("") ytitle("") ///
          title("`title'", size(medium)) ///
          subtitle("Edge width proportional to number of combination treatments", size(vsmall)) ///
          legend(off) aspect(1) scheme(s1color) `grname'

    if `"`savegraph'"' != "" graph save `"`savegraph'"', replace

    restore
end


