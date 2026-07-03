# =============================================================================
# 02_event_study.R
# Event studies around MP 1108/2022 (Art. 75-F), treated vs. Control A and B.
#
# Treatment (has_child_u4) is time-varying eligibility, so the event study
# estimates the treated-vs-control gap by quarter, normalized to 2022Q1 (the
# last pre-MP quarter), via i(year_quarter, treated, ref=20221) with individual
# and quarter FE. The full interaction set subsumes the treated main effect.
#
#   fig06 — home office (first stage)
#   fig09 — maternity leave (on_maternity_leave), built because the pooled DiD
#           on this outcome is significant; the event study shows whether that
#           is a clean post-break or a pre-trend/mechanical pattern.
#
# Sample: WOMEN 18-49, head/spouse (main_data holds both sexes).
# =============================================================================

library(data.table)
library(fixest)
library(ggplot2)
library(here)

source(here::here("config", "config.R"))
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
GRAPH_DIR    <- here("analysis", "output", "graphs")
dir.create(GRAPH_DIR, showWarnings = FALSE, recursive = TRUE)

REF_QUARTER <- 20221L
mp_date <- as.Date("2022-04-01")
NAVY <- "#2C3E50"; REFC <- "#C0392B"

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[female == 1 & is_head_or_spouse == 1 & panel_matched == 1]

# Event-study coefficients (in pp) for outcome `yvar`, one control group.
run_es <- function(data, control_flag, label, yvar) {
  d <- data[has_child_u4 == 1 | control_flag]
  d[, treated := as.integer(has_child_u4 == 1)]
  m <- feols(as.formula(sprintf("%s ~ i(year_quarter, treated, ref = %d) | id_panel + year_quarter",
                                yvar, REF_QUARTER)),
             data = d, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
  ct <- as.data.table(coeftable(m), keep.rownames = "term")
  setnames(ct, c("term", "estimate", "se", "t", "p"))
  ct <- ct[grepl("year_quarter::", term)]
  ct[, year_quarter := as.integer(sub(".*year_quarter::([0-9]+):treated", "\\1", term))]
  ct <- rbind(ct[, .(year_quarter, estimate, se)],
              data.table(year_quarter = REF_QUARTER, estimate = 0, se = 0))
  ct[, `:=`(comparison = label, ci_lo = estimate - 1.96 * se, ci_hi = estimate + 1.96 * se,
            is_ref = as.integer(year_quarter == REF_QUARTER))]
  setorder(ct, year_quarter)
  ct[]
}

build_es <- function(yvar) {
  es <- rbind(
    run_es(dt, dt$has_child_5_7 == 1 & dt$has_child_u4 == 0,
           "Treated vs. Control A (child 5-7 years)", yvar),
    run_es(dt, dt$has_child_u4 == 0 & dt$has_child_5_7 == 0,
           "Treated vs. Control B (no child 0-7 years)", yvar))
  es[, comparison := factor(comparison, levels = c(
    "Treated vs. Control A (child 5-7 years)", "Treated vs. Control B (no child 0-7 years)"))]
  es[, `:=`(year = year_quarter %/% 10L, quarter = year_quarter %% 10L)]
  es[, date := as.Date(paste0(year, "-", (quarter - 1L) * 3L + 1L, "-01"))]
  es[]
}

plot_es <- function(es, ylab) {
  ggplot(es, aes(x = date, y = estimate * 100)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "grey45", linewidth = 0.5) +
    geom_vline(xintercept = mp_date, linetype = "dashed", colour = "grey20", linewidth = 0.6) +
    geom_line(colour = NAVY, linewidth = 0.5) +
    geom_errorbar(aes(ymin = ci_lo * 100, ymax = ci_hi * 100), width = 45, colour = NAVY, linewidth = 0.5) +
    geom_point(colour = NAVY, size = 1.9) +
    geom_point(data = es[is_ref == 1], colour = REFC, fill = REFC, shape = 23, size = 2.8) +
    facet_wrap(~comparison, ncol = 1) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    scale_y_continuous(labels = function(x) paste0(x, "pp")) +
    labs(x = NULL, y = ylab) +
    theme_bw(base_size = 14) +
    theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
          axis.text = element_text(size = 12), axis.title = element_text(size = 13),
          strip.text = element_text(size = 12, face = "bold"),
          strip.background = element_rect(fill = "grey94", colour = NA))
}

# ---- fig06: home office -----------------------------------------------------
fig6 <- plot_es(build_es("home_office"), "Difference in home office (pp)")
ggsave(file.path(GRAPH_DIR, "fig06_event_study_home_office.pdf"), fig6, width = 8, height = 7)
ggsave(file.path(GRAPH_DIR, "fig06_event_study_home_office.png"), fig6, width = 8, height = 7, dpi = 300)
message("Figure 6 (home office event study) saved.")

# ---- fig09: maternity leave -------------------------------------------------
fig9 <- plot_es(build_es("on_maternity_leave"), "Difference in maternity leave (pp)")
ggsave(file.path(GRAPH_DIR, "fig09_event_study_maternity.pdf"), fig9, width = 8, height = 7)
ggsave(file.path(GRAPH_DIR, "fig09_event_study_maternity.png"), fig9, width = 8, height = 7, dpi = 300)
message("Figure 9 (maternity-leave event study) saved.")

# ---- Pre-trend joint test ---------------------------------------------------
# Joint Wald test that all pre-reform leads are zero (H0: parallel pre-trends),
# for home office, using the clustered vcov. Pre-period terms are the treated x
# quarter interactions for 2018Q1-2021Q4 (2022Q1 is the omitted reference).
pretrend_test <- function(control_flag, label, yvar = "home_office") {
  d <- dt[has_child_u4 == 1 | control_flag]
  d[, treated := as.integer(has_child_u4 == 1)]
  m <- feols(as.formula(sprintf("%s ~ i(year_quarter, treated, ref = %d) | id_panel + year_quarter",
                                yvar, REF_QUARTER)),
             data = d, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
  b <- coef(m); V <- vcov(m)
  pre <- grep("year_quarter::20(18|19|20|21)[1-4]:treated", names(b), value = TRUE)
  bb <- b[pre]; VV <- V[pre, pre]
  chi2 <- as.numeric(t(bb) %*% solve(VV) %*% bb)
  k <- length(pre); p <- pchisq(chi2, df = k, lower.tail = FALSE)
  cat(sprintf("Pre-trend joint test [%s, %s]: chi2(%d) = %.2f, p = %.3f\n",
              label, yvar, k, chi2, p))
  invisible(list(chi2 = chi2, df = k, p = p))
}
cat("\n=== Pre-trend joint tests (H0: all pre-reform leads = 0) ===\n")
pretrend_test(dt$has_child_5_7 == 1 & dt$has_child_u4 == 0, "Control A", "home_office")
pretrend_test(dt$has_child_u4 == 0 & dt$has_child_5_7 == 0, "Control B", "home_office")
# Downstream outcomes with significant pooled DiD coefficients: home office is
# the ONLY one with flat pre-trends; employment, participation, and maternity
# leave all reject parallel pre-trends, so their post coefficients are not causal.
pretrend_test(dt$has_child_5_7 == 1 & dt$has_child_u4 == 0, "Control A", "employed")
pretrend_test(dt$has_child_5_7 == 1 & dt$has_child_u4 == 0, "Control A", "in_labor_force")
pretrend_test(dt$has_child_5_7 == 1 & dt$has_child_u4 == 0, "Control A", "on_maternity_leave")

message("\n=== 02_event_study.R complete ===")
