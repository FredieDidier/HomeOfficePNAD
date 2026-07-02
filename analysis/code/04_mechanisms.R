# =============================================================================
# 04_mechanisms.R  — telework-priority channel (women; both-sex base filtered).
#
#   Table 4  — first-stage home-office effect by BASELINE telework eligibility
#              (all / eligible / not eligible). If the law worked through
#              telework, the effect concentrates among teleworkable women.
#   Table 5  — occupational sorting: telework-eligible occupation as the OUTCOME
#              (Control A and Control B). Tests whether treated mothers move into
#              eligible occupations to claim the priority.
#   Table 5b — occupation transition matrix (descriptive), among matched women
#              observed both pre- and post-MP.
#
# Baseline eligibility (`pt_base`) = each woman's occupation eligibility in her
# first observed quarter, held fixed (occupation is endogenous to the policy).
# Spec: home_office ~ treated + treat_x_post | id_panel + year_quarter, weighted,
# clustered at id_dom, on the preferred sample (treated vs Control A).
# =============================================================================

library(data.table)
library(fixest)
library(here)
source(here("analysis", "code", "00_utils.R"))

DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[female == 1 & is_head_or_spouse == 1 & panel_matched == 1]
setorder(dt, id_panel, year_quarter)
dt[, pt_base := as.integer(potential_telework[1] == 1), by = id_panel]

dict <- c(treat_x_post = "Treated $\\times$ Post", treated = "Treated (child $\\leq$4)",
          home_office = "Home office", potential_telework = "Telework-eligible occupation",
          id_panel = "Individual", id_dom = "Household", year_quarter = "Year-quarter")

A <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]
B <- dt[has_child_u4 == 1 | (has_child_u4 == 0 & has_child_5_7 == 0)]

fe <- function(sample, y = "home_office")
  feols(as.formula(sprintf("%s ~ treated + treat_x_post | id_panel + year_quarter", y)),
        sample, weights = ~V1028, cluster = ~id_dom, notes = FALSE)

# ---- Table 4: moderation by baseline telework eligibility -------------------
tab04_file <- file.path(TABLE_DIR, "tab04_mechanism_moderation.tex")
etable(fe(A), fe(A[pt_base == 1]), fe(A[pt_base == 0]),
       tex = TRUE, file = tab04_file, replace = TRUE, signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
       dict = dict, headers = c("All", "Telework-eligible", "Not eligible"),
       fitstat = ~ n + r2, digits = 3, digits.stats = 3,
       title = "First-Stage Home-Office Effect by Baseline Telework Eligibility",
       label = "tab:mech_moderation",
       notes = paste("\\footnotesize\\textit{Notes:} Sample: women 18--49, household head or spouse, treated (child $\\leq$4) vs.\\ Control A (youngest child 5--7). Baseline telework eligibility is the woman's occupation eligibility, following \\citet{costa2024}, measured in her first observed quarter and held fixed. All columns include individual and year-quarter fixed effects, are weighted by the survey weights, and cluster standard errors at the household in parentheses.", SIGNIF_NOTE))
postprocess_tex(tab04_file, fontsize = "\\small", tabcolsep = 5)

# ---- Table 5: occupational sorting (potential_telework as outcome) ----------
tab05_file <- file.path(TABLE_DIR, "tab05_mechanism_allocation.tex")
etable(fe(A, "potential_telework"), fe(B, "potential_telework"),
       tex = TRUE, file = tab05_file, replace = TRUE, signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
       dict = dict, headers = c("Control A (5--7)", "Control B (no child 0--7)"),
       fitstat = ~ n + r2, digits = 3, digits.stats = 3,
       title = "Occupational Sorting: Telework-Eligible Occupation as Outcome",
       label = "tab:mech_allocation",
       notes = paste("\\footnotesize\\textit{Notes:} The outcome is an indicator for being in a telework-eligible occupation. A positive Treated $\\times$ Post coefficient would mean treated mothers move into eligible occupations after the reform. The specification is the same preferred difference-in-differences used for the first stage: the treated main effect with individual and year-quarter fixed effects, weighted by the survey weights. Standard errors are clustered at the household in parentheses.", SIGNIF_NOTE))
postprocess_tex(tab05_file, fontsize = "\\small", tabcolsep = 5)

# ---- Table 5b: occupation transition matrix (descriptive) ------------------
# Among matched women observed both pre- and post-MP: baseline (first pre-MP)
# vs latest (last post-MP) telework-eligible state, treated vs control.
m <- dt[panel_matched == 1 & (has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0))]
pre  <- m[post_mp == 0, .(pt_pre  = potential_telework[.N]), by = .(id_panel, grp = has_child_u4)]
post <- m[post_mp == 1, .(pt_post = potential_telework[1]),  by = .(id_panel)]
tr   <- merge(pre, post, by = "id_panel")

n_tr   <- nrow(tr[grp == 1])
n_ctrl <- nrow(tr[grp == 0])
trans_tab <- function(g, lbl) {
  s <- tr[grp == g]
  ng <- formatC(nrow(s), big.mark = ",", format = "d")
  p <- function(a, b) sprintf("%.1f\\%%", 100 * mean(s$pt_pre == a & s$pt_post == b))
  c(sprintf("\\multicolumn{3}{l}{\\textit{%s} --- %s women} \\\\", lbl, ng),
    " & Post: not eligible & Post: eligible \\\\",
    sprintf("$\\quad$ Pre: not eligible & %s & %s \\\\", p(0, 0), p(0, 1)),
    sprintf("$\\quad$ Pre: eligible & %s & %s \\\\", p(1, 0), p(1, 1)))
}
tb <- c("\\begin{table}[H]\\centering",
  "\\caption{Occupation Transitions Around the Reform}",
  "\\label{tab:occ_transition}\\small",
  "\\begin{tabular}{lcc}", "\\toprule",
  trans_tab(1, "Treated (child $\\leq$4)"), "\\midrule",
  trans_tab(0, "Control A (child 5--7)"), "\\bottomrule\\end{tabular}",
  "\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Each cell is the share of women in a given pre-to-post telework-eligibility transition, among matched women observed both before and after the second quarter of 2022 (the number of women in each group is shown in the panel headers). Off-diagonal cells are occupation switches. The treated and control distributions are similar, consistent with the null in Table~\\ref{tab:mech_allocation}.",
  "\\end{table}")
writeLines(tb, file.path(TABLE_DIR, "tab05b_occupation_transition.tex"))

# ---- Console ----------------------------------------------------------------
cat("\n=== Mechanism I: first stage by baseline eligibility (pp) ===\n")
for (lab in c("all", "elig", "nonelig")) {
  s <- switch(lab, all = A, elig = A[pt_base == 1], nonelig = A[pt_base == 0])
  ct <- coeftable(fe(s))["treat_x_post", ]
  cat(sprintf("  %-9s %.2f (%.2f) p=%.2f\n", lab, ct[1] * 100, ct[2] * 100, ct[4]))
}
cat("\n=== Mechanism II: potential_telework as outcome (pp) ===\n")
for (nm in c("A", "B")) {
  ct <- coeftable(fe(get(nm), "potential_telework"))["treat_x_post", ]
  cat(sprintf("  vs Control %s: %.2f (%.2f) p=%.2f\n", nm, ct[1] * 100, ct[2] * 100, ct[4]))
}
message("\n=== 04_mechanisms.R complete ===")
