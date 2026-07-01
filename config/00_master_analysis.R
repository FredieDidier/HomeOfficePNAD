# =============================================================================
# 00_master_analysis.R
# Master script for the analysis pipeline.
# Run this file after 00_master_build.R to reproduce all results.
#
# Analysis scripts will be added here as the project progresses.
# Each script should be self-contained and load main_data.RData from Dropbox.
#
# Expected pipeline (to be populated):
#   01_descriptives.R   →  Summary statistics, sample description
#   02_event_study.R    →  Event-study plot around MP 1108/2022 (March 2022)
#   03_did.R            →  Difference-in-differences estimates
#   04_mechanisms.R     →  Telework-priority channel: potential_telework moderation + occupation-allocation
#   05_heterogeneity.R  →  Subgroup splits: formal/informal, public/private, education, age band
#   06_robustness.R     →  Robustness checks and placebo tests
#
# PATHS: Only DROPBOX_ROOT in 01_pnadc.R needs to be updated on a new machine.
# =============================================================================

library(here)

source(here("analysis", "code", "01_descriptives.R"))
source(here("analysis", "code", "02_event_study.R"))
source(here("analysis", "code", "03_did.R"))
source(here("analysis", "code", "04_mechanisms.R"))
source(here("analysis", "code", "05_heterogeneity.R"))
source(here("analysis", "code", "06_robustness.R"))
