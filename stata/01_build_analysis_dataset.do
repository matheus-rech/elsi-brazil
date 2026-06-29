version 17
clear all
set more off
set varabbrev off
capture log close build

global project "/Users/matheusrech/Pictures/ELSI"
global out "$project/docs/generated"
global logs "$project/docs/generated/stata_logs"

log using "$logs/01_build_analysis_dataset.log", replace text name(build)

capture program drop ynflag
program define ynflag
    syntax name(name=src), GENerate(name)
    capture confirm variable `src'
    if _rc {
        gen byte `generate' = .
        exit
    }
    gen byte `generate' = .
    capture confirm numeric variable `src'
    if !_rc {
        replace `generate' = 1 if `src' == 1 & !missing(`src')
        replace `generate' = 0 if `src' == 0 & !missing(`src')
    }
end

capture program drop numcopy
program define numcopy
    syntax name(name=src), GENerate(name) [SPECIAL]
    capture confirm variable `src'
    if _rc {
        gen double `generate' = .
        exit
    }
    gen double `generate' = `src'
    if "`special'" != "" {
        replace `generate' = . if inlist(`generate', 666, 777, 888, 999, 6666, 7777, 8888, 9999)
    }
end

capture program drop clone_or_missing
program define clone_or_missing
    syntax name(name=src), GENerate(name)
    capture confirm variable `src'
    if _rc {
        gen double `generate' = .
        exit
    }
    clonevar `generate' = `src'
end

capture program drop clean_range
program define clean_range
    syntax varname, MIN(real) MAX(real)
    replace `varlist' = . if `varlist' < `min' & !missing(`varlist')
    replace `varlist' = . if `varlist' > `max' & !missing(`varlist')
end

tempfile wave1 wave2 wave3

forvalues w = 1/3 {
    if `w' == 1 {
        local dta "$project/ELSI Portugues (1a onda) stata13.dta"
        local label "2015-16"
    }
    else if `w' == 2 {
        local dta "$project/ELSI Portugues (2a onda) stata13.dta"
        local label "2019-21"
    }
    else {
        local dta "$project/ELSI Portugues (3a onda).dta"
        local label "2023-24"
    }

    display as result "Reading wave `w': `dta'"
    use "`dta'", clear

    gen byte wave = `w'
    gen str7 wave_label = "`label'"
    gen long anon_row_id = _n

    clone_or_missing upa, gen(upa_analysis)
    clone_or_missing estrato, gen(estrato_analysis)
    clone_or_missing peso_calibrado, gen(weight_analysis)
    clone_or_missing regiao, gen(region)
    clone_or_missing zona, gen(zone)
    label define region_lbl 1 "Norte" 2 "Nordeste" 3 "Sudeste" 4 "Sul" 5 "Centro-Oeste", replace
    label values region region_lbl
    label define zone_lbl 1 "Urbano" 2 "Rural", replace
    label values zone zone_lbl
    clone_or_missing sexo, gen(sex)
    clone_or_missing e9, gen(race_ethnicity)
    clone_or_missing e22, gen(education_level)

    numcopy idade, gen(age_years) special
    numcopy rendadompc, gen(household_income_pc)
    numcopy rendaind, gen(individual_income)

    gen byte age_group = .
    replace age_group = 1 if age_years >= 50 & age_years <= 59 & !missing(age_years)
    replace age_group = 2 if age_years >= 60 & age_years <= 69 & !missing(age_years)
    replace age_group = 3 if age_years >= 70 & age_years <= 79 & !missing(age_years)
    replace age_group = 4 if age_years >= 80 & !missing(age_years)
    label define age_group_lbl 1 "50-59" 2 "60-69" 3 "70-79" 4 "80+", replace
    label values age_group age_group_lbl

    ynflag n60, gen(cancer_survivor)
    numcopy n60_1, gen(cancer_age_dx) special
    ynflag n60_3, gen(cancer_recent_treatment)
    clone_or_missing n60_4, gen(cancer_treatment_first)
    clone_or_missing n60_7, gen(cancer_course_2y)
    ynflag n60_51, gen(cancer_chemo)
    ynflag n60_52, gen(cancer_surgery)
    ynflag n60_53, gen(cancer_radiation)
    ynflag n60_54, gen(cancer_symptom_medication)
    ynflag n60_57, gen(cancer_other_treatment)

    ynflag n60_1_1, gen(cancer_breast)
    ynflag n60_1_2, gen(cancer_uterus)
    ynflag n60_1_3, gen(cancer_ovary)
    ynflag n60_1_4, gen(cancer_prostate)
    ynflag n60_1_5, gen(cancer_lung)
    ynflag n60_1_6, gen(cancer_skin)
    ynflag n60_1_7, gen(cancer_gi)
    ynflag n60_1_8, gen(cancer_pancreas)
    ynflag n60_1_9, gen(cancer_liver)
    ynflag n60_1_10, gen(cancer_brain)
    ynflag n60_1_11, gen(cancer_leukemia)
    ynflag n60_1_12, gen(cancer_other_site)

    clone_or_missing m13, gen(pap_smear_timing)
    clone_or_missing m14, gen(breast_exam_timing)
    clone_or_missing m15, gen(mammogram_timing)
    ynflag n68_2, gen(colonoscopy_10y)
    ynflag n68_3, gen(colonoscopy_4y)

    ynflag n52, gen(stroke_survivor)
    numcopy n53, gen(stroke_age_dx) special
    ynflag n53_2, gen(recurrent_stroke)
    ynflag n53_4, gen(stroke_medication)
    ynflag n53_5, gen(stroke_problem)
    ynflag n53_6, gen(stroke_rehab)

    ynflag n58, gen(chronic_spine_condition)
    ynflag n28, gen(hypertension)
    ynflag n35, gen(diabetes)
    ynflag n59, gen(depression_dx)

    ynflag u59_1, gen(physio_90d)
    ynflag u62_1, gen(occupational_therapy_90d)
    ynflag u65_1, gen(speech_therapy_90d)
    ynflag u60, gen(paid_physio_90d)
    ynflag u63, gen(paid_occupational_therapy_90d)
    ynflag u66, gen(paid_speech_therapy_90d)

    ynflag n69, gen(frailty_weight_loss)

    clone_or_missing n73, gen(n73_raw)
    gen byte frailty_exhaustion = .
    capture confirm numeric variable n73_raw
    if !_rc {
        replace frailty_exhaustion = 1 if inlist(n73_raw, 3, 4) & !missing(n73_raw)
        replace frailty_exhaustion = 0 if inlist(n73_raw, 0, 1, 2) & !missing(n73_raw)
    }

    if `w' == 1 {
        numcopy l5, gen(walk_days) special
        numcopy l6, gen(walk_minutes) special
        numcopy l7, gen(mod_days) special
        numcopy l8, gen(mod_minutes) special
        numcopy l9, gen(vig_days) special
        numcopy l10, gen(vig_minutes) special
        numcopy l11, gen(sedentary_minutes_weekday) special
    }
    else {
        numcopy l5, gen(walk_days) special
        numcopy l6_1, gen(walk_hours) special
        numcopy l6_2, gen(walk_min_part) special
        gen double walk_minutes = walk_hours * 60 + walk_min_part

        numcopy l7, gen(mod_days) special
        numcopy l8_1, gen(mod_hours) special
        numcopy l8_2, gen(mod_min_part) special
        gen double mod_minutes = mod_hours * 60 + mod_min_part

        numcopy l9, gen(vig_days) special
        numcopy l10_1, gen(vig_hours) special
        numcopy l10_2, gen(vig_min_part) special
        gen double vig_minutes = vig_hours * 60 + vig_min_part

        numcopy l11_1, gen(sedentary_hours) special
        numcopy l11_2, gen(sedentary_min_part) special
        gen double sedentary_minutes_weekday = sedentary_hours * 60 + sedentary_min_part
    }

    foreach v in walk_days mod_days vig_days {
        replace `v' = . if (`v' < 0 | `v' > 7) & !missing(`v')
    }
    foreach v in walk_minutes mod_minutes vig_minutes sedentary_minutes_weekday {
        replace `v' = . if (`v' < 0 | `v' > 1440) & !missing(`v')
    }

    gen double walk_total = walk_days * walk_minutes
    gen double mod_total = mod_days * mod_minutes
    gen double vig_total = vig_days * vig_minutes
    replace walk_total = 0 if walk_days == 0 & missing(walk_total)
    replace mod_total = 0 if mod_days == 0 & missing(mod_total)
    replace vig_total = 0 if vig_days == 0 & missing(vig_total)
    egen weekly_activity_minutes = rowtotal(walk_total mod_total vig_total), missing

    foreach v in mf27 mf28 mf29 {
        capture confirm variable `v'
        if !_rc {
            replace `v' = . if (`v' < 0 | `v' > 120) & !missing(`v')
        }
    }
    egen grip_max_kg = rowmax(mf27 mf28 mf29)

    foreach v in mf35s mf38s {
        capture confirm variable `v'
        if !_rc {
            replace `v' = . if (`v' < 0.1 | `v' > 120) & !missing(`v')
        }
    }
    egen gait_best_seconds = rowmin(mf35s mf38s)

    gen byte current_smoker = .
    capture confirm variable l30
    if !_rc {
        replace current_smoker = 1 if inlist(l30, 1, 2) & !missing(l30)
        replace current_smoker = 0 if inlist(l30, 0, 3) & !missing(l30)
    }
    capture confirm variable l30_0
    if !_rc {
        replace current_smoker = 0 if missing(current_smoker) & inlist(l30_0, 0, 2) & !missing(l30_0)
    }

    gen byte former_smoker = .
    capture confirm variable l31
    if !_rc {
        replace former_smoker = 1 if inlist(l31, 1, 2) & !missing(l31)
        replace former_smoker = 0 if l31 == 0 & !missing(l31)
    }

    clone_or_missing l24, gen(alcohol_frequency)
    numcopy l25, gen(alcohol_days_week) special
    numcopy l19, gen(fruit_days_week) special
    numcopy l15, gen(vegetable_days_week) special

    gen byte alcohol_any = .
    capture confirm variable l24
    if !_rc {
        replace alcohol_any = 1 if inlist(l24, 2, 3) & !missing(l24)
        replace alcohol_any = 0 if l24 == 1 & !missing(l24)
    }
    replace alcohol_any = 1 if missing(alcohol_any) & alcohol_days_week > 0 & alcohol_days_week <= 7 & !missing(alcohol_days_week)
    replace alcohol_any = 0 if missing(alcohol_any) & alcohol_days_week == 0 & !missing(alcohol_days_week)

    gen byte any_rehab_90d = .
    egen rehab_util_any = rowmax(physio_90d occupational_therapy_90d speech_therapy_90d)
    egen rehab_paid_any = rowmax(paid_physio_90d paid_occupational_therapy_90d paid_speech_therapy_90d)
    replace any_rehab_90d = rehab_util_any if !missing(rehab_util_any)
    replace any_rehab_90d = rehab_paid_any if missing(any_rehab_90d) & !missing(rehab_paid_any)

    keep wave wave_label anon_row_id upa_analysis estrato_analysis weight_analysis ///
        region zone age_years age_group sex race_ethnicity education_level ///
        household_income_pc individual_income cancer_* pap_smear_timing ///
        breast_exam_timing mammogram_timing colonoscopy_10y colonoscopy_4y ///
        stroke_* recurrent_stroke chronic_spine_condition hypertension diabetes ///
        depression_dx physio_90d occupational_therapy_90d speech_therapy_90d ///
        paid_* any_rehab_90d weekly_activity_minutes sedentary_minutes_weekday ///
        current_smoker former_smoker alcohol_frequency alcohol_days_week alcohol_any ///
        fruit_days_week vegetable_days_week frailty_weight_loss frailty_exhaustion ///
        grip_max_kg gait_best_seconds

    compress
    if `w' == 1 {
        save `wave1', replace
    }
    else if `w' == 2 {
        save `wave2', replace
    }
    else {
        save `wave3', replace
    }
}

use `wave1', clear
append using `wave2'
append using `wave3'

bysort wave: egen low_activity_cut = pctile(weekly_activity_minutes), p(20)
bysort wave: egen slow_gait_cut = pctile(gait_best_seconds), p(80)
bysort wave sex: egen weak_grip_cut = pctile(grip_max_kg), p(20)

gen byte frailty_low_activity = .
replace frailty_low_activity = 1 if weekly_activity_minutes <= low_activity_cut & !missing(weekly_activity_minutes, low_activity_cut)
replace frailty_low_activity = 0 if weekly_activity_minutes > low_activity_cut & !missing(weekly_activity_minutes, low_activity_cut)

gen byte frailty_slow_gait = .
replace frailty_slow_gait = 1 if gait_best_seconds >= slow_gait_cut & !missing(gait_best_seconds, slow_gait_cut)
replace frailty_slow_gait = 0 if gait_best_seconds < slow_gait_cut & !missing(gait_best_seconds, slow_gait_cut)

gen byte frailty_weak_grip = .
replace frailty_weak_grip = 1 if grip_max_kg <= weak_grip_cut & !missing(grip_max_kg, weak_grip_cut)
replace frailty_weak_grip = 0 if grip_max_kg > weak_grip_cut & !missing(grip_max_kg, weak_grip_cut)

egen frailty_available_components = rownonmiss(frailty_weight_loss frailty_exhaustion frailty_low_activity frailty_weak_grip frailty_slow_gait)
egen frailty_score_raw = rowtotal(frailty_weight_loss frailty_exhaustion frailty_low_activity frailty_weak_grip frailty_slow_gait)
gen byte frailty_score = frailty_score_raw if frailty_available_components >= 3

gen byte frailty_group = .
replace frailty_group = 0 if frailty_score == 0 & !missing(frailty_score)
replace frailty_group = 1 if inlist(frailty_score, 1, 2) & !missing(frailty_score)
replace frailty_group = 2 if frailty_score >= 3 & !missing(frailty_score)
label define frailty_group_lbl 0 "Robust" 1 "Prefrail" 2 "Frail", replace
label values frailty_group frailty_group_lbl

gen byte frail_binary = .
replace frail_binary = 1 if frailty_score >= 3 & !missing(frailty_score)
replace frail_binary = 0 if frailty_score < 3 & !missing(frailty_score)

rename upa_analysis upa
rename estrato_analysis estrato
rename weight_analysis peso_calibrado

drop low_activity_cut slow_gait_cut weak_grip_cut frailty_score_raw

label data "ELSI harmonized cross-sectional analysis dataset created by Stata pipeline"
compress
save "$out/stata_analysis_dataset.dta", replace
export delimited using "$out/stata_analysis_dataset.csv", replace

display as result "Saved $out/stata_analysis_dataset.dta and .csv"
log close build
