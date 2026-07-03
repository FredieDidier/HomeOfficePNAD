# =============================================================================
# 00_master_analysis.R
# Master script for the analysis pipeline.
# Run this file after 00_master_build.R to reproduce all results.
#
# Each script is self-contained and loads main_data.RData from Dropbox/output.
#
# Pipeline:
#   01_descriptives.R   →  Summary statistics (Table 1, A0), descriptive figures
#   02_event_study.R    →  Event studies + pre-trend joint tests (fig06, fig09)
#   03_did.R            →  First stage (Table 2) and reduced-form outcomes (Table 3)
#   04_mechanisms.R     →  Telework moderation + occupation-allocation (Tables 4, 5, 5b)
#   05_heterogeneity.R  →  Subgroup splits + Holm correction (Table 6, 6b, fig07)
#   06_robustness.R     →  Robustness, placebo, control-window sweep (Table 7, fig08)
#   07_triple_diff.R    →  Triple difference with men (Tables 8, 8b)
#
# PATHS: set DROPBOX_ROOT once in config/config.R (the only path to change on a
#   new machine); every script sources it. GitHub-repo paths use here::here().
# =============================================================================

library(here)

source(here("analysis", "code", "01_descriptives.R"))
source(here("analysis", "code", "02_event_study.R"))
source(here("analysis", "code", "03_did.R"))
source(here("analysis", "code", "04_mechanisms.R"))
source(here("analysis", "code", "05_heterogeneity.R"))
source(here("analysis", "code", "06_robustness.R"))
source(here("analysis", "code", "07_triple_diff.R"))
