suppressWarnings(suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(purrr)
  library(readr)
  library(stringr)
  library(tidyr)
}))

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

required_data_files <- c(
  "ELSI Portugues (1a onda) stata13.dta",
  "ELSI Portugues (2a onda) stata13.dta",
  "ELSI Portugues (3a onda).dta"
)

find_project_root <- function(start = getwd()) {
  candidates <- unique(normalizePath(
    c(
      start,
      file.path(start, ".."),
      file.path(start, "..", ".."),
      file.path(start, "..", "..", "..")
    ),
    mustWork = FALSE
  ))
  for (candidate in candidates) {
    if (all(file.exists(file.path(candidate, required_data_files)))) {
      return(normalizePath(candidate, mustWork = TRUE))
    }
  }
  normalizePath(start, mustWork = TRUE)
}

project_root <- find_project_root()

if (!all(file.exists(file.path(project_root, required_data_files)))) {
  stop(
    "Run scripts from /Users/matheusrech/Pictures/ELSI so the ELSI .dta files are visible.",
    call. = FALSE
  )
}

path_here <- function(...) file.path(project_root, ...)

ensure_output_dirs <- function() {
  dirs <- c("docs/generated", "config", "src/R", "src/app", "tests/testthat")
  walk(file.path(project_root, dirs), dir.create, recursive = TRUE, showWarnings = FALSE)
}

wave_files <- tibble::tibble(
  wave = c(1L, 2L, 3L),
  wave_label = c("2015-16", "2019-21", "2023-24"),
  dta_file = required_data_files,
  dta_path = file.path(project_root, required_data_files)
)

read_elsi_dta <- function(path, ...) {
  tryCatch(
    haven::read_dta(path, ...),
    error = function(e) {
      if (!str_detect(e$message, "encoding|invalid byte sequence|Unable to convert")) {
        stop(e)
      }
      haven::read_dta(path, ..., encoding = "latin1")
    }
  )
}

repair_text <- function(x) {
  if (is.factor(x)) x <- as.character(x)
  out <- as.character(x)
  needs_repair <- !is.na(out) & str_detect(out, "[ÃÂ]")
  if (any(needs_repair)) {
    out[needs_repair] <- vapply(out[needs_repair], function(value) {
      current <- value
      for (i in seq_len(4)) {
        if (!str_detect(current, "[ÃÂ]")) break
        ints <- utf8ToInt(current)
        if (any(is.na(ints)) || any(ints > 255)) break
        converted <- rawToChar(as.raw(ints))
        Encoding(converted) <- "UTF-8"
        current <- converted
      }
      current
    }, character(1))
  }
  out <- enc2utf8(out)
  out
}

clean_chr <- function(x) {
  if (length(x) == 0) return(character())
  if (inherits(x, "haven_labelled") || inherits(x, "labelled")) {
    out <- suppressWarnings(as.character(haven::as_factor(x, levels = "labels")))
  } else {
    out <- suppressWarnings(as.character(x))
  }
  out <- repair_text(out)
  str_squish(out)
}

clean_numeric <- function(x, invalid_codes = c(666, 777, 888, 999, 6666, 7777, 8888, 9999, 88888, 99999)) {
  out <- suppressWarnings(as.numeric(haven::zap_labels(x)))
  out[out %in% invalid_codes] <- NA_real_
  out
}

safe_var <- function(data, var) {
  if (var %in% names(data)) data[[var]] else rep(NA, nrow(data))
}

safe_chr <- function(data, var) clean_chr(safe_var(data, var))

safe_num <- function(data, var) clean_numeric(safe_var(data, var))

yes_no_to01 <- function(x) {
  value <- str_to_lower(clean_chr(x))
  case_when(
    str_detect(value, "^(sim|yes)$") ~ 1L,
    str_detect(value, "^(n[oã]o|no)$") ~ 0L,
    TRUE ~ NA_integer_
  )
}

pattern_to01 <- function(x, yes_pattern, no_pattern = "^(nunca|raramente|poucas vezes|não|nao|no)$") {
  value <- str_to_lower(clean_chr(x))
  case_when(
    str_detect(value, yes_pattern) ~ 1L,
    str_detect(value, no_pattern) ~ 0L,
    TRUE ~ NA_integer_
  )
}

valid_days <- function(x) {
  out <- clean_numeric(x)
  out[out < 0 | out > 7] <- NA_real_
  out
}

valid_minutes <- function(x) {
  out <- clean_numeric(x)
  out[out < 0 | out > 1440] <- NA_real_
  out
}

valid_hour_minute_total <- function(hours, minutes) {
  valid_minutes(clean_numeric(hours) * 60 + clean_numeric(minutes))
}

normalize_zone <- function(x) {
  value <- clean_chr(x)
  lower <- str_to_lower(value)
  case_when(
    str_detect(lower, "^rural$|não-urbanizada|nao-urbanizada") ~ "Rural",
    str_detect(lower, "^urbano$|urbanizada") ~ "Urbano",
    TRUE ~ value
  )
}

valid_measure <- function(x, low = -Inf, high = Inf) {
  out <- clean_numeric(x)
  out[out < low | out > high] <- NA_real_
  out
}

row_any_valid <- function(...) {
  mat <- cbind(...)
  rowSums(!is.na(mat)) > 0
}

row_sum_valid <- function(...) {
  mat <- cbind(...)
  out <- rowSums(mat, na.rm = TRUE)
  out[rowSums(!is.na(mat)) == 0] <- NA_real_
  out
}

row_max_valid <- function(...) {
  mat <- cbind(...)
  out <- apply(mat, 1, function(row) {
    if (all(is.na(row))) NA_real_ else max(row, na.rm = TRUE)
  })
  as.numeric(out)
}

row_min_valid <- function(...) {
  mat <- cbind(...)
  out <- apply(mat, 1, function(row) {
    if (all(is.na(row))) NA_real_ else min(row, na.rm = TRUE)
  })
  as.numeric(out)
}

make_age_group <- function(age) {
  cut(
    age,
    breaks = c(49, 59, 69, 79, Inf),
    labels = c("50-59", "60-69", "70-79", "80+"),
    right = TRUE
  )
}

activity_minutes_week <- function(data, wave) {
  activity_total <- function(days, minutes) {
    out <- days * minutes
    out[days == 0 & is.na(out)] <- 0
    out
  }
  if (wave == 1L) {
    walking <- activity_total(valid_days(safe_var(data, "l5")), valid_minutes(safe_var(data, "l6")))
    moderate <- activity_total(valid_days(safe_var(data, "l7")), valid_minutes(safe_var(data, "l8")))
    vigorous <- activity_total(valid_days(safe_var(data, "l9")), valid_minutes(safe_var(data, "l10")))
  } else {
    walk_minutes <- valid_hour_minute_total(safe_var(data, "l6_1"), safe_var(data, "l6_2"))
    mod_minutes <- valid_hour_minute_total(safe_var(data, "l8_1"), safe_var(data, "l8_2"))
    vig_minutes <- valid_hour_minute_total(safe_var(data, "l10_1"), safe_var(data, "l10_2"))
    walking <- activity_total(valid_days(safe_var(data, "l5")), walk_minutes)
    moderate <- activity_total(valid_days(safe_var(data, "l7")), mod_minutes)
    vigorous <- activity_total(valid_days(safe_var(data, "l9")), vig_minutes)
  }
  row_sum_valid(walking, moderate, vigorous)
}

sedentary_minutes_day <- function(data, wave) {
  if (wave == 1L) {
    valid_minutes(safe_var(data, "l11"))
  } else {
    valid_hour_minute_total(safe_var(data, "l11_1"), safe_var(data, "l11_2"))
  }
}

quantile_cut <- function(x, probs) {
  valid <- x[!is.na(x)]
  if (length(valid) < 30) return(NA_real_)
  as.numeric(stats::quantile(valid, probs = probs, na.rm = TRUE, names = FALSE, type = 2))
}

write_csv_utf8 <- function(data, file) {
  readr::write_excel_csv(data, path_here(file), na = "")
}
