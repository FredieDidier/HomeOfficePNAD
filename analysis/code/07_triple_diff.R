# =============================================================================
# 07_triple_diff.R — triple-difference (DDD) with men, and the men placebo.
#
# main_data.RData now holds both sexes. Men with young children are ALSO eligible
# under Art. 75-F (the law is not gender-restricted), so men are not a pure
# placebo for eligibility; instead they net out any generic "parent of a young
# child, post-2022" shock, isolating the WOMAN-specific response.
#
#   men DiD    : home_office ~ treated + treat_x_post | id_panel + year_quarter   (female==0)
#   women DiD  : same, female==1                                                  (= Table 3, col 1)
#   DDD        : home_office ~ treated + treated:female + treat_x_post
#                             + treat_x_post:female | id_panel + female^year_quarter
#                The coefficient on treat_x_post:female is the DDD (extra effect
#                for women vs men). female^year-quarter FE absorb any female-
#                specific time shock; individual FE absorb sex and fixed traits.
#
# Sample: treated (child <=4) vs Control A (child 5-7), both sexes, 18-49,
# head/spouse. Weighted, clustered at id_dom.
#
#   Table 8   — first stage: men / women / DDD
#   Table 8b  — DDD across all outcomes (men effect + DDD row)
# =============================================================================

library(data.table)
library(fixest)
library(here)

DROPBOX_ROOT <- "/Users/fredie/Library/CloudStorage/Dropbox/HomeOfficePNAD"
OUTPUT_PATH  <- file.path(DROPBOX_ROOT, "build", "output")
TABLE_DIR    <- here("analysis", "output", "tables")

load(file.path(OUTPUT_PATH, "main_data.RData"))
setDT(dt)
dt <- dt[is_head_or_spouse == 1 & panel_matched == 1]
setnames(dt, "VD4031", "hours_usual")

S <- dt[has_child_u4 == 1 | (has_child_5_7 == 1 & has_child_u4 == 0)]
S[, tr_fem   := treated * female]
S[, trxp_fem := treat_x_post * female]

dict <- c(treat_x_post = "Treated $\\times$ Post", trxp_fem = "Treated $\\times$ Post $\\times$ Female",
          treated = "Treated (child $\\leq$4)", tr_fem = "Treated $\\times$ Female",
          home_office = "Home office", rendimento_habitual_real = "Real income",
          hours_usual = "Usual hours", employed = "Employed", in_labor_force = "In labor force",
          on_maternity_leave = "Maternity leave", id_panel = "Individual", id_dom = "Household",
          year_quarter = "Year-quarter", female = "Female")

did  <- function(sample, y = "home_office")
  feols(as.formula(sprintf("%s ~ treated + treat_x_post | id_panel + year_quarter", y)),
        sample, weights = ~V1028, cluster = ~id_dom, notes = FALSE)
ddd  <- function(y = "home_office")
  feols(as.formula(sprintf("%s ~ treated + tr_fem + treat_x_post + trxp_fem | id_panel + female^year_quarter", y)),
        S, weights = ~V1028, cluster = ~id_dom, notes = FALSE)

# ---- Table 8: first stage, men / women / DDD -------------------------------
etable(did(S[female == 0]), did(S[female == 1]), ddd(),
       tex = TRUE, file = file.path(TABLE_DIR, "tab08_triple_diff.tex"), replace = TRUE,
       dict = dict, headers = c("Men", "Women", "DDD"),
       fitstat = ~ n + r2, digits = 3, digits.stats = 3,
       title = "Triple Difference: Home Office, Men vs.\\ Women",
       label = "tab:triple_diff",
       notes = "Columns 1--2 are separate DiDs for men and women (treated $=$ child $\\leq$4 vs.\\ Control A). Column 3 is the pooled triple difference; the coefficient Treated $\\times$ Post $\\times$ Female is the extra effect for women relative to men, with female$\\times$year-quarter fixed effects absorbing any sex-specific time shock. Individual FE throughout; weighted; SE clustered at the household. $^{*}$/$^{**}$/$^{***}$: 10/5/1\\%.")

# ---- Table 8b: DDD across outcomes -----------------------------------------
outcomes <- c("home_office", "rendimento_habitual_real", "hours_usual",
              "employed", "in_labor_force", "on_maternity_leave")
ddd_mods <- setNames(lapply(outcomes, ddd), outcomes)
etable(ddd_mods,
       tex = TRUE, file = file.path(TABLE_DIR, "tab08b_triple_diff_outcomes.tex"), replace = TRUE,
       dict = dict, fitstat = ~ n + r2, digits = 3, digits.stats = 3,
       title = "Triple Difference Across Outcomes",
       label = "tab:triple_diff_outcomes",
       notes = "Each column is a triple-difference regression with the same specification as the first-stage triple difference. Reported: the men effect (Treated $\\times$ Post) and the female differential (Treated $\\times$ Post $\\times$ Female). $^{*}$/$^{**}$/$^{***}$: 10/5/1\\%.")

# ---- Console ---------------------------------------------------------------
cat("\n=== First stage: men / women / DDD (home office, pp) ===\n")
cm <- coeftable(did(S[female == 0]))["treat_x_post", ]
cw <- coeftable(did(S[female == 1]))["treat_x_post", ]
cd <- coeftable(ddd())
cat(sprintf("  Men   (treat x post):          %.2f (%.2f) p=%.2f\n", cm[1]*100, cm[2]*100, cm[4]))
cat(sprintf("  Women (treat x post):          %.2f (%.2f) p=%.2f\n", cw[1]*100, cw[2]*100, cw[4]))
cat(sprintf("  DDD   (treat x post x female): %.2f (%.2f) p=%.2f\n",
            cd["trxp_fem",1]*100, cd["trxp_fem",2]*100, cd["trxp_fem",4]))
cat("\n=== DDD (treat x post x female) across outcomes ===\n")
for (y in outcomes) {
  ct <- coeftable(ddd_mods[[y]])["trxp_fem", ]
  sc <- if (y %in% c("rendimento_habitual_real", "hours_usual")) 1 else 100
  cat(sprintf("  %-26s %.3f (%.3f) p=%.2f\n", y, ct[1]*sc, ct[2]*sc, ct[4]))
}
message("\n=== 07_triple_diff.R complete ===")
