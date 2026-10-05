# CCW: Clone-Censor-Weight analysis for Stata (v5.1, 01 Oct 2026)

Commands: `create_clones`, `cast_clones_to_long`, `generate_ccw`, `bootstrap_ccw`.
Requires Stata 16 or higher.

## Install from this folder
1. Open `install_ccw_v2.do` and edit the two lines marked `>>> EDIT`:
   `local source` (where you saved ccw_package) and `local dest` (your Stata PERSONAL folder; type `sysdir` in Stata to see it).
2. Run it in Stata: `do "C:\...\ccw_package\install_ccw_v2.do"`

## Install from GitHub
```
net install ccw, from("https://raw.githubusercontent.com/YOURNAME/ccw/main/") replace
```

## Pipeline
```
create_clones, id(id) event(event) timetoevent(timetoevent) ///
    exposure(exposure) timetoexposure(timetoexposure) ced(100)
cast_clones_to_long
generate_ccw, predvars(cov1 cov2)
gen long rowid = _n
bootstrap_ccw, cluster(id) reps(200) seed(12345)
```
See `help create_clones` and the other help files for details and references.

Ammarin Thakkinstian, Department of Clinical Epidemiology and Biostatistics (CEB),
Faculty of Medicine Ramathibodi Hospital, Mahidol University. ammarin.tha@mahidol.ac.th
