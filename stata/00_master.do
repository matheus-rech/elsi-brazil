version 17
clear all
macro drop _all
set more off
set varabbrev off
capture log close _all

global project "/Users/matheusrech/Pictures/ELSI"
global out "$project/docs/generated"
global logs "$project/docs/generated/stata_logs"

capture mkdir "$out"
capture mkdir "$logs"

log using "$logs/00_master.log", replace text name(master)

display as result "ELSI Stata survey pipeline started: " c(current_date) " " c(current_time)

do "$project/src/stata/01_build_analysis_dataset.do"
do "$project/src/stata/02_survey_analysis.do"

display as result "ELSI Stata survey pipeline finished: " c(current_date) " " c(current_time)
log close master
