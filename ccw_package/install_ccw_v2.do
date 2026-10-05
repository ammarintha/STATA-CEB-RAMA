* =========================================================================
* install_ccw_v2.do - Install the CCW package (v5.1, 01oct2026)
* Ammarin Thakkinstian
* Department of Clinical Epidemiology and Biostatistics (CEB),
* Faculty of Medicine Ramathibodi Hospital, Mahidol University
* =========================================================================
* HOW TO USE
*   Step 1: Edit the TWO lines marked >>> EDIT below (source and dest)
*           so they match YOUR computer.
*   Step 2: In Stata, run:   do "<full path>\install_ccw_v2.do"
* =========================================================================

* -------------------------------------------------------------------------
* SOURCE: the folder where YOU saved the ccw_package folder
*         (the folder that contains this file and the 8 .ado/.sthlp files)
* Examples (choose the one that matches YOUR computer):
*   C:\data\ccw_stata_package\ccw_package
*   C:\Users\YourName\Downloads\ccw_package
*   C:\Users\YourName\Desktop\ccw_package
*   H:\My Drive\...\ccw_package
* -------------------------------------------------------------------------
local source "C:\data\ccw_stata_package\ccw_package"      // >>> EDIT

* -------------------------------------------------------------------------
* DESTINATION: your Stata PERSONAL ado folder (no admin rights needed)
* Common paths:
*   C:\ado\personal                  (Stata default on Windows)
*   C:\Users\YourName\ado\personal
* To find YOURS: in Stata type   sysdir   and copy the PERSONAL line.
* Do NOT use C:\Program Files\...\ado\base (needs admin rights and
* is overwritten when Stata is updated).
* -------------------------------------------------------------------------
local dest "C:\ado\personal"                                 // >>> EDIT

local files create_clones.ado create_clones.sthlp           ///
            cast_clones_to_long.ado cast_clones_to_long.sthlp ///
            generate_ccw.ado generate_ccw.sthlp               ///
            bootstrap_ccw.ado bootstrap_ccw.sthlp

di as txt _n "Installing CCW package v5.1"
di as txt "  From: `source'"
di as txt "  To:   `dest'" _n

* 1. Check all 8 files are here
foreach f of local files {
    capture confirm file "`source'/`f'"
    if _rc {
        di as err "Missing: `f'"
        di as err "Check the 'local source' line in this file:"
        di as err "it must point to the folder that contains the 8 CCW files."
        exit 601
    }
}

* 2. Create the PERSONAL folder if needed, then copy
capture mkdir "`dest'"
foreach f of local files {
    copy "`source'/`f'" "`dest'/`f'", replace
    di as txt "  copied `f'"
}

* 3. Check
discard
di as txt _n "Done. Check that the new version is in use:"
which bootstrap_ccw
di as txt _n "The line above should read:  *! bootstrap_ccw v5.1  01oct2026"
di as txt "If it shows another folder first, an older copy is installed there - remove it."
di as txt "Help:  help create_clones  /  help bootstrap_ccw" _n
