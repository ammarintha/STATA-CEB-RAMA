*! cast_clones_to_long v1.1  27sep2026  Ammarin Thakkinstian
*! Department of Clinical Epidemiology and Biostatistics (CEB), Faculty of Medicine Ramathibodi Hospital, Mahidol University
*! Replicates survivalCCW::cast_clones_to_long() from R (Genentech)
*
*  Converts a cloned dataset (wide format, one row per clone-patient) into
*  counting-process (long) format with one row per time interval per clone-patient.
*  Split points are all unique event times, exposure times, and the CED boundary
*  (if a finite CED was specified) — matching the R package exactly.
*
*  Must be run AFTER create_clones.
*
*  Syntax:
*    cast_clones_to_long [, verbose]
*
*  See also: create_clones, generate_ccw

program define cast_clones_to_long
    version 16
    syntax [, Verbose]

    * ---- Retrieve metadata set by create_clones ---------------------------
    local id_var             "`_dta[ccw_id]'"
    local timetoevent_var    "`_dta[ccw_timetoevent]'"
    local timetoexposure_var "`_dta[ccw_timetoexposure]'"
    local ced_val            = real("`_dta[ccw_ced]'")
    local ced_type           "`_dta[ccw_ced_type]'"
    local ced_input          "`_dta[ccw_ced_input]'"

    if "`id_var'" == "" {
        di as err "cast_clones_to_long: no CCW metadata found."
        di as err "  Run create_clones first."
        exit 198
    }

    * ---- 5.1 Unique numeric ID per clone-patient pair --------------------
    capture drop stid
    egen long stid = group(`id_var' clone)
    label var stid "Unique clone-patient ID"

    * ---- 5.2 End of follow-up (corrected formula) ------------------------
    *     KEY: non-censored patients follow to fup_outcome (may exceed CED).
    *     Artificially censored patients stop at fup_censor.
    *     Using min(fup_outcome, fup_censor) would wrongly truncate clone-0
    *     patients who remain unexposed beyond CED.
    capture drop fu_end
    gen double fu_end = fup_outcome               // default: follow to actual end
    replace    fu_end = fup_censor if censor == 1 // artificially censored: stop there
    label var fu_end "End of follow-up for this clone (corrected)"

    * ---- 5.3 Preserve artificial-censor flag before stsplit --------------
    capture drop cens_orig
    gen byte cens_orig = censor

    * ---- 5.4–5.9 Collect cut-points and build counting-process long format -
    *     All cut-point work happens inside one preserve block so no local
    *     macro needs to survive stset or preserve/restore scope issues.
    *
    *     Stub "cp" is unambiguous (no other variable starts with "cp").
    *     CED boundary added only when ced_type == "fixed".
    *
    tempfile _ivals
    preserve
        keep `timetoevent_var' `timetoexposure_var'
        rename `timetoevent_var'    cp1
        rename `timetoexposure_var' cp2
        gen long obs = _n
        quietly reshape long cp, i(obs) j(type)
        keep cp
        drop if missing(cp)
        * Add CED boundary when a finite grace period is specified
        if "`ced_type'" == "fixed" {
            local n1 = _N + 1
            quietly set obs `n1'
            replace cp = `ced_val' in `n1'
        }
        duplicates drop cp, force
        sort cp
        if "`verbose'" != "" {
            di as txt "  Unique cut-points collected: " _N
        }
        else {
            di as txt "  Cut-points collected: " _N " unique times"
        }
        * Build adjacent intervals [t_start, t_stop); prepend 0 as origin
        local ncp  = _N
        local ntot = `ncp' + 1
        quietly set obs `ntot'
        replace cp = 0 in `ntot'
        sort cp
        gen double t_start = cp
        gen double t_stop  = cp[_n+1]
        drop if missing(t_stop)   // last row has no successor — drop it
        drop cp
        save `_ivals'
    restore

    cross using `_ivals'          // one row per clone-patient × interval

    keep if t_start < fu_end
    replace t_stop = fu_end if t_stop > fu_end
    drop if t_start >= t_stop

    * ---- 5.7 Counting-process time variable labels -----------------------
    label var t_start "Interval start time"
    label var t_stop  "Interval stop  time"

    * ---- 5.8–5.9 Assign outcome and censor to last row only --------------
    sort stid t_start
    bysort stid (t_stop): gen byte is_last = (_n == _N)
    replace outcome = (outcome == 1 & is_last)
    replace censor  = (cens_orig == 1 & is_last)
    drop cens_orig is_last

    * ---- Summary ----------------------------------------------------------
    di as txt ""
    di as txt "cast_clones_to_long complete:"
    di as txt "  Total rows (long format) : " _N
    qui count if outcome == 1
    di as txt "  Event rows               : " r(N)
    qui count if censor == 1
    di as txt "  Artificial-censor rows   : " r(N)
    di as txt "  Run generate_ccw next."

end
