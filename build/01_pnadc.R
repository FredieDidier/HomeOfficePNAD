# =============================================================================
# 01_pnadc.R
# Download PNADC panel data and build the final analytical dataset.
#
# Project: HomeOfficePNAD
# Description: Evaluates the causal effect of MP 1108/2022 (Art. 75-F) on
#   women's labor market outcomes and fertility. The article mandates employers
#   to give priority access to telework for employees with children or legal
#   dependents under 4 years old.
#
# DATA SOURCE:
#   Panel files are downloaded using the datazoom.social R package (PUC-Rio):
#   https://github.com/datazoompuc/datazoom.social
#   Function: load_pnadc(panel = "advanced_3") — Stage 3 fuzzy matching with
#   Graph Theory. Saved as Panel_{V1014}.RData in INPUT_PATH.
#
#   id_rs3 = Stage 3 advanced individual panel ID (links the same person across
#             quarters using donated birth dates + household order + Graph Theory
#             fuzzy matching for fragmented interviews). NA for unmatched obs.
#   id_dom = household identifier (globally unique within each V1014 group).
#
# PIPELINE:
#   Step 1 — download_pnadc_panels(): downloads PNADC from IBGE via datazoom.social,
#             builds the Stage 3 rotating panel ONE PANEL GROUP AT A TIME to
#             limit peak RAM usage, and saves Panel_{V1014}.RData to INPUT_PATH.
#             Run only once (or to refresh data).
#             *** Commented out below: uncomment to (re-)download. ***
#   Step 2 — build_main_data(): merges panel .RData files, applies sample
#             restrictions, adds research variables, saves main_data.RData
#             to OUTPUT_PATH.
#
# DOWNLOAD STRATEGY — panel-by-panel AND column-pruned, to fit in 16GB RAM:
#   `load_pnadc()` internally downloads all requested quarters, binds them into
#   one data.table, and THEN splits the bound data by V1014 (the panel rotation
#   group identifier) before calling `build_pnadc_panel()` separately on each
#   V1014 subset. `build_pnadc_panel()` — including the Stage 3 fuzzy-matching
#   step — only ever looks within the rows it is given, so panel identification
#   for group V1014 = p depends ONLY on rows belonging to that group. As long as
#   the downloaded window fully contains a group's own quarters, results are
#   IDENTICAL whether obtained from a single bulk 2018-2025 download filtered
#   afterward, or from a narrower per-group window filtered the same way.
#
#   IMPORTANT LIMITATION of load_pnadc()/get_pnadc() discovered after the first
#   panel-by-panel attempt still crashed: `get_pnadc()` ALWAYS returns its full set of ~210
#   structural columns (survey weights, identifiers, every questionnaire item)
#   REGARDLESS of the `vars` argument — per the function's own documentation,
#   `vars` only ADDS columns on top of that set, it never restricts it. So even
#   a 3-year window still holds ~210 columns x up to 12 quarters x millions of
#   rows in memory at once, and load_pnadc()'s internal loop additionally
#   processes EVERY V1014 group present in the window (not just our target),
#   accumulating each processed group's data in a list before any of it is
#   saved or released. Disk space is not the bottleneck here — this is a pure RAM problem, so moving R's tempdir
#   to a bigger disk (which only affects where downloaded .zip files land) does
#   not help.
#
#   Fix: bypass load_pnadc()'s convenience wrapper and drive the download
#   ourselves, one quarter at a time, via PNADcIBGE::get_pnadc() directly. Right
#   after each quarter is downloaded and cleaned with datazoom.social's own
#   (internal) treat_pnadc(), we do two things load_pnadc() cannot do for us:
#     1. Immediately drop every column except the ~35 raw + derived columns this
#        project actually needs (see `raw_cols_needed` / `derived_cols_needed`
#        below) — roughly a 6x reduction in memory per row.
#     2. Immediately filter to V1014 == the target panel group for this
#        iteration, discarding the other, unrelated panel groups that happen to
#        overlap the same calendar window. This mirrors what load_pnadc() does
#        internally (it also filters `dat <- all_quarters %>% filter(V1014==p)`
#        before calling build_pnadc_panel()) — we just do it earlier, one
#        quarter at a time, instead of after binding everything.
#   Only after both reductions do we bind the (now much smaller) quarters
#   together and call the package's own exported `build_pnadc_panel()` on that
#   reduced data — so panel identification itself is untouched, just fed less
#   data to hold in memory at once.
#
# PATHS:
#   GitHub paths  → use here::here() [reproducible across machines]
#   Dropbox paths → change only DROPBOX_ROOT below to match your machine
# =============================================================================
library(data.table)
library(here)

# ---- User-defined Dropbox root (only line to change on a new machine) -------
DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"

# Derived Dropbox paths (do not edit)
INPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "input")
OUTPUT_PATH <- file.path(DROPBOX_ROOT, "build", "output")

# =============================================================================
# FUNCTION: download_pnadc_panels
#
# Downloads PNADC quarterly microdata from IBGE via PNADcIBGE::get_pnadc(),
# applies datazoom.social's own quarterly cleaning (treat_pnadc, internal) and
# panel identification (build_pnadc_panel, exported, Stage 3 = advanced_3), and
# saves Panel_{V1014}.RData to INPUT_PATH — ONE PANEL GROUP AT A TIME, with
# columns pruned and rows filtered to the target group immediately after each
# quarter is downloaded (see header comment above for why this is necessary).
#
# Panel group → year window mapping (window fully contains each group's own
# interviews; matches the Start/End table published in the datazoom.social
# README):
#   V1014 = 6  : 2017Q1–2019Q1   → years_needed = 2017:2019
#   V1014 = 7  : 2018Q2–2020Q2   → years_needed = 2018:2020
#   V1014 = 8  : 2019Q3–2021Q3   → years_needed = 2019:2021
#   V1014 = 9  : 2020Q4–2022Q4   → years_needed = 2020:2022
#   V1014 = 10 : 2022Q1–2024Q1   → years_needed = 2022:2024
#   V1014 = 11 : 2023Q2–2025Q2   → years_needed = 2023:2025
#   V1014 = 12 : 2024Q3–2026Q3   → years_needed = 2024:2026
#   V1014 = 13 : 2025Q4–2027Q4   → years_needed = 2025:2027
#
# Usage (run once to populate INPUT_PATH):
#   download_pnadc_panels()
# =============================================================================
download_pnadc_panels <- function() {
  # Install datazoom.social if needed:
  # devtools::install_github("datazoompuc/datazoom.social")
  library(datazoom.social)
  library(PNADcIBGE)

  dir.create(INPUT_PATH, showWarnings = FALSE, recursive = TRUE)

  # --- Columns to keep after each quarter's download -------------------------
  # get_pnadc() always returns ~210 raw structural columns no matter what `vars`
  # is set to (per package docs, `vars` only ADDS columns, never restricts) — so
  # we prune manually right after download instead.
  #
  # raw_cols_needed: columns required either by build_pnadc_panel()'s household/
  # individual identification algorithm (UPA, V1008, V1014, V2007, V20082,
  # V20081, V2008, V2003, V2009), or kept directly in the final analytical
  # dataset (see keep_vars in build_main_data() below), or needed as inputs to
  # treat_pnadc()'s derived variables (e.g. VD4012 for formal/informal, UF for
  # regiao/sigla_uf).
  raw_cols_needed <- c(
    # Household / individual identification (build_pnadc_panel())
    "UPA", "V1008", "V1014", "V2007", "V20082", "V20081", "V2008", "V2003", "V2009",
    # Survey design
    "V1016", "V1028", "posest", "UF",
    # Demographics kept in the final dataset
    "V2010", "V2005", "V1022",
    # Education
    "VD3004", "VD3005",
    # Labor market (raw) — VD4012 is an input to treat_pnadc()'s formal/informal
    # classification but is not itself kept in the final dataset
    "VD4001", "VD4002", "VD4009", "VD4012", "VD4019",
    "VD4031", "VD4035",
    # Home office, sector, occupation
    "V4022", "V4013", "V4010",
    # Maternity leave proxy
    "V4006A"
  )
  # derived_cols_needed: columns treat_pnadc() computes from the raw columns
  # above, kept in the final dataset (see keep_vars in build_main_data()).
  derived_cols_needed <- c(
    "regiao", "sigla_uf", "faixa_idade", "faixa_educ",
    "rendimento_habitual_real",
    "ocupado", "forca_trab", "formal", "informal",
    "home_office", "cnae_2dig", "cod_2dig"
  )

  panel_specs <- list(
    list(v1014 = 6L,  years_needed = 2017:2019),
    list(v1014 = 7L,  years_needed = 2018:2020),
    list(v1014 = 8L,  years_needed = 2019:2021),
    list(v1014 = 9L,  years_needed = 2020:2022),
    list(v1014 = 10L, years_needed = 2022:2024),
    list(v1014 = 11L, years_needed = 2023:2025),
    list(v1014 = 12L, years_needed = 2024:2026),
    list(v1014 = 13L, years_needed = 2025:2027)
  )

  for (spec in panel_specs) {
    out_file <- file.path(INPUT_PATH, sprintf("Panel_%d.RData", spec$v1014))

    if (file.exists(out_file)) {
      message(sprintf("  Panel %d — already exists, skipping.", spec$v1014))
      next
    }

    message(sprintf("  Panel %d — downloading years %d-%d, one quarter at a time ...",
                    spec$v1014, min(spec$years_needed), max(spec$years_needed)))

    n_quarters_max <- length(spec$years_needed) * 4L
    quarter_list   <- vector("list", n_quarters_max)
    k <- 0L

    for (yr in spec$years_needed) {
      for (q in 1:4) {
        k <- k + 1L
        message(sprintf("    Downloading %d Q%d ...", yr, q))

        df <- tryCatch(
          PNADcIBGE::get_pnadc(year = yr, quarter = q, vars = NULL,
                               labels = FALSE, deflator = TRUE, design = FALSE),
          error = function(e) NULL
        )

        if (is.null(df)) {
          message(sprintf("      %d Q%d not available (not yet published or download failed), skipping.", yr, q))
          next
        }

        # Mirror load_pnadc()'s own pre-processing order exactly: coerce every
        # column to numeric BEFORE running treat_pnadc(), since its case_match()
        # logic expects numeric PNADC codes as input.
        df <- as.data.frame(lapply(df, as.numeric))
        df <- datazoom.social:::treat_pnadc(df)
        df$Ano       <- yr
        df$Trimestre <- q

        # Filter to the TARGET panel group immediately — this is the same
        # filter load_pnadc() applies internally (dat <- all_quarters %>%
        # filter(V1014 == p)) before calling build_pnadc_panel(), just done per
        # quarter instead of after binding everything, and skipping the other
        # overlapping groups entirely instead of downloading+processing them.
        if ("V1014" %in% names(df)) {
          df <- df[!is.na(df$V1014) & df$V1014 == spec$v1014, , drop = FALSE]
        }

        # Prune to only the columns this project needs (~35 instead of ~210) —
        # the actual fix for the RAM crash, since get_pnadc()'s `vars` argument
        # cannot restrict the download itself (see header comment).
        keep_cols <- intersect(names(df), c(raw_cols_needed, derived_cols_needed,
                                            "Habitual", "Ano", "Trimestre"))
        df <- as.data.table(df)[, ..keep_cols]

        quarter_list[[k]] <- df
        rm(df); gc()

        # get_pnadc() downloads and unzips each quarter's raw microdata into
        # R's session tempdir() and NEVER cleans it up afterward. Across many
        # quarters this silently fills the disk. We no longer
        # need those files once get_pnadc() has returned the parsed data into
        # `df` above, so purge the tempdir after every quarter.
        unlink(list.files(tempdir(), full.names = TRUE), recursive = TRUE, force = TRUE)
      }
    }

    quarter_data <- rbindlist(quarter_list, fill = TRUE)
    rm(quarter_list); gc()

    if (nrow(quarter_data) == 0L) {
      message(sprintf("  Panel %d — no rows found for this group in the downloaded window, skipping.",
                      spec$v1014))
      next
    }

    message(sprintf("  Panel %d — running advanced_3 identification on %s rows ...",
                    spec$v1014, format(nrow(quarter_data), big.mark = ",")))

    tryCatch({
      panel_data <- build_pnadc_panel(dat = quarter_data, panel = "advanced_3")
      rm(quarter_data); gc()

      panel_data <- as.data.table(panel_data)

      save(panel_data, file = out_file)
      message(sprintf("  Panel %d — saved %s rows to %s",
                      spec$v1014,
                      format(nrow(panel_data), big.mark = ","),
                      out_file))
      rm(panel_data); gc()

    }, error = function(e) {
      message(sprintf("  Panel %d — ERROR: %s", spec$v1014, conditionMessage(e)))
    })
  }

  rdata_files <- list.files(INPUT_PATH, pattern = "^Panel_.*\\.RData$", full.names = TRUE)
  message(sprintf("\nDone. %d panel .RData file(s) in: %s",
                  length(rdata_files), INPUT_PATH))
}

# download_pnadc_panels()   # <-- uncomment to (re-)download

# =============================================================================
# FUNCTION: build_main_data
# Merges all datazoom.social panel .RData files from INPUT_PATH, restricts the
# sample to women aged 18-49, adds research-specific variables, and saves
# main_data.RData to OUTPUT_PATH.
#
# The panel files already contain individual panel identifiers (id_rs3, id_dom)
# and derived labor market variables provided by datazoom.social.
#
# V2005 — position in household (PNADC dictionary, full code list):
#   01 = household head
#   02 = spouse/partner, different sex
#   03 = spouse/partner, same sex
#   04 = child of BOTH head and spouse/partner
#   05 = child of head ONLY
#   06 = stepchild
#   07 = son/daughter-in-law
#   08 = parent/stepparent of head
#   09 = parent-in-law
#   10 = grandchild
#   11 = great-grandchild
#   12 = sibling
#   13 = grandparent
#   14 = other relative
#   15 = non-relative member, does not share expenses
#   16 = non-relative member, shares expenses
#   17 = lodger
#   18 = domestic worker
#   19 = domestic worker's relative
#
# Child-presence variables (three combinations):
#   has_child_u4          : V2005 ∈ {4,5,6,10,11} — main treatment (children, stepchildren, grandchildren+)
#   has_child_u4_no_gc    : V2005 ∈ {4,5,6}        — robustness: excludes grandchildren/great-grandchildren
#   has_child_u4_no_sc    : V2005 ∈ {4,5,10,11}    — robustness: excludes stepchildren
#   has_child_5_7         : same V2005 sets, age 5-7 — donut DiD control A
#   has_child_5_7_no_gc / has_child_5_7_no_sc : robustness variants of control A
#
# Key variables added here:
#   year_quarter          : numeric time ID, e.g. 20221 = Q1 2022
#   has_child_u4[_no_gc|_no_sc] : child ≤4 flags (main + robustness variants)
#   has_child_5_7[_no_gc|_no_sc]: child 5-7 flags (donut DiD control)
#   age_youngest_child    : age of youngest qualifying child
#   potential_telework    : occupation eligible for telework (Góes et al. 2020)
#   treated               : = has_child_u4 (DiD treatment indicator)
#   post_mp               : = 1 if year_quarter >= 20222 (Q2 2022+, main spec)
#   post_mp_alt           : = 1 if year_quarter >= 20221 (Q1 2022+, robustness)
#   treat_x_post          : treated × post_mp (main DiD interaction)
#   treat_x_post_alt      : treated × post_mp_alt (robustness DiD interaction)
#   on_maternity_leave    : = 1 if V4006A == 2 (proxy for recent birth)
#   is_head_or_spouse     : = 1 if V2005 ∈ {1,2,3}
# =============================================================================
build_main_data <- function() {
  dir.create(OUTPUT_PATH, showWarnings = FALSE, recursive = TRUE)

  panel_files <- list.files(INPUT_PATH, pattern = "^Panel_.*\\.RData$",
                            full.names = TRUE, recursive = TRUE)
  if (length(panel_files) == 0) {
    stop("No Panel_*.RData files found in: ", INPUT_PATH,
         "\nRun download_pnadc_panels() to populate INPUT_PATH.")
  }
  message(sprintf("Found %d panel .RData files. Processing one at a time ...",
                  length(panel_files)))

  # V2005 position-in-household codes for children (see header comment above)
  child_positions_all   <- c(4L, 5L, 6L, 10L, 11L)  # children + stepchildren + grandchildren/great-grandchildren
  child_positions_no_gc <- c(4L, 5L, 6L)             # excludes grandchildren/great-grandchildren (no V2005 ∈ {10,11})
  child_positions_no_sc <- c(4L, 5L, 10L, 11L)       # excludes stepchildren (no V2005 = 6)

  # Two-pass approach (avoids loading all panels simultaneously):
  # Pass 1 — extract household-level child flags from FULL data (all ages).
  # Pass 2 — filter to sample women, merge child flags, accumulate.

  # --- PASS 1: household-level child-presence lookup ---
  message("  Pass 1: extracting household child indicators ...")

  hh_lookup_list <- vector("list", length(panel_files))

  for (i in seq_along(panel_files)) {
    f <- panel_files[[i]]
    message(sprintf("    [%d/%d] %s", i, length(panel_files), basename(f)))

    load(f)  # loads object named 'panel_data'
    tmp <- as.data.table(panel_data)
    rm(panel_data)

    # CRITICAL: key the household lookup on (id_dom, V1014, year_quarter), NOT
    # just (id_dom, year_quarter). id_dom is only unique WITHIN a V1014 rotation
    # group, not across groups (confirmed: ~26k (id_dom, year_quarter) keys
    # collide across the two panels that overlap each calendar quarter). Since a
    # physical household belongs to exactly one V1014 group, adding V1014 to the
    # key fully disambiguates. Without it, the Pass-2 merge below matched women
    # to child flags from a DIFFERENT household in another panel that happened to
    # share the same id_dom in the same quarter, duplicating rows and assigning
    # false treatment flags.
    tmp <- tmp[, .(id_dom, V1014, Ano, Trimestre, V2009, V2005)]
    tmp[, year_quarter := Ano * 10L + Trimestre]

    # Children ≤4 (all child types: biological + stepchildren + grandchildren+)
    ch_all <- tmp[V2009 <= 4L & V2005 %in% child_positions_all,
                  .(has_child_u4_hh      = 1L,
                    age_youngest_child   = min(V2009, na.rm = TRUE)),
                  by = .(id_dom, V1014, year_quarter)]

    # Children ≤4 (excluding grandchildren/great-grandchildren)
    ch_no_gc <- tmp[V2009 <= 4L & V2005 %in% child_positions_no_gc,
                    .(has_child_u4_no_gc_hh        = 1L,
                      age_youngest_child_no_gc     = min(V2009, na.rm = TRUE)),
                    by = .(id_dom, V1014, year_quarter)]

    # Children ≤4 (excluding stepchildren)
    ch_no_sc <- tmp[V2009 <= 4L & V2005 %in% child_positions_no_sc,
                    .(has_child_u4_no_sc_hh        = 1L,
                      age_youngest_child_no_sc     = min(V2009, na.rm = TRUE)),
                    by = .(id_dom, V1014, year_quarter)]

    # Children 5-7 (all child types — donut DiD Control A)
    ch_5_7 <- tmp[V2009 >= 5L & V2009 <= 7L & V2005 %in% child_positions_all,
                  .(has_child_5_7_hh = 1L),
                  by = .(id_dom, V1014, year_quarter)]

    # Children 5-7 (excluding grandchildren/great-grandchildren)
    ch_5_7_no_gc <- tmp[V2009 >= 5L & V2009 <= 7L & V2005 %in% child_positions_no_gc,
                        .(has_child_5_7_no_gc_hh = 1L),
                        by = .(id_dom, V1014, year_quarter)]

    # Children 5-7 (excluding stepchildren)
    ch_5_7_no_sc <- tmp[V2009 >= 5L & V2009 <= 7L & V2005 %in% child_positions_no_sc,
                        .(has_child_5_7_no_sc_hh = 1L),
                        by = .(id_dom, V1014, year_quarter)]

    # Youngest child of ANY age (all child types). Flexible variable that
    # subsumes all group definitions: treated == (age_youngest_child_any <= 4);
    # control window [5,K] == (age_youngest_child_any in 5:K); Control B
    # == (age_youngest_child_any >= 8 | is.na()). Enables the control-window
    # robustness (5-6 ... 5-12) without a proliferation of binary flags.
    ch_any <- tmp[V2005 %in% child_positions_all,
                  .(age_youngest_child_any = min(V2009, na.rm = TRUE)),
                  by = .(id_dom, V1014, year_quarter)]

    lu_key <- c("id_dom", "V1014", "year_quarter")
    hh_lu <- merge(ch_all,      ch_no_gc,    by = lu_key, all = TRUE)
    hh_lu <- merge(hh_lu,       ch_no_sc,    by = lu_key, all = TRUE)
    hh_lu <- merge(hh_lu,       ch_5_7,      by = lu_key, all = TRUE)
    hh_lu <- merge(hh_lu,       ch_5_7_no_gc, by = lu_key, all = TRUE)
    hh_lu <- merge(hh_lu,       ch_5_7_no_sc, by = lu_key, all = TRUE)
    hh_lu <- merge(hh_lu,       ch_any,       by = lu_key, all = TRUE)

    hh_lookup_list[[i]] <- hh_lu
    rm(tmp, ch_all, ch_no_gc, ch_no_sc, ch_5_7, ch_5_7_no_gc, ch_5_7_no_sc, ch_any, hh_lu); gc()
  }

  hh_lookup <- rbindlist(hh_lookup_list, fill = TRUE)
  rm(hh_lookup_list); gc()

  # Replace Inf (from min() on empty sets) with NA
  for (v in c("age_youngest_child", "age_youngest_child_no_gc", "age_youngest_child_no_sc",
              "age_youngest_child_any")) {
    if (v %in% names(hh_lookup))
      hh_lookup[is.infinite(get(v)), (v) := NA_real_]
  }

  message(sprintf("  Pass 1 done. Lookup: %s household x quarter rows.",
                  format(nrow(hh_lookup), big.mark = ",")))

  # --- PASS 2: filter to sample, merge child flags, accumulate ---
  message("  Pass 2: building sample dataset ...")

  filtered_list <- vector("list", length(panel_files))

  for (i in seq_along(panel_files)) {
    f <- panel_files[[i]]
    message(sprintf("    [%d/%d] %s", i, length(panel_files), basename(f)))

    load(f)  # loads 'panel_data'
    tmp <- as.data.table(panel_data)
    rm(panel_data)

    # Filter to women 18-49 from 2018 onwards (V4022/home_office only from Q1 2018)
    tmp <- tmp[V2007 == 2L & V2009 >= 18L & V2009 <= 49L & Ano >= 2018L]
    tmp[, year_quarter := Ano * 10L + Trimestre]

    # Merge on the composite key (id_dom, V1014, year_quarter) — see the Pass-1
    # comment for why V1014 is required to avoid cross-panel contamination.
    tmp <- merge(tmp, hh_lookup, by = c("id_dom", "V1014", "year_quarter"), all.x = TRUE)

    # Fill NA (household not in lookup = no qualifying child in household)
    flag_vars <- c("has_child_u4_hh", "has_child_u4_no_gc_hh", "has_child_u4_no_sc_hh",
                   "has_child_5_7_hh", "has_child_5_7_no_gc_hh", "has_child_5_7_no_sc_hh")
    for (v in flag_vars) {
      if (v %in% names(tmp)) tmp[is.na(get(v)), (v) := 0L]
    }

    filtered_list[[i]] <- tmp
    rm(tmp); gc()
  }

  message("  Merging filtered panels ...")
  dt <- rbindlist(filtered_list, fill = TRUE)
  rm(filtered_list, hh_lookup); gc()

  # --- Individual position in household ---
  # V2005: 1 = household head, 2 = spouse (different sex), 3 = spouse (same sex)
  dt[, is_head_or_spouse := fifelse(V2005 %in% c(1L, 2L, 3L), 1L, 0L)]

  # --- Child flags (household flag × individual is head/spouse) ---
  dt[, has_child_u4       := is_head_or_spouse * has_child_u4_hh]
  dt[, has_child_u4_no_gc := is_head_or_spouse * has_child_u4_no_gc_hh]
  dt[, has_child_u4_no_sc := is_head_or_spouse * has_child_u4_no_sc_hh]
  dt[, has_child_5_7       := is_head_or_spouse * has_child_5_7_hh]
  dt[, has_child_5_7_no_gc := is_head_or_spouse * has_child_5_7_no_gc_hh]
  dt[, has_child_5_7_no_sc := is_head_or_spouse * has_child_5_7_no_sc_hh]

  # Set youngest-child age to NA when the corresponding flag is 0
  dt[has_child_u4       == 0L, age_youngest_child       := NA_real_]
  dt[has_child_u4_no_gc == 0L, age_youngest_child_no_gc := NA_real_]
  dt[has_child_u4_no_sc == 0L, age_youngest_child_no_sc := NA_real_]

  # Drop intermediary household-level flag columns
  dt[, c("has_child_u4_hh", "has_child_u4_no_gc_hh", "has_child_u4_no_sc_hh",
         "has_child_5_7_hh", "has_child_5_7_no_gc_hh", "has_child_5_7_no_sc_hh") := NULL]

  # --- Potential telework (occupation eligibility) ---
  # COD codes eligible for telework, following Góes et al. (2020) adapted for
  # Brazil, as reported in Table 2 of Costa et al. (2024), Rev. Bras. de Econ.
  # de Empresas. Variable V4010 = 4-digit COD occupation code.
  # NOTE: do NOT restrict the main sample to potential_telework == 1 — occupation
  # is endogenous to the MP (women may switch to telework-eligible jobs in
  # response to the policy). Use potential_telework as a heterogeneity moderator.
  # EXACT list of the 126 COD codes from Table 2 of Costa et al. (2024),
  # transcribed code-by-code. Source PDF:
  # https://savearchive.zbw.eu/bitstream/11159/709467/1/1931566534_0.pdf
  telework_cod <- c(
    1111L, 1112L, 1113L, 1114L, 1120L,
    1211L, 1212L, 1213L, 1219L, 1221L, 1223L,
    1321L, 1322L, 1323L, 1324L, 1330L, 1344L, 1345L, 1431L,
    2111L, 2120L, 2133L, 2142L, 2151L, 2152L, 2153L,
    2161L, 2162L, 2163L, 2164L, 2166L,
    2265L, 2266L,
    2310L, 2320L, 2330L, 2341L, 2342L, 2351L, 2352L, 2353L, 2354L, 2355L, 2356L, 2359L,
    2411L, 2412L, 2413L, 2421L, 2422L, 2424L, 2431L,
    2511L, 2512L, 2513L, 2514L, 2519L, 2521L, 2522L, 2523L, 2529L,
    2611L, 2612L, 2621L, 2622L, 2631L, 2632L, 2633L, 2634L, 2636L, 2641L, 2643L,
    2651L, 2652L, 2653L, 2654L, 2655L, 2656L, 2659L,
    3118L,
    3311L, 3312L, 3313L, 3314L, 3315L, 3321L, 3322L, 3323L, 3341L, 3342L, 3343L,
    3352L, 3353L, 3359L,
    3411L, 3413L, 3421L, 3422L, 3423L,
    3511L, 3512L, 3513L, 3514L, 3522L,
    4110L, 4120L, 4221L, 4222L, 4223L, 4225L,
    4311L, 4312L, 4313L, 4411L, 4413L, 4415L,
    5165L, 5241L, 5244L, 5311L, 5312L,
    7316L, 7317L, 7318L, 7319L,
    7533L
  )
  dt[, potential_telework := fifelse(!is.na(V4010) & V4010 %in% telework_cod, 1L, 0L)]

  # --- Maternity leave proxy ---
  # V4006A: reason for absence (available Q4 2015+); category 2 = maternity/
  # paternity leave.
  dt[, on_maternity_leave := fifelse(!is.na(V4006A) & V4006A == 2L, 1L, 0L)]

  # --- Employment status outcomes (defined over the FULL sample) ---
  # datazoom's `ocupado` (from VD4002) is NA for anyone out of the labor force
  # (forca_trab == 0), so using it directly as a DiD outcome would silently drop
  # out-of-labor-force women — i.e. condition on labor-force participation, which
  # is itself a post-treatment outcome. We therefore build 0/1 indicators over
  # ALL sample women (out-of-labor-force → not employed / not unemployed):
  #   in_labor_force : = forca_trab (already 0/1, never NA)
  #   employed       : in labor force AND ocupado  → 1, else 0
  #   unemployed     : in labor force AND not ocupado (desocupado) → 1, else 0
  # Note ocupado is non-NA exactly when forca_trab == 1, so these are well-defined.
  dt[, in_labor_force := as.integer(forca_trab)]
  dt[, employed   := fifelse(!is.na(ocupado) & ocupado == 1L, 1L, 0L)]
  dt[, unemployed := fifelse(!is.na(ocupado) & ocupado == 0L, 1L, 0L)]

  # --- CLT private-sector employee (sharp "law binds" indicator) ---
  # Art. 75-F binds on CLT employees. datazoom's `formal` is broader (also public,
  # military/statutory, and INSS-contributing self-employed), where the law does
  # NOT bind. VD4009 == 1 = "empregado no setor privado com carteira" is the
  # sharpest group the provision applies to. Used as the precise placebo/
  # heterogeneity split in 05_heterogeneity.R; `formal`/`informal` (datazoom) are
  # kept as the general informality measure. = 0 for everyone else (incl. non-employed).
  dt[, clt_private := fifelse(!is.na(VD4009) & VD4009 == 1L, 1L, 0L)]

  # --- Panel identifier for TWFE regressions ---
  # load_pnadc(panel="advanced_3") produces id_rs3: the Stage 3 (Graph Theory
  # fuzzy match) individual ID. Unmatched individuals get id_rs3 = NA.
  # Multiple DIFFERENT unmatched women would be lumped into one spurious FE if
  # we used id_rs3 directly. id_panel: use id_rs3 when matching succeeded;
  # assign a unique row-level ID for unmatched individuals.
  dt[, panel_matched := fifelse(!is.na(id_rs3), 1L, 0L)]
  dt[, id_panel := fifelse(
    panel_matched == 1L,
    id_rs3,
    paste0("unmatched_", .I)
  )]
  # id_rs3 is already globally unique across panels (confirmed: 0 collisions),
  # so id_panel needs no V1014 prefix.

  # --- Globally-unique household ID (for clustering & retention stats) ---
  # Unlike id_rs3, the datazoom household ID id_dom is only unique WITHIN a
  # V1014 rotation group (confirmed: ~197k id_dom values are reused across
  # panels for genuinely different households). Clustering and
  # the panel-retention diagnostics would otherwise pool two unrelated
  # households across panels. Prefix with V1014 to make it globally unique.
  # (This is done AFTER the Pass-2 merge, which needs the raw integer id_dom.)
  dt[, id_dom := paste0(V1014, "_", id_dom)]

  # --- Treatment & post-policy indicators ---
  # Art. 75-F of MP 1108/2022 (enacted 25 March 2022; published 28 March 2022).
  # Most PNADC reference weeks in Q1 2022 pre-date the MP.
  # Main spec: Q1 2022 = pre-period. Robustness: Q1 2022 = post-period.
  dt[, treated          := has_child_u4]
  dt[, post_mp          := fifelse(year_quarter >= 20222L, 1L, 0L)]
  dt[, post_mp_alt      := fifelse(year_quarter >= 20221L, 1L, 0L)]
  dt[, treat_x_post     := treated * post_mp]
  dt[, treat_x_post_alt := treated * post_mp_alt]

  # --- Select columns for the final dataset ---
  keep_vars <- c(
    # Panel identifiers
    "id_rs3", "id_dom", "id_panel", "panel_matched",
    # Time identifiers
    "Ano", "Trimestre", "year_quarter", "V1016",
    # Survey design
    "UF", "UPA", "V1008", "V1014", "V1028", "posest",
    # Demographics (raw)
    "V2007", "V2009", "V2010", "V2005", "V1022",
    # Demographics (datazoom-derived)
    "faixa_idade", "regiao", "sigla_uf",
    # Education
    "VD3004", "VD3005", "faixa_educ",
    # Labor market (raw)
    "VD4001", "VD4002", "VD4009",
    # Labor market (datazoom-derived)
    "ocupado", "forca_trab", "formal", "informal",
    # Employment status outcomes (project-derived, defined over full sample)
    "in_labor_force", "employed", "unemployed",
    # CLT private-sector employee (sharp "law binds" heterogeneity indicator)
    "clt_private",
    # Income
    "VD4019", "Habitual", "rendimento_habitual_real",
    # Hours
    "VD4031", "VD4035",
    # Home office (V4022 available from Q1 2018)
    "V4022", "home_office",
    # Sector and occupation
    "V4013", "V4010", "cnae_2dig", "cod_2dig",
    # Maternity leave proxy
    "V4006A", "on_maternity_leave",
    # Household composition & treatment variables
    "is_head_or_spouse",
    "has_child_u4", "has_child_u4_no_gc", "has_child_u4_no_sc",
    "has_child_5_7", "has_child_5_7_no_gc", "has_child_5_7_no_sc",
    "age_youngest_child", "age_youngest_child_no_gc", "age_youngest_child_no_sc",
    "age_youngest_child_any",
    "potential_telework",
    "treated", "post_mp", "post_mp_alt",
    "treat_x_post", "treat_x_post_alt"
  )

  keep_vars <- intersect(keep_vars, names(dt))
  dt <- dt[, ..keep_vars]

  # --- Save ---
  output_file <- file.path(OUTPUT_PATH, "main_data.RData")
  message(sprintf("Saving main_data.RData (%s rows, %d vars) -> %s",
                  format(nrow(dt), big.mark = ","), ncol(dt), output_file))
  save(dt, file = output_file)
  message("Done.")

  return(invisible(NULL))
}

# =============================================================================
# RUN
# =============================================================================
build_main_data()             # Step 2 — build analytical dataset
