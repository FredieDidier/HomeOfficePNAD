# =============================================================================
# 00_master_build.R
# Master script for the data build pipeline.
# Run this file to reproduce the full dataset from scratch.
#
# Pipeline:
#   01_pnadc.R  →  Downloads PNADC quarterly microdata, builds rotating panel
#                  files (saved to Dropbox/input), then merges all panels into
#                  the final analytical dataset (saved to Dropbox/output as
#                  main_data.RData).
#
# NOTE: Step 1 (downloading from IBGE) is commented out at the bottom of
#   01_pnadc.R once the panel files already exist in Dropbox/input. Uncomment
#   download_pnadc_panels() there only if you need to (re-)download raw data —
#   it skips any Panel_{v}.RData that already exists, so it is safe to re-run.
#
# PATHS: Only DROPBOX_ROOT in 01_pnadc.R needs to be updated on a new machine.
# =============================================================================

library(here)

source(here("build", "01_pnadc.R"))
