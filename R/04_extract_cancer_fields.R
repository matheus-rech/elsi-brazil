source("src/R/00_common.R")

ensure_output_dirs()

field_specs <- tibble::tribble(
  ~domain, ~standard_name, ~display_name, ~description, ~rule, ~wave1_var, ~wave2_var, ~wave3_var, ~comparability_note,
  "Cancer diagnosis", "cancer_dx", "Cancer diagnosis", "Doctor ever said the respondent has or had cancer.", "yes_no", "n60", "n60", "n60", "Directly comparable yes/no diagnosis item across all three local waves.",
  "Cancer diagnosis", "cancer_age_dx", "Age at first cancer diagnosis", "Age when the doctor first said the respondent had cancer.", "numeric", NA, "n60_1", "n60_1", "Available in waves 2-3 only.",
  "Recent treatment", "cancer_recent_treatment", "Cancer treatment in last 2 years", "Any cancer treatment in the last two years.", "yes_no", NA, "n60_3", "n60_3", "Available in waves 2-3 only.",
  "Recent treatment", "cancer_first_or_recurrence", "First treatment vs recurrence", "Whether recent treatment was first treatment or recurrence treatment.", "label", NA, "n60_4", "n60_4", "Available in waves 2-3 only; categorical label preserved.",
  "Recent treatment", "cancer_tx_chemo", "Chemotherapy", "Recent cancer treatment included chemotherapy.", "yes_no", NA, "n60_51", "n60_51", "Available in waves 2-3 only.",
  "Recent treatment", "cancer_tx_surgery", "Surgery", "Recent cancer treatment included surgery.", "yes_no", NA, "n60_52", "n60_52", "Available in waves 2-3 only.",
  "Recent treatment", "cancer_tx_radiation", "Radiation", "Recent cancer treatment included radiation/radiotherapy.", "yes_no", NA, "n60_53", "n60_53", "Available in waves 2-3 only.",
  "Recent treatment", "cancer_tx_symptom_medication", "Symptom medication", "Recent cancer treatment included medication for symptoms.", "yes_no", NA, "n60_54", NA, "Present in wave 2; not present in the local wave 3 DTA.",
  "Recent treatment", "cancer_tx_other", "Other treatment", "Recent cancer treatment included another treatment type.", "yes_no", NA, "n60_57", NA, "Present in wave 2; not present in the local wave 3 DTA.",
  "Recent treatment", "cancer_course_2y", "Cancer course in last 2 years", "Self-assessed cancer course in the last two years.", "label", NA, "n60_7", "n60_7", "Available in waves 2-3 only; categorical label preserved.",
  "Cancer site", "cancer_site_breast", "Breast cancer", "Cancer site: breast.", "yes_no", NA, NA, "n60_1_1", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_uterus", "Uterus cancer", "Cancer site: uterus/cervix/body.", "yes_no", NA, NA, "n60_1_2", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_ovary", "Ovary cancer", "Cancer site: ovary.", "yes_no", NA, NA, "n60_1_3", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_prostate", "Prostate cancer", "Cancer site: prostate.", "yes_no", NA, NA, "n60_1_4", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_lung", "Bronchi/lung cancer", "Cancer site: bronchi/lungs.", "yes_no", NA, NA, "n60_1_5", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_skin", "Skin cancer", "Cancer site: skin.", "yes_no", NA, NA, "n60_1_6", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_gi", "Stomach/intestine cancer", "Cancer site: stomach/intestine.", "yes_no", NA, NA, "n60_1_7", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_pancreas", "Pancreas cancer", "Cancer site: pancreas.", "yes_no", NA, NA, "n60_1_8", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_liver", "Liver cancer", "Cancer site: liver.", "yes_no", NA, NA, "n60_1_9", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_brain", "Brain cancer", "Cancer site: brain.", "yes_no", NA, NA, "n60_1_10", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_leukemia", "Leukemia", "Cancer site: blood/leukemia.", "yes_no", NA, NA, "n60_1_11", "Site-specific fields are present only in the local wave 3 DTA.",
  "Cancer site", "cancer_site_other", "Other cancer site", "Cancer site: other organs.", "yes_no", NA, NA, "n60_1_12", "Site-specific fields are present only in the local wave 3 DTA.",
  "Screening", "pap_smear_timing", "Pap smear timing", "Timing of last Pap smear/cervical cancer preventive exam.", "label", "m13", "m13", "m13", "Comparable across all waves; response wording shifts from Portuguese labels in wave 1 to cleaned wave 2/3 labels.",
  "Screening", "breast_exam_timing", "Clinical breast exam timing", "Timing of last clinical breast exam by doctor or nurse.", "label", "m14", "m14", "m14", "Comparable across all waves.",
  "Screening", "mammogram_timing", "Mammogram timing", "Timing of last mammogram or breast x-ray.", "label", "m15", "m15", "m15", "Comparable across all waves; wave 1 label order starts with Never.",
  "Screening", "colonoscopy_10y", "Colonoscopy in last 10 years", "Colonoscopy in the last 10 years.", "yes_no", NA, "n68_2", "n68_2", "Available in waves 2-3 only.",
  "Screening", "colonoscopy_4y", "Colonoscopy in last 4 years", "Whether the colonoscopy was done in the last four years.", "yes_no", NA, "n68_3", "n68_3", "Available in waves 2-3 only among those reporting colonoscopy.",
  "Gynecologic history", "uterus_removed", "Hysterectomy", "Respondent had uterus removed.", "yes_no", "m11", "m11", "m11", "Available across all waves for eligible women.",
  "Gynecologic history", "uterus_removed_age", "Age at hysterectomy", "Age when uterus was removed.", "numeric", NA, "m11_1", "m11_1", "Available in waves 2-3 only.",
  "Gynecologic history", "uterus_removal_reason", "Reason for hysterectomy", "Doctor-reported reason for removing uterus, including gynecological cancer option.", "label", "m12", "m12", "m12", "Available across all waves; keep categorical reason labels.",
  "Gynecologic history", "ovary_removed", "Ovary surgery", "Respondent had ovary/ovaries removed.", "yes_no", NA, NA, "m12_1", "Wave 3 only.",
  "Gynecologic history", "ovary_removed_age", "Age at ovary removal", "Age when ovary/ovaries were removed.", "numeric", NA, NA, "m12_2", "Wave 3 only.",
  "Gynecologic history", "ovary_removal_reason", "Reason for ovary removal", "Reason for removing ovary/ovaries, including cancer/cancer-prevention options.", "label", NA, NA, "m12_3", "Wave 3 only."
)

questionnaire_evidence <- tibble::tribble(
  ~wave, ~wave_label, ~questionnaire_file, ~evidence_scope, ~notes,
  1L, "2015-16", "Domiciliar/Entrevista-domiciliar-2015-16.pdf", "No local wave 1 individual questionnaire file was present; Stata labels were used for wave 1 cancer-field wording.", "The local household PDF did not expose the individual cancer items in text search.",
  2L, "2019-21", "Individual/Individual_interview_2019-21.pdf", "Individual questionnaire text confirms Pap smear, breast exam, mammogram, n60 cancer diagnosis, age at diagnosis, recent treatment, treatment type, course, and colonoscopy items.", "Wave 2 does not include cancer-site variables in the local DTA.",
  3L, "2023-24", "Individual/Individual_interview_2023-24.pdf", "Individual questionnaire text confirms Pap smear, breast exam, mammogram, n60 cancer diagnosis, age at diagnosis, organ/site items, recent treatment, treatment type, course, and colonoscopy items.", "Wave 3 adds site-specific cancer variables and ovary-removal history."
)

read_wave_metadata <- function(wave, wave_label, dta_file, dta_path) {
  empty <- read_elsi_dta(dta_path, n_max = 0)
  tibble::tibble(
    wave = wave,
    wave_label = wave_label,
    dta_file = dta_file,
    variable = names(empty),
    label = purrr::map_chr(empty, ~ repair_text(attr(.x, "label") %||% "")),
    storage_class = purrr::map_chr(empty, ~ paste(class(.x), collapse = ";")),
    value_labels = purrr::map_chr(empty, function(x) {
      labels <- attr(x, "labels")
      if (is.null(labels)) return("")
      paste0(repair_text(names(labels)), "=", unname(labels), collapse = " | ")
    })
  )
}

field_specs_long <- field_specs %>%
  tidyr::pivot_longer(
    cols = c(wave1_var, wave2_var, wave3_var),
    names_to = "wave_key",
    values_to = "variable"
  ) %>%
  mutate(
    wave = dplyr::case_when(
      wave_key == "wave1_var" ~ 1L,
      wave_key == "wave2_var" ~ 2L,
      wave_key == "wave3_var" ~ 3L
    )
  ) %>%
  left_join(wave_files %>% select(wave, wave_label, dta_file), by = "wave") %>%
  select(-wave_key)

metadata <- purrr::pmap_dfr(wave_files, read_wave_metadata)

cancer_field_catalog <- field_specs_long %>%
  left_join(metadata, by = c("wave", "wave_label", "dta_file", "variable")) %>%
  mutate(
    present = !is.na(variable) & !is.na(label),
    source = dplyr::case_when(
      wave == 1L ~ "Stata label; local wave 1 individual questionnaire not present",
      wave == 2L ~ "Stata label plus Individual_interview_2019-21.pdf text inspection",
      wave == 3L ~ "Stata label plus Individual_interview_2023-24.pdf text inspection",
      TRUE ~ "Stata label"
    ),
    label = dplyr::coalesce(label, ""),
    storage_class = dplyr::coalesce(storage_class, ""),
    value_labels = dplyr::coalesce(value_labels, "")
  ) %>%
  arrange(domain, standard_name, wave)

extract_by_rule <- function(data, variable, rule) {
  n <- nrow(data)
  if (is.na(variable) || !(variable %in% names(data))) {
    return(switch(
      rule,
      yes_no = rep(NA_integer_, n),
      numeric = rep(NA_real_, n),
      label = rep(NA_character_, n)
    ))
  }

  switch(
    rule,
    yes_no = yes_no_to01(data[[variable]]),
    numeric = clean_numeric(data[[variable]]),
    label = clean_chr(data[[variable]])
  )
}

extract_cancer_wave <- function(wave, wave_label, dta_file, dta_path) {
  message("Reading wave ", wave, " cancer fields from ", dta_file)
  data <- read_elsi_dta(dta_path)
  wave_variable <- if (wave == 1L) {
    field_specs$wave1_var
  } else if (wave == 2L) {
    field_specs$wave2_var
  } else {
    field_specs$wave3_var
  }
  wave_specs <- field_specs %>%
    mutate(variable = wave_variable)

  extracted <- purrr::map2(wave_specs$variable, wave_specs$rule, ~ extract_by_rule(data, .x, .y))
  names(extracted) <- wave_specs$standard_name

  tibble::tibble(
    wave = wave,
    wave_label = wave_label,
    source_file = dta_file,
    anon_row_id = seq_len(nrow(data)),
    upa = safe_num(data, "upa"),
    estrato = safe_num(data, "estrato"),
    peso_calibrado = safe_num(data, "peso_calibrado"),
    region = safe_chr(data, "regiao"),
    zone = safe_chr(data, "zona"),
    age_years = safe_num(data, "idade"),
    sex = safe_chr(data, "sexo")
  ) %>%
    bind_cols(tibble::as_tibble(extracted))
}

wave_data <- purrr::pmap(wave_files, function(wave, wave_label, dta_file, dta_path) {
  read_elsi_dta(dta_path)
})
names(wave_data) <- as.character(wave_files$wave)

file_inventory <- purrr::map_dfr(names(wave_data), function(wave_chr) {
  idx <- match(as.integer(wave_chr), wave_files$wave)
  data <- wave_data[[wave_chr]]
  tibble::tibble(
    wave = wave_files$wave[idx],
    wave_label = wave_files$wave_label[idx],
    dta_file = wave_files$dta_file[idx],
    n_rows = nrow(data),
    n_variables = ncol(data)
  )
})

cancer_minimal_extract <- purrr::pmap_dfr(wave_files, extract_cancer_wave)

summarise_field <- function(domain, standard_name, display_name, description, rule,
                            wave1_var, wave2_var, wave3_var, comparability_note,
                            variable, wave, wave_label, dta_file) {
  data <- wave_data[[as.character(wave)]]
  present <- !is.na(variable) && variable %in% names(data)
  if (!present) {
    return(tibble::tibble(
      domain = domain,
      standard_name = standard_name,
      display_name = display_name,
      wave = wave,
      wave_label = wave_label,
      variable = variable %||% NA_character_,
      present = FALSE,
      n_records = nrow(data),
      n_nonmissing = 0L,
      pct_nonmissing = 0,
      n_yes = NA_integer_,
      pct_yes_among_nonmissing = NA_real_,
      numeric_min = NA_real_,
      numeric_median = NA_real_,
      numeric_max = NA_real_,
      n_distinct_values = NA_integer_
    ))
  }

  values <- extract_by_rule(data, variable, rule)
  n_nonmissing <- sum(!is.na(values) & values != "")
  n_yes <- if (rule == "yes_no") sum(values == 1L, na.rm = TRUE) else NA_integer_
  numeric_values <- if (rule == "numeric") values[!is.na(values)] else numeric()

  tibble::tibble(
    domain = domain,
    standard_name = standard_name,
    display_name = display_name,
    wave = wave,
    wave_label = wave_label,
    variable = variable,
    present = TRUE,
    n_records = nrow(data),
    n_nonmissing = n_nonmissing,
    pct_nonmissing = n_nonmissing / nrow(data),
    n_yes = n_yes,
    pct_yes_among_nonmissing = if (rule == "yes_no" && n_nonmissing > 0) n_yes / n_nonmissing else NA_real_,
    numeric_min = if (length(numeric_values) > 0) min(numeric_values) else NA_real_,
    numeric_median = if (length(numeric_values) > 0) stats::median(numeric_values) else NA_real_,
    numeric_max = if (length(numeric_values) > 0) max(numeric_values) else NA_real_,
    n_distinct_values = dplyr::n_distinct(values[!is.na(values) & values != ""])
  )
}

cancer_field_summary <- purrr::pmap_dfr(field_specs_long, summarise_field) %>%
  arrange(domain, standard_name, wave)

response_levels <- purrr::pmap_dfr(field_specs_long, function(domain, standard_name, display_name, description, rule,
                                                              wave1_var, wave2_var, wave3_var, comparability_note,
                                                              variable, wave, wave_label, dta_file) {
  data <- wave_data[[as.character(wave)]]
  if (rule == "numeric" || is.na(variable) || !(variable %in% names(data))) {
    return(tibble::tibble())
  }
  values <- extract_by_rule(data, variable, rule)
  tibble::tibble(response_label = as.character(values)) %>%
    filter(!is.na(response_label), response_label != "") %>%
    count(response_label, name = "n") %>%
    mutate(
      domain = domain,
      standard_name = standard_name,
      display_name = display_name,
      wave = wave,
      wave_label = wave_label,
      variable = variable,
      pct_among_nonmissing = n / sum(n),
      .before = 1
    )
}) %>%
  arrange(domain, standard_name, wave, desc(n), response_label)

cancer_wave_comparison <- cancer_field_catalog %>%
  group_by(domain, standard_name, display_name, description, rule, comparability_note) %>%
  summarise(
    wave1_variable = dplyr::first(variable[wave == 1]),
    wave1_present = dplyr::first(present[wave == 1]),
    wave1_label = dplyr::first(label[wave == 1]),
    wave2_variable = dplyr::first(variable[wave == 2]),
    wave2_present = dplyr::first(present[wave == 2]),
    wave2_label = dplyr::first(label[wave == 2]),
    wave3_variable = dplyr::first(variable[wave == 3]),
    wave3_present = dplyr::first(present[wave == 3]),
    wave3_label = dplyr::first(label[wave == 3]),
    availability = paste(wave_label[present], collapse = "; "),
    .groups = "drop"
  ) %>%
  arrange(domain, standard_name)

write_csv_utf8(file_inventory, "docs/generated/cancer_file_inventory.csv")
write_csv_utf8(questionnaire_evidence, "docs/generated/cancer_questionnaire_evidence.csv")
write_csv_utf8(cancer_field_catalog, "docs/generated/cancer_field_catalog.csv")
write_csv_utf8(cancer_wave_comparison, "docs/generated/cancer_wave_comparison.csv")
write_csv_utf8(cancer_field_summary, "docs/generated/cancer_field_summary.csv")
write_csv_utf8(response_levels, "docs/generated/cancer_response_levels.csv")
write_csv_utf8(cancer_minimal_extract, "docs/generated/cancer_minimal_extract.csv")

md_table <- function(data) {
  if (nrow(data) == 0) return(character())
  data <- mutate(data, across(everything(), as.character))
  header <- paste0("| ", paste(names(data), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(data)), collapse = " | "), " |")
  rows <- apply(data, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, sep, rows)
}

availability_counts <- cancer_field_catalog %>%
  group_by(wave, wave_label) %>%
  summarise(
    curated_fields = n(),
    fields_present = sum(present),
    fields_absent = sum(!present),
    .groups = "drop"
  )

core_comparison <- cancer_wave_comparison %>%
  filter(domain %in% c("Cancer diagnosis", "Recent treatment", "Cancer site", "Screening")) %>%
  transmute(
    field = display_name,
    wave1 = if_else(wave1_present, wave1_variable, "not available"),
    wave2 = if_else(wave2_present, wave2_variable, "not available"),
    wave3 = if_else(wave3_present, wave3_variable, "not available"),
    note = comparability_note
  )

logic_lines <- c(
  "# ELSI Cancer Field Extraction Logic",
  "",
  paste0("Generated on ", Sys.Date(), " from local files only."),
  "",
  "## Scope",
  "",
  "This artifact turns the local ELSI cancer-dashboard exploration into a reproducible extractor. It reads the three local Stata files, preserves Stata labels, applies an explicit cancer-field map, and writes de-identified CSV outputs under `docs/generated/`.",
  "",
  "It reuses the useful pattern from the May ELSI analysis history: keep all extraction local, preserve the Stata data dictionary, and write simple rerunnable outputs. It does not download data or call external services.",
  "",
  "## Input Inventory",
  "",
  md_table(file_inventory %>% select(wave_label, dta_file, n_rows, n_variables)),
  "",
  "## Questionnaire Evidence",
  "",
  md_table(questionnaire_evidence %>% select(wave_label, questionnaire_file, evidence_scope)),
  "",
  "## Availability Summary",
  "",
  md_table(availability_counts %>% select(wave_label, curated_fields, fields_present, fields_absent)),
  "",
  "## Core Wave Comparison",
  "",
  md_table(core_comparison),
  "",
  "## Extraction Rules",
  "",
  "- `yes_no`: convert labelled yes/no fields to 1/0 with nonresponse and not-applicable values set to missing.",
  "- `numeric`: remove Stata labels and set common nonresponse/not-applicable codes such as 888/999 to missing.",
  "- `label`: preserve cleaned value labels for ordered or nominal questionnaire responses.",
  "- Direct individual and household identifiers are not exported; `anon_row_id` is a wave-local row number only.",
  "",
  "## Generated Outputs",
  "",
  "- `cancer_file_inventory.csv`: local DTA file sizes in rows/variables.",
  "- `cancer_questionnaire_evidence.csv`: questionnaire files inspected and source limitations.",
  "- `cancer_field_catalog.csv`: curated variable-level map with Stata labels and value labels.",
  "- `cancer_wave_comparison.csv`: one row per harmonized field comparing availability across waves.",
  "- `cancer_field_summary.csv`: per-wave completeness and simple numeric/yes-no summaries.",
  "- `cancer_response_levels.csv`: response-level counts for categorical and yes/no fields.",
  "- `cancer_minimal_extract.csv`: de-identified row-level cancer/screening extract for rerunnable local analysis.",
  "",
  "## Main Comparability Notes",
  "",
  "- Cancer diagnosis (`n60`) is present in all three waves and is the safest cross-wave survivorship indicator.",
  "- Age at diagnosis and treatment details start in wave 2.",
  "- Cancer-site indicators are only present in wave 3 in the local DTA files.",
  "- Cervical and breast screening items are present across all waves; colonoscopy appears in waves 2 and 3.",
  "- The local wave 1 individual questionnaire PDF was not present, so wave 1 wording is documented from Stata labels rather than questionnaire text.",
  "",
  "## Rerun",
  "",
  "From `/Users/matheusrech/Pictures/ELSI` run:",
  "",
  "```bash",
  "Rscript src/R/04_extract_cancer_fields.R",
  "```"
)

writeLines(logic_lines, path_here("docs/generated/cancer_extraction_logic.md"), useBytes = TRUE)

message("Wrote cancer extractor outputs to docs/generated/")
