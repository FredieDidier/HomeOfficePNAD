# =============================================================================
# config.R — machine-specific configuration.
#
# ***THE ONLY FILE TO EDIT before reproducing the project on a new machine.***
# Set DROPBOX_ROOT to the local path of the data folder that holds
#   build/input/   (the Panel_*.RData panel files)
#   build/output/  (main_data.RData, the final analytical dataset)
# All GitHub-repo paths are resolved automatically with here::here(), so this
# single line is the only path that changes per machine. Sourced by every build
# and analysis script.
#
# Required R packages (install once):
#   install.packages(c("data.table", "fixest", "ggplot2", "here", "readxl",
#                      "PNADcIBGE", "remotes"))
#   remotes::install_github("datazoompuc/datazoom.social")
# Optional (only for the descriptive state map, not used in the paper):
#   install.packages(c("geobr", "sf"))
# =============================================================================

DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
