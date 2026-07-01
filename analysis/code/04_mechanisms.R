# =============================================================================
# 04_mechanisms.R
# Telework-priority channel of Art. 75-F. All specs use the main TWFE setup
# (treated main effect + treat_x_post | id_panel + year_quarter, weighted,
# clustered at id_dom), on the preferred sample (treated vs Control A, child 5-7).
#
#   Table 3 — first-stage (home_office) moderation by BASELINE telework
#             eligibility. If the law worked through telework, the home-office
#             effect should concentrate among women already in teleworkable
#             occupations; non-eligible women are a within-sample placebo.
#   Table 4 — occupation-allocation mechanism: `potential_telework` as the
#             OUTCOME. Tests whether treated mothers move INTO telework-eligible
#             occupations after the MP (priority-seeking sorting). This is the
#             coherent counterpart to never using potential_telework as a RHS
#             control (it is an outcome).
#
# Baseline telework eligibility (`pt_base`) = each individual's potential_telework
# in her first observed quarter, made time-invariant so it is a pre-determined
# moderator rather than a post-treatment outcome. (Occupation is endogenous to
# the MP, so the contemporaneous flag cannot be used as a moderator.)
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

# Baseline (first-observed) telework eligibility, time-invariant per individual.
setorder(dt, id_panel, year_quarter)
dt[, pt_base := as.integer(potential_telework[1] == 1), by = id_panel]

# Preferred sample: treated (child <=4) vs Control A (child 5-7).
A <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]

star <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
fmt  <- function(x, d = 2) formatC(x, format = "f", digits = d)
fmt0 <- function(x) formatC(x, format = "d", big.mark = ",")

# DiD of `y` on treated + treat_x_post; returns treat_x_post row (scaled to pp
# for binary outcomes).
did <- function(sample, y, pp = TRUE) {
  m <- feols(as.formula(sprintf("%s ~ treated + treat_x_post | id_panel + year_quarter", y)),
             data = sample, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
  ct <- coeftable(m)["treat_x_post", ]
  s  <- if (pp) 100 else 1
  used <- sample[!is.na(get(y))]
  list(est = ct[1] * s, se = ct[2] * s, star = star(ct[4]), n = nobs(m),
       n_ind = uniqueN(used$id_panel), n_hh = uniqueN(used$id_dom))
}

# =============================================================================
# Table 3 — first-stage moderation by baseline telework eligibility
# =============================================================================
m_all      <- did(A, "home_office")
m_elig     <- did(A[pt_base == 1], "home_office")
m_nonelig  <- did(A[pt_base == 0], "home_office")

# =============================================================================
# Table 4 — occupation-allocation: potential_telework as OUTCOME
# =============================================================================
m_alloc    <- did(A, "potential_telework")
m_alloc_B  <- did(dt[has_child_u4 == 1 | (has_child_u4 == 0 & has_child_5_7 == 0)],
                  "potential_telework")

# =============================================================================
# LaTeX
# =============================================================================
cell <- function(m) sprintf("%s$^{%s}$ & (%s)", fmt(m$est), m$star, fmt(m$se))

t3 <- c(
  "\\begin{table}[htbp]\\centering",
  "\\caption{Mechanism I --- First-Stage Home-Office Effect by Baseline Telework Eligibility}",
  "\\label{tab:mech_moderation}\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  " & All & Telework-eligible & Not eligible \\\\",
  " & & (baseline) & (baseline) \\\\",
  "\\midrule",
  sprintf("Treated $\\times$ Post & %s & %s & %s \\\\",
          sprintf("%s$^{%s}$", fmt(m_all$est), m_all$star),
          sprintf("%s$^{%s}$", fmt(m_elig$est), m_elig$star),
          sprintf("%s$^{%s}$", fmt(m_nonelig$est), m_nonelig$star)),
  sprintf(" & (%s) & (%s) & (%s) \\\\", fmt(m_all$se), fmt(m_elig$se), fmt(m_nonelig$se)),
  sprintf("Observations & %s & %s & %s \\\\", fmt0(m_all$n), fmt0(m_elig$n), fmt0(m_nonelig$n)),
  sprintf("Individuals & %s & %s & %s \\\\", fmt0(m_all$n_ind), fmt0(m_elig$n_ind), fmt0(m_nonelig$n_ind)),
  "\\bottomrule\\end{tabular}",
  "\\begin{tablenotes}\\small",
  "\\item \\textit{Notes:} Outcome is home office (pp). Sample: treated (child $\\leq$4) vs. Control A (child 5--7), women 18--49 head/spouse. Baseline telework eligibility is each woman's occupation eligibility (Costa et al. 2024) in her first observed quarter, held fixed. All columns include the treated main effect, individual and year-quarter FE, survey weights, and cluster SEs at the household. $^{*}$/$^{**}$/$^{***}$: 10/5/1\\%.",
  "\\end{tablenotes}\\end{table}"
)
writeLines(t3, file.path(TABLE_DIR, "tab03_mechanism_moderation.tex"))

t4 <- c(
  "\\begin{table}[htbp]\\centering",
  "\\caption{Mechanism II --- Occupational Sorting: Telework-Eligible Occupation as Outcome}",
  "\\label{tab:mech_allocation}\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & Control A (5--7) & Control B (no child 0--7) \\\\",
  "\\midrule",
  sprintf("Treated $\\times$ Post & %s$^{%s}$ & %s$^{%s}$ \\\\",
          fmt(m_alloc$est), m_alloc$star, fmt(m_alloc_B$est), m_alloc_B$star),
  sprintf(" & (%s) & (%s) \\\\", fmt(m_alloc$se), fmt(m_alloc_B$se)),
  sprintf("Observations & %s & %s \\\\", fmt0(m_alloc$n), fmt0(m_alloc_B$n)),
  "\\bottomrule\\end{tabular}",
  "\\begin{tablenotes}\\small",
  "\\item \\textit{Notes:} Outcome is an indicator for being in a telework-eligible occupation (pp). A positive coefficient means treated mothers move into eligible occupations after the MP. Same spec as Table 3. $^{*}$/$^{**}$/$^{***}$: 10/5/1\\%.",
  "\\end{tablenotes}\\end{table}"
)
writeLines(t4, file.path(TABLE_DIR, "tab04_mechanism_allocation.tex"))

# ---- Console summary --------------------------------------------------------
cat("\n=== Table 3: first stage (home office) by baseline telework eligibility ===\n")
cat(sprintf("  All:            %.2fpp (%.2f)%s   N=%s\n", m_all$est, m_all$se, m_all$star, fmt0(m_all$n)))
cat(sprintf("  Eligible:       %.2fpp (%.2f)%s   N=%s\n", m_elig$est, m_elig$se, m_elig$star, fmt0(m_elig$n)))
cat(sprintf("  Not eligible:   %.2fpp (%.2f)%s   N=%s\n", m_nonelig$est, m_nonelig$se, m_nonelig$star, fmt0(m_nonelig$n)))
cat("\n=== Table 4: potential_telework as OUTCOME (occupational sorting) ===\n")
cat(sprintf("  vs Control A:   %.2fpp (%.2f)%s   N=%s\n", m_alloc$est, m_alloc$se, m_alloc$star, fmt0(m_alloc$n)))
cat(sprintf("  vs Control B:   %.2fpp (%.2f)%s   N=%s\n", m_alloc_B$est, m_alloc_B$se, m_alloc_B$star, fmt0(m_alloc_B$n)))
message("\n=== 04_mechanisms.R complete ===")
