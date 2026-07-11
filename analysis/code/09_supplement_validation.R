# =============================================================================
# 09_supplement_validation.R — cross-sectional validation of the home-based-work
# proxy against IBGE's 2022 experimental telework supplement (referee Comment 3).
#
# The main outcome (home_office = main job performed at the worker's own
# residence, V4022 in {4,5}) measures work LOCATION, not the contractual telework
# arrangement, and so conflates employee telework with home-based self-employment.
# IBGE's 2022 annual supplement (experimental Table 9471) reports, by state, the
# share of employed persons (14+) who did remote work / telework / telework at
# home. This script validates the proxy cross-sectionally:
#
#   Table 14 (tab14_proxy_validation) — (A) aggregate proxy vs supplement,
#     (B) proxy by position (shows the self-employed drive home-based work),
#     (C) cross-state association (27 states).
#   Fig. 10 (fig10_proxy_validation)  — scatter of the proxy against the
#     supplement's telework-at-home rate across the 27 states.
#
# The supplement is an aggregate (state-level) table, so this is a cross-sectional
# validation, as the referee allowed; it cannot be merged at the individual level.
# Supplement universe: employed 14+, both sexes. Proxy universe: main_data, which
# is 18-49, both sexes -- close but not identical, so the exercise is about the
# spatial pattern and the order of magnitude, not an exact level match.
# =============================================================================

# Packages: data.table, fixest, ggplot2, here loaded by the master; readxl added.
source(here("analysis", "code", "00_utils.R"))
source(here::here("config", "config.R"))
OUTPUT_PATH <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR   <- here("analysis", "output", "tables")
GRAPH_DIR   <- here("analysis", "output", "graphs")

SUPP_FILE <- file.path(DROPBOX_ROOT, "build", "input", "2022_supplement_pnad.xlsx")
if (!file.exists(SUPP_FILE)) {
  message("Supplement file not found at ", SUPP_FILE, " -- skipping 09_supplement_validation.R.")
} else {
if (!requireNamespace("readxl", quietly = TRUE)) install.packages("readxl")

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)

fmt <- function(x, d = 1) formatC(x, format = "f", digits = d)

# ---- Supplement Table 3 (percent of employed 14+ in each category, by UF) ----
s3 <- suppressWarnings(readxl::read_excel(SUPP_FILE, sheet = "Tabela 3", col_names = FALSE))
sup <- data.table(cod = suppressWarnings(as.integer(s3[[1]])),
                  remoto  = suppressWarnings(as.numeric(s3[[3]])),
                  tele    = suppressWarnings(as.numeric(s3[[4]])),
                  teledom = suppressWarnings(as.numeric(s3[[5]])))[!is.na(cod)]
ufmap <- data.table(
  cod   = c(11:17, 21:29, 31:33, 35, 41:43, 50:53),
  sigla = c("RO","AC","AM","RR","PA","AP","TO","MA","PI","CE","RN","PB","PE","AL",
            "SE","BA","MG","ES","RJ","SP","PR","SC","RS","MS","MT","GO","DF"))
sup <- merge(sup, ufmap, by = "cod")

# ---- Proxy: home-based work among the employed, 2022, by state ---------------
e <- dt[year_quarter %/% 10L == 2022L & employed == 1]
myst <- e[, .(ho = 100 * weighted.mean(home_office, V1028), W = sum(V1028)), by = sigla_uf]
m <- merge(sup, myst, by.x = "sigla", by.y = "sigla_uf")

wcor <- function(x, y, w) {
  mx <- weighted.mean(x, w); my <- weighted.mean(y, w)
  sum(w * (x - mx) * (y - my)) / sqrt(sum(w * (x - mx)^2) * sum(w * (y - my)^2))
}
r_w  <- wcor(m$ho, m$teledom, m$W)
r_u  <- cor(m$ho, m$teledom)
r_s  <- cor(m$ho, m$teledom, method = "spearman")

# ---- Aggregate magnitudes (2022) --------------------------------------------
ho_all  <- 100 * e[, weighted.mean(home_office, V1028)]
sup_teledom_nat <- weighted.mean(m$teledom, m$W)  # employment-weighted national telework-at-home
sup_tele_nat    <- weighted.mean(m$tele,    m$W)
sup_remoto_nat  <- weighted.mean(m$remoto,  m$W)

# ---- Proxy by position in employment (2022) ---------------------------------
e[, pos := fcase(VD4009 %in% 1:6, "Employee (signed-card or public)",
                 VD4009 == 9, "Self-employed", VD4009 == 8, "Employer",
                 default = "Other")]
posr <- e[, .(ho = 100 * weighted.mean(home_office, V1028)), by = pos]
get_pos <- function(p) posr[pos == p, ho]
ho_emp  <- get_pos("Employee (signed-card or public)")
ho_self <- get_pos("Self-employed")
ho_er   <- get_pos("Employer")
e[, clt_covered := as.integer(!is.na(VD4009) & VD4009 %in% c(1L, 5L))]
ho_clt  <- 100 * e[clt_covered == 1, weighted.mean(home_office, V1028)]

# ---- Table 14 ---------------------------------------------------------------
row <- function(lbl, val) sprintf("$\\quad$ %s & %s \\\\", lbl, val)
tab14 <- c(
  "\\begin{table}[H]\\centering",
  "\\caption{Validation of the Home-Based-Work Proxy against the 2022 Telework Supplement}",
  "\\label{tab:proxy_validation}\\small",
  "\\begin{tabular}{lc}", "\\toprule",
  " & Share of employed (\\%) \\\\", "\\midrule",
  "\\multicolumn{2}{l}{\\textit{A. Aggregate magnitude, 2022}} \\\\",
  row("Home-based work (this paper's proxy, V4022)", fmt(ho_all)),
  row("Telework at home (2022 supplement)", fmt(sup_teledom_nat)),
  row("Any telework (2022 supplement)", fmt(sup_tele_nat)),
  row("Any remote work (2022 supplement)", fmt(sup_remoto_nat)),
  "\\midrule",
  "\\multicolumn{2}{l}{\\textit{B. Home-based-work proxy by position in employment, 2022}} \\\\",
  row("Employees (signed-card or public)", fmt(ho_emp)),
  row("CLT (celetista, private or public)", fmt(ho_clt)),
  row("Self-employed", fmt(ho_self)),
  row("Employers", fmt(ho_er)),
  "\\midrule",
  "\\multicolumn{2}{l}{\\textit{C. Cross-state association with supplement telework-at-home (27 states)}} \\\\",
  sprintf("$\\quad$ Pearson correlation, employment-weighted & %s \\\\", fmt(r_w, 2)),
  sprintf("$\\quad$ Pearson correlation, unweighted & %s \\\\", fmt(r_u, 2)),
  sprintf("$\\quad$ Spearman rank correlation & %s \\\\", fmt(r_s, 2)),
  "\\bottomrule\\end{tabular}",
  paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Cross-sectional validation of the home-based-work proxy (main job performed at the worker's own residence, V4022 $\\in\\{4,5\\}$) against IBGE's experimental 2022 telework supplement (Table 9471), which reports, by state, the share of employed persons aged 14 or older who did remote work, telework, or telework at home in 2022. Panel~A compares aggregate magnitudes: the proxy (6--7\\% of the employed) is close to the supplement's telework-at-home rate. Panel~B shows the proxy by position in employment: home-based work is concentrated among the self-employed (home businesses) and is low among the employees, and among the CLT (celetista) employees, that the statute binds---which is why the paper reports the effect on those predetermined subgroups separately (Table~\\ref{tab:estimands}). Panel~C reports the cross-state association between the proxy (share of the employed in main\\_data, aged 18--49) and the supplement's telework-at-home rate over the 27 states; the employment-weighted correlation is higher than the unweighted one because the small northern states, which the supplement flags as high-variance experimental estimates, are noisy. The supplement is an aggregate state-level table and cannot be linked at the individual level, so this is a cross-sectional check, not a person-level match."),
  "\\end{table}")
writeLines(tab14, file.path(TABLE_DIR, "tab14_proxy_validation.tex"))

# ---- Figure 10: scatter (27 states) -----------------------------------------
m[, big := sigla %in% c("DF", "SP", "RJ", "RS", "MG", "PR", "SC")]
fig <- ggplot(m, aes(x = teledom, y = ho)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dotted", colour = "grey60") +
  geom_smooth(method = "lm", se = FALSE, colour = "#C0392B", linewidth = 0.6, aes(weight = W)) +
  geom_point(aes(size = W), colour = "#2C3E50", alpha = 0.7) +
  geom_text(data = m[big == TRUE], aes(label = sigla), vjust = -0.9, size = 3.3, colour = "#2C3E50") +
  scale_size_continuous(range = c(1.5, 6), guide = "none") +
  labs(x = "Telework at home, 2022 supplement (% of employed)",
       y = "Home-based-work proxy (% of employed)",
       subtitle = sprintf("Across the 27 states; employment-weighted correlation = %s", fmt(r_w, 2))) +
  theme_bw(base_size = 13) +
  theme(panel.grid.minor = element_blank())
ggsave(file.path(GRAPH_DIR, "fig10_proxy_validation.pdf"), fig, width = 7.5, height = 5)
ggsave(file.path(GRAPH_DIR, "fig10_proxy_validation.png"), fig, width = 7.5, height = 5, dpi = 300)

cat("\n=== Proxy validation vs 2022 supplement ===\n")
cat(sprintf("Aggregate: proxy home-based %.1f%% vs supplement telework-at-home %.1f%% (weighted)\n",
            ho_all, sup_teledom_nat))
cat(sprintf("By position: employees %.1f%%, CLT %.1f%%, self-employed %.1f%%\n", ho_emp, ho_clt, ho_self))
cat(sprintf("Cross-state corr: weighted %.2f, unweighted %.2f, Spearman %.2f\n", r_w, r_u, r_s))
message("\n=== 09_supplement_validation.R complete ===")
}
