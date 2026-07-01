# =============================================================================
# 05_heterogeneity.R
# Subgroup heterogeneity of the first-stage home-office effect (Tables 5-8 +
# Figure 3 coefficient plot). Preferred sample: treated vs Control A (child 5-7).
#
# Two of the splits double as channel-validation / placebos: the law legally
# binds only on CLT (formal, private-sector) employees, so a near-zero effect
# for informal and for public-sector workers corroborates that any estimate
# reflects Art. 75-F rather than a generic young-children shock.
#
# Moderators are taken at BASELINE (each woman's first observed quarter) and
# held fixed, so the split is on a pre-determined characteristic rather than a
# post-treatment outcome (employment, occupation, and sector are all endogenous
# to the policy). Spec: home_office ~ treated + treat_x_post | id_panel +
# year_quarter, weighted, clustered at id_dom.
# =============================================================================

library(data.table)
library(fixest)
library(ggplot2)
library(here)

DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")
GRAPH_DIR    <- here("analysis", "output", "graphs")
dir.create(TABLE_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(GRAPH_DIR, showWarnings = FALSE, recursive = TRUE)

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[is_head_or_spouse == 1]

# ---- Baseline (first-observed) moderators, time-invariant per individual -----
setorder(dt, id_panel, year_quarter)
dt[, clt_base    := as.integer(clt_private[1] == 1), by = id_panel]
dt[, formal_base := as.integer(formal[1] == 1),      by = id_panel]
dt[, vd4009_base := VD4009[1],                       by = id_panel]
dt[, educ_base   := faixa_educ[1],                   by = id_panel]
dt[, age_base    := V2009[1],                        by = id_panel]
dt[, age_band := fcase(age_base <= 29, "18-29",
                       age_base <= 39, "30-39",
                       default        = "40-49")]

A <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]

star <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
fmt  <- function(x, d = 2) formatC(x, format = "f", digits = d)
fmt0 <- function(x) formatC(x, format = "d", big.mark = ",")

# First-stage DiD on a subsample -> one summary row.
did_row <- function(sub, label) {
  if (nrow(sub) < 1000 || sub[, uniqueN(treat_x_post)] < 2)
    return(data.table(label = label, est = NA, se = NA, star = "", n = nrow(sub)))
  m <- feols(home_office ~ treated + treat_x_post | id_panel + year_quarter,
             data = sub, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
  ct <- coeftable(m)["treat_x_post", ]
  data.table(label = label, est = ct[1] * 100, se = ct[2] * 100, star = star(ct[4]), n = nobs(m))
}

# ---- Build all subgroup rows ------------------------------------------------
rows <- rbindlist(list(
  did_row(A,                               "All (preferred)"),
  did_row(A[formal_base == 1],             "Formal (baseline)"),
  did_row(A[formal_base == 0],             "Informal (baseline)"),
  did_row(A[clt_base == 1],                "CLT private (VD4009=1)"),
  did_row(A[clt_base == 0],                "Not CLT private"),
  did_row(A[vd4009_base %in% c(1, 2)],     "Private employee"),
  did_row(A[vd4009_base %in% c(5, 6, 7)],  "Public employee"),
  did_row(A[educ_base == "15 ou mais anos de estudo"], "Higher education (15+ yrs)"),
  did_row(A[educ_base != "15 ou mais anos de estudo" & !is.na(educ_base)], "Below higher education"),
  did_row(A[age_band == "18-29"],          "Age 18-29"),
  did_row(A[age_band == "30-39"],          "Age 30-39"),
  did_row(A[age_band == "40-49"],          "Age 40-49")
))
rows[, ci_lo := est - 1.96 * se][, ci_hi := est + 1.96 * se]

# =============================================================================
# Table 5-8 (single table, grouped panels)
# =============================================================================
grp <- function(title, labels) {
  sub <- rows[label %in% labels][match(labels, label)]
  c(sprintf("\\multicolumn{4}{l}{\\textit{%s}} \\\\", title),
    apply(sub, 1, function(r) sprintf("$\\quad$ %s & %s$^{%s}$ & (%s) & %s \\\\",
          r[["label"]], fmt(as.numeric(r[["est"]])), r[["star"]],
          fmt(as.numeric(r[["se"]])), fmt0(as.integer(r[["n"]])))))
}
tab <- c(
  "\\begin{table}[htbp]\\centering",
  "\\caption{Heterogeneity of the First-Stage Home-Office Effect}",
  "\\label{tab:heterogeneity}\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  "Subgroup & Treated $\\times$ Post & (SE) & Obs. \\\\",
  "\\midrule",
  grp("Panel A --- Formality (placebo: effect only where the law binds)",
      c("Formal (baseline)", "Informal (baseline)", "CLT private (VD4009=1)", "Not CLT private")),
  "\\midrule",
  grp("Panel B --- Sector (placebo: private only)", c("Private employee", "Public employee")),
  "\\midrule",
  grp("Panel C --- Education", c("Higher education (15+ yrs)", "Below higher education")),
  "\\midrule",
  grp("Panel D --- Age band", c("Age 18-29", "Age 30-39", "Age 40-49")),
  "\\bottomrule\\end{tabular}",
  "\\begin{tablenotes}\\small",
  "\\item \\textit{Notes:} Each row is a separate first-stage DiD (outcome: home office, pp) on the preferred sample (treated vs. Control A, child 5--7). Subgroups defined at baseline (first observed quarter), held fixed. All include the treated main effect, individual and year-quarter FE, survey weights, and cluster SEs at the household. $^{*}$/$^{**}$/$^{***}$: 10/5/1\\%.",
  "\\end{tablenotes}\\end{table}"
)
writeLines(tab, file.path(TABLE_DIR, "tab05_heterogeneity.tex"))

# =============================================================================
# Figure 3 (fig07) — coefficient plot
# =============================================================================
rows[, label := factor(label, levels = rev(rows$label))]
fig <- ggplot(rows[!is.na(est)], aes(x = est, y = label)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey45") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.25, colour = "#2C3E50") +
  geom_point(colour = "#2C3E50", size = 2) +
  labs(x = "First-stage home-office effect (pp), Treated x Post", y = NULL) +
  theme_bw(base_size = 13) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        axis.text = element_text(size = 11))
ggsave(file.path(GRAPH_DIR, "fig07_heterogeneity_coefplot.pdf"), fig, width = 8, height = 6)
ggsave(file.path(GRAPH_DIR, "fig07_heterogeneity_coefplot.png"), fig, width = 8, height = 6, dpi = 300)

cat("\n=== First-stage home office by subgroup (pp) ===\n")
print(rows[, .(label, est = round(est, 2), se = round(se, 2), star, n = fmt0(n))])
message("\n=== 05_heterogeneity.R complete ===")
