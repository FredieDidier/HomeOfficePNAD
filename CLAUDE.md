# HomeOfficePNAD — Project Guide

## Project Overview

Empirical paper (working title *"A Priority That Does Not Bind"*) asking whether **MP 1108/2022 → Law 14.442/2022 (Art. 75-F)** — which orders employers to give priority telework access to employees with children/dependents under 4 — causally affected women's labor-market outcomes and fertility. MP enacted **25 Mar 2022** (published 28 Mar), converted to Law 14.442 on **2 Sep 2022**.

> **Art. 75-F:** "Employers must give priority to employees with disabilities and to employees with children or minors under judicial guardianship up to 4 years of age in the allocation of positions for activities that can be performed through telework or remote work."

**Result:** a precisely-estimated **null** — a discretionary, unenforceable priority moved neither telework take-up, nor occupational sorting, nor labor outcomes. The paper is written now, as the null; it competes on identification + question + institutional argument. **Target journal: Journal of Population Economics** (see memory `style-exemplar-jpope` for the writing model, Battaglia & Brown 2025, and JPopE submission mechanics).

**Author:** Fredie Didier (fdidier@terra.com.br).

---

## Research Design

### Identification — DiD with two control groups
| Group | Role |
|---|---|
| Women with child ≤4 (`has_child_u4`) | **Treated** |
| Women with youngest child 5–7 (`has_child_5_7`) | **Control A** — headline; tight age-threshold match |
| Women with no child 0–7 | **Control B** — complementary (power + A-vs-B placebo) |

Control A is the preferred/headline control; Control B is kept (not dropped) because the **A-vs-B placebo** (5–7 vs. no-children ≈ 0) is what licenses treating 5–7 as clean, and pre-empts the "why not all women?" question. Both appear in the DiD tables; text leads with A. The **dose-response falsification**: large effect for treated vs. either control, **zero** for 5–7 vs. no-children.

`age_youngest_child_any` (youngest child of ANY age) subsumes all groups and powers the **control-window sweep** (5–6 … 5–12) in `06_robustness.R` — first stage is stable across all windows (all n.s.), so the control's upper bound doesn't drive results.

### Intent-to-Treat (ITT)
Art. 75-F is a **priority claim, not an automatic right**: the employer must prioritize eligible employees for teleworkable positions but need not grant telework to anyone, and take-up is unobserved individually. We observe **eligibility** (`has_child_u4`) and **realized outcomes** (`home_office`, income, hours…) before/after the law. So the estimand is the **ITT effect of being legally entitled to priority** — policy-relevant, but a lower bound on the effect on women actually granted telework (TOT, unobserved). `home_office` is also the **first-stage / compliance proxy**: its (null) ITT bounds how large any reduced-form ITT on wages/hours/fertility can be.

### Treatment / control / period
- **Treated:** head/spouse (V2005 ∈ {1,2,3}) with child ≤4 (`has_child_u4 == 1`).
- **Control A:** same position, youngest child 5–7. **Control B:** same position, no child ≤7.
- **Post (main):** `post_mp` = `year_quarter >= 20222` (Q2 2022; MP fell in last week of Q1, so Q1 2022 is pre).
- **Post (robustness):** `post_mp_alt` = `year_quarter >= 20221` (Q1 2022 post).

### COVID contamination
Pre-period overlaps the pandemic home-office spike (2020–2021), a potential confounder. **Main spec:** TWFE on full 2018Q1–2026Q1 panel with individual + quarter FE (quarter FE absorb COVID in levels). Diagnostic: the **event study** — check whether treated/control pre-trends diverge in 2020–2021. Empirically pre-trends are flat through COVID. **Robustness:** drop 2020–2021 (clean 2018–2019 pre-period) and `post_mp_alt`; estimates unchanged.

### Telework eligibility (`potential_telework`)
`telework_cod` in `build/01_pnadc.R` is the **126-code list from Table 2 of Costa et al. (2024)** (adapting Dingel–Neiman 2020 / Góes et al. 2020 to the COD/V4010). Flags ~29.8% of employed women. Used as a **moderator** and as an **outcome** (job switching is a mechanism), **never as a sample restriction** — conditioning on it post-policy is a bad control (occupation is endogenous to the MP). Documented in appendix §"Classifying telework-eligible occupations".

### Key outcomes
1. `home_office` — telework (V4022 ∈ {4,5}); the first stage.
2. `income_habitual_real` — real habitual monthly income.
3. `hours_usual` / `hours_effective` — weekly hours.
4. `employed`, `unemployed`, `in_labor_force` — project-derived 0/1 over the FULL sample. **Never use datazoom's raw `ocupado` as the outcome** (NA out of labor force → silently conditions on LFP).
5. `on_maternity_leave` — recent-birth proxy. DiD is significant (−0.87pp***) but `fig09` shows **strong pre-trends** → parallel trends fails → **not interpreted causally**. Only `home_office` has clean flat pre-trends.

### Sample
Women 18–49, head/spouse (`is_head_or_spouse == 1`), from Q1 2018 (V4022 availability), matched panel (`panel_matched == 1`). Unit: individual × quarter (`id_panel` + `year_quarter`); each appears 1–5 quarters (rotating panel). Every women-only script filters `female == 1 & is_head_or_spouse == 1 & panel_matched == 1`.
- **Age:** examined only as heterogeneity bands (18–29/30–39/40–49, baseline age) in `05_heterogeneity.R`; the old robustness age-windows were **removed** (redundant with the bands). The lone significant band (40–49, +1.4pp**) does not survive the **Bonferroni** correction over the 13 heterogeneity subgroups (min p 0.042→0.55; raw + Bonferroni p are columns in Table 6, cite `romanoshaikhwolf2010`). Table 6 also carries a **By race** panel (White/Non-white, both null) and an appendix companion `tab06b` (all outcomes for the 40–49 cell: only home office moves).
- **Do NOT restrict to formal/CLT** (selection on a post-treatment variable). Use `clt_private` (VD4009==1) only as the sharp heterogeneity/placebo split, never as a restriction.

---

## Stack

| Layer | Tools |
|---|---|
| Download | R (`PNADcIBGE::get_pnadc`; `datazoom.social` for the Stage-3 panel — [github.com/datazoompuc/datazoom.social](https://github.com/datazoompuc/datazoom.social)) |
| Build & analysis | R (`data.table`, `fixest`, `ggplot2`) |
| Writing | LaTeX (JPopE draft) |

Always use **`id_panel`, not `id_rs3`**, as the FE variable. Panel input files and the final dataset are `.RData`.

## Repository Layout
```
build/01_pnadc.R           Download PNADC, build panels (→Dropbox/input), merge final dataset (→Dropbox/output)
config/00_master_build.R    Sources build/01_pnadc.R
config/00_master_analysis.R Sources analysis/code/ scripts
analysis/code/
  01_descriptives.R  02_event_study.R  03_did.R  04_mechanisms.R
  05_heterogeneity.R  06_robustness.R  07_triple_diff.R  00_utils.R
analysis/output/{tables,graphs,maps}/   committed to git
latex/{paper.tex,appendix.tex,refs.bib}
dictionary/  CLAUDE.md  README.md
```

## Data (Dropbox, not git)
```
Dropbox/HomeOfficePNAD/build/{input/Panel_6..13.RData, output/main_data.RData}
```
`main_data.RData` covers **2018Q1–2026Q1**, holds **BOTH sexes** (7,150,307 obs = 3,676,650 women + 3,473,657 men). Women are the analysis sample; men enter only `07_triple_diff.R`. Path set via `DROPBOX_ROOT` at the top of `build/01_pnadc.R` (only line to change per machine); GitHub paths via `here::here()`.

> **`id_dom` is globally unique by construction.** datazoom's raw `id_dom` is unique only within a V1014 rotation group, so `build_main_data()` stores it as composite `"<V1014>_<id>"` and keys the child-flag merge on `(id_dom, V1014, year_quarter)` — required for correct clustering (`cluster = ~id_dom`). `id_rs3`/`id_panel` are already globally unique.

---

## Key Variables

| Variable | Description | Source |
|---|---|---|
| `id_rs3` | Stage-3 advanced individual panel ID (fuzzy graph matching); `NA` if unmatched. | datazoom.social |
| `id_panel` | FE variable for `feols`. = `id_rs3` when matched; unique `unmatched_<row>` otherwise (never missing). | Project |
| `panel_matched` | = 1 if `id_rs3` non-missing. | Project |
| `id_dom` | Household ID, globally-unique composite `"<V1014>_<id>"`. Clustering variable. | Project (from datazoom) |
| `home_office` | = 1 if work location is own residence (V4022 ∈ {4,5}). | datazoom (Q1 2018+) |
| `ocupado` | = 1 if employed. **NA out of labor force** — do NOT use as outcome; use `employed`. | datazoom |
| `forca_trab` / `in_labor_force` | In labor force (never NA); `in_labor_force` = clean 0/1 over all sample women. | datazoom / Project |
| `employed` | = 1 if in labor force AND occupied, else 0 (out-of-LF → 0). Use this, not `ocupado`. | Project |
| `unemployed` | = 1 if in labor force AND not occupied, else 0. | Project |
| `rendimento_habitual_real` / `income_habitual_real` | Real habitual monthly income (all jobs, deflated). | datazoom / Derived |
| `formal` / `informal` | datazoom flags. `formal`=1 includes signed-card employees (private/domestic/public), military/statutory, AND INSS-contributing self-employed — broader than CLT. Employers (VD4009=8) are neither. | datazoom |
| `clt_private` | = 1 if VD4009 == 1 (private-sector carteira-assinada = CLT). The **sharp "law binds here" group**; heterogeneity/placebo split only, never a restriction. | Derived |
| `has_child_u4` | = 1 if head/spouse with child ≤4 (V2005 ∈ {4,5,6,10,11}: biological of head+spouse (4), of head (5), stepchild (6), grandchild (10), great-grandchild (11)). **Treatment.** | HH merge |
| `has_child_u4_no_gc` / `_no_sc` | Excluding grandchildren/great-grandchildren (V2005 ∈ {4,5,6}) / excluding stepchildren (∈ {4,5,10,11}). Robustness. | HH merge |
| `has_child_5_7` (+ `_no_gc`/`_no_sc`) | = 1 if head/spouse with youngest child 5–7. **Control A.** | HH merge |
| `age_youngest_child` / `_any` | Age of youngest qualifying child ≤4 / of ANY age (subsumes all groups; powers control-window sweep). | HH merge |
| `potential_telework` | = 1 if V4010 ∈ 126 COD telework codes (Costa et al. 2024). Moderator/outcome only. | Derived from V4010 |
| `female` | = 1 if V2007 == 2. Base holds both sexes; main analyses filter `female == 1`. | Derived |
| `higher_educ` | = 1 if VD3004 == 7 (completed higher ed). ~19.7% of women. | Derived |
| `is_head_or_spouse` | = 1 if V2005 ∈ {1,2,3}. | V2005 |
| `treated` / `post_mp` / `post_mp_alt` | `has_child_u4` / `year_quarter>=20222` / `>=20221`. | Derived |
| `treat_x_post` / `_alt` | `treated × post_mp` / `× post_mp_alt` (main / robustness interaction). | Derived |
| `year_quarter` | Numeric time ID (20221 = Q1 2022 = Ano×10 + Trimestre). | Derived |
| `V1016` | Interview round (1–5). | PNADC |

---

## Conventions
- All code/comments in **English**; `data.table` throughout (no dplyr/base merge in build).
- GitHub paths via `here::here()`; Dropbox via `DROPBOX_ROOT`.
- Output → `analysis/output/{tables,graphs,maps}/`, committed. Tables are `.tex` fragments for `\input{}`.
- `treated` is always `has_child_u4` (V2005 ∈ {4,5,6,10,11}); robustness `_no_gc` / `_no_sc`. **V2005 codes 10 (grandchild) and 11 (great-grandchild) are separate** — `_no_gc` excludes both.
- SEs: cluster at `id_dom` (household) in main specs; `UPA` in robustness.
- **Survey weights (`V1028`) in EVERY spec** — PNADC is not self-weighting; there is no unweighted version of any table.
- **ggplot label text (titles/legends/strips) = plain ASCII only** (`<=`, `-`), never `≤`/`–` (rendering truncates to "..."). Unicode is fine in `.tex` (real LaTeX `$\leq$`) and in this file.

---

## Empirical Strategy — FE and covariates

**Main TWFE:**
```r
feols(outcome ~ treated + treat_x_post | id_panel + year_quarter,
      data = dt[is_head_or_spouse == 1], weights = ~V1028, cluster = ~id_dom)
```

- **Include the `treated` main effect** — eligibility is time-varying (turns on at a birth, off at age 5), so individual FE do NOT absorb it; omitting it loads the level motherhood penalty onto `treat_x_post`. (The event study handles this via `i(year_quarter, treated, ref=20221)`, which subsumes the main effect — no separate term there.)
- **Individual FE (`id_panel`): always.** The ladder in the first-stage table shows without them the first stage is +0.4pp (selection); adding them → ≈0. Never `id_rs3` alone (unmatched would pool into one spurious FE).
- **Main sample = matched panel** (`panel_matched == 1`); the 3.72% unmatched are singletons (own FE → contribute nothing). FE estimates identical with/without them; only N changes.
- **Quarter FE (`year_quarter`): always** — absorbs COVID/business cycle/national trends. Single common post date ⇒ generalized 2×2 DiD, **not** exposed to staggered-DiD negative weighting (Goodman-Bacon 2021; de Chaisemartin & D'Haultfœuille 2020).
- **Hours is an OUTCOME, not a covariate.** Same for employment status — never a RHS control.

**Do NOT include (post-treatment / bad controls):** occupation FE (`cod_2dig`), sector FE (`cnae_2dig`), employment status, job tenure, `potential_telework`, formal status. Race (`V2010`) and mostly-stable education are absorbed by individual FE.

**Specification ladder (first-stage table):** (1) OLS + demographic controls, no FE; (2) + quarter FE; (3) + individual FE; (4) + age & age² (`V2009 + I(V2009^2)`). Age's linear term is near-collinear under FE; quadratic carries the adjustment; first stage unchanged either way.

**Additional/robustness FE:** state × quarter (`sigla_uf^year_quarter`); `UPA` clustering. **Table reporting:** below coefficients report N obs, N individuals (`uniqueN(id_panel)`), N households (`uniqueN(id_dom)`), within-R²; note the clustering variable.

---

## Exhibit map (final — keyed to actual output files)

**Main text**
| Role | File | Script |
|---|---|---|
| Table 1 — Summary stats by group × period | `tab01_descriptives.tex` | 01 |
| Table 2 — First-stage ladder (`home_office`) | `tab02_did_firststage.tex` | 03 |
| Table 3 — Reduced-form outcomes, Control A | `tab03a_did_outcomes_A.tex` | 03 |
| Table 4 — Telework-eligibility moderation of first stage | `tab04_mechanism_moderation.tex` | 04 |
| Table 5 — `potential_telework` as outcome (allocation) | `tab05_mechanism_allocation.tex` | 04 |
| Table 6 — Heterogeneity (formality/sector/educ/age) | `tab06_heterogeneity.tex` | 05 |
| Table — Triple diff, first stage | `tab08_triple_diff.tex` | 07 |
| Fig — Event study, `home_office` (both controls) | `fig06_event_study_home_office` | 02 |

**Appendix**
| Role | File | Script |
|---|---|---|
| Table A0 — Panel retention | `tabA0_panel_retention.tex` | 01 |
| Table — Reduced-form outcomes, Control B | `tab03b_did_outcomes_B.tex` | 03 |
| Table — Occupation transition matrix | `tab05b_occupation_transition.tex` | 04 |
| Table — All outcomes for the age 40–49 cell (multiple-testing companion) | `tab06b_age4049_outcomes.tex` | 05 |
| Table — Robustness (first stage + log earnings) | `tab07_robustness.tex` | 06 |
| Table — Triple diff, all outcomes | `tab08b_triple_diff_outcomes.tex` | 07 |
| Fig — Heterogeneity coefplot | `fig07_heterogeneity_coefplot` | 05 |
| Fig — Control-window sweep | `fig08_control_window_sweep` | 06 |
| Fig — Event study, maternity leave (pre-trends) | `fig09_event_study_maternity` | 02 |
| §Classifying telework-eligible occupations (Costa et al. 2024 + COD dict) | appendix.tex | — |

**Descriptive figures** `fig01`–`fig04` (home-office trends, LFP/employment, two-control panels, telework-eligible subgroup) — available for appendix/slides as needed.

**Decided NOT in the paper:** `fig05` state map (`analysis/output/maps/`) — treatment has no geographic dimension (single national date), so a map is decorative and would need pre+post panels; kept in repo only.

---

## Policy Context

- **MP 1108/2022** enacted 25 Mar 2022 (published 28 Mar) → **Law 14.442/2022** (2 Sep 2022, Art. 75-F unchanged). Scope: CLT `empregados`. Mechanism: **priority, not mandate** — no automatic right, no enforcement/penalty, no request/certification requirement.
- Interpretation: a **supply-side, soft mandate** raising the chance eligible women are allocated to existing teleworkable roles. Expected first stage: `home_office` ↑ for treated. Reduced form: wages ambiguous, hours likely ↓, employment retention, fertility.
- **Q1 2022 status:** MP published in the last week of Q1; PNADC reference weeks span the quarter. Main: Q1 2022 pre; robustness (`post_mp_alt`): Q1 2022 post. Similar estimates under both ⇒ cutoff doesn't drive results.

## Target Journals (most → least likely)
1. **Journal of Population Economics** — primary (family policy, female labor supply, fertility, quasi-experiments; receptive to clean nulls).
2. **Labour Economics** — second (policy DiD).
3. **Journal of Development Economics** — stretch (developing-country policy eval, sharp ID; higher bar for a null).

See memory `style-exemplar-jpope` for the JPopE writing model and submission mechanics.
