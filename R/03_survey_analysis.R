source("src/R/00_common.R")

suppressPackageStartupMessages({
  library(survey)
})

ensure_output_dirs()
options(survey.lonely.psu = "adjust")

analytic_path <- path_here("docs/generated/analytic_dataset.csv")
if (!file.exists(analytic_path)) {
  stop("Missing docs/generated/analytic_dataset.csv. Run Rscript src/R/02_build_analysis_dataset.R first.", call. = FALSE)
}

analytic <- readr::read_csv(analytic_path, show_col_types = FALSE) %>%
  mutate(
    wave = as.integer(wave),
    region = factor(region, levels = c("Norte", "Nordeste", "Sudeste", "Sul", "Centro-Oeste")),
    zone = factor(normalize_zone(zone), levels = c("Urbano", "Rural")),
    sex = factor(sex, levels = c("Feminino", "Masculino")),
    age_group = factor(age_group, levels = c("50-59", "60-69", "70-79", "80+")),
    frailty_group = factor(frailty_group, levels = c("Robust", "Prefrail", "Frail"))
  )

indicator_labels <- c(
  cancer_survivor = "Cancer survivor",
  cancer_recent_treatment = "Cancer treatment in last 2 years",
  stroke_survivor = "Stroke survivor",
  stroke_rehab = "Stroke-related rehab",
  chronic_spine_condition = "Chronic spine condition",
  frail_binary = "Frail proxy",
  any_rehab_90d = "Any allied rehab in last 90 days",
  colonoscopy_10y = "Colonoscopy in last 10 years",
  current_smoker = "Current smoker",
  alcohol_any = "Any alcohol use"
)

make_design <- function(data) {
  survey::svydesign(
    ids = ~upa,
    strata = ~estrato,
    weights = ~peso_calibrado,
    data = data,
    nest = TRUE
  )
}

estimate_indicator <- function(data, indicator, group_var = NULL) {
  needed <- c("upa", "estrato", "peso_calibrado", indicator, group_var)
  data <- data %>%
    filter(if_all(all_of(c("upa", "estrato", "peso_calibrado")), ~ !is.na(.x))) %>%
    filter(!is.na(.data[[indicator]]))

  if (!is.null(group_var)) {
    data <- data %>% filter(!is.na(.data[[group_var]]), .data[[group_var]] != "")
    groups <- sort(unique(data[[group_var]]))
  } else {
    groups <- "Overall"
  }

  map_dfr(groups, function(group_value) {
    group_data <- if (is.null(group_var)) data else data %>% filter(.data[[group_var]] == group_value)
    if (nrow(group_data) < 20 || length(unique(group_data[[indicator]])) < 1) {
      return(tibble::tibble(
        group_var = group_var %||% "overall",
        group_value = group_value,
        indicator = indicator,
        indicator_label = indicator_labels[[indicator]] %||% indicator,
        estimate = NA_real_,
        ci_low = NA_real_,
        ci_high = NA_real_,
        n_unweighted = nrow(group_data)
      ))
    }

    design <- make_design(group_data)
    estimate <- tryCatch(
      survey::svymean(stats::as.formula(paste0("~", indicator)), design, na.rm = TRUE),
      error = function(e) e
    )
    if (inherits(estimate, "error")) {
      return(tibble::tibble(
        group_var = group_var %||% "overall",
        group_value = group_value,
        indicator = indicator,
        indicator_label = indicator_labels[[indicator]] %||% indicator,
        estimate = NA_real_,
        ci_low = NA_real_,
        ci_high = NA_real_,
        n_unweighted = nrow(group_data)
      ))
    }

    est <- as.numeric(stats::coef(estimate)[1])
    se <- as.numeric(survey::SE(estimate)[1])
    tibble::tibble(
      group_var = group_var %||% "overall",
      group_value = group_value,
      indicator = indicator,
      indicator_label = indicator_labels[[indicator]] %||% indicator,
      estimate = est,
      ci_low = pmax(0, est - stats::qnorm(0.975) * se),
      ci_high = pmin(1, est + stats::qnorm(0.975) * se),
      n_unweighted = nrow(group_data)
    )
  })
}

estimate_by_wave <- function(indicator, group_var = NULL) {
  map_dfr(sort(unique(analytic$wave)), function(wv) {
    estimate_indicator(analytic %>% filter(wave == wv), indicator, group_var) %>%
      mutate(wave = wv, wave_label = unique(analytic$wave_label[analytic$wave == wv]), .before = 1)
  })
}

indicators <- names(indicator_labels)

overall <- map_dfr(indicators, estimate_by_wave)
by_region <- map_dfr(indicators, ~ estimate_by_wave(.x, "region"))
by_zone <- map_dfr(indicators, ~ estimate_by_wave(.x, "zone"))
by_sex <- map_dfr(indicators, ~ estimate_by_wave(.x, "sex"))

fit_svy_or <- function(wv, outcome, exposure, adjustment_vars, subpop = NULL) {
  data <- analytic %>%
    filter(wave == wv) %>%
    filter(!is.na(.data[[outcome]]), !is.na(.data[[exposure]])) %>%
    filter(if_all(all_of(c("upa", "estrato", "peso_calibrado")), ~ !is.na(.x)))

  if (!is.null(subpop) && !is.na(subpop)) {
    data <- data %>% filter(!is.na(.data[[subpop]]), .data[[subpop]] == 1)
  }

  if (nrow(data) < 100 ||
      length(unique(data[[outcome]])) < 2 ||
      length(unique(data[[exposure]])) < 2) {
    return(tibble::tibble(
      wave = wv,
      wave_label = unique(analytic$wave_label[analytic$wave == wv]),
      outcome = outcome,
      exposure = exposure,
      term = exposure,
      odds_ratio = NA_real_,
      ci_low = NA_real_,
      ci_high = NA_real_,
      p_value = NA_real_,
      n_unweighted = nrow(data),
      status = "Skipped: insufficient variation or sample size"
    ))
  }

  usable_adjustments <- adjustment_vars[
    map_lgl(adjustment_vars, ~ .x %in% names(data) && sum(!is.na(data[[.x]])) >= 100 && length(unique(na.omit(data[[.x]]))) > 1)
  ]

  formula <- stats::as.formula(paste(outcome, "~", paste(c(exposure, usable_adjustments), collapse = " + ")))
  design <- make_design(data)
  fit <- tryCatch(
    survey::svyglm(formula, design = design, family = quasibinomial()),
    error = function(e) e
  )

  if (inherits(fit, "error")) {
    return(tibble::tibble(
      wave = wv,
      wave_label = unique(analytic$wave_label[analytic$wave == wv]),
      outcome = outcome,
      exposure = exposure,
      term = exposure,
      odds_ratio = NA_real_,
      ci_low = NA_real_,
      ci_high = NA_real_,
      p_value = NA_real_,
      n_unweighted = nrow(data),
      status = paste("Model error:", fit$message)
    ))
  }

  coefs <- summary(fit)$coefficients
  exposure_terms <- rownames(coefs)[str_detect(rownames(coefs), paste0("^", exposure))]
  if (length(exposure_terms) == 0) exposure_terms <- exposure

  map_dfr(exposure_terms, function(term_name) {
    beta <- unname(coefs[term_name, "Estimate"])
    se <- unname(coefs[term_name, "Std. Error"])
    crit <- if (is.finite(fit$df.residual) && fit$df.residual > 0) {
      stats::qt(0.975, df = fit$df.residual)
    } else {
      stats::qnorm(0.975)
    }
    tibble::tibble(
      wave = wv,
      wave_label = unique(analytic$wave_label[analytic$wave == wv]),
      outcome = outcome,
      exposure = exposure,
      term = term_name,
      odds_ratio = exp(beta),
      ci_low = exp(beta - crit * se),
      ci_high = exp(beta + crit * se),
      p_value = unname(coefs[term_name, "Pr(>|t|)"]),
      n_unweighted = nrow(data),
      status = "OK"
    )
  })
}

audit_adjustments <- c("age_years", "sex", "region", "zone")

model_specs <- tibble::tribble(
  ~outcome, ~exposure, ~waves, ~subpop,
  "frail_binary", "cancer_survivor", list(1:3), NA_character_,
  "frail_binary", "chronic_spine_condition", list(1:3), NA_character_,
  "frail_binary", "stroke_survivor", list(1:3), NA_character_,
  "stroke_rehab", "frail_binary", list(2:3), "stroke_survivor",
  "stroke_rehab", "region", list(2:3), "stroke_survivor",
  "stroke_rehab", "zone", list(2:3), "stroke_survivor"
)

models <- model_specs %>%
  pmap_dfr(function(outcome, exposure, waves, subpop) {
    map_dfr(unlist(waves), function(wv) {
      fit_svy_or(wv, outcome, exposure, audit_adjustments, subpop = subpop)
    })
  })

write_csv_utf8(overall, "docs/generated/weighted_prevalence_overall.csv")
write_csv_utf8(by_region, "docs/generated/weighted_prevalence_by_region.csv")
write_csv_utf8(by_zone, "docs/generated/weighted_prevalence_by_zone.csv")
write_csv_utf8(by_sex, "docs/generated/weighted_prevalence_by_sex.csv")
write_csv_utf8(models, "docs/generated/survey_association_models.csv")

message("Wrote survey-weighted summaries and first-pass models to docs/generated/")
