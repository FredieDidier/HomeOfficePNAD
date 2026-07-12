# =============================================================================
# 08_referee_revision.R — additional analyses answering the referee report
# (Proof Patrol / econ-GPT, July 2026). Every regression is the paper's DiD
# on the preferred sample (young-child vs Control A), varying what the referee
# asked for. Produces the new exhibits cited in the revised paper:
#
#   Table 4  (tab04_estimands)     — home-based work by PREDETERMINED subsample:
#                                    all / employed / salaried employees / CLT /
#                                    self-employed / teleworkable / CLT x
#                                    teleworkable. Separates the population-
#                                    average estimand from the effect among the
#                                    legally covered (Comments 1 and 3).
#   Table 5  (tab05_equivalence)   — precision and TOST equivalence tests, with
#                                    95% CI, pre-reform mean, upper bound as % of
#                                    mean, and the equivalence verdict against a
#                                    pre-specified SESOI (Comment 7).
#   Table E.2 (tabE2_inference)    — inference and estimator robustness: state
#                                    clustering, wild cluster bootstrap over the
#                                    27 states, a repeated-cross-section DiD with
#                                    child-age / maternal-age / state x quarter
#                                    fixed effects, a local difference-in-
#                                    discontinuities around the 60-month cutoff,
#                                    and a pre-reform temporal placebo
#                                    (Comments 5 and 6).
#   Table E.3 (tabE3_attrition)    — differential-attrition test and an inverse-
#                                    probability-of-retention-weighted estimate
#                                    (Comment 9).
#   Table E.4 (tabE4_identification)— decomposition of the identifying variation
#                                    by how eligibility changes within a woman
#                                    (Comment 5).
#
# The displayed treatment variable is "Young child" (child aged 4 or younger),
# renamed from "Treated" per Comment 1; internal column names stay `treated` /
# `treat_x_post` to avoid churn across the pipeline.
# =============================================================================

# Packages (data.table, fixest, ggplot2, here) are loaded by
# config/00_master_analysis.R via pacman::p_load(); fwildclusterboot is loaded
# on demand below.
source(here("analysis", "code", "00_utils.R"))
source(here::here("config", "config.R"))
OUTPUT_PATH <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR   <- here("analysis", "output", "tables")

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[female == 1 & is_head_or_spouse == 1 & panel_matched == 1]
setorder(dt, id_panel, year_quarter)

# CLT (celetista) employees the law legally reaches = signed-card employees,
# private OR public (public companies / mixed-economy firms hire under the CLT).
# Derived from VD4009 so the script runs on the existing build; see
# build/01_pnadc.R for the canonical definition.
dt[, clt_covered := as.integer(!is.na(VD4009) & VD4009 %in% c(1L, 5L))]

star <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
fmt  <- function(x, d = 2) sub("^-(0\\.?0*)$", "\\1", formatC(x, format = "f", digits = d))  # strip signed zero
fmt0 <- function(x) formatC(as.integer(x), format = "d", big.mark = ",")

# =============================================================================
# PREDETERMINED baseline covariates (Comment 2): value at the LAST observation on
# or before 2022Q1 (the last pre-reform quarter), NOT the first observed quarter.
# Women with no pre-reform observation get NA and drop from the subsample rows.
# =============================================================================
pre <- dt[year_quarter <= 20221]
base <- pre[, .SD[.N], by = id_panel,
            .SDcols = c("clt_covered", "potential_telework", "employed",
                        "VD4009", "V2009")]
setnames(base, c("clt_covered", "potential_telework", "employed", "VD4009", "V2009"),
         c("clt_pre", "tele_pre", "emp_pre", "vd4009_pre", "age_pre"))
base[, salaried_pre := as.integer(vd4009_pre %in% 1:6)]  # employees (private/domestic/public), signed or not
base[, selfemp_pre  := as.integer(vd4009_pre == 9)]      # conta propria (self-employed)
base[, clt_pre      := as.integer(clt_pre == 1)]
base[, tele_pre     := as.integer(tele_pre == 1)]
base[, emp_pre      := as.integer(emp_pre == 1)]
dt <- merge(dt, base, by = "id_panel", all.x = TRUE)

A <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]

# Core DiD helper: preferred spec, returns a one-row summary with CI and the
# pre-reform outcome mean on the treated group (for the equivalence table).
did_fit <- function(sample, y = "home_office", clu = ~id_dom,
                    fes = "id_panel + year_quarter") {
  m <- feols(as.formula(sprintf("%s ~ treated + treat_x_post | %s", y, fes)),
             sample, weights = ~V1028, cluster = clu, notes = FALSE)
  ct <- coeftable(m)["treat_x_post", ]
  premean <- sample[has_child_u4 == 1 & post_mp == 0,
                    weighted.mean(get(y), V1028, na.rm = TRUE)]
  data.table(est = ct[1], se = ct[2], p = ct[4], n = nobs(m),
             npers = sample[, uniqueN(id_panel)], premean = premean)
}

# =============================================================================
# Table 4 — home-based work by predetermined subsample (Comments 1, 3)
# =============================================================================
# Each row is the same DiD on women who, at their last pre-reform observation,
# were in the stated group. "All women" is the population-average (exposure)
# estimand; the CLT and CLT x teleworkable rows are the legally-covered estimand.
subs <- list(
  list("All women (population-average exposure)", A),
  list("Employed at baseline",                    A[emp_pre == 1]),
  list("Salaried employees at baseline",          A[salaried_pre == 1]),
  list("CLT (private or public) at baseline",     A[clt_pre == 1]),
  list("Self-employed at baseline",               A[selfemp_pre == 1]),
  list("Telework-eligible occupation at baseline", A[tele_pre == 1]),
  list("CLT $\\times$ telework-eligible at baseline", A[clt_pre == 1 & tele_pre == 1])
)
estim <- rbindlist(lapply(subs, function(s) cbind(label = s[[1]], did_fit(s[[2]]))))
estim[, `:=`(est_pp = est * 100, se_pp = se * 100,
             ci_lo = (est - 1.96 * se) * 100, ci_hi = (est + 1.96 * se) * 100,
             premean_pp = premean * 100)]
estim[, ub_pct := 100 * ci_hi / premean_pp]  # upper CI bound as % of pre-reform mean

est_row <- function(r) sprintf(
  "%s & %s$^{%s}$ (%s) & [%s, %s] & %s & %s & %s \\\\",
  r$label, fmt(r$est_pp), star(r$p), fmt(r$se_pp),
  fmt(r$ci_lo), fmt(r$ci_hi), fmt(r$premean_pp, 1), fmt0(r$n), fmt0(r$npers))
tab9 <- c(
  "\\begin{table}[H]\\centering",
  "\\caption{Home-Based Work by Predetermined Subsample: Population-Average versus Legally-Covered Estimands}",
  "\\label{tab:estimands}\\small",
  "\\resizebox{\\ifdim\\width>\\linewidth\\linewidth\\else\\width\\fi}{!}{%",
  "\\begin{tabular}{lccccc}", "\\toprule",
  "Subsample (predetermined) & Young child $\\times$ Post (se) & 95\\% CI & Pre-mean & Obs. & Persons \\\\", "\\midrule",
  unlist(lapply(seq_len(nrow(estim)), function(i) est_row(estim[i]))),
  "\\bottomrule\\end{tabular}}",
  paste(paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} The outcome is an indicator for performing the main job at the worker's own residence (home-based work as measured in the PNADC); non-employed women are coded zero, so in the first row the estimand is the population-average effect on the share of \\emph{all} women working from home. Each row re-estimates ", EQ_REF, " on the subsample of women who were in the stated group at their \\emph{last observation on or before 2022Q1} (predetermined); women with no pre-reform observation are excluded. Coefficients are in percentage points; ``Pre-mean'' is the survey-weighted pre-reform home-based-work rate among treated women in each subsample. The first row is the population-average (exposure) estimand; the CLT and CLT $\\times$ telework-eligible rows are the effect among the workers Article~75-F can legally reach."), WEIGHT_NOTE, CLUSTER_NOTE, SIGNIF_NOTE),
  "\\end{table}")
writeLines(tab9, file.path(TABLE_DIR, "tab04_estimands.tex"))

# =============================================================================
# Table 3 — statutory-reach funnel (new reviewer Comment 2)
# =============================================================================
# A descriptive accounting of how quickly the population Article 75-F can reach
# narrows, among women with a child aged 0-4. Predetermined snapshot: each woman
# at her last observation on or before 2022Q1. The steps NEST: employees (VD4009
# in 1:6) contain the celetistas (VD4009 in {1,5}), who contain the teleworkable
# celetistas, who contain those not already working from home. Shares are of ALL
# young-child women (survey-weighted). Descriptive, not causal: a teleworkable
# occupation does not imply an employer has a remote position to allocate.
fu <- dt[has_child_u4 == 1 & year_quarter <= 20221][
  , .SD[.N], by = id_panel,
  .SDcols = c("VD4009", "potential_telework", "employed", "home_office", "V1028")]
den <- fu[, sum(V1028)]
reach <- data.table(
  label = c("All women with a child aged 0--4",
            "Employed",
            "Salaried employees",
            "CLT (celetista, private or public)",
            "CLT in a telework-eligible occupation",
            "CLT, telework-eligible, and not already working from home"),
  pct = c(100,
          100 * fu[employed == 1, sum(V1028)] / den,
          100 * fu[VD4009 %in% 1:6, sum(V1028)] / den,
          100 * fu[VD4009 %in% c(1, 5), sum(V1028)] / den,
          100 * fu[VD4009 %in% c(1, 5) & potential_telework == 1, sum(V1028)] / den,
          100 * fu[VD4009 %in% c(1, 5) & potential_telework == 1 & home_office == 0, sum(V1028)] / den))
tab16 <- c(
  "\\begin{table}[H]\\centering",
  "\\caption{Potential Statutory Reach among Women with a Young Child}",
  "\\label{tab:reach}\\small",
  "\\begin{tabular}{lc}", "\\toprule",
  "Step & Weighted share (\\%) \\\\", "\\midrule",
  sprintf("%s & %s \\\\", reach$label, fmt(reach$pct, 1)),
  "\\bottomrule\\end{tabular}",
  paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Survey-weighted shares of all women aged 18--49 who are household heads or spouses and have a child aged 0--4, each taken at her last observation on or before 2022Q1 (predetermined). The steps are nested: salaried employees contain the CLT covered by Article~75-F, who contain those in a telework-eligible occupation, who contain those not already working from home."),
  "\\end{table}")
writeLines(tab16, file.path(TABLE_DIR, "tab03_statutory_reach.tex"))
cat("\n=== Statutory-reach funnel (weighted %) ===\n"); print(reach)

# =============================================================================
# Table 5 — precision and equivalence tests (Comment 7)
# =============================================================================
# Pre-specified smallest effect size of interest (SESOI): 0.5 pp in the full
# population, 1.0 pp in the narrower legally-covered subgroups (the referee's
# own suggested margins). TOST: the effect is statistically equivalent to zero
# at the 5% level if the 90% CI lies inside +/- SESOI, i.e. |est| + 1.645*se <=
# SESOI. We report the two one-sided p-values' max (the TOST p-value).
tost <- function(est_pp, se_pp, sesoi) {
  # H0_upper: est >= sesoi ; H0_lower: est <= -sesoi. p = max of one-sided ps.
  p_up <- pnorm((est_pp - sesoi) / se_pp)          # P(Z < (est - sesoi)/se)
  p_lo <- pnorm((-est_pp - sesoi) / se_pp)         # mirror
  max(p_up, p_lo)
}
equiv <- copy(estim)
equiv[, sesoi := ifelse(grepl("All women", label), 0.5, 1.0)]
equiv[, tost_p := mapply(tost, est_pp, se_pp, sesoi)]
equiv[, equiv_verdict := ifelse(tost_p < 0.05, "Equivalent", "Inconclusive")]

eq_row <- function(r) sprintf(
  "%s & %s (%s) & [%s, %s] & $\\pm$%s & %s & %s \\\\",
  r$label, fmt(r$est_pp), fmt(r$se_pp), fmt(r$ci_lo), fmt(r$ci_hi),
  fmt(r$sesoi, 1), fmt(r$tost_p, 3), r$equiv_verdict)
tab10 <- c(
  "\\begin{table}[H]\\centering",
  "\\caption{Precision and Equivalence Tests for the Home-Based-Work Effect}",
  "\\label{tab:equivalence}\\small",
  "\\resizebox{\\ifdim\\width>\\linewidth\\linewidth\\else\\width\\fi}{!}{%",
  "\\begin{tabular}{lccccc}", "\\toprule",
  "Subsample & Estimate (se) & 95\\% CI & SESOI & TOST $p$ & Verdict \\\\", "\\midrule",
  unlist(lapply(seq_len(nrow(equiv)), function(i) eq_row(equiv[i]))),
  "\\bottomrule\\end{tabular}}",
  paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Estimates (percentage points) and 95\\% confidence intervals reproduce Table~\\ref{tab:estimands}. The smallest effect size of interest (SESOI) is pre-specified at $0.5$ pp for the full population and $1.0$ pp for the narrower legally-covered subgroups. ``TOST $p$'' is the $p$-value of the two-one-sided-tests equivalence test against that SESOI: a value below $0.05$ (verdict ``Equivalent'') means the effect is statistically distinguishable from anything as large as the SESOI, i.e. a precise null. ``Inconclusive'' means the data neither reject zero nor establish equivalence, so a substantively relevant effect cannot be ruled out. ", SIGNIF_NOTE),
  "\\end{table}")
writeLines(tab10, file.path(TABLE_DIR, "tab05_equivalence.tex"))

# =============================================================================
# Table E.2 — inference and estimator robustness (Comments 5, 6)
# =============================================================================
inf_rows <- list()
add_inf <- function(label, est_pp, se_pp, p, extra = "") {
  inf_rows[[length(inf_rows) + 1]] <<- data.table(
    label = label, est = est_pp, se = se_pp, p = p, extra = extra)
}

# (a) Preferred spec, household clustering (baseline reference).
b <- did_fit(A); add_inf("Individual FE, household-clustered (baseline)",
                         b$est*100, b$se*100, b$p)
# (b) State clustering (27 clusters), individual + year-quarter FE.
s1 <- did_fit(A, clu = ~sigla_uf)
add_inf("Individual FE, state-clustered (27 clusters)", s1$est*100, s1$se*100, s1$p)
# (c) State clustering + state x year-quarter FE (absorbs state-level shocks).
s2 <- did_fit(A, clu = ~sigla_uf, fes = "id_panel + sigla_uf^year_quarter")
add_inf("Individual + state$\\times$quarter FE, state-clustered", s2$est*100, s2$se*100, s2$p)

# (d) Wild cluster bootstrap of the PREFERRED individual-FE estimate over the 27
#     states. boottest cannot carry 174k individual fixed effects, so we partial
#     them out by the weighted within-transformation (Frisch-Waugh-Lovell): demean
#     the outcome and the two regressors by (individual, year-quarter) FE, then
#     bootstrap a plain weighted regression on the residuals. Its point estimate
#     equals the feols within estimate; the Webb wild bootstrap gives the few-
#     cluster-robust p-value FOR THE PREFERRED SPECIFICATION (not the repeated
#     cross-section below).
wb_p <- NA_real_
if (requireNamespace("fwildclusterboot", quietly = TRUE)) {
  wb_p <- tryCatch({
    dm <- fixest::demean(A[, .(home_office, treated, treat_x_post)],
                         A[, .(id_panel, year_quarter)], weights = A$V1028)
    dm <- as.data.frame(dm)
    dm$V1028 <- A$V1028; dm$sigla_uf <- A$sigla_uf
    lm_dm <- lm(home_office ~ treated + treat_x_post, data = dm, weights = V1028)
    set.seed(20260709); dqrng::dqset.seed(20260709)
    fwildclusterboot::boottest(lm_dm, clustid = "sigla_uf",
                               param = "treat_x_post", B = 9999, type = "webb")$p_val
  }, error = function(e) { message("boottest failed: ", conditionMessage(e)); NA_real_ })
}
add_inf("Wild cluster bootstrap of preferred spec",
        b$est*100, b$se*100, wb_p, extra = "wildp")

# (e) Repeated-cross-section DiD (no individual FE): child-age, maternal-age and
#     state x quarter fixed effects. This deliberately does NOT net out person-
#     level selection into young motherhood, so it reproduces the cross-sectional
#     association (cf. Table 2 columns 1-3); the individual-FE estimator above,
#     which removes that selection, is the preferred null.
A_rcs <- copy(A)
A_rcs[, child_age := as.factor(age_youngest_child_any)]   # youngest child's age (0-7)
A_rcs[, mage := as.factor(V2009)]
m_rcs <- feols(home_office ~ treated + treat_x_post |
                 child_age + mage + sigla_uf^year_quarter,
               A_rcs, weights = ~V1028, cluster = ~sigla_uf, notes = FALSE)
ct_rcs <- coeftable(m_rcs)["treat_x_post", ]
add_inf("Repeated cross-section DiD, no person FE (reproduces cross-sectional selection)",
        ct_rcs[1]*100, ct_rcs[2]*100, ct_rcs[4])

# (f) Local difference-in-discontinuities around the 60-month (fifth-birthday)
#     boundary, in the child's age in months. Repeated cross-section within a
#     bandwidth h, linear running variable on each side, state x quarter FE.
didisc <- function(h) {
  s <- dt[!is.na(age_youngest_child_months_any) &
            age_youngest_child_months_any >= (60 - h) &
            age_youngest_child_months_any <  (60 + h)]
  s[, young := as.integer(age_youngest_child_months_any < 60)]
  s[, rv := age_youngest_child_months_any - 60]
  s[, yxp := young * post_mp]
  m <- feols(home_office ~ young + post_mp + yxp + rv + rv:young +
               rv:post_mp + rv:young:post_mp | sigla_uf^year_quarter,
             s, weights = ~V1028, cluster = ~sigla_uf, notes = FALSE)
  ct <- coeftable(m)["yxp", ]
  data.table(est = ct[1]*100, se = ct[2]*100, p = ct[4], n = nobs(m))
}
for (h in c(12L, 18L, 24L)) {
  d <- didisc(h)
  add_inf(sprintf("Local diff-in-disc.\\ around 60m, bandwidth $\\pm$%dm", h),
          d$est, d$se, d$p)
}

# (g) Pre-reform temporal placebo: restrict to 2018Q1-2021Q4 and assign a fake
#     reform at 2020Q2. A significant "effect" would signal spurious trends.
Pl <- A[year_quarter <= 20214]
Pl[, fake_post := as.integer(year_quarter >= 20202)]
Pl[, fake_trxp := treated * fake_post]
m_pl <- feols(home_office ~ treated + fake_trxp | id_panel + year_quarter,
              Pl, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
ct_pl <- coeftable(m_pl)["fake_trxp", ]
add_inf("Temporal placebo (fake reform 2020Q2, pre-period only)",
        ct_pl[1]*100, ct_pl[2]*100, ct_pl[4])

inf <- rbindlist(inf_rows)
inf_row <- function(r) {
  if (identical(r$extra, "wildp"))
    sprintf("%s & \\multicolumn{1}{c}{---} & %s \\\\", r$label, fmt(r$p, 3))
  else
    sprintf("%s & %s$^{%s}$ (%s) & %s \\\\", r$label, fmt(r$est),
            star(r$p), fmt(r$se), fmt(r$p, 3))
}
tab11 <- c(
  "\\begin{table}[H]\\centering",
  "\\caption{Inference and Estimator Robustness of the Home-Based-Work Effect}",
  "\\label{tab:inference}\\small",
  "\\resizebox{\\ifdim\\width>\\linewidth\\linewidth\\else\\width\\fi}{!}{%",
  "\\begin{tabular}{lcc}", "\\toprule",
  "Specification & Young child $\\times$ Post (se) & $p$-value \\\\", "\\midrule",
  unlist(lapply(seq_len(nrow(inf)), function(i) inf_row(inf[i]))),
  "\\bottomrule\\end{tabular}}",
  paste(paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Home-based work in percentage points. The first block varies the level of clustering for the preferred individual-fixed-effects estimator: household (baseline), state, and state with state-by-year-quarter fixed effects. For the wild cluster bootstrap of the preferred specification, the outcome and the regressors are residualized with respect to the individual and year-quarter fixed effects (the within-transformation), and the restricted null is tested at the state level using Webb weights and $9{,}999$ replications; the reported $p$-value is that of the preferred individual-fixed-effects estimate. The repeated-cross-section row is a separate specification---it drops the individual fixed effects and instead absorbs the youngest child's age, the mother's age, and state-by-year-quarter fixed effects---and is not the model underlying the reported bootstrap $p$-value. The local difference-in-discontinuities rows compare children just below and just above the fifth-birthday (60-month) boundary within the stated bandwidth, with a linear running variable on each side. The temporal placebo restricts the sample to 2018Q1--2021Q4 and assigns a fake reform in 2020Q2. ", WEIGHT_NOTE), SIGNIF_NOTE),
  "\\end{table}")
writeLines(tab11, file.path(TABLE_DIR, "tabE2_inference.tex"))

# =============================================================================
# Table E.3 — differential attrition and inverse-probability weighting (Comment 9)
# =============================================================================
# Retention: does the probability of reappearing in the immediately following
# quarter differ for young-child women after the reform? R_{i,t+1} regressed on
# Young child x Post with year-quarter FE. A significant coefficient would signal
# post-reform differential attrition that individual FE do not fix.
setorder(dt, id_panel, year_quarter)
dt[, next_q := shift(year_quarter, type = "lead"), by = id_panel]
dt[, reappear := as.integer(!is.na(next_q) & next_q == year_quarter + 1L)]
# Interview round 1-4 only (round 5 is the last possible interview, cannot reappear).
Aret <- dt[(has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)) & V1016 < 5]
m_ret <- feols(reappear ~ treated + treat_x_post | year_quarter,
               Aret, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
ct_ret <- coeftable(m_ret)["treat_x_post", ]

# IPW: weight each observation by 1 / P(reappear) x survey weight and re-estimate
# the main DiD, so that under-retained cells are up-weighted. P(reappear) from a
# logit on demographics, child-age, and quarter.
Aret[, retp := predict(feglm(reappear ~ V2009 + I(V2009^2) + higher_educ +
                               factor(age_youngest_child_any) + factor(year_quarter),
                             Aret, family = binomial(), weights = ~V1028), type = "response")]
retmap <- Aret[, .(id_panel, year_quarter, retp)]
A_ipw <- merge(A, retmap, by = c("id_panel", "year_quarter"), all.x = TRUE)
A_ipw[, ipw := V1028 / pmax(retp, 0.05)]
A_ipw[is.na(retp), ipw := V1028]
m_ipw <- feols(home_office ~ treated + treat_x_post | id_panel + year_quarter,
               A_ipw, weights = ~ipw, cluster = ~id_dom, notes = FALSE)
ct_ipw <- coeftable(m_ipw)["treat_x_post", ]

att <- rbindlist(list(
  data.table(label = "Differential attrition: P(reappear next quarter)",
             est = ct_ret[1]*100, se = ct_ret[2]*100, p = ct_ret[4]),
  data.table(label = "Home-based work, inverse-retention-probability weighted",
             est = ct_ipw[1]*100, se = ct_ipw[2]*100, p = ct_ipw[4])
))
att_row <- function(r) sprintf("%s & %s$^{%s}$ (%s) & %s \\\\",
                               r$label, fmt(r$est), star(r$p), fmt(r$se), fmt(r$p, 3))
tab12 <- c(
  "\\begin{table}[H]\\centering",
  "\\caption{Panel Attrition and Inverse-Probability-Weighted Estimate}",
  "\\label{tab:attrition}\\small",
  "\\begin{tabular}{lcc}", "\\toprule",
  "Specification & Young child $\\times$ Post (se) & $p$-value \\\\", "\\midrule",
  unlist(lapply(seq_len(nrow(att)), function(i) att_row(att[i]))),
  "\\bottomrule\\end{tabular}",
  paste(paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} The first row regresses an indicator for reappearing in the immediately following quarter on Young child $\\times$ Post with year-quarter fixed effects, among women in interview rounds 1--4 (round 5 cannot reappear); a coefficient near zero means the reform did not change the retention of young-child women differentially, so panel attrition does not compose the estimation sample around the reform. The second row re-estimates the preferred home-based-work DiD weighting each observation by the survey weight times the inverse predicted probability of retention (from a logit on age, education, child age, and quarter), up-weighting under-retained cells. ", WEIGHT_NOTE), CLUSTER_NOTE, SIGNIF_NOTE),
  "\\end{table}")
writeLines(tab12, file.path(TABLE_DIR, "tabE3_attrition.tex"))

# =============================================================================
# Table E.4 — decomposition of the identifying variation (Comment 5)
# =============================================================================
# With individual FE and a common post date, beta is identified by within-woman
# variation in Young child x Post. Classify each woman observed both before and
# after 2022Q2 by how her eligibility moves, and re-estimate on the cleanest
# subset (women whose eligibility status is STABLE across the reform, so beta is
# a pure pre/post contrast rather than a birth or age-out).
span <- A[, .(pre = any(post_mp == 0), post = any(post_mp == 1),
              yc_pre  = any(post_mp == 0 & has_child_u4 == 1),
              yc_post = any(post_mp == 1 & has_child_u4 == 1),
              ct_pre  = any(post_mp == 0 & has_child_u4 == 0),
              ct_post = any(post_mp == 1 & has_child_u4 == 0),
              ever_yc = any(has_child_u4 == 1)), by = id_panel]
span_both <- span[pre & post]
span_both[, category := fcase(
  yc_pre & yc_post & !ct_pre & !ct_post, "Stable young-child across reform",
  ct_pre & ct_post & !yc_pre & !yc_post, "Stable comparison across reform",
  !yc_pre & yc_post,                     "Entered eligibility (birth)",
  yc_pre & !yc_post,                     "Left eligibility (child aged out)",
  default = "Other / multiple switches")]
decomp <- span_both[, .(persons = .N), by = category]
decomp[, share := 100 * persons / sum(persons)]
setorder(decomp, -persons)

# Re-estimate on the two stable groups only (clean pre/post contrast).
stable_ids <- span_both[category %in% c("Stable young-child across reform",
                                        "Stable comparison across reform"), id_panel]
A_stable <- A[id_panel %in% stable_ids]
m_stable <- feols(home_office ~ treated + treat_x_post | id_panel + year_quarter,
                  A_stable, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
ct_stable <- coeftable(m_stable)["treat_x_post", ]

dec_row <- function(r) sprintf("%s & %s & %s\\%% \\\\", r$category, fmt0(r$persons), fmt(r$share, 1))
tab13 <- c(
  "\\begin{table}[H]\\centering",
  "\\caption{Eligibility Paths among Women Observed Before and After the Reform}",
  "\\label{tab:identification}\\small",
  "\\begin{tabular}{lcc}", "\\toprule",
  "Woman's eligibility path (observed pre and post) & Persons & Share \\\\", "\\midrule",
  unlist(lapply(seq_len(nrow(decomp)), function(i) dec_row(decomp[i]))),
  "\\midrule",
  sprintf("\\multicolumn{3}{@{}l}{\\textit{DiD re-estimated on stable-status women only:} %s$^{%s}$ (%s) pp} \\\\",
          fmt(ct_stable[1]*100), star(ct_stable[4]), fmt(ct_stable[2]*100)),
  "\\bottomrule\\end{tabular}",
  paste(paste0("\\par\\vspace{3pt}\\footnotesize\\raggedright \\textit{Notes:} Among women observed both before and after the reform (2022Q2), the table classifies each by how her eligibility (a young child in the household) moves over the panel. Most retain a stable eligibility status across the reform, whose pre/post contrast is uncontaminated by a birth or a child ageing out; the table reports person counts, not the econometric weight each path carries in the pooled estimator. The final row re-estimates ", EQ_REF, " on the stable-status women only, as a check that the pooled null is not driven solely by the switchers. The person counts and shares are unweighted; the final-row regression is weighted by the survey weights."), CLUSTER_NOTE, SIGNIF_NOTE),
  "\\end{table}")
writeLines(tab13, file.path(TABLE_DIR, "tabE4_identification.tex"))

# =============================================================================
# Console summary
# =============================================================================
cat("\n=== Table 4: home-based work by predetermined subsample (pp) ===\n")
print(estim[, .(label = substr(gsub("\\$|\\\\times|\\\\", "", label), 1, 40),
                est = round(est_pp, 2), ci_lo = round(ci_lo, 2), ci_hi = round(ci_hi, 2),
                premean = round(premean_pp, 1), npers = fmt0(npers))])
cat("\n=== Table 5: equivalence (TOST) ===\n")
print(equiv[, .(label = substr(gsub("\\$|\\\\times|\\\\", "", label), 1, 40),
                est = round(est_pp, 2), sesoi, tost_p = round(tost_p, 3), equiv_verdict)])
cat("\n=== Table E.2: inference/estimator robustness (pp) ===\n")
print(inf[, .(label = substr(gsub("\\$|\\\\quad|\\\\times|\\\\pm|\\\\", "", label), 1, 52),
              est = round(est, 2), se = round(se, 2), p = round(p, 3))])
cat("\nWild cluster bootstrap p-value (Webb, 27 states):", round(wb_p, 4), "\n")
cat("\n=== Table E.3: attrition / IPW (pp) ===\n")
print(att[, .(label = substr(label, 1, 52), est = round(est, 2), se = round(se, 2), p = round(p, 3))])
cat("\n=== Table E.4: identification decomposition ===\n")
print(decomp)
cat(sprintf("Stable-status re-estimate: %.2f (%.2f) pp, p=%.2f\n",
            ct_stable[1]*100, ct_stable[2]*100, ct_stable[4]))
message("\n=== 08_referee_revision.R complete ===")
