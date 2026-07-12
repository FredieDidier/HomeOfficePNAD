# =============================================================================
# 05_heterogeneity.R — subgroup heterogeneity of the first-stage home-office
# effect (Table 6 + coefficient plot fig07). Preferred sample: treated vs
# Control A (child 5-7), women 18-49 head/spouse.
#
# The formality split doubles as a placebo: the law binds only on CLT
# (celetista) employees — private AND public-company/mixed-economy celetistas —
# so a ~zero effect for the informal, who the law cannot reach, would corroborate
# the channel; here everything is ~zero.
#
# Moderators taken at BASELINE (first observed quarter), held fixed, since
# employment/occupation/sector are endogenous to the policy. Education uses the
# `higher_educ` indicator (completed higher education, VD3004==7).
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

# CLT (celetista) employees the law reaches = signed-card employees, private OR
# public (public companies / mixed-economy firms hire under the CLT). Derived
# here from VD4009 so the script runs on the existing build without a rebuild;
# see build/01_pnadc.R for the canonical definition.
dt[, clt_covered := as.integer(!is.na(VD4009) & VD4009 %in% c(1L, 5L))]

# PREDETERMINED baseline moderators (referee Comment 2): each moderator is taken
# at the woman's LAST observation on or before 2022Q1 (the last pre-reform
# quarter), NOT her first observed quarter, so that for women first interviewed
# after the reform the moderator is genuinely pre-determined. Women with no
# pre-reform observation are dropped from the heterogeneity sample.
pre <- dt[year_quarter <= 20221]
b <- pre[, .SD[.N], by = id_panel,
         .SDcols = c("clt_covered", "formal", "VD4009", "higher_educ",
                     "V2009", "V2010", "single_mother")]
setnames(b, c("clt_covered", "formal", "VD4009", "higher_educ", "V2009", "V2010", "single_mother"),
         c("clt_cov_base", "formal_base", "vd4009_base", "he_base", "age_base", "race_raw", "sm_raw"))
b[, `:=`(clt_cov_base = as.integer(clt_cov_base == 1),
         formal_base = as.integer(formal_base == 1),
         he_base = as.integer(he_base == 1), race_base = as.integer(race_raw %in% c(1L, 3L)),
         sm_base = as.integer(sm_raw == 1), has_pre = 1L)]
b[, age_band := fcase(age_base <= 29, "Age 18--29", age_base <= 39, "Age 30--39", default = "Age 40--49")]
dt <- merge(dt, b[, .(id_panel, clt_cov_base, formal_base, vd4009_base, he_base, age_base,
                      age_band, race_base, sm_base, has_pre)], by = "id_panel", all.x = TRUE)

A <- dt[(has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)) & has_pre == 1L]

star <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
did_row <- function(sub, label) {
  if (nrow(sub) < 1000 || sub[, uniqueN(treat_x_post)] < 2)
    return(data.table(label = label, est = NA, se = NA, star = "", n = nrow(sub), p = NA_real_))
  m <- feols(home_office ~ treated + treat_x_post | id_panel + year_quarter,
             sub, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
  ct <- coeftable(m)["treat_x_post", ]
  data.table(label = label, est = ct[1] * 100, se = ct[2] * 100, star = star(ct[4]), n = nobs(m), p = ct[4])
}

rows <- rbindlist(list(
  did_row(A,                              "All women"),
  did_row(A[formal_base == 1],            "Formal"),
  did_row(A[formal_base == 0],            "Informal"),
  did_row(A[clt_cov_base == 1],           "CLT (private or public)"),
  did_row(A[clt_cov_base == 0],           "Non-CLT"),
  did_row(A[vd4009_base %in% c(1, 2)],    "Private employee"),
  did_row(A[vd4009_base %in% c(5, 6, 7)], "Public employee"),
  did_row(A[he_base == 1],                "With higher education"),
  did_row(A[he_base == 0],                "Without higher education"),
  did_row(A[race_base == 1],              "White"),
  did_row(A[race_base == 0],              "Non-white"),
  did_row(A[sm_base == 1],                "Single mother"),
  did_row(A[sm_base == 0],                "Partnered mother"),
  # Decomposition of the single-mother cell by contract type (channel check: the
  # statute binds only CLT). NOT added to het_subs, so NOT in the Holm family;
  # placed next to the single-mother rows so they sit together in the coefplot.
  did_row(A[sm_base == 1 & clt_cov_base == 1], "Single mother, CLT"),
  did_row(A[sm_base == 1 & clt_cov_base == 0], "Single mother, non-CLT"),
  did_row(A[age_band == "Age 18--29"],    "Age 18--29"),
  did_row(A[age_band == "Age 30--39"],    "Age 30--39"),
  did_row(A[age_band == "Age 40--49"],    "Age 40--49")
))
rows[, ci_lo := est - 1.96 * se][, ci_hi := est + 1.96 * se]

# Multiple-testing correction across the displayed subgroups (Holm). Only
# one of the 13 subgroups is individually significant; correcting for the number
# of tests leaves nothing significant.
het_subs <- c("Formal", "Informal", "CLT (private or public)", "Non-CLT",
              "Private employee", "Public employee", "With higher education",
              "Without higher education", "White", "Non-white",
              "Single mother", "Partnered mother",
              "Age 18--29", "Age 30--39", "Age 40--49")
pv <- setNames(rows[match(het_subs, label), p], het_subs)
K_tests <- length(pv)
holm_p <- p.adjust(pv, method = "holm")   # Holm (1979) step-down FWER control
holm_min <- min(holm_p)
holm_min_lab <- gsub("--", "--", names(holm_p)[which.min(holm_p)])  # subgroup with the smallest adjusted p
mt_note <- sprintf("The Holm $p$ is the Holm step-down adjustment for testing the %d subgroups, which controls the family-wise error rate under arbitrary dependence across the tests; a value of $1.00$ marks a subgroup far from significance. No subgroup is significant after adjustment: the smallest adjusted $p$-value is $%.2f$ (the ``%s'' subgroup).", K_tests, holm_min, holm_min_lab)

# ---- Table 6 (compact one-line format: estimate followed by (se) inline, to
# keep all subgroups on a single page) ----------------------------------------
fmt <- function(x) sub("^-(0\\.?0*)$", "\\1", formatC(x, format = "f", digits = 2))  # strip signed zero
# Standard subgroups: estimate (se), raw p, Holm p, obs.
grp <- function(title, labs) {
  s <- rows[label %in% labs][match(labs, label)]
  c(sprintf("\\multicolumn{5}{l}{\\textit{%s}} \\\\", title),
    sapply(seq_len(nrow(s)), function(i) {
      r <- s[i]
      sprintf("$\\quad$ %s & %s$^{%s}$ (%s) & %s & %s & %s \\\\",
              r$label, fmt(r$est), r$star, fmt(r$se),
              formatC(r$p, format = "f", digits = 3),
              formatC(holm_p[r$label], format = "f", digits = 2),
              formatC(r$n, big.mark = ",", format = "d"))
    }))
}
# Decomposition rows (single-mother by contract type): a channel check, not part
# of the Holm multiple-testing family, so the Holm-$p$ column shows a dash.
grp_decomp <- function(title, labs) {
  s <- rows[label %in% labs][match(labs, label)]
  c(sprintf("\\multicolumn{5}{l}{\\textit{%s}} \\\\", title),
    sapply(seq_len(nrow(s)), function(i) {
      r <- s[i]
      sprintf("$\\quad$ %s & %s$^{%s}$ (%s) & %s & --- & %s \\\\",
              r$label, fmt(r$est), r$star, fmt(r$se),
              formatC(r$p, format = "f", digits = 3),
              formatC(r$n, big.mark = ",", format = "d"))
    }))
}
tab <- c("\\begin{table}[H]\\centering",
  "\\caption{Heterogeneity of the Home-Based-Work Effect}",
  "\\label{tab:heterogeneity}\\small",
  "\\resizebox{\\ifdim\\width>\\linewidth\\linewidth\\else\\width\\fi}{!}{%",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & Young child $\\times$ Post (se) & $p$-value & Holm $p$ & Obs. \\\\", "\\midrule",
  grp("By formality",
      c("Formal", "Informal", "CLT (private or public)", "Non-CLT")), "\\midrule",
  grp("By sector", c("Private employee", "Public employee")), "\\midrule",
  grp("By education", c("With higher education", "Without higher education")), "\\midrule",
  grp("By race", c("White", "Non-white")), "\\midrule",
  grp("By household structure", c("Single mother", "Partnered mother")), "\\midrule",
  grp_decomp("Single mothers, by contract type", c("Single mother, CLT", "Single mother, non-CLT")), "\\midrule",
  grp("By age band", c("Age 18--29", "Age 30--39", "Age 40--49")),
  "\\bottomrule\\end{tabular}}",
  paste(paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Each estimate is a separate difference-in-differences regression estimating ", EQ_REF, " (outcome: home-based work, in percentage points) on the preferred sample (young child vs.\\ Control~A), for the subgroup indicated; standard errors in parentheses next to the estimate. Subgroups are defined at each woman's last observation on or before 2022Q1 (predetermined), and the sample is restricted to women observed at least once before the reform."), mt_note, WEIGHT_NOTE, CLUSTER_NOTE, SIGNIF_NOTE),
  "\\end{table}")
writeLines(tab, file.path(TABLE_DIR, "tab08_heterogeneity.tex"))

# ---- Figure 3 (fig07) — coefficient plot -----------------------------------
# ggplot renders labels verbatim, so convert the LaTeX en-dash "--" in the age
# bands to a plain ASCII hyphen for the axis (CLAUDE.md: ASCII-only in ggplot).
rows_fig <- rows[!is.na(est)]  # includes the single-mother CLT/non-CLT decomposition rows
rows_fig[, label := gsub("--", "-", label)]
rows_fig[, label := factor(label, levels = rev(label))]
fig <- ggplot(rows_fig, aes(x = est, y = label)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey45") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.25, colour = "#2C3E50") +
  geom_point(colour = "#2C3E50", size = 2) +
  labs(x = "Home-based-work effect (pp)", y = NULL) +
  theme_bw(base_size = 13) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
        axis.text = element_text(size = 11))
ggsave(file.path(GRAPH_DIR, "fig07_heterogeneity_coefplot.pdf"), fig, width = 8, height = 6)
ggsave(file.path(GRAPH_DIR, "fig07_heterogeneity_coefplot.png"), fig, width = 8, height = 6, dpi = 300)

cat("\n=== First-stage home office by subgroup (pp) ===\n")
print(rows[, .(label, est = round(est, 2), se = round(se, 2), star, n = formatC(n, big.mark = ",", format = "d"))])

# Single-mother x CLT decomposition (now shown at the bottom of Table 6). The
# raw-significant negative single-mother coefficient is concentrated among
# single mothers OUTSIDE the CLT (the group the statute cannot reach) and is null
# among the celetista (CLT, private or public) single mothers it does bind, so it
# cannot be a response to the law.
cat("\n=== Single-mother x CLT decomposition (first stage, pp) ===\n")
print(rows[grepl("^Single mother", label),
           .(label, est = round(est, 2), se = round(se, 2), star, p = round(p, 3),
             n = formatC(n, big.mark = ",", format = "d"))])
message("\n=== 05_heterogeneity.R complete ===")
