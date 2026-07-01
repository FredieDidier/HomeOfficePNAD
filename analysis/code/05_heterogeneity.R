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

DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")
GRAPH_DIR    <- here("analysis", "output", "graphs")

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[female == 1 & is_head_or_spouse == 1]
setorder(dt, id_panel, year_quarter)
dt[, clt_base    := as.integer(clt_private[1] == 1), by = id_panel]
dt[, formal_base := as.integer(formal[1] == 1),      by = id_panel]
dt[, vd4009_base := VD4009[1],                       by = id_panel]
dt[, he_base     := as.integer(higher_educ[1] == 1), by = id_panel]
dt[, age_base    := V2009[1],                        by = id_panel]
dt[, age_band := fcase(age_base <= 29, "Age 18--29", age_base <= 39, "Age 30--39", default = "Age 40--49")]

A <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]

star <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
did_row <- function(sub, label) {
  if (nrow(sub) < 1000 || sub[, uniqueN(treat_x_post)] < 2)
    return(data.table(label = label, est = NA, se = NA, star = "", n = nrow(sub)))
  m <- feols(home_office ~ treated + treat_x_post | id_panel + year_quarter,
             sub, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
  ct <- coeftable(m)["treat_x_post", ]
  data.table(label = label, est = ct[1] * 100, se = ct[2] * 100, star = star(ct[4]), n = nobs(m))
}

rows <- rbindlist(list(
  did_row(A,                              "All women"),
  did_row(A[formal_base == 1],            "Formal"),
  did_row(A[formal_base == 0],            "Informal"),
  did_row(A[clt_base == 1],               "Private, signed card (CLT)"),
  did_row(A[clt_base == 0],               "Other"),
  did_row(A[vd4009_base %in% c(1, 2)],    "Private employee"),
  did_row(A[vd4009_base %in% c(5, 6, 7)], "Public employee"),
  did_row(A[he_base == 1],                "Higher education"),
  did_row(A[he_base == 0],                "No higher education"),
  did_row(A[age_band == "Age 18--29"],    "Age 18--29"),
  did_row(A[age_band == "Age 30--39"],    "Age 30--39"),
  did_row(A[age_band == "Age 40--49"],    "Age 40--49")
))
rows[, ci_lo := est - 1.96 * se][, ci_hi := est + 1.96 * se]

# ---- Table 6 (two-line journal format: estimate; (se) below) ----------------
fmt <- function(x) formatC(x, format = "f", digits = 2)
grp <- function(title, labs) {
  s <- rows[label %in% labs][match(labs, label)]
  c(sprintf("\\multicolumn{3}{l}{\\textit{%s}} \\\\", title),
    unlist(lapply(seq_len(nrow(s)), function(i) {
      r <- s[i]
      c(sprintf("$\\quad$ %s & %s$^{%s}$ & %s \\\\", r$label, fmt(r$est), r$star,
                formatC(r$n, big.mark = ",", format = "d")),
        sprintf(" & (%s) & \\\\", fmt(r$se)))
    })))
}
tab <- c("\\begin{table}[htbp]\\centering",
  "\\caption{Heterogeneity of the First-Stage Home-Office Effect (pp)}",
  "\\label{tab:heterogeneity}\\small",
  "\\begin{tabular}{lcc}", "\\toprule",
  " & Treated $\\times$ Post & Obs. \\\\", "\\midrule",
  grp("By formality (placebo: effect only where the law binds)",
      c("Formal", "Informal", "Private, signed card (CLT)", "Other")), "\\midrule",
  grp("By sector (placebo: private only)", c("Private employee", "Public employee")), "\\midrule",
  grp("By education", c("Higher education", "No higher education")), "\\midrule",
  grp("By age band", c("Age 18--29", "Age 30--39", "Age 40--49")),
  "\\bottomrule\\end{tabular}",
  "\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Each estimate is a separate first-stage difference-in-differences regression (outcome: home office, in percentage points) on the preferred sample (treated vs.\\ Control A), including the treated main effect, individual and year-quarter fixed effects, weighted by survey weights, with standard errors clustered at the household (in parentheses). Subgroups are defined at baseline (first observed quarter). $^{*}$/$^{**}$/$^{***}$ denote significance at 10/5/1\\%.",
  "\\end{table}")
writeLines(tab, file.path(TABLE_DIR, "tab06_heterogeneity.tex"))

# ---- Figure 3 (fig07) — coefficient plot -----------------------------------
rows[, label := factor(label, levels = rev(rows$label))]
fig <- ggplot(rows[!is.na(est)], aes(x = est, y = label)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey45") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.25, colour = "#2C3E50") +
  geom_point(colour = "#2C3E50", size = 2) +
  labs(x = "First-stage home-office effect (pp), Treated x Post", y = NULL) +
  theme_bw(base_size = 13) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
        axis.text = element_text(size = 11))
ggsave(file.path(GRAPH_DIR, "fig07_heterogeneity_coefplot.pdf"), fig, width = 8, height = 6)
ggsave(file.path(GRAPH_DIR, "fig07_heterogeneity_coefplot.png"), fig, width = 8, height = 6, dpi = 300)

cat("\n=== First-stage home office by subgroup (pp) ===\n")
print(rows[, .(label, est = round(est, 2), se = round(se, 2), star, n = formatC(n, big.mark = ",", format = "d"))])
message("\n=== 05_heterogeneity.R complete ===")
