# ELSI Local Analysis Runbook

Run all commands from `/Users/matheusrech/Pictures/ELSI`.

## 0. Build the minimal cancer-field extractor artifact

```bash
Rscript src/R/04_extract_cancer_fields.R
```

Outputs:

- `docs/generated/cancer_extraction_logic.md`
- `docs/generated/cancer_file_inventory.csv`
- `docs/generated/cancer_questionnaire_evidence.csv`
- `docs/generated/cancer_field_catalog.csv`
- `docs/generated/cancer_wave_comparison.csv`
- `docs/generated/cancer_field_summary.csv`
- `docs/generated/cancer_response_levels.csv`
- `docs/generated/cancer_minimal_extract.csv`

This path is the smallest reproducible local cancer artifact. It reads only the three local `.dta` files and local questionnaires, exports no direct household or individual IDs, and does not use external services.

## 0b. Prepare and preview the static frontend

```bash
Rscript src/R/05_prepare_static_site_data.R
python3 -m http.server 8888 --directory site
```

Then open `http://localhost:8888`.

The static frontend uses only aggregate/provenance CSVs copied into `site/data`. It intentionally does not publish `docs/generated/cancer_minimal_extract.csv`. Netlify is configured in `netlify.toml` with `site` as the publish directory. Vercel is configured in `vercel.json` with `site` as the output directory; `.vercelignore` uploads only `site/` and `vercel.json`.

## 1. Extract metadata

```bash
Rscript src/R/01_extract_metadata.R
```

Outputs:

- `docs/generated/variable_catalog.csv`
- `docs/generated/topic_variable_catalog.csv`
- `docs/generated/module_summary.csv`

## 2. Build harmonized analytic dataset

```bash
Rscript src/R/02_build_analysis_dataset.R
```

Outputs:

- `docs/generated/analytic_dataset.csv`
- `docs/generated/frailty_thresholds.csv`
- `docs/generated/derived_variable_dictionary.csv`

The exported analytic dataset excludes direct individual and household IDs. It keeps design variables (`upa`, `estrato`, `peso_calibrado`) because they are required for survey-weighted analysis.

Harmonization checks that should stay aligned between R and Stata:

- Region uses the Stata code order `Norte`, `Nordeste`, `Sudeste`, `Sul`, `Centro-Oeste`.
- Zone is normalized to `Urbano` and `Rural` in all waves, including the longer wave 3 labels.
- Wave 2-3 hour/minute activity fields are capped after hours and minutes are combined; combined domain totals above 1,440 minutes are set missing before frailty low-activity classification.

## 3. Generate survey summaries and first-pass models

```bash
Rscript src/R/03_survey_analysis.R
```

Outputs:

- `docs/generated/weighted_prevalence_overall.csv`
- `docs/generated/weighted_prevalence_by_region.csv`
- `docs/generated/weighted_prevalence_by_zone.csv`
- `docs/generated/weighted_prevalence_by_sex.csv`
- `docs/generated/survey_association_models.csv`

## 4. Run the Stata audit pipeline

```bash
/Applications/StataNow/StataSE.app/Contents/MacOS/stata-se -b do src/stata/00_master.do
```

Outputs:

- `docs/generated/stata_analysis_dataset.dta`
- `docs/generated/stata_analysis_dataset.csv`
- `docs/generated/stata_weighted_prevalence.dta`
- `docs/generated/stata_weighted_prevalence.csv`
- `docs/generated/stata_survey_models.dta`
- `docs/generated/stata_survey_models.csv`
- `docs/generated/stata_logs/00_master.log`
- `docs/generated/stata_logs/01_build_analysis_dataset.log`
- `docs/generated/stata_logs/02_survey_analysis.log`

The Stata path is the primary audit trail for the survey-weighted estimates and logistic models. The R path remains the dashboard and exploratory-analysis path; both read the same three local `.dta` files and use the same harmonized phenotype definitions.

Audit logistic models use age, sex, region, and zone adjustment only. Region models use `Norte` as the reference and zone models use `Urbano` as the reference. Stroke-rehabilitation models are restricted to stroke survivors in waves 2-3 because `stroke_rehab` is only defined after a stroke report.

In `stata_survey_models.csv`, factor terms follow Stata numeric codes: `2.region` = `Nordeste`, `3.region` = `Sudeste`, `4.region` = `Sul`, `5.region` = `Centro-Oeste`, and `2.zone` = `Rural`.

## 5. Run tests

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
```

## 6. Launch the dashboard

```bash
Rscript -e 'shiny::runApp("src/app", host = "127.0.0.1", port = 3838, launch.browser = TRUE)'
```

The dashboard reads the generated CSV files. If they do not exist yet, run steps 1-3 first.
