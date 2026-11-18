* ============================================================
* workshop_demo.do
* cNMA Workshop — CEB,Faculty of Medicine Ramathibodi Hospital, Mahidol University
* Friday Workshop: Prof. Ammarin Thakkinstian
*
* TOPIC : Component Network Meta-Analysis (cNMA)
* DATA  : 1) FMA stroke rehabilitation (34 studies, 10 treatments)
*         6 components: FES, TMS_high, TMS_low, NMES, rPMS, Rehab(ref)
		  2) CP-CPPS 
* ============================================================

* ── Prerequisite : run workshop_install.do first ────────────
* then restart Stata (or type: discard)

* ── 0. Load your dataset ────────────────────────────────────
* Adjust the path below to your data file:
* use "C:\cnma_workshop\FMA_wide.dta", clear


* ══════════════════════════════════════════════════════════════
* PART 1  –  Continuous Outcome  (Mean Difference scale)
* ══════════════════════════════════════════════════════════════

* ── 1. cnma : fit additive cNMA model ──────────────────────
cnma, study(studyid) y(y) sd(sd) n(n)             ///
    trtlist(FES FES_TMShigh NMES NMES_TMShigh       ///
            NMES_TMSlow NMES_rPMS Rehab              ///
            TMShigh TMSlow rPMS)                     ///
    ref(Rehab) measure(md)
* Results : 5 component effects, tau2=14.98
* FES & NMES significant; rPMS borderline

* ── 2. cnma_map : component network visualization ──────────
cnma_map, layout(pentagon) savegraph("FES_pentagon")
cnma_map, layout(hexagon)  savegraph("FES_hexagon")

* ── 3. cnma_test : LR test of additivity ───────────────────
cnma_test
* LR = 4.662   df = 4   p = 0.3238
* Interpretation: additivity NOT rejected → keep additive model

* ── 4. cnma_interact : explore one interaction at a time ───
cnma_test, interact(NMES_TMShigh)


* delta = -4.43  SE = 8.20  p = 0.589  → not significant

* ── 5. cnma_rank : P-score & SUCRA rankings ────────────────
cnma_rank, seed(1234) reps(1000)
* NMES+TMSlow  SUCRA=0.604  Rank #1
* FES+TMShigh  SUCRA=0.343  Rank #6 (worst)

* ── 6. lincom : combinations of components ─────────────────
lincom _b[FES] + _b[NMES]
* FES + NMES = 9.03*  (p=0.002,  95% CI: 3.43 – 14.63)

lincom _b[FES] + _b[rPMS]
* FES + rPMS = 9.75*  (p=0.004,  95% CI: 3.05 – 16.45)


* ══════════════════════════════════════════════════════════════
* PART 2  –  Binary Outcome  (Odds Ratio scale)
* ══════════════════════════════════════════════════════════════
* Example: preterm birth prevention (5 studies, 6 treatments)
* Adjust path and variable names for your dataset

* use "C:\data\cnma\updated ado\Data\CP-CPPS long-d n.dta", clear

* ── 1. cnma_dicho : binary cNMA ────────────────────────────
.  cnma_dicho, study(study_id) treat(treat) d(d) n(n) ref(plac) measure(or) coef
.  cnma_dicho, study(study_id) treat(treat) d(d) n(n) ref(plac) measure(or) 


* anti-inf most effective;  OR scale

* ── 2. cnma_map : binary network map ───────────────────────
cnma_map, layout(hexagon) savegraph("binary_hexagon")
cnma_map

* ── 3. cnma_test : additivity test (binary) ────────────────
cnma_test

* ── 4. cnma_interact : interaction check ───────────────────
* cnma_interact, interact(<treatment>)
	cnma_test, interact(alph_antib)
	


* ── 5. cnma_rank : binary rankings ────────────────────────
cnma_rank, seed(2345) reps(1000)
* anti-inf  SUCRA=0.765  Rank #1
* plac(ref) SUCRA=0.101  Rank #6

* ════════════════════════════════════════════════════════════
* END OF WORKSHOP DEMO
* Questions? Contact: ammarin.tha@mahidol.ac.th
* CEB, Faculty of Medicine Ramathibodi Hospital
* ════════════════════════════════════════════════════════════
