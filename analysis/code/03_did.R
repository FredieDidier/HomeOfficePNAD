# =============================================================================
# 03_did.R
# Main difference-in-differences results.
#
#   Table 2  — First stage (home office): specification ladder.
#              (1) OLS + demographic controls, no FE
#              (2) + year-quarter FE
#              (3) + individual FE                (preferred)
#              (4) + individual FE + age, age^2
#              Shows the null does not depend on the fixed-effects/covariate
#              choice (addresses whether individual FE and age controls matter).
#   Table 3  — All outcomes under the preferred spec, Control A and Control B,
#              plus the A-vs-B placebo (home office).
#
# Preferred spec: treated + treat_x_post | id_panel + year_quarter, weighted by
# V1028, clustered at id_dom. The `treated` (= has_child_u4) main effect is
# included because treatment status is time-varying (see CLAUDE.md).
#
# Sample: WOMEN aged 18-49, head or spouse (main_data now holds both sexes; men
# enter only in 07_triple_diff.R).
# =============================================================================

library(data.table)
library(fixest)
library(here)

DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")
dir.create(TABLE_DIR, showWarnings = FALSE, recursive = TRUE)

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[female == 1 & is_head_or_spouse == 1]
setnames(dt, "VD4031", "hours_usual")

# Human-readable labels for etable. Nuisance controls are left unlabeled so they
# can be dropped from the display by their raw names.
dict <- c(
  treat_x_post = "Treated $\\times$ Post",
  treated      = "Treated (child $\\leq$4)",
  home_office  = "Home office", rendimento_habitual_real = "Real income",
  hours_usual  = "Usual hours", employed = "Employed",
  in_labor_force = "In labor force", on_maternity_leave = "Maternity leave",
  id_panel = "Individual", year_quarter = "Year-quarter"
)

samp_A <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]
samp_B <- dt[has_child_u4 == 1 | (has_child_u4 == 0 & has_child_5_7 == 0)]

# =============================================================================
# Table 2 — first-stage specification ladder (Control A)
# =============================================================================
m1 <- feols(home_office ~ treated + post_mp + treat_x_post + V2009 + I(V2009^2) +
              higher_educ + i(V2010) + i(regiao),
            samp_A, weights = ~V1028, cluster = ~id_dom)
m2 <- feols(home_office ~ treated + treat_x_post + V2009 + I(V2009^2) +
              higher_educ + i(V2010) + i(regiao) | year_quarter,
            samp_A, weights = ~V1028, cluster = ~id_dom)
m3 <- feols(home_office ~ treated + treat_x_post | id_panel + year_quarter,
            samp_A, weights = ~V1028, cluster = ~id_dom)
m4 <- feols(home_office ~ treated + treat_x_post + V2009 + I(V2009^2) |
              id_panel + year_quarter,
            samp_A, weights = ~V1028, cluster = ~id_dom)

etable(m1, m2, m3, m4,
       tex = TRUE, file = file.path(TABLE_DIR, "tab02_did_firststage.tex"), replace = TRUE,
       dict = dict, drop = c("post_mp", "V2009", "V2010", "regiao", "higher_educ", "Constant"),
       extralines = list("Demographic controls" = c("Yes", "Yes", "No", "Age only")),
       fitstat = ~ n + r2 + wr2, digits = 3, digits.stats = 3,
       title = "First-Stage Home-Office Effect: Specification Ladder (Control A, child 5--7)",
       label = "tab:did_firststage",
       notes = "Sample: women 18--49, head/spouse, treated (child $\\leq$4) vs.\\ Control A (child 5--7). Outcome: home office (0/1). Demographic controls: age, age$^2$, higher education, race, region. Weighted by survey weights; SE clustered at the household in parentheses. Columns (3)--(4) add individual fixed effects. $^{*}$/$^{**}$/$^{***}$: 10/5/1\\%.")

# =============================================================================
# Table 3 — all outcomes, preferred spec, Control A and Control B
# =============================================================================
outcomes <- c("home_office", "rendimento_habitual_real", "hours_usual",
              "employed", "in_labor_force", "on_maternity_leave")
run_all <- function(sample) {
  setNames(lapply(outcomes, function(y)
    feols(as.formula(sprintf("%s ~ treated + treat_x_post | id_panel + year_quarter", y)),
          sample, weights = ~V1028, cluster = ~id_dom, notes = FALSE)), outcomes)
}
mods_A <- run_all(samp_A)
mods_B <- run_all(samp_B)

etable(mods_A,
       tex = TRUE, file = file.path(TABLE_DIR, "tab03a_did_outcomes_A.tex"), replace = TRUE,
       dict = dict, fitstat = ~ n + r2, digits = 3, digits.stats = 3,
       title = "DiD Estimates by Outcome --- Control A (child 5--7)",
       label = "tab:did_outcomes_A",
       notes = "Each column is a separate DiD (preferred spec: treated main effect + individual and year-quarter FE, weighted, clustered at the household). Sample: women 18--49, head/spouse. Real income and usual hours are observed for workers only. $^{*}$/$^{**}$/$^{***}$: 10/5/1\\%.")

etable(mods_B,
       tex = TRUE, file = file.path(TABLE_DIR, "tab03b_did_outcomes_B.tex"), replace = TRUE,
       dict = dict, fitstat = ~ n + r2, digits = 3, digits.stats = 3,
       title = "DiD Estimates by Outcome --- Control B (no child 0--7)",
       label = "tab:did_outcomes_B",
       notes = "As Table \\ref{tab:did_outcomes_A}, using Control B (women with no child aged 0--7).")

# ---- A-vs-B placebo (home office) ------------------------------------------
samp_P <- dt[(has_child_5_7 == 1 & has_child_u4 == 0) | (has_child_u4 == 0 & has_child_5_7 == 0)]
samp_P[, fake_x_post := as.integer(has_child_5_7 == 1) * post_mp]
mP <- feols(home_office ~ has_child_5_7 + fake_x_post | id_panel + year_quarter,
            samp_P, weights = ~V1028, cluster = ~id_dom, notes = FALSE)

# ---- Console summary --------------------------------------------------------
cat("\n=== Table 2: first-stage ladder (home office, treat_x_post) ===\n")
for (nm in c("m1", "m2", "m3", "m4")) {
  ct <- coeftable(get(nm))["treat_x_post", ]
  cat(sprintf("  %s: %.3f (%.3f) p=%.2f\n", nm, ct[1] * 100, ct[2] * 100, ct[4]))
}
cat("\n=== Table 3: Control A outcomes (treat_x_post) ===\n")
for (y in outcomes) {
  ct <- coeftable(mods_A[[y]])["treat_x_post", ]
  sc <- if (y %in% c("rendimento_habitual_real", "hours_usual")) 1 else 100
  cat(sprintf("  %-26s %.3f (%.3f) p=%.2f\n", y, ct[1] * sc, ct[2] * sc, ct[4]))
}
ctP <- coeftable(mP)["fake_x_post", ]
cat(sprintf("\n  Placebo A-vs-B (home office): %.3f (%.3f) p=%.2f\n", ctP[1] * 100, ctP[2] * 100, ctP[4]))
message("\n=== 03_did.R complete ===")
