version 17
clear all
set more off
set varabbrev off
capture log close analysis

global project "/Users/matheusrech/Pictures/ELSI"
global out "$project/docs/generated"
global logs "$project/docs/generated/stata_logs"

log using "$logs/02_survey_analysis.log", replace text name(analysis)

use "$out/stata_analysis_dataset.dta", clear

local indicators cancer_survivor cancer_recent_treatment stroke_survivor ///
    stroke_rehab chronic_spine_condition frail_binary any_rehab_90d ///
    colonoscopy_10y current_smoker alcohol_any

tempname prev
postfile `prev' int wave str7 wave_label str32 group_var str80 group_value ///
    str40 indicator double estimate se ci_low ci_high int n_unweighted ///
    using "$out/stata_weighted_prevalence.dta", replace

foreach w of numlist 1/3 {
    preserve
    keep if wave == `w'
    local wl = wave_label[1]
    svyset upa [pweight = peso_calibrado], strata(estrato) singleunit(centered)

    foreach y of local indicators {
        capture confirm variable `y'
        if !_rc {
            quietly count if !missing(`y')
            local n = r(N)
            if `n' > 0 {
                capture noisily svy: mean `y'
                if !_rc {
                    matrix b = e(b)
                    matrix V = e(V)
                    scalar est = b[1,1]
                    scalar ses = sqrt(V[1,1])
                    scalar lb = max(0, est - invnormal(.975) * ses)
                    scalar ub = min(1, est + invnormal(.975) * ses)
                    post `prev' (`w') ("`wl'") ("overall") ("Overall") ("`y'") ///
                        (est) (ses) (lb) (ub) (`n')
                }
            }
        }
    }

    foreach g in region zone sex age_group {
        capture confirm variable `g'
        if !_rc {
            levelsof `g' if !missing(`g'), local(levels)
            local vallabel : value label `g'
            foreach level of local levels {
                local group_text "`level'"
                if "`vallabel'" != "" {
                    local group_text : label `vallabel' `level'
                }
                capture drop __subpop
                gen byte __subpop = (`g' == `level') if !missing(`g')
                foreach y of local indicators {
                    quietly count if __subpop == 1 & !missing(`y')
                    local n = r(N)
                    if `n' > 0 {
                        capture noisily svy, subpop(__subpop): mean `y'
                        if !_rc {
                            matrix b = e(b)
                            matrix V = e(V)
                            scalar est = b[1,1]
                            scalar ses = sqrt(V[1,1])
                            scalar lb = max(0, est - invnormal(.975) * ses)
                            scalar ub = min(1, est + invnormal(.975) * ses)
                            post `prev' (`w') ("`wl'") ("`g'") ("`group_text'") ("`y'") ///
                                (est) (ses) (lb) (ub) (`n')
                        }
                    }
                }
            }
        }
    }
    restore
}
postclose `prev'

use "$out/stata_weighted_prevalence.dta", clear
export delimited using "$out/stata_weighted_prevalence.csv", replace

use "$out/stata_analysis_dataset.dta", clear
tempname models
postfile `models' int wave str7 wave_label str40 outcome str40 exposure ///
    str80 term double odds_ratio ci_low ci_high p_value int n_unweighted ///
    str120 status using "$out/stata_survey_models.dta", replace
global MODELPOST "`models'"

capture program drop fit_model
program define fit_model
    syntax, WAVE(integer) OUTcome(name) EXPOSure(name) [SUBPOP(name)]
    preserve
    keep if wave == `wave'
    local wl = wave_label[1]
    capture confirm variable `outcome'
    if _rc {
        post $MODELPOST (`wave') ("`wl'") ("`outcome'") ("`exposure'") ("`exposure'") ///
            (.) (.) (.) (.) (0) ("Skipped: outcome missing")
        restore
        exit
    }
    capture confirm variable `exposure'
    if _rc {
        post $MODELPOST (`wave') ("`wl'") ("`outcome'") ("`exposure'") ("`exposure'") ///
            (.) (.) (.) (.) (0) ("Skipped: exposure missing")
        restore
        exit
    }

    if "`subpop'" != "" {
        capture confirm variable `subpop'
        if !_rc keep if `subpop' == 1
    }

    keep if !missing(`outcome', `exposure', upa, estrato, peso_calibrado)
    quietly count
    local n = r(N)
    if `n' < 100 {
        post $MODELPOST (`wave') ("`wl'") ("`outcome'") ("`exposure'") ("`exposure'") ///
            (.) (.) (.) (.) (`n') ("Skipped: n < 100")
        restore
        exit
    }

    quietly tab `outcome'
    if r(r) < 2 {
        post $MODELPOST (`wave') ("`wl'") ("`outcome'") ("`exposure'") ("`exposure'") ///
            (.) (.) (.) (.) (`n') ("Skipped: outcome has no variation")
        restore
        exit
    }
    quietly tab `exposure'
    if r(r) < 2 {
        post $MODELPOST (`wave') ("`wl'") ("`outcome'") ("`exposure'") ("`exposure'") ///
            (.) (.) (.) (.) (`n') ("Skipped: exposure has no variation")
        restore
        exit
    }

    svyset upa [pweight = peso_calibrado], strata(estrato) singleunit(centered)
    capture noisily svy: logistic `outcome' i.`exposure' c.age_years i.sex i.region i.zone
    if _rc {
        local rc = _rc
        post $MODELPOST (`wave') ("`wl'") ("`outcome'") ("`exposure'") ("`exposure'") ///
            (.) (.) (.) (.) (`n') ("Model error rc=`rc'")
        restore
        exit
    }

    matrix T = r(table)
    local cnames : colnames T
    local ncols = colsof(T)
    forvalues j = 1/`ncols' {
        local col : word `j' of `cnames'
        if strpos("`col'", ".`exposure'") > 0 & strpos("`col'", "b.") == 0 & strpos("`col'", "o.") == 0 {
            scalar or = T[1, `j']
            scalar ll = T[5, `j']
            scalar ul = T[6, `j']
            scalar pv = T[4, `j']
            post $MODELPOST (`wave') ("`wl'") ("`outcome'") ("`exposure'") ("`col'") ///
                (or) (ll) (ul) (pv) (`n') ("OK")
        }
    }
    restore
end

foreach w of numlist 1/3 {
    fit_model, wave(`w') outcome(frail_binary) exposure(cancer_survivor)
    fit_model, wave(`w') outcome(frail_binary) exposure(chronic_spine_condition)
    fit_model, wave(`w') outcome(frail_binary) exposure(stroke_survivor)
}

foreach w of numlist 2/3 {
    fit_model, wave(`w') outcome(stroke_rehab) exposure(frail_binary) subpop(stroke_survivor)
    fit_model, wave(`w') outcome(stroke_rehab) exposure(region) subpop(stroke_survivor)
    fit_model, wave(`w') outcome(stroke_rehab) exposure(zone) subpop(stroke_survivor)
}

postclose `models'

use "$out/stata_survey_models.dta", clear
export delimited using "$out/stata_survey_models.csv", replace

display as result "Saved Stata survey prevalence and model outputs in $out"
log close analysis
