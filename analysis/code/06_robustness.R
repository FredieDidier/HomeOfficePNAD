# =============================================================================
# 06_robustness.R
# Robustness of the (null) first-stage home-office effect. Every row is the
# main DiD (treated main effect + treated x post | id_panel + year_quarter,
# weighted) on the preferred sample (treated vs Control A, child 5-7), varying
# one design choice at a time. Confirms the null is not an artifact of any
# single specification choice.
#
#   - Alternative post-MP cutoff (Q1 2022)
#   - Treatment variants (exclude grandchildren / stepchildren)
#   - COVID window (drop 2020-2021)
#   - State x quarter fixed effects; two-way (household, PSU) clustering
#   - Telework-eligible-only sample (baseline)
#   - Log real earnings, raw and winsorized at the top 1%
#   - Control-window sweep (5-6 ... 5-12) coefplot
#
# The estimation sample is the matched panel (panel_matched == 1), the main
# sample throughout the paper; the men placebo is in 07_triple_diff.R.
# =============================================================================

library(data.table)
library(fixest)
library(ggplot2)
library(here)
source(here("analysis", "code", "00_utils.R"))

DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")
GRAPH_DIR    <- here("analysis", "output", "graphs")

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[female == 1 & is_head_or_spouse == 1 & panel_matched == 1]
setorder(dt, id_panel, year_quarter)
dt[, pt_base := as.integer(potential_telework[1] == 1), by = id_panel]

star <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
fmt  <- function(x, d = 2) formatC(x, format = "f", digits = d)
fmt0 <- function(x) formatC(x, format = "d", big.mark = ",")

# Generic first-stage DiD. `sample` must already contain `tr` (0/1 treated) and
# `trxp` (tr x post). Returns the trxp row scaled to pp (or level for income).
fs <- function(sample, label, clu = ~id_dom, y = "home_office", pp = TRUE,
               fes = "id_panel + year_quarter") {
  m <- feols(as.formula(sprintf("%s ~ tr + trxp | %s", y, fes)),
             data = sample, weights = ~V1028, cluster = clu, notes = FALSE)
  ct <- coeftable(m)["trxp", ]
  s  <- if (pp) 100 else 1
  data.table(label = label, est = ct[1] * s, se = ct[2] * s, star = star(ct[4]), n = nobs(m))
}

# Build a treated-vs-control-A sample for a given treated/control flag pair.
mk <- function(treat_col, ctrl_col, post_col = "post_mp", extra = NULL) {
  s <- dt[get(treat_col) == 1 | (get(ctrl_col) == 1 & get(treat_col) == 0)]
  if (!is.null(extra)) s <- s[eval(extra, s)]
  s[, tr := as.integer(get(treat_col) == 1)]
  s[, trxp := tr * get(post_col)]
  s[]
}

A_main <- mk("has_child_u4", "has_child_5_7")

rows <- rbindlist(list(
  fs(A_main,                                              "Baseline"),
  fs(mk("has_child_u4", "has_child_5_7", "post_mp_alt"),  "Alternative cutoff (2022Q1 post)"),
  fs(mk("has_child_u4_no_gc", "has_child_5_7_no_gc"),     "Treated, excluding grandchildren"),
  fs(mk("has_child_u4_no_sc", "has_child_5_7_no_sc"),     "Treated, excluding stepchildren"),
  fs(A_main[!(year_quarter %/% 10L %in% c(2020L, 2021L))],"Excluding 2020--2021 (COVID)"),
  fs(A_main, "State $\\times$ quarter fixed effects", fes = "id_panel + sigla_uf^year_quarter"),
  fs(A_main, "Two-way cluster (household, PSU)", clu = ~id_dom + UPA),
  fs(A_main[pt_base == 1],                                "Telework-eligible only")
))

# ---- Earnings: log real earnings, with a winsorized version -----------------
# Earnings are observed only for workers with positive income; the outcome is
# the log of real monthly earnings, so the coefficient is a proportional effect.
# The winsorized version caps earnings at the 99th percentile before taking logs.
A_inc <- A_main[!is.na(rendimento_habitual_real) & rendimento_habitual_real > 0]
cap <- A_inc[, quantile(rendimento_habitual_real, 0.99)]
A_inc[, log_earn   := log(rendimento_habitual_real)]
A_inc[, log_earn_w := log(pmin(rendimento_habitual_real, cap))]
inc_log  <- fs(A_inc, "Log real earnings",                       y = "log_earn",   pp = FALSE)
inc_logw <- fs(A_inc, "Log real earnings (winsorized top 1\\%)", y = "log_earn_w", pp = FALSE)

# =============================================================================
# Table A (first stage) + income (two-line journal format: estimate; (se) below)
# =============================================================================
row_tex <- function(r, d = 2) c(
  sprintf("%s & %s$^{%s}$ & %s \\\\", r$label, fmt(r$est, d), r$star, fmt0(r$n)),
  sprintf(" & (%s) & \\\\", fmt(r$se, d)))
tab <- c(
  "\\begin{table}[H]\\centering",
  "\\caption{Robustness of the First-Stage Home-Office Effect}",
  "\\label{tab:robustness}\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & Treated $\\times$ Post & Obs. \\\\",
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Home office (pp)}} \\\\",
  unlist(lapply(seq_len(nrow(rows)), function(i) row_tex(rows[i]))),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Log real earnings (workers with positive earnings)}} \\\\",
  row_tex(inc_log, 3),
  row_tex(inc_logw, 3),
  "\\bottomrule\\end{tabular}",
  paste("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Each estimate is a separate difference-in-differences regression on the preferred sample (treated vs.\\ Control A, youngest child 5--7), including the treated main effect and individual and year-quarter fixed effects, weighted by the survey weights. Standard errors are clustered at the household in parentheses, except the two-way row, which clusters at the household and at the primary sampling unit (the census enumeration area PNADC samples within each geographic stratum).", SIGNIF_NOTE, "The placebo on men is reported in Table~\\ref{tab:triple_diff}."),
  "\\end{table}"
)
writeLines(tab, file.path(TABLE_DIR, "tab07_robustness.tex"))

# =============================================================================
# Figure A5 (fig08) — control-window sweep, first stage
# =============================================================================
win <- rbindlist(lapply(6:12, function(K) {
  s <- dt[has_child_u4 == 1 | (age_youngest_child_any >= 5 & age_youngest_child_any <= K)]
  s[, tr := as.integer(has_child_u4 == 1)][, trxp := tr * post_mp]
  fs(s, sprintf("5-%d", K))
}))
win[, ci_lo := est - 1.96 * se][, ci_hi := est + 1.96 * se]
win[, label := factor(label, levels = win$label)]

figw <- ggplot(win, aes(x = label, y = est)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey45") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.2, colour = "#2C3E50") +
  geom_point(colour = "#2C3E50", size = 2) +
  labs(x = "Control window (youngest child age)", y = "First-stage home-office effect (pp)") +
  theme_bw(base_size = 13) +
  theme(panel.grid.minor = element_blank())
ggsave(file.path(GRAPH_DIR, "fig08_control_window_sweep.pdf"), figw, width = 7.5, height = 4.5)
ggsave(file.path(GRAPH_DIR, "fig08_control_window_sweep.png"), figw, width = 7.5, height = 4.5, dpi = 300)

cat("\n=== First-stage robustness (home office, pp) ===\n")
print(rows[, .(label = gsub("\\\\", "", label), est = round(est, 2), se = round(se, 2), star, n = fmt0(n))])
cat("\n=== Log real earnings ===\n")
print(rbind(inc_log, inc_logw)[, .(label = gsub("\\\\", "", label), est = round(est, 3), se = round(se, 3), star)])
message("\n=== 06_robustness.R complete ===")
