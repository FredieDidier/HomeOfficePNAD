# =============================================================================
# 06_robustness.R
# Robustness of the (null) first-stage home-office effect. Every row is the
# main DiD (treated main effect + treated x post | id_panel + year_quarter,
# weighted) on the preferred sample (treated vs Control A, child 5-7), varying
# one design choice at a time. Confirms the null is not an artifact of any
# single specification choice.
#
#   Table A1  Alternative post-MP cutoff (Q1 2022, post_mp_alt)
#   Table A2  Treatment variants (exclude grandchildren / stepchildren)
#   Table A3  COVID window (drop 2020-2021)
#   Table A4  Age-restricted samples (20-35, 20-40)
#   Table A5  UPA-level clustering
#   Table A6  Matched-panel subsample (panel_matched == 1)
#   Table A7  Telework-eligible-only sample (baseline)
#   Table A9  Outlier sensitivity: winsorized real income (income outcome)
#   Figure A5 Control-window sweep (5-6 ... 5-12) coefplot
#
# Table A8 (placebo — men) needs a separate parallel extraction
# (build_placebo_men_data, V2007==1) and is deferred; see the Paper Output Plan.
# =============================================================================

library(data.table)
library(fixest)
library(ggplot2)
library(here)

DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")
GRAPH_DIR    <- here("analysis", "output", "graphs")

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[is_head_or_spouse == 1]
setorder(dt, id_panel, year_quarter)
dt[, pt_base := as.integer(potential_telework[1] == 1), by = id_panel]

star <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
fmt  <- function(x, d = 2) formatC(x, format = "f", digits = d)
fmt0 <- function(x) formatC(x, format = "d", big.mark = ",")

# Generic first-stage DiD. `sample` must already contain `tr` (0/1 treated) and
# `trxp` (tr x post). Returns the trxp row scaled to pp (or level for income).
fs <- function(sample, label, clu = ~id_dom, y = "home_office", pp = TRUE) {
  m <- feols(as.formula(sprintf("%s ~ tr + trxp | id_panel + year_quarter", y)),
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
  fs(A_main,                                              "Main (Q2 2022, id\\_dom)"),
  fs(mk("has_child_u4", "has_child_5_7", "post_mp_alt"),  "A1: alt. cutoff (Q1 2022)"),
  fs(mk("has_child_u4_no_gc", "has_child_5_7_no_gc"),     "A2: treated excl. grandchildren"),
  fs(mk("has_child_u4_no_sc", "has_child_5_7_no_sc"),     "A2: treated excl. stepchildren"),
  fs(A_main[!(year_quarter %/% 10L %in% c(2020L, 2021L))],"A3: drop 2020--2021 (COVID)"),
  fs(A_main[V2009 >= 20 & V2009 <= 35],                   "A4: ages 20--35"),
  fs(A_main[V2009 >= 20 & V2009 <= 40],                   "A4: ages 20--40"),
  fs(A_main, "A5: cluster UPA", clu = ~UPA),
  fs(A_main[panel_matched == 1],                          "A6: matched panel only"),
  fs(A_main[pt_base == 1],                                "A7: telework-eligible only")
))

# ---- A9: winsorized real income (top 1%), income outcome --------------------
A_inc <- copy(A_main)
cap <- A_inc[!is.na(rendimento_habitual_real), quantile(rendimento_habitual_real, 0.99, na.rm = TRUE)]
A_inc[rendimento_habitual_real > cap, rendimento_habitual_real := cap]
inc_raw  <- fs(A_main, "Income: raw",        y = "rendimento_habitual_real", pp = FALSE)
inc_wins <- fs(A_inc,  "Income: winsor. 1\\%", y = "rendimento_habitual_real", pp = FALSE)

# =============================================================================
# Table A1-A7 (first stage) + A9 (income)
# =============================================================================
row_tex <- function(r, d = 2) sprintf("%s & %s$^{%s}$ & (%s) & %s \\\\",
                                       r$label, fmt(r$est, d), r$star, fmt(r$se, d), fmt0(r$n))
tab <- c(
  "\\begin{table}[htbp]\\centering",
  "\\caption{Robustness of the First-Stage Home-Office Effect}",
  "\\label{tab:robustness}\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  "Specification & Treated $\\times$ Post & (SE) & Obs. \\\\",
  "\\midrule",
  "\\multicolumn{4}{l}{\\textit{Home office (pp)}} \\\\",
  unlist(lapply(seq_len(nrow(rows)), function(i) row_tex(rows[i]))),
  "\\midrule",
  "\\multicolumn{4}{l}{\\textit{Real income (R\\$), outlier sensitivity}} \\\\",
  row_tex(inc_raw, 1),
  row_tex(inc_wins, 1),
  "\\bottomrule\\end{tabular}",
  "\\begin{tablenotes}\\small",
  "\\item \\textit{Notes:} Each row is a separate DiD on the preferred sample (treated vs. Control A, child 5--7) with the treated main effect, individual and year-quarter FE, and survey weights. Clustering is at the household except row A5 (UPA). $^{*}$/$^{**}$/$^{***}$: 10/5/1\\%. Placebo on men (Table A8) requires a separate extraction and is pending.",
  "\\end{tablenotes}\\end{table}"
)
writeLines(tab, file.path(TABLE_DIR, "tab06_robustness.tex"))

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
cat("\n=== Income (R$) ===\n")
print(rbind(inc_raw, inc_wins)[, .(label = gsub("\\\\", "", label), est = round(est, 1), se = round(se, 1), star)])
message("\n=== 06_robustness.R complete ===")
