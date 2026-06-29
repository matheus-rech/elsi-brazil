source("src/R/00_common.R")

ensure_output_dirs()

module_taxonomy <- readr::read_csv(path_here("config/module_taxonomy.csv"), show_col_types = FALSE)

topic_regex <- list(
  oncology_survivorship = regex("câncer|cancer|neoplas|quimio|radioter|radiação|mama|útero|ovário|próstata|pulm[oõ]es?|pele|pâncreas|fígado|leucemia", ignore_case = TRUE),
  cancer_screening = regex("papanicolau|mamograf|exame clínico das.*mamas?|colonoscopia", ignore_case = TRUE),
  stroke_survivorship = regex("\\bavc\\b|derrame|acidente vascular cerebral", ignore_case = TRUE),
  low_back_spine = regex("coluna|lombar|costas", ignore_case = TRUE),
  rehabilitation_access = regex("reabilita|fisioter|terapia ocupacional|fonoaud", ignore_case = TRUE),
  frailty_proxy = regex("perdeu peso|quilos perdeu|grande esforço|atividade física|caminh|força|preensão|equil[ií]brio|apetite", ignore_case = TRUE),
  geo_disparities = regex("regi[aã]o|zona|urbana|rural|munic[ií]pio|vizinhança", ignore_case = TRUE),
  sociodemographic_disparities = regex("sexo|idade|cor|raça|etnia|escolar|renda|aposentadoria", ignore_case = TRUE),
  lifestyle_disparities = regex("fuma|cigar|tabag|álcool|bebida alcoólica|fruta|verdura|legume|atividade física|sentado", ignore_case = TRUE)
)

extract_one_wave <- function(wave, wave_label, dta_file, dta_path) {
  empty <- read_elsi_dta(dta_path, n_max = 0)
  tibble::tibble(
    wave = wave,
    wave_label = wave_label,
    variable = names(empty),
    prefix = str_extract(variable, "^[A-Za-z]+"),
    label = map_chr(empty, ~ repair_text(attr(.x, "label") %||% "")),
    storage_class = map_chr(empty, ~ paste(class(.x), collapse = ";")),
    value_labels = map_chr(empty, function(x) {
      labels <- attr(x, "labels")
      if (is.null(labels)) return("")
      paste0(repair_text(names(labels)), "=", unname(labels), collapse = " | ")
    })
  )
}

variable_catalog <- pmap_dfr(wave_files, extract_one_wave) %>%
  left_join(module_taxonomy, by = "prefix") %>%
  mutate(
    module_pt = coalesce(module_pt, "Não classificado"),
    category_pt = coalesce(category_pt, "Não classificado"),
    questionnaire_scope = coalesce(questionnaire_scope, "Unknown"),
    searchable_text = str_to_lower(paste(variable, label, module_pt, category_pt)),
    topic_tags = map_chr(searchable_text, function(text) {
      hits <- names(keep(topic_regex, ~ str_detect(text, .x)))
      paste(hits, collapse = ";")
    })
  ) %>%
  select(-searchable_text) %>%
  arrange(wave, category_pt, module_pt, variable)

topic_variable_catalog <- variable_catalog %>%
  filter(topic_tags != "") %>%
  separate_rows(topic_tags, sep = ";") %>%
  rename(topic_key = topic_tags) %>%
  left_join(readr::read_csv(path_here("config/analysis_topics.csv"), show_col_types = FALSE), by = "topic_key") %>%
  arrange(topic_key, wave, variable)

module_summary <- variable_catalog %>%
  count(wave, wave_label, category_pt, module_pt, questionnaire_scope, name = "n_variables") %>%
  arrange(wave, category_pt, module_pt)

write_csv_utf8(variable_catalog, "docs/generated/variable_catalog.csv")
write_csv_utf8(topic_variable_catalog, "docs/generated/topic_variable_catalog.csv")
write_csv_utf8(module_summary, "docs/generated/module_summary.csv")

message("Wrote metadata catalogs to docs/generated/")
