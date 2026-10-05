*! create_clones v1.1  27sep2026  Ammarin Thakkinstian
*! Department of Clinical Epidemiology and Biostatistics (CEB), Faculty of Medicine Ramathibodi Hospital, Mahidol University
*! Replicates survivalCCW::create_clones() from R (Genentech)
*
*  Creates two clones (assigned-exposed / assigned-unexposed) per patient
*  and applies artificial censoring rules within the grace period (CED).
*
*  Syntax:
*    create_clones, id(varname) event(varname) timetoevent(varname)  ///
*                   exposure(varname) timetoexposure(varname) ced(#|.)
*
*    ced(.)  = no grace-period limit (treatment may start at any time);
*              internally sets CED = max(timetoevent)+1 so no clone-1
*              patient is artificially censored due to a time constraint.
*
*  See also: cast_clones_to_long, generate_ccw

program define create_clones
    version 16
    syntax , id(varname) event(varname) timetoevent(varname)  ///
             exposure(varname) timetoexposure(varname) ced(string)

    * ---- Process CED option ------------------------------------------------
    if "`ced'" == "." {
        qui sum `timetoevent'
        local ced_num  = r(max) + 1   // effectively +infinity
        local ced_type = "none"       // flag: no grace period
        di as txt "Note: ced(.) specified — no grace-period limit."
        di as txt "  Internally using CED = " `ced_num' " (max follow-up + 1)."
    }
    else {
        local ced_num = real("`ced'")
        if missing(`ced_num') | `ced_num' <= 0 {
            di as err "create_clones: ced() must be a positive number or . (no grace period)."
            exit 198
        }
        local ced_type = "fixed"
    }

    * ---- Store metadata for downstream programs ----------------------------
    char _dta[ccw_id]             "`id'"
    char _dta[ccw_event]          "`event'"
    char _dta[ccw_timetoevent]    "`timetoevent'"
    char _dta[ccw_exposure]       "`exposure'"
    char _dta[ccw_timetoexposure] "`timetoexposure'"
    char _dta[ccw_ced]            "`ced_num'"
    char _dta[ccw_ced_input]      "`ced'"
    char _dta[ccw_ced_type]       "`ced_type'"

    * ---- Basic checks ------------------------------------------------------
    confirm numeric variable `exposure'
    confirm numeric variable `event'
    confirm numeric variable `timetoevent'
    qui levelsof `exposure', local(explevs)
    if !inlist("`explevs'", "0 1", "0", "1") {
        di as err "create_clones: `exposure' must be binary (0/1)."
        exit 198
    }

    * ---- STEP 1: Expand to two clones per patient -------------------------
    sort `id'
    expand 2, gen(clone)
    bysort `id': replace clone = _n - 1
    * clone 0 = assigned-unexposed strategy
    * clone 1 = assigned-exposed   strategy
    label var clone "Clone strategy: 1=assigned-exposed, 0=assigned-unexposed"

    * ---- STEP 2: CED variable ---------------------------------------------
    gen double ced = `ced_num'
    label var ced "Clinical eligibility duration (grace period)"

    * ---- STEP 3 & 4: Initialise outcome/censor variables -----------------
    gen double outcome     = .
    gen double fup_outcome = .
    gen double censor      = .
    gen double fup_censor  = .
    gen double exposure2   = `exposure'

    label var outcome     "Outcome indicator for this clone"
    label var fup_outcome "Follow-up time to outcome for this clone"
    label var censor      "Artificial censor indicator (1 = censored)"
    label var fup_censor  "Follow-up time to artificial censoring"
    label var exposure2   "Actual exposure status for this clone"

    * ========================================================================
    * CLONE 1 — Assigned-exposed strategy
    * ========================================================================

    * 3a. Exposed within CED → adherent; keep original outcome
    replace exposure2   = `exposure'       if clone==1 & `exposure'==1 & `timetoexposure'<=`ced_num'
    replace censor      = 0                if clone==1 & `exposure'==1 & `timetoexposure'<=`ced_num'
    replace fup_censor  = `timetoexposure' if clone==1 & `exposure'==1 & `timetoexposure'<=`ced_num'
    replace outcome     = `event'          if clone==1 & `exposure'==1 & `timetoexposure'<=`ced_num'
    replace fup_outcome = `timetoevent'    if clone==1 & `exposure'==1 & `timetoexposure'<=`ced_num'

    * 3b. Exposed > CED or never exposed → deviates; censor at CED
    replace exposure2   = 0          if clone==1 & `exposure'==1 & (`timetoexposure'>`ced_num' | missing(`timetoexposure'))
    replace censor      = 1          if clone==1 & `exposure'==1 & (`timetoexposure'>`ced_num' | missing(`timetoexposure'))
    replace fup_censor  = `ced_num'  if clone==1 & `exposure'==1 & (`timetoexposure'>`ced_num' | missing(`timetoexposure'))
    replace outcome     = 0          if clone==1 & `exposure'==1 & (`timetoexposure'>`ced_num' | missing(`timetoexposure'))
    replace fup_outcome = `ced_num'  if clone==1 & `exposure'==1 & (`timetoexposure'>`ced_num' | missing(`timetoexposure'))

    * 3c. Unexposed, event/end within CED → no artificial censoring
    replace exposure2   = `exposure'    if clone==1 & `exposure'==0 & `timetoevent'<=`ced_num'
    replace censor      = 0             if clone==1 & `exposure'==0 & `timetoevent'<=`ced_num'
    replace fup_censor  = `timetoevent' if clone==1 & `exposure'==0 & `timetoevent'<=`ced_num'
    replace outcome     = `event'       if clone==1 & `exposure'==0 & `timetoevent'<=`ced_num'
    replace fup_outcome = `timetoevent' if clone==1 & `exposure'==0 & `timetoevent'<=`ced_num'

    * 3d. Unexposed beyond CED → deviates; censor at CED
    replace exposure2   = `exposure'  if clone==1 & `exposure'==0 & `timetoevent'>`ced_num'
    replace censor      = 1           if clone==1 & `exposure'==0 & `timetoevent'>`ced_num'
    replace fup_censor  = `ced_num'   if clone==1 & `exposure'==0 & `timetoevent'>`ced_num'
    replace outcome     = 0           if clone==1 & `exposure'==0 & `timetoevent'>`ced_num'
    replace fup_outcome = `ced_num'   if clone==1 & `exposure'==0 & `timetoevent'>`ced_num'

    * ========================================================================
    * CLONE 0 — Assigned-unexposed strategy
    * ========================================================================

    * 4a. Unexposed, beyond CED → adherent; keep original outcome
    replace exposure2   = `exposure'    if clone==0 & `exposure'==0 & `timetoevent'>`ced_num'
    replace censor      = 0             if clone==0 & `exposure'==0 & `timetoevent'>`ced_num'
    replace fup_censor  = `ced_num'     if clone==0 & `exposure'==0 & `timetoevent'>`ced_num'
    replace outcome     = `event'       if clone==0 & `exposure'==0 & `timetoevent'>`ced_num'
    replace fup_outcome = `timetoevent' if clone==0 & `exposure'==0 & `timetoevent'>`ced_num'

    * 4b. Unexposed, within CED → adherent; keep original outcome
    replace exposure2   = `exposure'    if clone==0 & `exposure'==0 & `timetoevent'<=`ced_num'
    replace censor      = 0             if clone==0 & `exposure'==0 & `timetoevent'<=`ced_num'
    replace fup_censor  = `timetoevent' if clone==0 & `exposure'==0 & `timetoevent'<=`ced_num'
    replace outcome     = `event'       if clone==0 & `exposure'==0 & `timetoevent'<`ced_num'
    replace fup_outcome = `timetoevent' if clone==0 & `exposure'==0 & `timetoevent'<`ced_num'

    * 4c. Exposed within CED → deviates; artificial censor at exposure time
    replace exposure2   = `exposure'       if clone==0 & `exposure'==1 & `timetoexposure'<`ced_num'
    replace censor      = 1                if clone==0 & `exposure'==1 & `timetoexposure'<`ced_num'
    replace fup_censor  = `timetoexposure' if clone==0 & `exposure'==1 & `timetoexposure'<`ced_num'
    replace outcome     = 0                if clone==0 & `exposure'==1 & `timetoexposure'<`ced_num'
    replace fup_outcome = `timetoexposure' if clone==0 & `exposure'==1 & `timetoexposure'<`ced_num'

    * 4d. Exposed at/beyond CED → adherent (treated as never exposed)
    replace exposure2   = 0             if clone==0 & `exposure'==1 & inrange(`timetoexposure',`ced_num',.)
    replace censor      = 0             if clone==0 & `exposure'==1 & inrange(`timetoexposure',`ced_num',.)
    replace fup_censor  = `ced_num'     if clone==0 & `exposure'==1 & inrange(`timetoexposure',`ced_num',.)
    replace outcome     = `event'       if clone==0 & `exposure'==1 & inrange(`timetoexposure',`ced_num',.)
    replace fup_outcome = `timetoevent' if clone==0 & `exposure'==1 & inrange(`timetoexposure',`ced_num',.)

    * ---- Summary ----------------------------------------------------------
    qui count
    local nrows = r(N)
    local npts  = `nrows' / 2
    di as txt ""
    di as txt "create_clones complete:"
    di as txt "  Patients : `npts'"
    di as txt "  Rows     : `nrows' (2 clones per patient)"
    if "`ced_type'" == "none" {
        di as txt "  CED      : . (no grace-period limit)"
    }
    else {
        di as txt "  CED      : `ced_num'"
    }
    di as txt "  Run cast_clones_to_long next."

end
