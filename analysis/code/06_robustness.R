# =============================================================================
# 06_robustness.R
# Robustness of the (null) first-stage home-office effect. Every row is the
# main DiD (treated main effect + treated x post | id_panel + year_quarter,
# weighted) on the preferred sample (treated vs Control A, child 5-7), varying
# one design choice at a time. Confirms the null is not an artifact of any
# single specification choice.
#
#   - Alternative post-MP cutoff (Q1 2022)
#   - Treatment variants (exclude grandchildren / stepchildren / both)
#   - COVID window (drop 2020-2021)
#   - State x year-quarter fixed effects; two-way (household, PSU) clustering
#   - Telework-eligible-only sample (baseline)
#   - Symmetric age donut around the five-year cutoff (Lucas Emanuel's suggestion)
#   - First stage by the youngest child's age bin (Lucas Emanuel's suggestion)
#   - Log real earnings, raw and winsorized at the top 1%
#   - Control-window sweep (5-6 ... 5-12) coefplot
#
# The estimation sample is the matched panel (panel_matched == 1), the main
# sample throughout the paper; the men placebo is in 07_triple_diff.R.
# =============================================================================

# Packages (data.table, fixest, ggplot2, here) are loaded by
# config/00_master_analysis.R via pacman::p_load() before this script is
# source()'d; not repeated here.
source(here("analysis", "code", "00_utils.R"))

source(here::here("config", "config.R"))
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")
GRAPH_DIR    <- here("analysis", "output", "graphs")

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[female == 1 & is_head_or_spouse == 1 & panel_matched == 1]
setorder(dt, id_panel, year_quarter)
# Predetermined baseline telework eligibility (referee Comment 2): eligibility at
# the last observation on or before 2022Q1, not the first observed quarter.
.preb <- dt[year_quarter <= 20221][, .(pt_base = as.integer(potential_telework[.N] == 1)), by = id_panel]
dt <- merge(dt, .preb, by = "id_panel", all.x = TRUE)

star <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
fmt  <- function(x, d = 2) sub("^-(0\\.?0*)$", "\\1", formatC(x, format = "f", digits = d))  # strip signed zero
fmt0 <- function(x) formatC(x, format = "d", big.mark = ",")

# Generic first-stage DiD. `sample` must already contain `tr` (0/1 treated) and
# `trxp` (tr x post). Returns the trxp row scaled to pp (or level for earnings).
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

# A-vs-B placebo: among the two control groups (youngest child 5-7 vs no child
# 0-7), neither covered by the law, assign a fake treatment to the 5-7 group. A
# ~zero coefficient licenses treating the 5-7 group as a clean control.
Pl <- dt[(has_child_5_7 == 1 & has_child_u4 == 0) | (has_child_u4 == 0 & has_child_5_7 == 0)]
Pl[, tr := as.integer(has_child_5_7 == 1)][, trxp := tr * post_mp]

rows <- rbindlist(list(
  fs(A_main,                                              "Baseline"),
  fs(Pl,                                                  "Placebo: youngest child 5--7 vs.\\ no child 0--7"),
  fs(mk("has_child_u4", "has_child_5_7", "post_mp_alt"),  "Alternative cutoff (2022Q1 post)"),
  fs(mk("has_child_u4_no_gc", "has_child_5_7_no_gc"),     "Treated, excluding grandchildren"),
  fs(mk("has_child_u4_no_sc", "has_child_5_7_no_sc"),     "Treated, excluding stepchildren"),
  fs(mk("has_child_u4_no_gc_sc", "has_child_5_7_no_gc_sc"), "Treated, excluding grandchildren and stepchildren"),
  fs(A_main[!(year_quarter %/% 10L %in% c(2020L, 2021L))],"Excluding 2020--2021 (COVID)"),
  fs(A_main, "State $\\times$ year-quarter fixed effects", fes = "id_panel + sigla_uf^year_quarter"),
  fs(A_main, "Two-way cluster (household, PSU)", clu = ~id_dom + UPA),
  fs(A_main[pt_base == 1],                                "Telework-eligible only")
))

# ---- Earnings: log real earnings, with a winsorized version -----------------
# Earnings are observed only for workers with positive earnings; the outcome is
# the log of real monthly earnings, so the coefficient is a proportional effect.
# The winsorized version caps earnings at the 99th percentile before taking logs.
A_inc <- A_main[!is.na(earnings_habitual_real) & earnings_habitual_real > 0]
cap <- A_inc[, quantile(earnings_habitual_real, 0.99)]
A_inc[, log_earn   := log(earnings_habitual_real)]
A_inc[, log_earn_w := log(pmin(earnings_habitual_real, cap))]
inc_log  <- fs(A_inc, "Log real earnings",                       y = "log_earn",   pp = FALSE)
inc_logw <- fs(A_inc, "Log real earnings (winsorized top 1\\%)", y = "log_earn_w", pp = FALSE)

# ---- Post-reform timing: early (2022-2023) vs late (2024-2026) --------------
# The event study drifts up only in 2024-2025, so splitting Treated x Post into
# an early and a late window tests directly whether a delayed effect is hiding
# behind the pooled null. Both come from ONE regression (two interaction terms).
A_tim <- copy(A_main)
A_tim[, post_early := as.integer(year_quarter >= 20222 & year_quarter <= 20234)]
A_tim[, post_late  := as.integer(year_quarter >= 20241)]
A_tim[, trxp_early := tr * post_early][, trxp_late := tr * post_late]
m_tim <- feols(home_office ~ tr + trxp_early + trxp_late | id_panel + year_quarter,
               A_tim, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
ct_tim <- coeftable(m_tim)
timing <- rbindlist(Map(function(v, lbl)
  data.table(label = lbl, est = ct_tim[v, 1] * 100, se = ct_tim[v, 2] * 100,
             star = star(ct_tim[v, 4]), n = nobs(m_tim)),
  c("trxp_early", "trxp_late"),
  c("Early post (2022--2023)", "Late post (2024--2026)")))

# ---- Exact-birthdate treatment ceiling --------------------------------------
# Robustness to how sharply the statutory "up to 4 years of age" boundary is
# drawn. The main treatment uses completed-year age (V2009 <= 4 = exact age <5),
# which cannot resolve where a completed-age-4 child sits relative to the true
# cutoff. Here treatment is defined from the youngest child's PRECISE age in
# months (age_youngest_child_months_any, from birth month/year at the quarter
# midpoint), so the eligibility ceiling can slide across the 4-year boundary.
# Control is held fixed at Control A (youngest child 5-7 = [60, 96) months) so
# that ONLY the treated ceiling moves. A ceiling of 60 months (exact age <5)
# reproduces the completed-year main definition; ceilings below 60 impose a
# "donut" dropping children between the ceiling and age 5 from both groups, which
# directly addresses the concern that some completed-age-4 children just under 5
# could sit above the intended statutory cutoff. A 48-month ceiling is the strict
# "until the 4th birthday" reading. Coverage: ~7% of under-4 children lack a
# usable birth date and drop out of these rows (they remain in the main spec).
mk_prec <- function(C_months, post_col = "post_mp") {
  s <- dt[(!is.na(age_youngest_child_months_any) & age_youngest_child_months_any < C_months) |
          (age_youngest_child_months_any >= 60 & age_youngest_child_months_any < 96)]
  s[, tr := as.integer(age_youngest_child_months_any < C_months)]
  s[, trxp := tr * get(post_col)]
  s[]
}
prec_cuts <- data.table(
  C   = c(48L, 49L, 51L, 53L, 60L),
  lab = c("Ceiling 48 months (until 4th birthday)", "Ceiling 49 months (4y1m)",
          "Ceiling 51 months (4y3m)", "Ceiling 53 months (4y5m)",
          "Ceiling 60 months (exact age $<5$; = main)"))
prec_rows <- rbindlist(lapply(seq_len(nrow(prec_cuts)),
  function(i) fs(mk_prec(prec_cuts$C[i]), prec_cuts$lab[i])))

# ---- Symmetric age donut around the five-year cutoff ------------------------
# Threat to results: treated mothers (youngest child 0-4) differ from the 5-7
# control not only in eligibility but in life-stage -- the treated pool includes
# mothers of very young children who face the most acute care demands and are the
# most likely to be on maternity leave, so the contrast could mix the policy
# effect with an early-motherhood gap. A symmetric donut around the 60-month
# (fifth-birthday) boundary addresses this by keeping ONLY the oldest eligible
# band [60-w, 60) months as treated and the youngest ineligible band [60, 60+w)
# as control: the very-young treated children are dropped and the two groups are
# matched tightly in age around the cutoff. Precise age in months is used, so
# ~7% of children with an unusable birth date drop out (as in the ceiling sweep).
mk_donut <- function(w) {
  s <- dt[(!is.na(age_youngest_child_months_any) &
             age_youngest_child_months_any >= (60 - w) & age_youngest_child_months_any < 60) |
          (age_youngest_child_months_any >= 60 & age_youngest_child_months_any < (60 + w))]
  s[, tr := as.integer(age_youngest_child_months_any < 60)]
  s[, trxp := tr * post_mp]
  s[]
}
donut_rows <- rbindlist(lapply(c(12L, 18L, 24L), function(w)
  fs(mk_donut(w), sprintf("Donut $\\pm$%dm (treated %d--59m vs.\\ 60--%dm)", w, 60 - w, 60 + w - 1))))

# ---- First stage by the youngest child's completed-year age bin -------------
# Threat to results: the pooled null could mask an effect concentrated among the
# youngest children -- where the demand for telework is highest -- diluted by
# older eligible children close to ageing out. A single regression splits
# eligibility by the youngest child's age bin (0-1, 2-3, 4), each interacted with
# post, all relative to Control A (youngest child 5-7). A null in every bin, and
# in particular in the 0-1 bin, rules out a hidden effect at the highest-demand
# life-stage. Age bins use completed-year age (full sample, no birth-date drop).
S_strat <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]
S_strat[, bin01 := as.integer(has_child_u4 == 1 & age_youngest_child_any %in% 0:1)]
S_strat[, bin23 := as.integer(has_child_u4 == 1 & age_youngest_child_any %in% 2:3)]
S_strat[, bin4  := as.integer(has_child_u4 == 1 & age_youngest_child_any == 4L)]
S_strat[, `:=`(t01 = bin01 * post_mp, t23 = bin23 * post_mp, t4 = bin4 * post_mp)]
m_strat <- feols(home_office ~ bin01 + bin23 + bin4 + t01 + t23 + t4 | id_panel + year_quarter,
                 S_strat, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
ct_strat <- coeftable(m_strat)
strat_rows <- rbindlist(Map(function(v, lbl)
  data.table(label = lbl, est = ct_strat[v, 1] * 100, se = ct_strat[v, 2] * 100,
             star = star(ct_strat[v, 4]), n = nobs(m_strat)),
  c("t01", "t23", "t4"),
  c("Youngest child aged 0--1 $\\times$ post", "Youngest child aged 2--3 $\\times$ post",
    "Youngest child aged 4 $\\times$ post")))

# =============================================================================
# Table D.1 (first stage) + earnings. Compact one-line format (estimate followed
# by (se) inline). Emitted as a longtable so the many rows break gracefully
# across pages, repeating the column header, with the notes in the final footer.
# =============================================================================
row_tex <- function(r, d = 2)
  sprintf("%s & %s$^{%s}$ (%s) & %s \\\\", r$label, fmt(r$est, d), r$star, fmt(r$se, d), fmt0(r$n))
note_txt <- paste(paste0("\\textit{Notes:} Each estimate is a separate difference-in-differences regression estimating ", EQ_REF, " on the preferred sample (treated vs.\\ Control~A, youngest child 5--7), varying one design choice at a time; the log-earnings rows use the log of real monthly earnings among workers with positive earnings. The exact-birthdate rows redefine treatment from the youngest child's precise age in months (computed from the reported month and year of birth, anchored at the quarter midpoint since the exact interview date is unobserved), sliding the eligibility ceiling across the statutory four-year boundary while holding the comparison group fixed at Control~A; a ceiling of 60 months reproduces the main completed-year definition, and lower ceilings drop children between the ceiling and age five from both groups. The symmetric-donut rows keep only the oldest eligible band (from $60-w$ to 60 months) as treated and the youngest ineligible band (60 to $60+w$ months) as control, dropping the very-young treated children and matching the two groups' ages tightly around the five-year cutoff. The by-age rows come from a single regression that splits eligibility by the youngest child's completed-year age (0--1, 2--3, 4), each interacted with post, relative to Control~A. The two post-reform-timing rows come from a single regression that splits Treated $\\times$ Post into a 2022--2023 and a 2024--2026 window. ", WEIGHT_NOTE), "Standard errors are clustered at the household level in parentheses, except the two-way row, which clusters at the household level and at the primary sampling unit (the census enumeration area PNADC samples within each geographic stratum).", SIGNIF_NOTE)
tab <- c(
  "{\\small",
  "\\setlength{\\LTcapwidth}{\\linewidth}",
  "\\begin{longtable}{lcc}",
  "\\caption{Robustness of the Home-Based-Work Effect}\\label{tab:robustness}\\\\",
  "\\toprule",
  " & Young child $\\times$ Post (se) & Obs. \\\\",
  "\\midrule",
  "\\endfirsthead",
  "\\multicolumn{3}{c}{\\footnotesize\\itshape Table \\ref{tab:robustness} (continued)} \\\\",
  "\\toprule",
  " & Young child $\\times$ Post (se) & Obs. \\\\",
  "\\midrule",
  "\\endhead",
  "\\midrule",
  "\\multicolumn{3}{r}{\\footnotesize\\itshape Continued on next page} \\\\",
  "\\endfoot",
  "\\bottomrule",
  paste0("\\multicolumn{3}{@{}p{\\linewidth}@{}}{\\vspace{2pt}\\footnotesize\\raggedright ", note_txt, "} \\\\"),
  "\\endlastfoot",
  "\\multicolumn{3}{l}{\\textit{Home-based work (pp)}} \\\\",
  unlist(lapply(seq_len(nrow(rows)), function(i) row_tex(rows[i]))),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Home-based work, by exact-birthdate treatment ceiling (pp)}} \\\\",
  unlist(lapply(seq_len(nrow(prec_rows)), function(i) row_tex(prec_rows[i]))),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Home-based work, symmetric age donut around the five-year cutoff (pp)}} \\\\",
  unlist(lapply(seq_len(nrow(donut_rows)), function(i) row_tex(donut_rows[i]))),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Home-based work, by the youngest child's age (pp)}} \\\\",
  unlist(lapply(seq_len(nrow(strat_rows)), function(i) row_tex(strat_rows[i]))),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Home-based work, by post-reform timing (pp)}} \\\\",
  unlist(lapply(seq_len(nrow(timing)), function(i) row_tex(timing[i]))),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Log real earnings}} \\\\",
  row_tex(inc_log, 3),
  row_tex(inc_logw, 3),
  "\\end{longtable}",
  "}"
)
writeLines(tab, file.path(TABLE_DIR, "tabE1_robustness.tex"))

# =============================================================================
# Figure A5 (fig08) — control-window sweep, first stage
# =============================================================================
# K starts at 5 (control = youngest child aged 5 only, the tightest age-threshold
# match) and widens to 5-12.
win <- rbindlist(lapply(5:12, function(K) {
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
  labs(x = "Control window (youngest child age)", y = "Home-based-work effect (pp)") +
  theme_bw(base_size = 13) +
  theme(panel.grid.minor = element_blank())
ggsave(file.path(GRAPH_DIR, "fig08_control_window_sweep.pdf"), figw, width = 7.5, height = 4.5)
ggsave(file.path(GRAPH_DIR, "fig08_control_window_sweep.png"), figw, width = 7.5, height = 4.5, dpi = 300)

cat("\n=== First-stage robustness (home office, pp) ===\n")
print(rows[, .(label = gsub("\\\\", "", label), est = round(est, 2), se = round(se, 2), star, n = fmt0(n))])
cat("\n=== Exact-birthdate treatment ceiling (home office, pp) ===\n")
print(prec_rows[, .(label = gsub("\\$|\\\\", "", label), est = round(est, 2), se = round(se, 2), star, n = fmt0(n))])
cat("\n=== Symmetric age donut around the 5-year cutoff (home office, pp) ===\n")
print(donut_rows[, .(label = gsub("\\$|\\\\pm|\\\\", "", label), est = round(est, 2), se = round(se, 2), star, n = fmt0(n))])
cat("\n=== First stage by youngest child's age bin (home office, pp) ===\n")
print(strat_rows[, .(label = gsub("\\$|\\\\times|\\\\", "", label), est = round(est, 2), se = round(se, 2), star,
                     ci_lo = round(est - 1.96 * se, 2), ci_hi = round(est + 1.96 * se, 2))])
cat("\n=== Post-reform timing (home office, pp; 95% CI) ===\n")
print(timing[, .(label = gsub("--", "-", label), est = round(est, 2), se = round(se, 2), star,
                 ci_lo = round(est - 1.96 * se, 2), ci_hi = round(est + 1.96 * se, 2))])
cat("\n=== Log real earnings ===\n")
print(rbind(inc_log, inc_logw)[, .(label = gsub("\\\\", "", label), est = round(est, 3), se = round(se, 3), star)])
message("\n=== 06_robustness.R complete ===")
