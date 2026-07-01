# =============================================================================
# 02_event_study.R
# Event study of `home_office` around MP 1108/2022 (Art. 75-F), for the two
# control groups in parallel (Figure 1, Main Results).
#
# DESIGN NOTE — treatment is time-varying eligibility.
# `treated` = `has_child_u4` is defined at the individual x quarter level (a
# woman is "treated" in the quarters where she has a child <=4 in the household).
# It is therefore NOT a fixed cohort indicator. The event study estimates, for
# each calendar quarter, the treated-vs-control gap in `home_office`, normalized
# to the gap in the last pre-MP quarter (2022Q1 = `year_quarter` 20221, the
# reference). With individual FE (`id_panel`) + quarter FE (`year_quarter`):
#
#   feols(home_office ~ i(year_quarter, treated, ref = 20221)
#                     | id_panel + year_quarter,
#         weights = ~V1028, cluster = ~id_dom)
#
# The i() interaction spans the full set of quarter-specific treated effects
# (main `treated` effect is subsumed), so no separate `treated` term is added.
# Flat pre-MP coefficients => parallel trends in the gap; a post-MP jump is the
# first-stage effect of the law. Run separately for:
#   Control A (child 5-7)  — cleaner control, similar selection into motherhood
#   Control B (no child 0-7) — broad control, higher power
#
# Output: fig06_event_study_home_office.{pdf,png}
# =============================================================================

library(data.table)
library(fixest)
library(ggplot2)
library(here)

# ---- Paths ------------------------------------------------------------------
DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
GRAPH_DIR    <- here("analysis", "output", "graphs")
dir.create(GRAPH_DIR, showWarnings = FALSE, recursive = TRUE)

REF_QUARTER <- 20221L  # 2022Q1: last quarter before the MP (main-spec pre-period)

# ---- Load & restrict to the main sample -------------------------------------
load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[is_head_or_spouse == 1]

# =============================================================================
# Event-study estimator for one control group
# =============================================================================
# `control_flag` selects the control rows; treated rows are always has_child_u4==1.
run_event_study <- function(data, control_flag, label) {
  d <- data[has_child_u4 == 1 | control_flag]
  d[, treated := as.integer(has_child_u4 == 1)]

  mod <- feols(
    home_office ~ i(year_quarter, treated, ref = REF_QUARTER) |
      id_panel + year_quarter,
    data    = d,
    weights = ~V1028,
    cluster = ~id_dom
  )

  ct <- as.data.table(coeftable(mod), keep.rownames = "term")
  setnames(ct, c("term", "estimate", "std_error", "t", "p"))
  ct <- ct[grepl("year_quarter::", term)]
  ct[, year_quarter := as.integer(sub(".*year_quarter::([0-9]+):treated", "\\1", term))]

  # Add the reference quarter (normalized to 0)
  ct <- rbind(
    ct[, .(year_quarter, estimate, std_error)],
    data.table(year_quarter = REF_QUARTER, estimate = 0, std_error = 0)
  )
  ct[, comparison := label]
  ct[, ci_lo := estimate - 1.96 * std_error]
  ct[, ci_hi := estimate + 1.96 * std_error]
  ct[, is_ref := as.integer(year_quarter == REF_QUARTER)]
  setorder(ct, year_quarter)
  ct[]
}

es_A <- run_event_study(dt, dt$has_child_5_7 == 1 & dt$has_child_u4 == 0,
                        "Treated vs. Control A (child 5-7 years)")
es_B <- run_event_study(dt, dt$has_child_u4 == 0 & dt$has_child_5_7 == 0,
                        "Treated vs. Control B (no child 0-7 years)")

es <- rbind(es_A, es_B)
es[, comparison := factor(comparison, levels = c(
  "Treated vs. Control A (child 5-7 years)",
  "Treated vs. Control B (no child 0-7 years)"
))]

# Calendar date for the x-axis (year_quarter is not evenly spaced numerically)
es[, year    := year_quarter %/% 10L]
es[, quarter := year_quarter  %% 10L]
es[, date    := as.Date(paste0(year, "-", (quarter - 1L) * 3L + 1L, "-01"))]

# =============================================================================
# Plot — classic event-study style: point estimates with capped 95% CI error
# bars (no shaded ribbon), dashed zero line, dashed MP line, and the reference
# quarter highlighted. Y-axis label carries no "ref =" text (that belongs in the
# figure caption, per journal convention).
# =============================================================================
mp_date <- as.Date("2022-04-01")  # Q2 2022 (first post-MP quarter)
NAVY <- "#2C3E50"
REFC <- "#C0392B"

fig <- ggplot(es, aes(x = date, y = estimate * 100)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey45", linewidth = 0.5) +
  geom_vline(xintercept = mp_date, linetype = "dashed", colour = "grey20", linewidth = 0.6) +
  geom_line(colour = NAVY, linewidth = 0.5) +
  geom_errorbar(aes(ymin = ci_lo * 100, ymax = ci_hi * 100),
                width = 45, colour = NAVY, linewidth = 0.5) +
  geom_point(colour = NAVY, size = 1.9) +
  # highlight the reference quarter (normalized to 0)
  geom_point(data = es[is_ref == 1], colour = REFC, fill = REFC, shape = 23, size = 2.8) +
  facet_wrap(~comparison, ncol = 1) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = function(x) paste0(x, "pp")) +
  labs(x = NULL, y = "Difference in home office (pp)") +
  theme_bw(base_size = 14) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "grey92"),
    axis.text        = element_text(size = 12),
    axis.title       = element_text(size = 13),
    strip.text       = element_text(size = 12, face = "bold"),
    strip.background = element_rect(fill = "grey94", colour = NA)
  )

ggsave(file.path(GRAPH_DIR, "fig06_event_study_home_office.pdf"), fig, width = 8, height = 7)
ggsave(file.path(GRAPH_DIR, "fig06_event_study_home_office.png"), fig, width = 8, height = 7, dpi = 300)
message("Figure 6 (event study) saved.")

message("\n=== 02_event_study.R complete ===")
message("Graphs: ", GRAPH_DIR)
