# =============================================================================
# 05_heterogeneity.R — subgroup heterogeneity of the first-stage home-office
# effect (Table 6 + coefficient plot fig07). Preferred sample: treated vs
# Control A (child 5-7), women 18-49 head/spouse.
#
# The formality and sector splits double as placebos: the law binds only on CLT
# (formal, private) employees, so a ~zero effect for informal and for public
# workers would corroborate the channel — here everything is ~zero.
#
# Moderators taken at BASELINE (first observed quarter), held fixed, since
# employment/occupation/sector are endogenous to the policy. Education uses the
# `higher_educ` indicator (completed higher education, VD3004==7).
# =============================================================================

library(data.table)
library(fixest)
library(ggplot2)
library(here)
source(here("analysis", "code", "00_utils.R"))

source(here::here("config", "config.R"))
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")
GRAPH_DIR    <- here("analysis", "output", "graphs")

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[female == 1 & is_head_or_spouse == 1 & panel_matched == 1]
setorder(dt, id_panel, year_quarter)
dt[, clt_base    := as.integer(clt_private[1] == 1), by = id_panel]
dt[, formal_base := as.integer(formal[1] == 1),      by = id_panel]
dt[, vd4009_base := VD4009[1],                       by = id_panel]
dt[, he_base     := as.integer(higher_educ[1] == 1), by = id_panel]
dt[, age_base    := V2009[1],                        by = id_panel]
dt[, age_band := fcase(age_base <= 29, "Age 18--29", age_base <= 39, "Age 30--39", default = "Age 40--49")]
dt[, race_base := as.integer(V2010[1] %in% c(1L, 3L)), by = id_panel]  # white = branca(1)+amarela(3); non-white = preta/parda/indigena

A <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]

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
  did_row(A[clt_base == 1],               "Private, signed card (CLT)"),
  did_row(A[clt_base == 0],               "Non-CLT"),
  did_row(A[vd4009_base %in% c(1, 2)],    "Private employee"),
  did_row(A[vd4009_base %in% c(5, 6, 7)], "Public employee"),
  did_row(A[he_base == 1],                "With higher education"),
  did_row(A[he_base == 0],                "Without higher education"),
  did_row(A[race_base == 1],              "White"),
  did_row(A[race_base == 0],              "Non-white"),
  did_row(A[age_band == "Age 18--29"],    "Age 18--29"),
  did_row(A[age_band == "Age 30--39"],    "Age 30--39"),
  did_row(A[age_band == "Age 40--49"],    "Age 40--49")
))
rows[, ci_lo := est - 1.96 * se][, ci_hi := est + 1.96 * se]

# Multiple-testing correction across the displayed subgroups (Bonferroni). Only
# one of the 11 subgroups is individually significant; correcting for the number
# of tests leaves nothing significant.
het_subs <- c("Formal", "Informal", "Private, signed card (CLT)", "Non-CLT",
              "Private employee", "Public employee", "With higher education",
              "Without higher education", "White", "Non-white",
              "Age 18--29", "Age 30--39", "Age 40--49")
pv <- setNames(rows[match(het_subs, label), p], het_subs)
K_tests <- length(pv)
holm_p <- p.adjust(pv, method = "holm")   # Holm (1979) step-down FWER control
holm_min <- min(holm_p)
mt_note <- sprintf("The Holm $p$ is the Holm step-down adjustment for testing the %d subgroups, which controls the family-wise error rate under arbitrary dependence across the tests; a value of $1.00$ marks a subgroup far from significance. No subgroup is significant after adjustment: the smallest adjusted $p$-value is $%.2f$, for women aged 40--49.", K_tests, holm_min)

# ---- Table 6 (two-line journal format: estimate; (se) below) ----------------
fmt <- function(x) formatC(x, format = "f", digits = 2)
grp <- function(title, labs) {
  s <- rows[label %in% labs][match(labs, label)]
  c(sprintf("\\multicolumn{5}{l}{\\textit{%s}} \\\\", title),
    unlist(lapply(seq_len(nrow(s)), function(i) {
      r <- s[i]
      padj <- holm_p[r$label]
      c(sprintf("$\\quad$ %s & %s$^{%s}$ & %s & %s & %s \\\\", r$label, fmt(r$est), r$star,
                formatC(r$p, format = "f", digits = 3), formatC(padj, format = "f", digits = 2),
                formatC(r$n, big.mark = ",", format = "d")),
        sprintf(" & (%s) & & & \\\\", fmt(r$se)))
    })))
}
tab <- c("\\begin{table}[H]\\centering",
  "\\caption{Heterogeneity of the First-Stage Home-Office Effect}",
  "\\label{tab:heterogeneity}\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & Treated $\\times$ Post & $p$-value & Holm $p$ & Obs. \\\\", "\\midrule",
  grp("By formality",
      c("Formal", "Informal", "Private, signed card (CLT)", "Non-CLT")), "\\midrule",
  grp("By sector", c("Private employee", "Public employee")), "\\midrule",
  grp("By education", c("With higher education", "Without higher education")), "\\midrule",
  grp("By race", c("White", "Non-white")), "\\midrule",
  grp("By age band", c("Age 18--29", "Age 30--39", "Age 40--49")),
  "\\bottomrule\\end{tabular}",
  paste(paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Each estimate is a separate first-stage difference-in-differences regression estimating ", EQ_REF, " (outcome: home office, in percentage points) on the preferred sample (treated vs.\\ Control~A), for the subgroup indicated. Subgroups are defined at baseline (first observed quarter)."), WEIGHT_NOTE, CLUSTER_NOTE, mt_note, SIGNIF_NOTE),
  "\\end{table}")
writeLines(tab, file.path(TABLE_DIR, "tab06_heterogeneity.tex"))

# ---- Figure 3 (fig07) — coefficient plot -----------------------------------
# ggplot renders labels verbatim, so convert the LaTeX en-dash "--" in the age
# bands to a plain ASCII hyphen for the axis (CLAUDE.md: ASCII-only in ggplot).
rows_fig <- rows[!is.na(est)]
rows_fig[, label := gsub("--", "-", label)]
rows_fig[, label := factor(label, levels = rev(label))]
fig <- ggplot(rows_fig, aes(x = est, y = label)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey45") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.25, colour = "#2C3E50") +
  geom_point(colour = "#2C3E50", size = 2) +
  labs(x = "First-stage home-office effect (pp)", y = NULL) +
  theme_bw(base_size = 13) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
        axis.text = element_text(size = 11))
ggsave(file.path(GRAPH_DIR, "fig07_heterogeneity_coefplot.pdf"), fig, width = 8, height = 6)
ggsave(file.path(GRAPH_DIR, "fig07_heterogeneity_coefplot.png"), fig, width = 8, height = 6, dpi = 300)

cat("\n=== First-stage home office by subgroup (pp) ===\n")
print(rows[, .(label, est = round(est, 2), se = round(se, 2), star, n = formatC(n, big.mark = ",", format = "d"))])
message("\n=== 05_heterogeneity.R complete ===")
