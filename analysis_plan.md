# ELSI Cancer, Frailty, Rehabilitation, and Disparities Analysis Plan

## Aim

Build a local, reproducible cross-sectional analysis workspace for the three available ELSI-Brazil waves, focused on public-health-relevant disparities among adults aged 50+.

The initial scientific emphasis is:

- Frailty burden among oncologic survivors, chronic spine/low-back-condition respondents, and stroke survivors.
- Rehabilitation access among stroke survivors and broader allied-health use.
- Geographic, sociodemographic, and lifestyle disparities across outcomes.
- Cancer screening and survivorship fields across waves.

## Data Sources

- `ELSI Portugues (1a onda) stata13.dta`
- `ELSI Portugues (2a onda) stata13.dta`
- `ELSI Portugues (3a onda).dta`
- Household and individual questionnaires under `Domiciliar/`, `Individual/`, and `Body measurements/`.

The scripts treat Stata labels as the primary machine-readable questionnaire metadata, then map variables into the screenshot-style category taxonomy in `config/module_taxonomy.csv`.

## Survey Design

Each wave is analyzed as a representative cross-sectional sample using:

- PSU: `upa`
- Strata: `estrato`
- Weight: `peso_calibrado`
- Survey design: `survey::svydesign(ids = ~upa, strata = ~estrato, weights = ~peso_calibrado, nest = TRUE)`

This is a per-wave cross-sectional design. The scaffold does not assume longitudinal follow-up, replicate weights, or survival-time inference unless those files are later added and documented.

The Stata pipeline in `src/stata/` is kept as the primary audit implementation for the weighted prevalence tables and survey logistic models. The R pipeline in `src/R/` generates the metadata catalog, harmonized CSVs, tests, and Shiny dashboard used for exploration.

For the audit models, R and Stata use the same reference categories: region `Norte` and zone `Urbano`. Wave 3 zone labels are normalized to `Urbano`/`Rural` before analysis. Hour/minute activity fields are capped after hours and minutes are combined, so impossible totals above 1,440 minutes per activity domain are missing in both engines.

## Core Derived Variables

- `cancer_survivor`: yes/no from `n60`.
- `cancer_recent_treatment`: yes/no from `n60_3`, available from wave 2 onward.
- `stroke_survivor`: yes/no from `n52`.
- `stroke_rehab`: yes/no from `n53_6`, available from wave 2 onward.
- `chronic_spine_condition`: yes/no from `n58`; the wording is chronic spine problem, not isolated lumbar pain.
- `frailty_score`: 0-5 Fried-like proxy from available components:
  - Unintentional weight loss: `n69`.
  - Exhaustion/effort: high-frequency response on `n73`.
  - Low activity: bottom wave-specific quintile of weekly walking/moderate/vigorous activity minutes.
  - Weakness: bottom wave- and sex-specific quintile of maximum grip strength from `mf27-mf29`.
  - Slowness: top wave-specific quintile of best valid gait time from `mf35s/mf38s`.
- `frailty_group`: robust, prefrail, frail. Rows with fewer than three available frailty components remain missing for this classification.

This frailty measure is a Fried-like operational proxy built from variables available across the local waves. It should be labeled as a proxy in manuscripts until replaced or benchmarked against a published ELSI-specific frailty definition.

## Initial Statistical Questions

1. Is frailty more prevalent among cancer survivors than non-cancer respondents after accounting for age, sex, region, and urban/rural zone?
2. Is frailty more prevalent among respondents with chronic spine conditions?
3. Among stroke survivors in waves 2-3, is stroke-related rehabilitation access patterned by region, zone, or frailty?
4. Do cancer screening indicators vary by region, zone, race/ethnicity, income, and lifestyle?
5. Which wave-specific oncology fields, especially cancer site in wave 3, suggest high-value secondary analyses?

## Modeling Strategy

Use survey-weighted estimates and confidence intervals for descriptive tables. Use survey logistic regression for the audit odds-ratio tables, reported with 95% confidence intervals. The audit adjustment set is age, sex, region, and zone, matching `svy: logistic ... c.age_years i.sex i.region i.zone` in Stata. Broader covariate adjustment with race/ethnicity, education, smoking, alcohol, or income should be treated as a sensitivity analysis and stored separately from the audit outputs.

Models should be interpreted as associations, not causal effects. The first scaffold prioritizes reproducible variable identification, transparent phenotype construction, and disparity screening over definitive inference.

## Sensitivity Priorities

- Replace the current frailty proxy with a published ELSI frailty phenotype if a validated definition is selected.
- Compare unweighted and weighted estimates for sparse subgroups.
- Separate cancer-site-specific analyses in wave 3.
- Treat rehabilitation access separately as stroke-specific rehab (`n53_6`) and general allied-health use (`u59_1`, `u62_1`, `u65_1`).
- Add official replicate weights or longitudinal weights if available.
