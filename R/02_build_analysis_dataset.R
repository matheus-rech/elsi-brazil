source("src/R/00_common.R")

ensure_output_dirs()

standardize_wave <- function(wave, wave_label, dta_file, dta_path) {
  wave_id <- as.integer(wave)
  message("Reading wave ", wave_id, " from ", basename(dta_path))
  data <- read_elsi_dta(dta_path)
  n <- nrow(data)

  activity_minutes <- activity_minutes_week(data, wave_id)
  grip_max <- row_max_valid(
    valid_measure(safe_var(data, "mf27"), low = 0, high = 120),
    valid_measure(safe_var(data, "mf28"), low = 0, high = 120),
    valid_measure(safe_var(data, "mf29"), low = 0, high = 120)
  )
  gait_best_seconds <- row_min_valid(
    valid_measure(safe_var(data, "mf35s"), low = 0.1, high = 120),
    valid_measure(safe_var(data, "mf38s"), low = 0.1, high = 120)
  )
  l30_num <- suppressWarnings(as.numeric(haven::zap_labels(safe_var(data, "l30"))))
  l30_0_num <- suppressWarnings(as.numeric(haven::zap_labels(safe_var(data, "l30_0"))))
  current_smoker <- case_when(
    l30_num %in% c(1, 2) ~ 1L,
    l30_num %in% c(0, 3) ~ 0L,
    (is.na(l30_num) | l30_num == 8) & l30_0_num %in% c(0, 2) ~ 0L,
    TRUE ~ NA_integer_
  )
  former_smoker <- case_when(
    suppressWarnings(as.numeric(haven::zap_labels(safe_var(data, "l31")))) %in% c(1, 2) ~ 1L,
    suppressWarnings(as.numeric(haven::zap_labels(safe_var(data, "l31")))) == 0 ~ 0L,
    TRUE ~ NA_integer_
  )
  l24_num <- suppressWarnings(as.numeric(haven::zap_labels(safe_var(data, "l24"))))
  l25_num <- suppressWarnings(as.numeric(haven::zap_labels(safe_var(data, "l25"))))
  alcohol_any <- case_when(
    l24_num %in% c(2, 3) ~ 1L,
    l24_num == 1 ~ 0L,
    is.na(l24_num) & l25_num >= 1 & l25_num <= 7 ~ 1L,
    is.na(l24_num) & l25_num == 0 ~ 0L,
    TRUE ~ NA_integer_
  )
  n73_num <- suppressWarnings(as.numeric(haven::zap_labels(safe_var(data, "n73"))))
  frailty_exhaustion <- case_when(
    n73_num %in% c(3, 4) ~ 1L,
    n73_num %in% c(0, 1, 2) ~ 0L,
    TRUE ~ NA_integer_
  )

  tibble::tibble(
    wave = wave_id,
    wave_label = wave_label,
    anon_row_id = seq_len(n),
    upa = safe_num(data, "upa"),
    estrato = safe_num(data, "estrato"),
    peso_calibrado = safe_num(data, "peso_calibrado"),
    region = safe_chr(data, "regiao"),
    zone = normalize_zone(safe_var(data, "zona")),
    age_years = safe_num(data, "idade"),
    age_group = make_age_group(age_years),
    sex = safe_chr(data, "sexo"),
    race_ethnicity = safe_chr(data, "e9"),
    education_level = safe_chr(data, "e22"),
    household_income_pc = safe_num(data, "rendadompc"),
    individual_income = safe_num(data, "rendaind"),
    cancer_survivor = yes_no_to01(safe_var(data, "n60")),
    cancer_age_dx = safe_num(data, "n60_1"),
    cancer_recent_treatment = yes_no_to01(safe_var(data, "n60_3")),
    cancer_treatment_first = safe_chr(data, "n60_4"),
    cancer_course_2y = safe_chr(data, "n60_7"),
    cancer_chemo = yes_no_to01(safe_var(data, "n60_51")),
    cancer_surgery = yes_no_to01(safe_var(data, "n60_52")),
    cancer_radiation = yes_no_to01(safe_var(data, "n60_53")),
    cancer_symptom_medication = yes_no_to01(safe_var(data, "n60_54")),
    cancer_other_treatment = yes_no_to01(safe_var(data, "n60_57")),
    cancer_breast = yes_no_to01(safe_var(data, "n60_1_1")),
    cancer_uterus = yes_no_to01(safe_var(data, "n60_1_2")),
    cancer_ovary = yes_no_to01(safe_var(data, "n60_1_3")),
    cancer_prostate = yes_no_to01(safe_var(data, "n60_1_4")),
    cancer_lung = yes_no_to01(safe_var(data, "n60_1_5")),
    cancer_skin = yes_no_to01(safe_var(data, "n60_1_6")),
    cancer_gi = yes_no_to01(safe_var(data, "n60_1_7")),
    cancer_pancreas = yes_no_to01(safe_var(data, "n60_1_8")),
    cancer_liver = yes_no_to01(safe_var(data, "n60_1_9")),
    cancer_brain = yes_no_to01(safe_var(data, "n60_1_10")),
    cancer_leukemia = yes_no_to01(safe_var(data, "n60_1_11")),
    cancer_other_site = yes_no_to01(safe_var(data, "n60_1_12")),
    pap_smear_timing = safe_chr(data, "m13"),
    breast_exam_timing = safe_chr(data, "m14"),
    mammogram_timing = safe_chr(data, "m15"),
    colonoscopy_10y = yes_no_to01(safe_var(data, "n68_2")),
    colonoscopy_4y = yes_no_to01(safe_var(data, "n68_3")),
    stroke_survivor = yes_no_to01(safe_var(data, "n52")),
    stroke_age_dx = safe_num(data, "n53"),
    recurrent_stroke = yes_no_to01(safe_var(data, "n53_2")),
    stroke_medication = yes_no_to01(safe_var(data, "n53_4")),
    stroke_problem = yes_no_to01(safe_var(data, "n53_5")),
    stroke_rehab = yes_no_to01(safe_var(data, "n53_6")),
    chronic_spine_condition = yes_no_to01(safe_var(data, "n58")),
    hypertension = yes_no_to01(safe_var(data, "n28")),
    diabetes = yes_no_to01(safe_var(data, "n35")),
    depression_dx = yes_no_to01(safe_var(data, "n59")),
    physio_90d = yes_no_to01(safe_var(data, "u59_1")),
    occupational_therapy_90d = yes_no_to01(safe_var(data, "u62_1")),
    speech_therapy_90d = yes_no_to01(safe_var(data, "u65_1")),
    paid_physio_90d = yes_no_to01(safe_var(data, "u60")),
    paid_occupational_therapy_90d = yes_no_to01(safe_var(data, "u63")),
    paid_speech_therapy_90d = yes_no_to01(safe_var(data, "u66")),
    weekly_activity_minutes = activity_minutes,
    sedentary_minutes_weekday = sedentary_minutes_day(data, wave_id),
    current_smoker = current_smoker,
    former_smoker = former_smoker,
    alcohol_frequency = safe_chr(data, "l24"),
    alcohol_days_week = safe_num(data, "l25"),
    alcohol_any = alcohol_any,
    fruit_days_week = safe_num(data, "l19"),
    vegetable_days_week = safe_num(data, "l15"),
    frailty_weight_loss = yes_no_to01(safe_var(data, "n69")),
    frailty_exhaustion = frailty_exhaustion,
    grip_max_kg = grip_max,
    gait_best_seconds = gait_best_seconds
  )
}

analytic <- pmap_dfr(wave_files, standardize_wave) %>%
  group_by(wave) %>%
  mutate(
    low_activity_cut = quantile_cut(weekly_activity_minutes, 0.20),
    slow_gait_cut = quantile_cut(gait_best_seconds, 0.80),
    frailty_low_activity = case_when(
      is.na(weekly_activity_minutes) | is.na(low_activity_cut) ~ NA_integer_,
      weekly_activity_minutes <= low_activity_cut ~ 1L,
      TRUE ~ 0L
    ),
    frailty_slow_gait = case_when(
      is.na(gait_best_seconds) | is.na(slow_gait_cut) ~ NA_integer_,
      gait_best_seconds >= slow_gait_cut ~ 1L,
      TRUE ~ 0L
    )
  ) %>%
  group_by(wave, sex) %>%
  mutate(
    weak_grip_cut = quantile_cut(grip_max_kg, 0.20),
    frailty_weak_grip = case_when(
      is.na(grip_max_kg) | is.na(weak_grip_cut) ~ NA_integer_,
      grip_max_kg <= weak_grip_cut ~ 1L,
      TRUE ~ 0L
    )
  ) %>%
  ungroup() %>%
  mutate(
    frailty_available_components = rowSums(!is.na(across(c(
      frailty_weight_loss,
      frailty_exhaustion,
      frailty_low_activity,
      frailty_weak_grip,
      frailty_slow_gait
    )))),
    frailty_score = rowSums(across(c(
      frailty_weight_loss,
      frailty_exhaustion,
      frailty_low_activity,
      frailty_weak_grip,
      frailty_slow_gait
    )), na.rm = TRUE),
    frailty_score = if_else(frailty_available_components >= 3, as.numeric(frailty_score), NA_real_),
    frailty_group = case_when(
      is.na(frailty_score) ~ NA_character_,
      frailty_score == 0 ~ "Robust",
      frailty_score %in% c(1, 2) ~ "Prefrail",
      frailty_score >= 3 ~ "Frail"
    ),
    frail_binary = case_when(
      is.na(frailty_score) ~ NA_integer_,
      frailty_score >= 3 ~ 1L,
      TRUE ~ 0L
    ),
    any_rehab_90d = case_when(
      row_any_valid(physio_90d, occupational_therapy_90d, speech_therapy_90d) ~
        pmax(physio_90d, occupational_therapy_90d, speech_therapy_90d, na.rm = TRUE),
      row_any_valid(paid_physio_90d, paid_occupational_therapy_90d, paid_speech_therapy_90d) ~
        pmax(paid_physio_90d, paid_occupational_therapy_90d, paid_speech_therapy_90d, na.rm = TRUE),
      TRUE ~ NA_integer_
    )
  ) %>%
  select(-low_activity_cut, -slow_gait_cut, -weak_grip_cut)

thresholds <- analytic %>%
  group_by(wave, wave_label, sex) %>%
  summarise(
    low_activity_cut = quantile_cut(weekly_activity_minutes, 0.20),
    slow_gait_cut = quantile_cut(gait_best_seconds, 0.80),
    weak_grip_cut = quantile_cut(grip_max_kg, 0.20),
    n = n(),
    .groups = "drop"
  )

dictionary <- tibble::tribble(
  ~variable, ~definition,
  "cancer_survivor", "n60 yes/no: doctor ever said respondent has or had cancer.",
  "stroke_survivor", "n52 yes/no: doctor ever said respondent had stroke/derrame.",
  "stroke_rehab", "n53_6 yes/no: receives physiotherapy, occupational therapy, or speech therapy due to stroke; waves 2-3.",
  "chronic_spine_condition", "n58 yes/no: doctor ever said respondent has chronic spine problem.",
  "frailty_score", "0-5 Fried-like proxy using weight loss, exhaustion, low activity, weak grip, and slow gait; requires at least 3 available components.",
  "frailty_group", "Robust = 0 components, Prefrail = 1-2, Frail = 3+.",
  "any_rehab_90d", "Any physiotherapy, occupational therapy, or speech therapy in last 90 days when utilization variables exist; falls back to paid-care fields in wave 1.",
  "weekly_activity_minutes", "Walking + moderate + vigorous minutes in the last week using wave-specific activity variable shapes; wave 2-3 hour/minute totals are capped after combination."
)

write_csv_utf8(analytic, "docs/generated/analytic_dataset.csv")
write_csv_utf8(thresholds, "docs/generated/frailty_thresholds.csv")
write_csv_utf8(dictionary, "docs/generated/derived_variable_dictionary.csv")

message("Wrote analytic dataset and derived dictionaries to docs/generated/")
