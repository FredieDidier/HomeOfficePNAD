# =============================================================================
# 03_did.R
# Main difference-in-differences estimates (Table 2, Main Results).
#
# Preferred control: Control A (youngest child 5-7) — the tight, age-threshold
# comparison. Reported alongside: Control B (no child 0-7) — broader, higher
# power. Plus a falsification: Control A vs Control B should be ~0 (the 5-7 group
# is not treated by the law), which validates using it as the clean control.
#
# Main TWFE spec (weights + individual & quarter FE, clustered at household):
#   feols(outcome ~ has_child_u4 + treat_x_post | id_panel + year_quarter,
#         weights = ~V1028, cluster = ~id_dom)
# where treat_x_post = has_child_u4 * post_mp (post = Q2 2022 onwards).
#
# IMPORTANT — the `has_child_u4` main effect MUST be included. Treatment status
# here is TIME-VARYING (a woman is "treated" only in the quarters she has a
# child <=4; it switches as children are born / age past 4). Individual FE
# therefore do NOT absorb it, and omitting it lets treat_x_post pick up the
# level "motherhood penalty" of women who transition into young-child status in
# the post period (this is exactly what inflated the vs-Control-B reduced-form
# estimates in an earlier draft). With has_child_u4 controlled, treat_x_post is
# the clean DiD: how the young-child gap CHANGES post-MP.
#
# Column 1 (home_office) is the FIRST STAGE / compliance proxy and must be read
# first: it quantifies how much the law actually moved telework take-up among
# eligible women, and calibrates every reduced-form column. The pooled estimate
# averages over all post-MP quarters; the effect is back-loaded (see the event
# study, 02_event_study.R), so the pooled first stage is smaller than the
# mature (2024-2025) effect.
#
# NOTE on conditional outcomes: `income`/`hours` are observed only for
# workers/earners (NA otherwise), so those columns condition on employment (a
# post-treatment margin) — standard in the wage literature, flagged in the note.
# `home_office`, `employed`, `in_labor_force`, `on_maternity_leave` are defined
# over the full sample.
#
# Output: tab02_did_main.tex
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
dt <- dt[is_head_or_spouse == 1]

# ---- Outcomes (order = table columns) ---------------------------------------
outcomes <- c("home_office", "rendimento_habitual_real", "hours_usual",
              "employed", "in_labor_force", "on_maternity_leave")
outcome_labels <- c("Home office", "Real income", "Usual hours",
                    "Employed", "In labor force", "Maternity leave")
# outcomes reported as percentage-point effects (binary DVs)
pp_outcomes <- c("home_office", "employed", "in_labor_force", "on_maternity_leave")

setnames(dt, "VD4031", "hours_usual")  # rename for readability in this script

# ---- Estimation helper ------------------------------------------------------
# Runs the main TWFE DiD of `y` on `treat_x_post` for a given sample, returns a
# one-row summary with the coefficient, SE, stars, and reporting statistics.
star <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))

fit_one <- function(sample, y) {
  fml <- as.formula(sprintf("%s ~ has_child_u4 + treat_x_post | id_panel + year_quarter", y))
  m <- feols(fml, data = sample, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
  ct <- coeftable(m)["treat_x_post", ]
  used <- sample[!is.na(get(y))]
  scale <- if (y %in% pp_outcomes) 100 else 1
  list(
    est  = ct[1] * scale,
    se   = ct[2] * scale,
    star = star(ct[4]),
    n    = nobs(m),
    n_ind = uniqueN(used$id_panel),
    n_hh  = uniqueN(used$id_dom),
    wr2   = fitstat(m, "wr2")$wr2
  )
}

run_panel <- function(sample) {
  lapply(outcomes, function(y) fit_one(sample, y))
}

# ---- Samples ----------------------------------------------------------------
samp_A <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]
samp_B <- dt[has_child_u4 == 1 | (has_child_u4 == 0 & has_child_5_7 == 0)]

res_A <- run_panel(samp_A)
res_B <- run_panel(samp_B)

# ---- Placebo: Control A (5-7) vs Control B, home_office ----------------------
samp_P <- dt[(has_child_5_7 == 1 & has_child_u4 == 0) |
             (has_child_u4 == 0 & has_child_5_7 == 0)]
samp_P[, fake_x_post := as.integer(has_child_5_7 == 1) * post_mp]
# has_child_5_7 is the (time-varying) fake-treated main effect for the placebo.
mP <- feols(home_office ~ has_child_5_7 + fake_x_post | id_panel + year_quarter,
            data = samp_P, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
ctP <- coeftable(mP)["fake_x_post", ]
placebo <- list(est = ctP[1] * 100, se = ctP[2] * 100, star = star(ctP[4]), n = nobs(mP))

# =============================================================================
# LaTeX table
# =============================================================================
fmt <- function(x, d = 2) formatC(x, format = "f", digits = d)
fmt0 <- function(x) formatC(x, format = "d", big.mark = ",")

panel_rows <- function(res, panel_title) {
  coef_cells <- sapply(res, function(r) sprintf("%s$^{%s}$", fmt(r$est), r$star))
  se_cells   <- sapply(res, function(r) sprintf("(%s)", fmt(r$se)))
  n_cells    <- sapply(res, function(r) fmt0(r$n))
  ind_cells  <- sapply(res, function(r) fmt0(r$n_ind))
  hh_cells   <- sapply(res, function(r) fmt0(r$n_hh))
  wr2_cells  <- sapply(res, function(r) fmt(r$wr2, 3))
  c(
    sprintf("\\multicolumn{%d}{l}{\\textit{%s}} \\\\", length(outcomes) + 1, panel_title),
    paste0("$\\quad$ Treated $\\times$ Post & ", paste(coef_cells, collapse = " & "), " \\\\"),
    paste0(" & ", paste(se_cells, collapse = " & "), " \\\\"),
    paste0("$\\quad$ Observations & ", paste(n_cells, collapse = " & "), " \\\\"),
    paste0("$\\quad$ Individuals & ", paste(ind_cells, collapse = " & "), " \\\\"),
    paste0("$\\quad$ Households & ", paste(hh_cells, collapse = " & "), " \\\\"),
    paste0("$\\quad$ Within-$R^2$ & ", paste(wr2_cells, collapse = " & "), " \\\\")
  )
}

ncol_tab <- length(outcomes)
col_spec <- paste0("l", paste(rep("c", ncol_tab), collapse = ""))
header   <- paste0(" & ", paste(sprintf("(%d)", seq_len(ncol_tab)), collapse = " & "), " \\\\")
labels   <- paste0(" & ", paste(outcome_labels, collapse = " & "), " \\\\")

lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Difference-in-Differences Estimates of MP 1108/2022 (Art. 75-F)}",
  "\\label{tab:did_main}",
  "\\small",
  paste0("\\begin{tabular}{", col_spec, "}"),
  "\\toprule",
  header,
  labels,
  "\\midrule",
  panel_rows(res_A, "Panel A --- Preferred control: youngest child 5--7 years"),
  "\\midrule",
  panel_rows(res_B, "Panel B --- Broad control: no child aged 0--7 years"),
  "\\midrule",
  sprintf("\\multicolumn{%d}{l}{\\textit{Falsification (home office): Control A (5--7) vs. Control B}} \\\\", ncol_tab + 1),
  sprintf("$\\quad$ (5--7) $\\times$ Post & \\multicolumn{%d}{l}{%s$^{%s}$ \\; (%s) \\quad N = %s} \\\\",
          ncol_tab, fmt(placebo$est), placebo$star, fmt(placebo$se), fmt0(placebo$n)),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Each cell is the coefficient on Treated $\\times$ Post from a separate regression, where Treated $=$ has a child aged $\\leq 4$ and Post $=$ 2022Q2 onwards. All specifications include individual and year-quarter fixed effects, are weighted by survey weights (V1028), and cluster standard errors at the household level. Sample: women aged 18--49 who are household head or spouse. Columns (1), (4), (5), (6) are 0/1 outcomes reported in percentage points; column (1) is the first stage. Real income (2) and usual hours (3) are observed only for workers, so those columns condition on employment. $^{*}$, $^{**}$, $^{***}$: significance at 10\\%, 5\\%, 1\\%.",
  "\\end{tablenotes}",
  "\\end{table}"
)

outfile <- file.path(TABLE_DIR, "tab02_did_main.tex")
writeLines(lines, outfile)
message("Table 2 saved: ", outfile)

# ---- Console summary (for the researcher) -----------------------------------
cat("\n=== Table 2 — first stage (home office, pp) ===\n")
cat(sprintf("  Control A (5-7):  %.3f (%.3f)%s   N=%s\n",
            res_A[[1]]$est, res_A[[1]]$se, res_A[[1]]$star, fmt0(res_A[[1]]$n)))
cat(sprintf("  Control B (0-7):  %.3f (%.3f)%s   N=%s\n",
            res_B[[1]]$est, res_B[[1]]$se, res_B[[1]]$star, fmt0(res_B[[1]]$n)))
cat(sprintf("  Placebo A vs B:   %.3f (%.3f)%s   N=%s\n",
            placebo$est, placebo$se, placebo$star, fmt0(placebo$n)))
cat("\n=== all outcomes, Control A (preferred) ===\n")
for (j in seq_along(outcomes)) {
  cat(sprintf("  %-16s %.3f (%.3f)%s\n",
              outcome_labels[j], res_A[[j]]$est, res_A[[j]]$se, res_A[[j]]$star))
}
message("\n=== 03_did.R complete ===")
