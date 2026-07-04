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
# Packages install themselves: the master scripts (config/00_master_*.R) call
# pacman::p_load(), which installs any missing package automatically, so there
# is no need to run install.packages() by hand.
# =============================================================================

DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
