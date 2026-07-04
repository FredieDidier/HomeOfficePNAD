# =============================================================================
# 01_descriptives.R
# Summary statistics and pre-treatment trends for the HomeOfficePNAD project.
#
# Produces:
#   1. Table 1  — Sample means by treatment group (treated / control A / control B)
#   2. Table A.1 — Panel retention diagnostics (households/individuals across quarters)
#   3. Figure 1 — Home office rate by quarter and group (2018Q1-2026Q1)
#   4. Figure 2 — Home office rate: treated vs. each control group (separate panels)
#   5. Figure 3 — Share in labor force and employment rate by group over time
#   6. Figure 4 — Home office rate among women in telework-eligible occupations
#   7. Figure 5 (appendix, optional) — geographic map of home office, treated women
#
# Groups:
#   Treated   : is_head_or_spouse == 1 & has_child_u4 == 1
#   Control A : is_head_or_spouse == 1 & has_child_5_7 == 1 & has_child_u4 == 0
#   Control B : is_head_or_spouse == 1 & has_child_u4 == 0 & has_child_5_7 == 0
#
# All figures use survey weights (V1028).
# =============================================================================

# Packages (data.table, ggplot2, here) are loaded by config/00_master_analysis.R
# via pacman::p_load() before this script is source()'d; not repeated here.

# ---- Paths ------------------------------------------------------------------
source(here::here("config", "config.R"))
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")

TABLE_DIR <- here("analysis", "output", "tables")
GRAPH_DIR <- here("analysis", "output", "graphs")
MAP_DIR   <- here("analysis", "output", "maps")
dir.create(TABLE_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(GRAPH_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(MAP_DIR,   showWarnings = FALSE, recursive = TRUE)

# ---- Load data --------------------------------------------------------------
load(file.path(OUTPUT_PATH, "main_data.RData"))

# ---- Group assignment -------------------------------------------------------
# Keep only head/spouse women (main_data now holds both sexes; filter female==1)
dt_hs <- dt[female == 1 & is_head_or_spouse == 1 & panel_matched == 1]

dt_hs[, group := fcase(
  has_child_u4 == 1,                              "Treated (child <= 4 years)",
  has_child_5_7 == 1 & has_child_u4 == 0,        "Control A (child 5-7 years)",
  has_child_u4 == 0  & has_child_5_7 == 0,       "Control B (no child 0-7 years)",
  default = NA_character_
)]

dt_hs <- dt_hs[!is.na(group)]

# Ordered factor for plots
dt_hs[, group := factor(group, levels = c(
  "Treated (child <= 4 years)", "Control A (child 5-7 years)", "Control B (no child 0-7 years)"
))]

# Post-MP indicator (main cutoff: Q2 2022)
dt_hs[, post := fifelse(year_quarter >= 20222L, "Post-MP (Q2 2022+)", "Pre-MP")]
dt_hs[, post := factor(post, levels = c("Pre-MP", "Post-MP (Q2 2022+)"))]



# =============================================================================
# TABLE 1 — Sample means by group and pre/post
# =============================================================================

# Use the project-derived employment indicators (in_labor_force, employed),
# which are defined over ALL sample women. Do NOT use datazoom's `ocupado`
# directly here: it is NA for anyone out of the labor force, so its weighted
# mean would be the employment rate AMONG labor-force participants, not the
# share of all women who are employed (see build/01_pnadc.R).
vars_desc <- c(
  "home_office", "in_labor_force", "employed",
  "rendimento_habitual_real", "VD4031",
  "on_maternity_leave", "formal", "potential_telework",
  "V2009"
)

labels_desc <- c(
  "Home office (\\%)", "In labor force (\\%)", "Employed (\\%)",
  "Real monthly earnings (R\\$)", "Usual weekly hours",
  "On maternity leave (\\%)", "Formal employment (\\%)", "Telework-eligible occupation (\\%)",
  "Age (years)"
)

# Weighted means by group × pre/post
tab1 <- dt_hs[, lapply(.SD, function(x) {
  weighted.mean(x, w = V1028, na.rm = TRUE)
}), by = .(group, post), .SDcols = vars_desc]

# Also add N (unweighted) and n_eff rows
tab1_n <- dt_hs[, .N, by = .(group, post)]
tab1 <- merge(tab1, tab1_n, by = c("group", "post"))

# Wide format: one column per group×post combination
tab1_wide <- dcast(
  melt(tab1, id.vars = c("group", "post", "N"), variable.name = "variable"),
  variable ~ group + post,
  value.var = "value"
)

# LaTeX output
make_latex_table1 <- function(tab, labels, outfile) {
  nvar <- nrow(tab)
  lines <- character(0)
  lines <- c(lines,
    "\\begin{table}[H]",
    "\\centering",
    "\\caption{Summary Statistics by Treatment Group}",
    "\\label{tab:descriptives}",
    "\\footnotesize\\setlength{\\tabcolsep}{4pt}",
    "\\begin{tabular}{lcccccc}",
    "\\toprule",
    " & \\multicolumn{2}{c}{Treated (child $\\leq$ 4)} & \\multicolumn{2}{c}{Control A (child 5--7)} & \\multicolumn{2}{c}{Control B (no child 0--7)} \\\\",
    "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7}",
    " & Pre & Post & Pre & Post & Pre & Post \\\\",
    "\\midrule"
  )
  pp_vars <- c("home_office", "in_labor_force", "employed",
               "on_maternity_leave", "formal", "potential_telework")
  for (i in seq_len(nvar)) {
    row_vals <- as.numeric(tab[i, -1])
    # Scale 0/1 (share) variables ×100 for display as percentages
    if (vars_desc[i] %in% pp_vars) {
      row_vals[seq_along(row_vals)] <- row_vals * 100
      fmt <- "%.1f"
    } else if (vars_desc[i] == "rendimento_habitual_real") {
      fmt <- "%.0f"
    } else {
      fmt <- "%.1f"
    }
    cell_str <- paste(sprintf(fmt, row_vals), collapse = " & ")
    lines <- c(lines, paste0(labels[i], " & ", cell_str, " \\\\"))
  }

  # Row of obs
  n_row <- tab1_n[order(group, post)]
  n_vals <- format(n_row$N, big.mark = ",")
  lines <- c(lines,
    "\\midrule",
    paste0("Observations & ", paste(n_vals, collapse = " & "), " \\\\"),
    "\\bottomrule",
    "\\end{tabular}",
    "\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Sample restricted to women aged 18--49 who are household head or spouse, with at least one interview from 2018 onwards. Means are weighted by the survey sampling weights. Post refers to the second quarter of 2022 onwards, the first period after the reform. Treated women have a youngest child aged 0--4 in the household; Control A women have a youngest child aged 5--7; Control B women have no child aged 0--7 in the household. Earnings are in constant first-quarter-2026 reais, deflated with IBGE's official PNADC deflator.",
    "\\end{table}"
  )
  writeLines(lines, outfile)
  message("Table 1 saved: ", outfile)
}

# Reorder columns: treated pre, treated post, ctrlA pre, ctrlA post, ctrlB pre, ctrlB post
col_order <- c(
  "variable",
  "Treated (child <= 4 years)_Pre-MP",    "Treated (child <= 4 years)_Post-MP (Q2 2022+)",
  "Control A (child 5-7 years)_Pre-MP", "Control A (child 5-7 years)_Post-MP (Q2 2022+)",
  "Control B (no child 0-7 years)_Pre-MP", "Control B (no child 0-7 years)_Post-MP (Q2 2022+)"
)
col_order <- intersect(col_order, names(tab1_wide))
tab1_wide <- tab1_wide[, ..col_order]

# Reorder rows to match labels_desc order
tab1_wide[, variable := factor(variable, levels = vars_desc)]
setorder(tab1_wide, variable)

make_latex_table1(
  tab      = tab1_wide,
  labels   = labels_desc,
  outfile  = file.path(TABLE_DIR, "tab01_descriptives.tex")
)


# =============================================================================
# TABLE A.1 — Panel retention diagnostics
#
# Validates, for the reader, that the datazoom.social advanced (Stage 3)
# individual panel identification is actually capturing the rotating panel's
# intended repeated structure (households/individuals interviewed up to 5
# consecutive quarters), which is the premise for including individual FE
# (id_panel) in every regression. Computed on the actual DiD estimation sample
# (dt_hs, women 18-49, head/spouse).
#
# Panel A: retention rate = share of households/individuals observed for AT
#   LEAST X consecutive-quarter-count (not necessarily consecutive calendar
#   quarters, since dropout/reentry patterns aside, PNADC's design caps any
#   given household/individual at 5 total interviews).
# Panel B: quarter-to-quarter transition probability = of all (id, quarter)
#   pairs where a NEXT quarter could in principle have been observed (i.e.
#   quarter is not the last quarter present anywhere in the data), the share
#   where that same id is also observed in the immediately following quarter.
#
# Individuals use id_rs3 restricted to panel_matched == 1 (i.e. the Stage 3
# algorithm's own matched IDs) -- this is what shows the matching algorithm is
# working, unlike id_panel, which would trivially show ~3.7% of "individuals"
# appearing in only 1 quarter by construction (every unmatched row gets its
# own unique id_panel value, see 01_pnadc.R). Households use id_dom (always
# non-missing).
# =============================================================================

next_yq <- function(yq) {
  yr <- yq %/% 10L
  q  <- yq %% 10L
  fifelse(q == 4L, (yr + 1L) * 10L + 1L, yq + 1L)
}

compute_retention <- function(pairs, id_colname) {
  dq <- copy(pairs)
  setnames(dq, id_colname, "id")
  n_q <- dq[, .N, by = id]
  retention_pct <- vapply(1:5, function(x) mean(n_q$N >= x) * 100, numeric(1))

  dq[, next_q := next_yq(year_quarter)]
  max_yq   <- max(dq$year_quarter)
  eligible <- dq[year_quarter < max_yq, .(id, next_q)]
  present  <- dq[, .(id, q = year_quarter, present_flag = TRUE)]
  merged   <- merge(eligible, present, by.x = c("id", "next_q"), by.y = c("id", "q"), all.x = TRUE)
  transition_pct <- mean(!is.na(merged$present_flag)) * 100

  list(retention = retention_pct, transition = transition_pct)
}

hh_pairs  <- unique(dt_hs[, .(id_dom, year_quarter)])
ind_pairs <- unique(dt_hs[panel_matched == 1, .(id_rs3, year_quarter)])

hh_res  <- compute_retention(hh_pairs,  "id_dom")
ind_res <- compute_retention(ind_pairs, "id_rs3")

make_latex_table2 <- function(hh_res, ind_res, outfile, range_str) {
  fmt_pct <- function(x) sprintf("%.1f\\%%", x)

  lines <- c(
    "\\begin{table}[H]",
    "\\centering",
    "\\caption{Retention Rates of Households and Individuals Across Quarters}",
    "\\label{tab:panel_retention}",
    "\\small",
    "\\begin{tabular}{lccccc}",
    "\\multicolumn{6}{l}{\\textbf{Panel A: Retention Analysis Across Quarters}} \\\\",
    "\\toprule",
    "Type & At least 1Q & At least 2Q & At least 3Q & At least 4Q & 5Q \\\\",
    "\\midrule",
    paste0("Households & ",  paste(fmt_pct(hh_res$retention),  collapse = " & "), " \\\\"),
    paste0("Individuals & ", paste(fmt_pct(ind_res$retention), collapse = " & "), " \\\\"),
    "\\bottomrule",
    "\\\\",
    "\\multicolumn{6}{l}{\\textbf{Panel B: Quarter-to-Quarter Transition Probabilities}} \\\\",
    "\\toprule",
    "\\multicolumn{4}{l}{Type} & \\multicolumn{2}{r}{Transition Probability (T $\\to$ T+1)} \\\\",
    "\\midrule",
    paste0("\\multicolumn{4}{l}{Households} & \\multicolumn{2}{r}{", fmt_pct(hh_res$transition), "} \\\\"),
    paste0("\\multicolumn{4}{l}{Individuals} & \\multicolumn{2}{r}{", fmt_pct(ind_res$transition), "} \\\\"),
    "\\bottomrule",
    "\\end{tabular}",
    "\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Sample: women aged 18--49 who are household head or spouse, the main estimation sample used throughout the paper. Panel A reports retention rates: the share of households and individuals observed for at least $X$ quarterly interviews. Panel B reports quarter-to-quarter transition probabilities: of all household-quarter or individual-quarter observations for which a subsequent quarter could in principle have been observed, the share that are. Statistics pool all quarters from ", range_str, ".",
    "\\end{table}"
  )
  writeLines(lines, outfile)
  message("Table 2 saved: ", outfile)
}

# Dynamic sample date range (e.g. "2018Q1 to 2026Q1") for the table note.
yq_to_str <- function(yq) sprintf("%dQ%d", yq %/% 10L, yq %% 10L)
range_str <- paste0(yq_to_str(min(dt_hs$year_quarter)), " to ",
                    yq_to_str(max(dt_hs$year_quarter)))

make_latex_table2(
  hh_res    = hh_res,
  ind_res   = ind_res,
  outfile   = file.path(TABLE_DIR, "tabA1_panel_retention.tex"),
  range_str = range_str
)


# =============================================================================
# Shared plot settings
# =============================================================================

mp_date <- as.Date("2022-04-01")  # Q2 2022

pal <- c(
  "Treated (child <= 4 years)"         = "#C0392B",
  "Control A (child 5-7 years)"      = "#2471A3",
  "Control B (no child 0-7 years)" = "#616A6B"
)

# Base theme for all figures.
# Group labels are long ("Control B (no child 0-7 years)"), so the legend is
# forced onto 2 rows (guide_legend(nrow = 2)) rather than 1 -- a single row at
# any reasonable figure width truncates the last label. Do not rely on
# widening the figure alone to fix this; the row wrap is the robust fix.
theme_paper <- function(base = 14) {
  list(
    theme_bw(base_size = base) +
    theme(
      legend.position      = "bottom",
      legend.title         = element_blank(),
      legend.text          = element_text(size = base - 2),
      legend.key.width     = unit(1.1, "cm"),
      legend.spacing.x     = unit(0.3, "cm"),
      legend.box.spacing   = unit(0.2, "cm"),
      panel.grid.minor     = element_blank(),
      panel.grid.major     = element_line(colour = "grey92"),
      axis.text            = element_text(size = base - 2),
      axis.title           = element_text(size = base - 1),
      strip.text           = element_text(size = base - 1, face = "bold"),
      strip.background     = element_rect(fill = "grey94", colour = NA),
      plot.title           = element_blank(),
      plot.subtitle        = element_blank()
    ),
    guides(colour = guide_legend(nrow = 2, byrow = TRUE, override.aes = list(linewidth = 1.2)))
  )
}


# =============================================================================
# FIGURE 1 — Home office rate by quarter and group (full 2018-2026)
# =============================================================================

trends <- dt_hs[, .(
  home_office_rate = weighted.mean(home_office, w = V1028, na.rm = TRUE),
  n = .N
), by = .(year_quarter, group)]

trends[, year    := year_quarter %/% 10L]
trends[, quarter := year_quarter  %% 10L]
trends[, date    := as.Date(paste0(year, "-", (quarter - 1L) * 3L + 1L, "-01"))]

fig1 <- ggplot(trends, aes(x = date, y = home_office_rate * 100, colour = group)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.6) +
  geom_vline(xintercept = mp_date, linetype = "dashed", colour = "black", linewidth = 0.7) +
  scale_colour_manual(values = pal) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0.02, 0.06))) +
  labs(x = NULL, y = "Share working from home (%)") +
  theme_paper()

ggsave(file.path(GRAPH_DIR, "fig01_home_office_trends.pdf"),
       fig1, width = 8, height = 5)
ggsave(file.path(GRAPH_DIR, "fig01_home_office_trends.png"),
       fig1, width = 8, height = 5, dpi = 300)
message("Figure 1 saved.")


# =============================================================================
# FIGURE 2 — Two-panel: Treated vs. Control A | Treated vs. Control B
# =============================================================================

trends_AB <- copy(trends[group %in% c("Treated (child <= 4 years)", "Control A (child 5-7 years)")])
trends_AB[, comparison := "Treated vs. Control A (child 5-7 years)"]

trends_AC <- copy(trends[group %in% c("Treated (child <= 4 years)", "Control B (no child 0-7 years)")])
trends_AC[, comparison := "Treated vs. Control B (no child 0-7 years)"]

trends2 <- rbind(trends_AB, trends_AC)
trends2[, comparison := factor(comparison, levels = c(
  "Treated vs. Control A (child 5-7 years)",
  "Treated vs. Control B (no child 0-7 years)"
))]

fig2 <- ggplot(trends2, aes(x = date, y = home_office_rate * 100, colour = group)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.6) +
  geom_vline(xintercept = mp_date, linetype = "dashed", colour = "black", linewidth = 0.7) +
  facet_wrap(~comparison, ncol = 1) +
  scale_colour_manual(values = pal) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0.02, 0.06))) +
  labs(x = NULL, y = "Share working from home (%)") +
  theme_paper()

ggsave(file.path(GRAPH_DIR, "fig02_home_office_two_controls.pdf"),
       fig2, width = 8, height = 8)
ggsave(file.path(GRAPH_DIR, "fig02_home_office_two_controls.png"),
       fig2, width = 8, height = 8, dpi = 300)
message("Figure 2 saved.")


# =============================================================================
# FIGURE 3 — Labor force participation and employment rate by group
# =============================================================================

# Both series are defined over ALL sample women, using the project-derived
# indicators (see build/01_pnadc.R): `in_labor_force` (= forca_trab) and
# `employed` (= 1 only if in the labor force AND occupied, else 0). So emp_rate
# here is the unconditional share of all women who are employed -- NOT the
# employment rate among labor-force participants. Using datazoom's raw `ocupado`
# instead would silently condition on labor-force participation (it is NA for
# anyone out of the labor force).
lfp_trends <- dt_hs[, .(
  lfp_rate = weighted.mean(in_labor_force, w = V1028, na.rm = TRUE),
  emp_rate = weighted.mean(employed,       w = V1028, na.rm = TRUE),
  n        = .N
), by = .(year_quarter, group)]

lfp_trends[, year    := year_quarter %/% 10L]
lfp_trends[, quarter := year_quarter  %% 10L]
lfp_trends[, date    := as.Date(paste0(year, "-", (quarter - 1L) * 3L + 1L, "-01"))]

lfp_long <- melt(
  lfp_trends,
  id.vars       = c("date", "group"),
  measure.vars  = c("lfp_rate", "emp_rate"),
  variable.name = "outcome",
  value.name    = "rate"
)
lfp_long[, panel_label := fcase(
  outcome == "lfp_rate", "Labor force participation rate",
  outcome == "emp_rate", "Employment rate (share of all women)"
)]
lfp_long[, panel_label := factor(panel_label, levels = c(
  "Labor force participation rate",
  "Employment rate (share of all women)"
))]

fig3 <- ggplot(lfp_long, aes(x = date, y = rate * 100, colour = group)) +
  geom_line(linewidth = 0.9) +
  geom_vline(xintercept = mp_date, linetype = "dashed", colour = "black", linewidth = 0.7) +
  facet_wrap(~panel_label, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = pal) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0.02, 0.06))) +
  labs(x = NULL, y = NULL) +
  theme_paper()

ggsave(file.path(GRAPH_DIR, "fig03_lfp_employment_trends.pdf"),
       fig3, width = 8, height = 8)
ggsave(file.path(GRAPH_DIR, "fig03_lfp_employment_trends.png"),
       fig3, width = 8, height = 8, dpi = 300)
message("Figure 3 saved.")


# =============================================================================
# FIGURE 4 — Home office rate for potential_telework == 1 subgroup
# =============================================================================

trends_pt <- dt_hs[potential_telework == 1, .(
  home_office_rate = weighted.mean(home_office, w = V1028, na.rm = TRUE),
  n = .N
), by = .(year_quarter, group)]

trends_pt[, year    := year_quarter %/% 10L]
trends_pt[, quarter := year_quarter  %% 10L]
trends_pt[, date    := as.Date(paste0(year, "-", (quarter - 1L) * 3L + 1L, "-01"))]

fig4 <- ggplot(trends_pt, aes(x = date, y = home_office_rate * 100, colour = group)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.6) +
  geom_vline(xintercept = mp_date, linetype = "dashed", colour = "black", linewidth = 0.7) +
  scale_colour_manual(values = pal) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0.02, 0.06))) +
  labs(x = NULL, y = "Share working from home (%)") +
  theme_paper()

ggsave(file.path(GRAPH_DIR, "fig04_home_office_telework_eligible.pdf"),
       fig4, width = 8, height = 5)
ggsave(file.path(GRAPH_DIR, "fig04_home_office_telework_eligible.png"),
       fig4, width = 8, height = 5, dpi = 300)
message("Figure 4 saved.")


# =============================================================================
# FIGURE 5 (APPENDIX, OPTIONAL) — Geographic distribution of home office among
# treated women, post-MP. Purely descriptive: the DiD design does not rely on
# geographic variation for identification (state x time is a robustness FE,
# not the main spec) — this figure only supports external validity by showing
# the effect is not concentrated in a single region. Skipped automatically if
# 'geobr'/'sf' are not installed.
# =============================================================================
if (requireNamespace("geobr", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)) {

  state_rates <- dt_hs[group == "Treated (child <= 4 years)" & post == "Post-MP (Q2 2022+)",
                       .(home_office_rate = weighted.mean(home_office, w = V1028, na.rm = TRUE)),
                       by = sigla_uf]

  states_sf <- geobr::read_state(year = 2020, showProgress = FALSE)
  states_sf <- merge(states_sf, state_rates, by.x = "abbrev_state", by.y = "sigla_uf", all.x = TRUE)

  fig5 <- ggplot(states_sf) +
    geom_sf(aes(fill = home_office_rate * 100), colour = "white", linewidth = 0.3) +
    scale_fill_gradient(name = "Home office (%)", low = "#D5F5E3", high = "#0B5345",
                        na.value = "grey85") +
    theme_void(base_size = 14) +
    theme(legend.position = "right")

  ggsave(file.path(MAP_DIR, "fig05_home_office_map_appendix.pdf"), fig5, width = 7, height = 6)
  ggsave(file.path(MAP_DIR, "fig05_home_office_map_appendix.png"), fig5, width = 7, height = 6, dpi = 300)
  message("Figure 5 (appendix map) saved.")
} else {
  message("Figure 5 (appendix map) skipped — install 'geobr' and 'sf' to generate it.")
}


message("\n=== 01_descriptives.R complete ===")
message("Tables: ", TABLE_DIR)
message("Graphs: ", GRAPH_DIR)
