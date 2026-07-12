# =============================================================================
# 03_did.R
# Main difference-in-differences results.
#
#   Table 2  — First stage (home office): specification ladder.
#              (1) raw OLS, no controls, no FE
#              (2) + demographic controls
#              (3) + year-quarter FE
#              (4) + individual FE                (preferred)
#              (5) + age^2 only (in place of demographic controls)
#              Shows the null does not depend on the fixed-effects/covariate
#              choice (addresses whether individual FE and age controls matter).
#   Table 3  — All outcomes under the preferred spec, Control A and Control B,
#              plus the A-vs-B placebo (home office).
#
# Preferred spec: treated + treat_x_post | id_panel + year_quarter, weighted by
# V1028, clustered at id_dom. The `treated` (= has_child_u4) main effect is
# included because treatment status is time-varying (see CLAUDE.md).
#
# Sample: WOMEN aged 18-49, head or spouse (main_data now holds both sexes; men
# enter only in 07_triple_diff.R).
# =============================================================================

# Packages (data.table, fixest, here) are loaded by config/00_master_analysis.R
# via pacman::p_load() before this script is source()'d; not repeated here.
source(here("analysis", "code", "00_utils.R"))

source(here::here("config", "config.R"))
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")
dir.create(TABLE_DIR, showWarnings = FALSE, recursive = TRUE)

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[female == 1 & is_head_or_spouse == 1 & panel_matched == 1]
setnames(dt, "VD4031", "hours_usual")

# Real earnings enter the outcome tables in logs (as in the robustness table), so
# the coefficient is a proportional effect. Defined only for workers with
# positive earnings; feols drops the remaining (NA) rows for that column only.
dt[, log_earnings := fifelse(earnings_habitual_real > 0, log(earnings_habitual_real), NA_real_)]

# Human-readable labels for etable. Nuisance controls are left unlabeled so they
# can be dropped from the display by their raw names.
dict <- c(
  treat_x_post = "Young child $\\times$ Post",
  treated      = "Young child ($\\leq$ 4)",
  home_office  = "Home-based work", log_earnings = "Log earnings",
  hours_usual  = "Usual hours", employed = "Employed",
  in_labor_force = "In labor force", on_maternity_leave = "Maternity leave",
  id_panel = "Individual", id_dom = "Household", year_quarter = "Year-quarter"
)

samp_A <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]
samp_B <- dt[has_child_u4 == 1 | (has_child_u4 == 0 & has_child_5_7 == 0)]

# =============================================================================
# Table 2 — first-stage specification ladder (Control A)
# =============================================================================
# Column 1: raw OLS, no controls and no fixed effects (the fully unconditional
# treated-vs-control difference around the reform). Columns 2-5 add, in turn,
# demographic controls, quarter FE, individual FE (preferred), and age^2 --- so
# the ladder separates what observed demographics do (little) from what the
# individual fixed effects do (collapse the estimate to zero).
m0 <- feols(home_office ~ treated + post_mp + treat_x_post,
            samp_A, weights = ~V1028, cluster = ~id_dom)
m1 <- feols(home_office ~ treated + post_mp + treat_x_post + V2009 + I(V2009^2) +
              higher_educ + i(V2010) + i(regiao),
            samp_A, weights = ~V1028, cluster = ~id_dom)
m2 <- feols(home_office ~ treated + treat_x_post + V2009 + I(V2009^2) +
              higher_educ + i(V2010) + i(regiao) | year_quarter,
            samp_A, weights = ~V1028, cluster = ~id_dom)
m3 <- feols(home_office ~ treated + treat_x_post | id_panel + year_quarter,
            samp_A, weights = ~V1028, cluster = ~id_dom)
# Column 5: add age^2 only. The linear age term is collinear with individual +
# year-quarter FE (age = calendar time - birth cohort, both absorbed), so it is
# mechanically dropped; the quadratic carries any age adjustment.
m4 <- feols(home_office ~ treated + treat_x_post + I(V2009^2) |
              id_panel + year_quarter,
            samp_A, weights = ~V1028, cluster = ~id_dom)

tab02_file <- file.path(TABLE_DIR, "tab02_did_firststage.tex")
etable(m0, m1, m2, m3, m4,
       tex = TRUE, file = tab02_file, replace = TRUE, signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
       dict = dict, drop = c("post_mp", "V2009", "V2010", "regiao", "higher_educ", "Constant"),
       extralines = list("Demographic controls" = c("No", "Yes", "Yes", "No", "Age$^2$ only")),
       fitstat = ~ n + r2, digits = 3, digits.stats = 3,
       title = "Home-Based-Work Effect: Specification Ladder (Control A)",
       label = "tab:did_firststage",
       notes = paste(paste0("\\footnotesize\\textit{Notes:} The outcome is an indicator for performing the main job at the worker's own residence (home-based work; non-employed women are coded zero). Column~(4) is the preferred specification, ", EQ_REF, ", with individual and year-quarter fixed effects; column~(1) is a raw regression with no controls, column~(2) adds demographic controls, column~(3) adds year-quarter fixed effects, and column~(5) adds a quadratic in age. Sample: women 18--49, household head or spouse, young child (aged 4 or younger) vs.\\ Control~A (youngest child 5--7). Demographic controls are age, age$^2$, completed higher education, race, and region."), WEIGHT_NOTE, CLUSTER_NOTE, SIGNIF_NOTE))
postprocess_tex(tab02_file, fontsize = "\\small", tabcolsep = 4)
# Show an explicit "No" where a fixed effect is absent (etable leaves it blank),
# and list Individual above Year-quarter to match the other tables. Ladder:
# year-quarter FE enters from col 3, individual FE from col 4.
.tx <- readLines(tab02_file)
iy <- grep("^\\s*Year-quarter\\s*&", .tx); ii <- grep("^\\s*Individual\\s*&", .tx)
lo <- min(iy, ii); hi <- max(iy, ii)
.tx[lo] <- "      Individual & No & No & No & Yes & Yes\\\\"
.tx[hi] <- "      Year-quarter & No & No & Yes & Yes & Yes\\\\"
writeLines(.tx, tab02_file)

# =============================================================================
# Table 3 — all outcomes, preferred spec, Control A and Control B
# =============================================================================
outcomes <- c("home_office", "log_earnings", "hours_usual",
              "employed", "in_labor_force", "on_maternity_leave")
run_all <- function(sample) {
  setNames(lapply(outcomes, function(y)
    feols(as.formula(sprintf("%s ~ treated + treat_x_post | id_panel + year_quarter", y)),
          sample, weights = ~V1028, cluster = ~id_dom, notes = FALSE)), outcomes)
}
mods_A <- run_all(samp_A)
mods_B <- run_all(samp_B)

tab03a_file <- file.path(TABLE_DIR, "tabE3_did_outcomes_A.tex")
etable(mods_A,
       tex = TRUE, file = tab03a_file, replace = TRUE, signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
       dict = dict, fitstat = ~ n + r2, digits = 3, digits.stats = 3,
       title = "Difference-in-Differences Estimates by Outcome, Control A",
       label = "tab:did_outcomes_A",
       notes = paste(paste0("\\footnotesize\\textit{Notes:} Each column is a separate difference-in-differences regression estimating ", EQ_REF, ". The home-based-work, employment, participation, and maternity-leave columns are defined over all sample women (non-employed coded zero); the log-earnings and hours columns are defined only for workers. Sample: women 18--49, household head or spouse, young child (aged 4 or younger) vs.\\ Control~A (youngest child 5--7). The employment, participation, and maternity-leave coefficients fail the parallel-trends pre-test (Section~\\ref{sec:results}) and are descriptive, not causal. ", UNITS_NOTE), WEIGHT_NOTE, CLUSTER_NOTE, SIGNIF_NOTE))
postprocess_tex(tab03a_file, fontsize = "\\footnotesize", tabcolsep = 3)

tab03b_file <- file.path(TABLE_DIR, "tabE10_did_outcomes_B.tex")
etable(mods_B,
       tex = TRUE, file = tab03b_file, replace = TRUE, signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
       dict = dict, fitstat = ~ n + r2, digits = 3, digits.stats = 3,
       title = "Difference-in-Differences Estimates by Outcome, Control B",
       label = "tab:did_outcomes_B",
       notes = paste(paste0("\\footnotesize\\textit{Notes:} Each column is a separate difference-in-differences regression estimating ", EQ_REF, " on the broad comparison group (women with no child aged 0--7). Sample: women 18--49, household head or spouse. As in the Control~A table, the employment, participation, and maternity-leave coefficients fail the parallel-trends pre-test and are descriptive, not causal. ", UNITS_NOTE), WEIGHT_NOTE, CLUSTER_NOTE, SIGNIF_NOTE))
postprocess_tex(tab03b_file, fontsize = "\\footnotesize", tabcolsep = 3)

# Note: the A-vs-B placebo (home office, fake treatment = has_child_5_7) is
# computed in 06_robustness.R, which writes it into tabE1_robustness.tex; it is
# not repeated here to avoid duplicating that regression.

# =============================================================================
# Table 3b — earnings and hours: intensive margin (workers) vs the extensive-
# margin-inclusive unconditional versions defined over ALL women (referee round
# 2, Comment 3). Earnings and usual hours among workers condition on employment,
# a post-treatment variable; to show that this conditioning is not what produces
# the null, the unconditional columns re-define each outcome over all women with
# the non-employed coded zero (asinh for earnings, to admit the zeros). For each,
# the pre-reform-leads joint test decides whether it can be read causally: the
# worker-conditional outcomes pass parallel trends and are precise nulls, while
# the unconditional versions fail (they inherit the employment extensive margin's
# differential trend), so the causal-clean set is defined by the diagnostic, not
# by assumption.
# =============================================================================
samp_A[, earn_uncond  := asinh(fifelse(is.na(earnings_habitual_real) | earnings_habitual_real < 0,
                                        0, earnings_habitual_real))]
samp_A[, hours_uncond := fifelse(is.na(hours_usual) | employed == 0, 0, hours_usual)]
eh_specs <- list(c("log_earnings",  "Log earnings (workers only)"),
                 c("hours_usual",   "Usual weekly hours (workers only)"),
                 c("earn_uncond",   "Inverse hyperbolic sine of earnings (all women, non-employed $=0$)"),
                 c("hours_uncond",  "Weekly hours (all women, non-employed $=0$)"))
eh <- rbindlist(lapply(eh_specs, function(s) {
  y <- s[1]
  m  <- feols(as.formula(sprintf("%s ~ treated + treat_x_post | id_panel + year_quarter", y)),
              samp_A, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
  ct <- coeftable(m)["treat_x_post", ]
  me <- feols(as.formula(sprintf("%s ~ i(year_quarter, treated, ref = 20221) | id_panel + year_quarter", y)),
              samp_A, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
  b <- coef(me); V <- vcov(me)
  pre <- grep("year_quarter::20(18|19|20|21)[1-4]:treated", names(b), value = TRUE)
  bb <- b[pre]; VV <- V[pre, pre]
  chi <- as.numeric(t(bb) %*% solve(VV) %*% bb); k <- length(pre)
  ptp <- pchisq(chi, k, lower.tail = FALSE)
  data.table(label = s[2], est = ct[1], se = ct[2], lo = ct[1] - 1.96 * ct[2],
             hi = ct[1] + 1.96 * ct[2], chi = chi, ptp = ptp,
             pass = ifelse(ptp > 0.05, "Yes", "No"), n = nobs(m))
}))
f3 <- function(x) formatC(x, format = "f", digits = 3)
eh_row <- function(r) sprintf("%s & %s (%s) & [%s, %s] & %.1f\\ ($p=%s$) & %s & %s \\\\",
  r$label, f3(r$est), f3(r$se), f3(r$lo), f3(r$hi), r$chi,
  formatC(r$ptp, format = "f", digits = 3), r$pass, formatC(r$n, big.mark = ",", format = "d"))
tab3b <- c("\\begin{table}[H]\\centering",
  "\\caption{Earnings and Hours: Worker-Conditional and Unconditional Estimates}",
  "\\label{tab:earnings_margins}\\small",
  "\\resizebox{\\ifdim\\width>\\linewidth\\linewidth\\else\\width\\fi}{!}{%",
  "\\begin{tabular}{lccccc}", "\\toprule",
  "Outcome & Young child $\\times$ Post (se) & 95\\% CI & Pre-trend $\\chi^2(16)$ & Parallel trends? & Obs. \\\\", "\\midrule",
  unlist(lapply(seq_len(nrow(eh)), function(i) eh_row(eh[i]))),
  "\\bottomrule\\end{tabular}}",
  paste(paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Each row is a separate difference-in-differences regression estimating ", EQ_REF, " on the preferred sample (young child vs.\\ Control~A). The first two rows are the intensive-margin outcomes observed only for workers (log real earnings and usual weekly hours). The last two re-define the outcomes over \\emph{all} sample women, coding the non-employed as zero (inverse hyperbolic sine for earnings, to admit the zeros), so they combine the intensive and the extensive margins. ``Pre-trend $\\chi^2(16)$'' is the joint Wald test that the pre-reform event-study leads are zero (the parallel-trends diagnostic): the worker-conditional earnings and hours pass it and are precise nulls, whereas the unconditional versions reject it, because they inherit the differential pre-trend of the employment extensive margin (Table~\\ref{tab:did_outcomes_A})."), WEIGHT_NOTE, CLUSTER_NOTE, SIGNIF_NOTE),
  "\\end{table}")
writeLines(tab3b, file.path(TABLE_DIR, "tabE4_earnings_margins.tex"))
cat("\n=== Table 3b: earnings/hours conditional vs unconditional ===\n")
print(eh[, .(label = substr(gsub("\\$|\\\\", "", label), 1, 34), est = round(est, 3),
             ptp = round(ptp, 3), pass, n = formatC(n, big.mark = ",", format = "d"))])

# ---- Console summary --------------------------------------------------------
cat("\n=== Table 2: first-stage ladder (home office, treat_x_post) ===\n")
for (nm in c("m0", "m1", "m2", "m3", "m4")) {
  ct <- coeftable(get(nm))["treat_x_post", ]
  cat(sprintf("  %s: %.3f (%.3f) p=%.2f\n", nm, ct[1] * 100, ct[2] * 100, ct[4]))
}
cat("\n=== Table 3: Control A outcomes (treat_x_post) ===\n")
for (y in outcomes) {
  ct <- coeftable(mods_A[[y]])["treat_x_post", ]
  sc <- if (y %in% c("log_earnings", "hours_usual")) 1 else 100
  cat(sprintf("  %-26s %.3f (%.3f) p=%.2f\n", y, ct[1] * sc, ct[2] * sc, ct[4]))
}
message("\n=== 03_did.R complete ===")
