source("src/R/00_common.R")

site_data_dir <- path_here("site", "data")
dir.create(site_data_dir, recursive = TRUE, showWarnings = FALSE)

site_files <- c(
  "cancer_file_inventory.csv",
  "cancer_questionnaire_evidence.csv",
  "cancer_field_catalog.csv",
  "cancer_wave_comparison.csv",
  "cancer_field_summary.csv",
  "cancer_response_levels.csv"
)

missing_files <- site_files[!file.exists(path_here("docs", "generated", site_files))]
if (length(missing_files) > 0) {
  stop(
    "Missing generated cancer files. Run Rscript src/R/04_extract_cancer_fields.R first: ",
    paste(missing_files, collapse = ", "),
    call. = FALSE
  )
}

purrr::walk(site_files, function(file) {
  file.copy(
    from = path_here("docs", "generated", file),
    to = file.path(site_data_dir, file),
    overwrite = TRUE
  )
})

manifest <- tibble::tibble(
  file = site_files,
  source = file.path("docs/generated", site_files),
  deployed_path = file.path("data", site_files),
  bytes = file.info(file.path(site_data_dir, site_files))$size
)

readr::write_csv(manifest, file.path(site_data_dir, "site_data_manifest.csv"))

message("Copied aggregate cancer extractor data to site/data/")
