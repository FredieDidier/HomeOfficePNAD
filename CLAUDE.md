# HomeOfficePNAD — Project Guide

## Project Overview

Empirical paper (title *"The Labor-Market Effects on Mothers of a Telework Priority for Parents of Young Children: Evidence from Brazil"* — retitled to a gender-neutral framing in the **July 2026 referee revision**; see the "Referee revision" section at the bottom of this file) asking whether **MP 1108/2022 → Law 14.442/2022 (Art. 75-F)** — which orders employers to give priority telework access to employees with children/dependents under 4 — causally affected women's labor-market outcomes and fertility. MP enacted **25 Mar 2022** (published 28 Mar), converted to Law 14.442 on **2 Sep 2022**.

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

`age_youngest_child_any` (youngest child of ANY age) subsumes all groups and powers the **control-window sweep** (5 … 5–12, i.e. control = age-5-only up to 5–12) in `06_robustness.R` — first stage is stable across all windows (all n.s.), so the control's upper bound doesn't drive results.

**"Up to 4 years" reading + exact-birthdate robustness (Artur's point).** Treatment `has_child_u4` = completed age ≤4 = child is **4 or younger / under 5**, so under a stricter reading of the statute (eligibility ending on the fourth rather than the fifth birthday) some of these
children would belong in the comparison group. Completed-year age (V2009) can't place a child relative to the boundary, so `age_youngest_child_months_any` (precise age in months from birth month/year V20081/V20082 at the quarter midpoint; day of birth unused since interview date is unknown) powers an **exact-birthdate treatment-ceiling sweep** in `06_robustness.R` (rows in `tab07`): ceiling 48/49/51/53/60 months (strict "until 4th birthday" → 60m = main definition). All null. Main spec keeps completed-year age (clean for everyone; ~7% of under-4 kids lack usable DOB and drop only from these rows). Paper wording standardized "under 4" → "aged 4 or younger".

### Intent-to-Treat (ITT)
Art. 75-F is a **priority claim, not an automatic right**: the employer must prioritize eligible employees for teleworkable positions but need not grant telework to anyone, and take-up is unobserved individually. We observe **eligibility** (`has_child_u4`) and **realized outcomes** (`home_office`, earnings, hours…) before/after the law. So the estimand is the **ITT effect of being legally entitled to priority** — policy-relevant, but a lower bound on the effect on women actually granted telework (TOT, unobserved). `home_office` is also the **first-stage / compliance proxy**: its (null) ITT bounds how large any reduced-form ITT on wages/hours/fertility can be.

### Treatment / control / period
- **Treated:** head/spouse (V2005 ∈ {1,2,3}) with child ≤4 (`has_child_u4 == 1`).
- **Control A:** same position, youngest child 5–7. **Control B:** same position, no child ≤7.
- **Post (main):** `post_mp` = `year_quarter >= 20222` (Q2 2022; MP fell in last week of Q1, so Q1 2022 is pre).
- **Post (robustness):** `post_mp_alt` = `year_quarter >= 20221` (Q1 2022 post).

### COVID contamination
Pre-period overlaps the pandemic home-office spike (2020–2021), a potential confounder. **Main spec:** TWFE on full 2018Q1–2026Q1 panel with individual + year-quarter FE (year-quarter FE absorb COVID in levels). Diagnostic: the **event study** — check whether treated/control pre-trends diverge in 2020–2021. Empirically pre-trends are flat through COVID. **Robustness:** drop 2020–2021 (clean 2018–2019 pre-period) and `post_mp_alt`; estimates unchanged.

The event study drifts up to ~1pp in a few 2024–25 quarters. To pre-empt "the null just hides a delayed effect", `06_robustness.R` splits `treat_x_post` into an **early (2022–2023) vs late (2024–2026)** window in one regression (rows in `tab07`): early −0.21pp, late **+0.18pp**, both n.s., late CI rules out >~0.9pp. The late drift does not survive aggregation.

### Telework eligibility (`potential_telework`)
`telework_cod` in `build/01_pnadc.R` is the **126-code list from Table 2 of Costa et al. (2024)** (adapting Dingel–Neiman 2020 / Góes et al. 2020 to the COD/V4010). Flags ~29.8% of employed women. Used as a **moderator** and as an **outcome** (job switching is a mechanism), **never as a sample restriction** — conditioning on it post-policy is a bad control (occupation is endogenous to the MP). Documented in appendix §"Classifying telework-eligible occupations".

### Key outcomes
1. `home_office` — telework (V4022 ∈ {4,5}); the first stage.
2. `earnings_habitual_real` — real habitual monthly earnings. **In every OUTCOME regression table it enters in LOGS** (`log_earnings = log` of positive real earnings), so the coefficient is an approximate proportional effect — matching the robustness log-earnings rows. This is the **intensive margin** (earnings *conditional on working*), the counterpart to `hours_usual`. Non-workers are NA and feols drops them per-column — **do NOT zero-fill**: (i) `log(0)` is undefined, and (ii) the "no work ⇒ zero earnings" extensive margin is already captured by `employed` / `in_labor_force` (0/1 over the FULL sample, non-worker = 0), so zeroing earnings would double-count it and break parity with `hours_usual` (also conditional on working). Conditioning earnings on employment is selection on a post-treatment variable, but it is innocuous here since the reform moves neither the first stage nor employment. Kept in **levels only** in the Table 1 descriptives (a summary stat, not a regression).
3. `hours_usual` (VD4031) — usual weekly hours, the intensive-margin hours outcome (conditional on working). `hours_effective` (VD4035) exists in the data but is **not used**: not an outcome, and dropped from the Table 1 descriptives (only `hours_usual` is shown, to match the regressions). Referred to in text as "usual weekly hours".
4. `employed`, `unemployed`, `in_labor_force` — project-derived 0/1 over the FULL sample. **Never use datazoom's raw `ocupado` as the outcome** (NA out of labor force → silently conditions on LFP). The +1pp DiD on `employed`/`in_labor_force` is **not causal**: joint pre-trend tests reject flat pre-trends (employed χ²(16)=39.6, LFP =38.0, both p<0.01), so they are differential trends, not a reform break.
5. `on_maternity_leave` — recent-birth proxy. DiD is significant (−0.87pp***) but `fig09` shows **strong pre-trends** (χ²(16)=282, p<0.001) → parallel trends fails → **not interpreted causally**. **Only `home_office` has clean flat pre-trends** (χ²(16)=12.6, p=0.70) and is read causally.

### Sample
Women 18–49, head/spouse (`is_head_or_spouse == 1`), from Q1 2018 (V4022 availability), matched panel (`panel_matched == 1`). Unit: individual × quarter (`id_panel` + `year_quarter`); each appears 1–5 quarters (rotating panel). Every women-only script filters `female == 1 & is_head_or_spouse == 1 & panel_matched == 1`.
- **Age:** examined only as heterogeneity bands (18–29/30–39/40–49, baseline age) in `05_heterogeneity.R`. **Two** of the **15** heterogeneity subgroups are raw-significant with **opposite signs** — 40–49 (+1.4pp**) and single mothers (−1.6pp**) — and **neither survives** the **Holm (1979)** step-down correction (min p 0.024→0.36, the single-mother cell; raw + Holm p are columns in Table 6, cite `holm1979`). The opposite signs + Holm failure are the multiple-testing point in action. Holm chosen over plain Bonferroni (uniformly more powerful, assumption-free) and over Romano-Wolf (needs a same-sample bootstrap `wildrwolf` can't do for overlapping subsamples). Table 6 also carries a **By race** (White/Non-white) and a **By household structure** panel (single vs partnered mother; `single_mother` = female lone head, Artur's suggestion — the single-mother −1.6pp is *wrong-signed* for a demand-driven priority effect and dies under Holm). **The −1.6pp is defused three ways**: (i) it's concentrated among **non-CLT** single mothers (−2.1pp**, the group the law *can't* bind) and is **null (+0.2pp) among CLT** single mothers it *does* bind → not a legal-channel effect — shown as a **"Single mothers, by contract type" decomposition panel** at the bottom of Table 6 (Holm-p = "---", NOT in the 15-test family, per `decomp_note`); (ii) single-mother pre-trends are **flat** (χ²(16)=19.3, p=0.25, from `02`) → not a differential trend (paper footnote); (iii) dies under Holm. **Both Table 6 and Table D.1 (tab07) use a compact one-line format** (est (se) inline, not stacked). Table 6 fits one page and is wrapped in shrink-only `\resizebox`. Table D.1 **outgrew a single page** (after the symmetric age-donut + by-child-age panels were added) and is emitted as a **`longtable`** (needs `\usepackage{longtable}` in `paper.tex`) that breaks across two pages, repeating the column header and carrying the notes in the final footer — so it is NOT wrapped in `\resizebox`. The decomposition rows are **also shown in fig07 (D.2)** in a distinct colour (red) with a bottom legend. **Why the CLT/non-CLT rows are NOT in the Holm family:** they split one already-listed cell (single mother = CLT ∪ non-CLT) rather than adding new subgroup hypotheses, so they're a post-hoc, mechanically dependent *channel check*, not additional tests — explained in the paper text + table note; Holm-p shows "---" for them. The Holm correction is one of three sufficient answers to the flagged cells;
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
`main_data.RData` covers **2018Q1–2026Q1**, holds **BOTH sexes** (7,150,307 obs = 3,676,650 women + 3,473,657 men). Women are the analysis sample; men enter only `07_triple_diff.R`. **`DROPBOX_ROOT` is set once in `config/config.R`** (the only path to change per machine); every build/analysis script does `source(here::here("config", "config.R"))`. GitHub paths via `here::here()`.

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
| `earnings_habitual_real` | Real habitual monthly earnings (all jobs, deflated). Renamed from datazoom's `rendimento_habitual_real` in `build_main_data()` (`build/01_pnadc.R`). **Enters outcome regressions as `log_earnings`** (log of positive earnings). | datazoom / Derived |
| `formal` / `informal` | datazoom flags. `formal`=1 includes signed-card employees (private/domestic/public), military/statutory, AND INSS-contributing self-employed — broader than CLT. Employers (VD4009=8) are neither. | datazoom |
| `clt_private` | = 1 if VD4009 == 1 (private-sector carteira-assinada = CLT). The **sharp "law binds here" group**; heterogeneity/placebo split only, never a restriction. | Derived |
| `has_child_u4` | = 1 if head/spouse with child ≤4 (V2005 ∈ {4,5,6,10,11}: biological of head+spouse (4), of head (5), stepchild (6), grandchild (10), great-grandchild (11)). **Treatment.** | HH merge |
| `has_child_u4_no_gc` / `_no_sc` / `_no_gc_sc` | Excluding grandchildren/great-grandchildren (V2005 ∈ {4,5,6}) / excluding stepchildren (∈ {4,5,10,11}) / excluding both (∈ {4,5}, biological children only). Robustness. | HH merge |
| `has_child_5_7` (+ `_no_gc`/`_no_sc`/`_no_gc_sc`) | = 1 if head/spouse with youngest child 5–7. **Control A.** | HH merge |
| `age_youngest_child` / `_any` | Age (completed years) of youngest qualifying child ≤4 / of ANY age (subsumes all groups; powers control-window sweep). | HH merge |
| `age_youngest_child_months_any` | Precise age **in months** of the youngest child of ANY age, from birth month/year (V20081/V20082) at the quarter midpoint. Continuous; powers the exact-birthdate treatment-ceiling sweep in `06_robustness.R`. NA (~7% of under-4 kids) when youngest child's DOB unusable. Robustness only — main spec uses completed-year age. | HH merge |
| `potential_telework` | = 1 if V4010 ∈ 126 COD telework codes (Costa et al. 2024). Moderator/outcome only. | Derived from V4010 |
| `female` | = 1 if V2007 == 2. Base holds both sexes; main analyses filter `female == 1`. | Derived |
| `higher_educ` | = 1 if VD3004 == 7 (completed higher ed). ~19.7% of women. | Derived |
| `is_head_or_spouse` | = 1 if V2005 ∈ {1,2,3}. | V2005 |
| `single_mother` | = 1 if female household head (V2005 == 1) with **no co-resident spouse/partner** (no household member V2005 ∈ {2,3}; quarterly PNADC has no marital-status var). In the child-having analysis sample = single/lone mother. **Baseline heterogeneity moderator only** (Table 6 "By household structure"), never a restriction. ~22% of sample women, ~16% of treated. | HH roster (V2005) |
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
- **ggplot label text (titles/legends/strips) = plain ASCII only** (`<=`, `-`), never `≤`/`–` (rendering truncates to "..."). Applies to axis text too: age bands are `"Age 18--29"` (LaTeX `--`) in the *table*, converted to `"Age 18-29"` for the *figure* (`gsub("--","-")` in `05_heterogeneity.R`). Unicode is fine in `.tex` (real LaTeX `$\leq$`) and in this file.
- **Regression-table notes follow ONE house style** — shared fragments in `00_utils.R` (`EQ_REF`, `WEIGHT_NOTE`, `CLUSTER_NOTE`, `UNITS_NOTE`, `SIGNIF_NOTE`); build each note as `paste(<lead sentence + EQ_REF inline>, WEIGHT_NOTE, CLUSTER_NOTE, SIGNIF_NOTE)`. Structure: what each column estimates (with a green `\eqref{eq:did}` = "Eq. (1)" link) → sample → units → weighting → clustering → significance. SEs are always "clustered at the **household level** in parentheses". Descriptive tables (tab01, tab05b, tabA1) are exempt.

---

## Empirical Strategy — FE and covariates

**Main TWFE:**
```r
feols(outcome ~ treated + treat_x_post | id_panel + year_quarter,
      data = dt[is_head_or_spouse == 1], weights = ~V1028, cluster = ~id_dom)
```

**Why exactly this spec, and nothing more (the intuition).** The RHS is deliberately minimal — `treated + treat_x_post`, two sets of FE, no covariates. Each choice defends against one threat:

- **Individual FE — because treated women aren't a random slice.** Women with a child ≤4 differ *permanently* from women whose youngest is 5–7: younger, less formal, different occupations, different tastes for working at home. A plain treated-vs-control comparison confounds "effect of the law" with "who these women are" (selection into young motherhood). Individual FE compare **each woman to herself over time**, differencing out everything fixed about her — observed *and* unobserved — so identification comes only from within-woman change around the reform. The ladder is the proof: demographics and year-quarter FE don't budge the +0.4pp; only individual FE collapse it to ≈0, i.e., the selection is on **time-invariant unobservables** no control could capture.
- **No sample restriction to formal / telework-eligible — because those are outcomes, not fixed traits.** A woman can move *into* a teleworkable occupation (to claim the priority) or into/out of formal employment *because of* the reform. Filtering the sample on such a variable conditions on a **post-treatment outcome** — a bad control that selects on the treatment's own effect and biases the estimate. So keep the **full** eligible sample and use occupation/formality only as **baseline** moderators (frozen at first observation) or as outcomes, never as filters.
- **No occupation/sector/employment/hours covariates, and no time-varying controls — same reason.** Anything the reform can move (occupation, sector, formal status, employment, hours) is a *channel* the effect could run through; "controlling" for it removes part of the very effect we want and can induce collider bias. The clean rule: let **individual FE** soak up everything time-invariant (education, race, permanent traits) and **year-quarter FE** soak up common time shocks (COVID, cycle), and add **nothing** the treatment could touch — hence the minimal RHS.

- **Include the `treated` main effect** — eligibility is time-varying (turns on at a birth, off at age 5), so individual FE do NOT absorb it; omitting it loads the level motherhood penalty onto `treat_x_post`. (The event study handles this via `i(year_quarter, treated, ref=20221)`, which subsumes the main effect — no separate term there.)
- **Individual FE (`id_panel`): always.** The ladder in the first-stage table shows without them the first stage is +0.4pp (selection); adding them → ≈0. Never `id_rs3` alone (unmatched would pool into one spurious FE).
- **Main sample = matched panel** (`panel_matched == 1`); the 3.7% unmatched are singletons (own FE → contribute nothing). FE estimates identical with/without them; only N changes.
- **Year-quarter FE (`year_quarter`): always** — absorbs COVID/business cycle/national trends. Single common post date ⇒ generalized 2×2 DiD, **not** exposed to staggered-DiD negative weighting (Goodman-Bacon 2021; de Chaisemartin & D'Haultfœuille 2020).
- **Hours is an OUTCOME, not a covariate.** Same for employment status — never a RHS control.

**Do NOT include (post-treatment / bad controls):** occupation FE (`cod_2dig`), sector FE (`cnae_2dig`), employment status, job tenure, `potential_telework`, formal status. Race (`V2010`) and mostly-stable education are absorbed by individual FE.

**Specification ladder (first-stage table, 5 cols):** (1) raw OLS, no controls/FE; (2) + demographic controls; (3) + quarter FE; (4) + individual FE (**preferred**); (5) + age² only (`I(V2009^2)` — the linear age term is dropped because age = calendar time − birth cohort is collinear with individual+quarter FE, so only the quadratic carries any age adjustment; table label reads "Age² only"). Cols 1–3 all give +0.4pp\* (demographics and quarter FE barely move it); only individual FE collapses it to ≈0 — the selection is on time-invariant unobservables, not observed demographics. First stage unchanged with or without the age² term. FE rows list **Individual above Year-quarter** (post-processing in `03_did.R` reorders them to match the other tables).

**Additional/robustness FE:** state × year-quarter (`sigla_uf^year_quarter`); `UPA` clustering. **Table reporting:** below coefficients report N obs, N individuals (`uniqueN(id_panel)`), N households (`uniqueN(id_dom)`), within-R²; note the clustering variable.

---

## Results guide — why each result is in the paper

The argument, exhibit by exhibit in paper order. This is the "are we telling the story right?" checklist; the **Exhibit map** below says *where* each lives (file/script). One narrative: *the compliance channel (home office) does not move, so nothing downstream can, and the null is uniform, robust, and not gendered.*

**Setup**
- **Table 1 — descriptives.** Establishes the three groups and two load-bearing facts: (i) home office is rare (~5%) and rises *in parallel* across groups; (ii) treated women are younger, less formal, less teleworkable. *Why it's needed:* the level gaps justify **individual FE** (not cross-sectional matching), and the tiny teleworkable share foreshadows *why* the priority has almost nothing to bite on.

**First stage (the crux)**
- **Table 2 — first-stage ladder.** The central result. Raw / +demographics / +quarter-FE all give **+0.4pp\***; only **individual FE** collapse it to ≈0. *Why it's needed:* proves the naive positive is **selection into young motherhood on time-invariant unobservables**, not the law. This is the identification — and the null first stage **bounds every downstream outcome**.
- **Fig. 2 (fig06) — event study, home office.** Flat pre-trends (incl. through COVID), no break at the reform; the late drift dies in the early/late split. *Why it's needed:* validates **parallel trends** and shows the null is dynamic, not an averaging artifact. Home office is the **only** outcome with clean pre-trends → the one read causally.

**Reduced form**
- **Table 3 — outcomes, Control A.** Log earnings and hours are **precise zeros**; employment/LFP/maternity are significant but **fail pre-trend tests** → not causal. *Why it's needed:* nothing downstream moves through the (null) telework channel; the ITT-bounds-everything logic in action, with honest handling of stray significant coefficients.

**Mechanisms**
- **Table 4 — moderation by baseline teleworkability.** Null **even among teleworkable women** — the only group a telework priority could bind. *Why it's needed:* rules out "it works where it can"; the null isn't just dilution by non-teleworkable jobs.
- **Table 5 — allocation (telework-eligible occ. as outcome).** Treated women **don't sort into** teleworkable jobs. *Why it's needed:* rules out a "priority-seeking" occupational response; the null isn't hidden by endogenous occupation change.

**Heterogeneity**
- **Table 6 — heterogeneity + Holm.** Null across formality/sector/education/race/**household structure (single vs partnered mother)**/age; the formality & sector splits **double as channel placebos** (law binds only CLT-private → effect should show there, doesn't), and the single-mother split targets the group with the strongest telework demand (Artur's suggestion). Two raw-significant cells (40–49 +1.4pp, single mother −1.6pp, opposite signs) both die under Holm. *Why it's needed:* the null is **uniform, including among single mothers and where the statute bites hardest**; pre-empts "you didn't look hard enough" and multiple-testing.

**Triple difference**
- **Table 7 (tab08) — triple diff, men vs. women.** Men are also null; the DDD is insignificant. *Why it's needed:* nets out any generic "parent of a young child, post-2022" shock and shows **the null is not gendered** — the reinforcement move (à la [[style-exemplar-jpope]]).

**Appendix (support & falsification)**
- **Table D.1 — robustness.** Null survives alt cutoff, treatment variants, COVID drop, state×year-quarter FE, two-way clustering, telework-eligible-only, the **exact-birthdate treatment-ceiling sweep** (48/49/51/53/60 months), the **symmetric age-donut around the 5-year cutoff** (±12/18/24 months — drops the very-young treated children so treated/control are matched tightly in child age; Lucas Emanuel's suggestion), the **by-child-age split** (youngest child 0–1 / 2–3 / 4, each × post vs. Control A — null even in the highest-demand 0–1 band; Lucas Emanuel's suggestion), and the **early/late timing split**; carries the **A-vs-B placebo** (licenses Control A as clean). *Why it's needed:* the null is not an artifact of any single design choice, including where the age boundary is drawn or which life-stage of the eligible window is examined.
- **Fig. D.3 (fig08) — control-window sweep.** Estimate stable 5 … 5–12 (control = age-5-only up to 5–12). *Why:* the control's upper bound doesn't drive results.
- **Table D.2 — occupation transitions.** Descriptive twin of Table 5 (identical treated/control flows). *Why:* backs "no sorting" without a regression.
- **Table D.4 — triple diff, all outcomes.** The significant coefficients track **pre-existing gender trends**, not the reform. *Why:* same non-causal story as Table 3, gender version.
- **Table D.5 — outcomes, Control B.** Broad control (more power), same conclusions. *Why:* precision robustness + shows the choice of control doesn't matter.
- **Fig. D.1 (fig09) — maternity event study.** Pronounced pre-trend. *Why:* the visual reason maternity is not read causally.
- **Figs. D.2/D.4/D.5, Tables A.1/C.1** — hetero coefplot; telework-eligible & LFP descriptive trends; panel-retention (individual FE are meaningful); telework-code list (classification transparency).

**If a result doesn't serve this narrative, question whether it belongs.** New exhibits should either tighten identification, chase the effect where it "should" be and keep finding zero, or bound/falsify an alternative story.

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

**Appendix.** Tables/figures are numbered **per appendix section** (`\numberwithin{table}{section}` in `paper.tex`): panel retention is **A.1**, telework codes **C.1**, and the "Additional tables and figures" section holds **D.1–D.4** (tables) and **D.1–D.5** (figures). Order the floats in `appendix.tex` to match first-citation order (JPopE requires consecutive numbering).
| Role | File | Script |
|---|---|---|
| Table A.1 — Panel retention | `tabA1_panel_retention.tex` | 01 |
| Table — Reduced-form outcomes, Control B | `tab03b_did_outcomes_B.tex` | 03 |
| Table — Occupation transition matrix | `tab05b_occupation_transition.tex` | 04 |
| Table — Robustness (first stage, exact-birthdate ceiling sweep, symmetric age-donut around 5y, by-child-age split, early/late timing split, log earnings; `longtable`, spans 2 pages) | `tab07_robustness.tex` | 06 |
| Table — Triple diff, all outcomes | `tab08b_triple_diff_outcomes.tex` | 07 |
| Fig — Heterogeneity coefplot | `fig07_heterogeneity_coefplot` | 05 |
| Fig — Control-window sweep | `fig08_control_window_sweep` | 06 |
| Fig — Event study, maternity leave (pre-trends) | `fig09_event_study_maternity` | 02 |
| §Variable definitions (home office, formal/informal, CLT, private/public employee, etc.) | appendix.tex | — |
| §Classifying telework-eligible occupations (Costa et al. 2024 + COD dict) | appendix.tex | — |

**Descriptive figures** `fig01`–`fig04` (home-office trends, LFP/employment, two-control panels, telework-eligible subgroup) — available for appendix/slides as needed.

**Decided NOT in the paper:** fig05` state map (`analysis/output/maps/`) — treatment has no geographic dimension (single national date), so a map is decorative and would need pre+post panels; kept in repo only.

## Policy Context

- **MP 1108/2022** enacted 25 Mar 2022 (published 28 Mar) → **Law 14.442/2022** (2 Sep 2022, Art. 75-F unchanged). Scope: CLT `empregados`. Mechanism: **priority, not mandate** — no automatic right, no enforcement/penalty, no request/certification requirement.
- Interpretation: a **supply-side, soft mandate** raising the chance eligible women are allocated to existing teleworkable roles. Expected first stage: `home_office` ↑ for treated. Reduced form: wages ambiguous, hours likely ↓, employment retention, fertility.
- **Q1 2022 status:** MP published in the last week of Q1; PNADC reference weeks span the quarter. Main: Q1 2022 pre; robustness (`post_mp_alt`): Q1 2022 post. Similar estimates under both ⇒ cutoff doesn't drive results.

## Target Journal
**Journal of Population Economics** — the target (family policy, female labor supply, fertility, quasi-experiments; receptive to clean nulls). Write to its house style and submission mechanics; see memory `style-exemplar-jpope` for the JPopE writing model (Battaglia & Brown 2025) and submission mechanics.

---

## Status / open items before submission
The paper compiles clean (**46 pp** after the July 2026 referee revision, no undefined refs/cites). Keep this list current — delete items as they close.
- **Verify citation *content*** (in progress, Fredie): confirm each cited paper and each footnote actually supports the claim it is attached to — the *substance*, not just the bibliographic details.
- **Anonymized replication repo (referee round):** the data-availability statement now promises an anonymized package to editors/referees *at submission* with a placeholder link (`[anonymized replication repository]`). Fredie must create the anonymized deposit (e.g. anonymous.4open.science) and paste the real URL there.
- **Replication-data deposit (upon publication/acceptance):** deposit the pre-built `main_data.RData` on **Zenodo** (DOI); paste the link in `README.md` Option A and the paper's data-availability statement.
- **Proxy validation (C3) — DONE** via `analysis/code/09_supplement_validation.R` (Table 14 `tab14_proxy_validation` + `fig10`, Appendix §"Validation of the home-based-work proxy"). Uses IBGE's aggregate **2022 telework supplement** (Table 9471), now stored at `DROPBOX_ROOT/build/input/2022_supplement_pnad.xlsx`. Result: proxy 6.5% ≈ supplement telework-at-home 7.2% in aggregate; employment-weighted cross-state corr **0.72** (unweighted 0.53); home-based work concentrated in **self-employed 19% vs employees 2.6% / CLT 2.9%** (corroborates the measurement caveat). Script skips gracefully if the xlsx is absent.
- **The differential-attrition test + IPW (Comment 9) *are* done (`tab12`).
- **Output-file renaming (deferred):** rename files to final exhibit numbers once the set is frozen.

## Referee revision (July 2026 — "Proof Patrol / econ-GPT" report)
A JPopE-oriented AI referee flagged 10 comments (6 blocker/high). All are addressed in code + text; the substantive new analyses live in **`analysis/code/08_referee_revision.R`** (Tables 9–13). Key changes future sessions must respect:
- **Estimand relabel (C1):** the displayed treatment is now **"Young child" ($\leq$4)**, not "Treated" (Eq. 1 uses `\text{YoungChild}`; internal R cols stay `treated`/`treat_x_post`). The headline β is framed as a **population-average effect of exposure**, and the effect among the **legally-covered** (predetermined CLT / teleworkable / CLT×teleworkable) is reported separately in **Table 9 (`tab09_estimands`)**.
- **Measurement (C3):** `home_office` is coded **0 for the non-employed** (verified) → it is the *unconditional* share working from home. Paper now calls it **"home-based work"** (not "telework take-up"), states the non-employed=0 coding, and notes the location-vs-contract ambiguity (self-employed ~27% pre vs CLT <2%).
- **No more IV language (C4):** dropped "first stage", "compliance proxy", "bounds any downstream effect", "upper bound". §5.1 retitled *"Home-based work: the primary implementation outcome"* (`\label{sec:firststage}`).
- **Predetermined baseline (C2):** moderators (`pt_base`, `clt_base`, etc. in `04`/`05`/`06`) are now taken at the **last obs on or before 2022Q1**, NOT the first observed quarter, and those subgroup regressions are **restricted to women observed pre-reform**. This changed the heterogeneity numbers: now **only the single-mother cell is raw-significant (−2.6pp\*\*, Holm p=0.44)**; the 40–49 cell is no longer significant. Single-mother effect concentrates in **non-CLT (−3.2pp\*\*)**, null in **CLT (−0.3, n.s.)**.
- **Inference/estimators (C5, C6):** Table 11 (`tab11_inference`) adds state clustering (27), a **Webb wild cluster bootstrap** of the individual-FE null (p=0.82, via FWL demeaning since `boottest` can't carry 174k FE or `^` FE), a **repeated-cross-section DiD** (reproduces the +0.35pp\*\*\* selection), a **local diff-in-discontinuities** around 60 months, and a temporal placebo.
- **Equivalence (C7):** Table 10 (`tab10_equivalence`) reports TOST vs SESOI (0.5pp population / 1pp covered). Honest result: population TOST p=0.08 (borderline), covered subgroups **inconclusive** — so the text no longer overclaims "precise zero" for the covered groups; abstract states the CI and that covered estimates are less precise.
- **Attrition (C9):** Table 12 (`tab12_attrition`) — differential-attrition test (n.s.) + IPW (null holds).
- **Identification decomposition (C5):** Table 13 (`tab13_identification`) — 61% stable young-child / 27% stable comparison; stable-status re-estimate −0.2pp. Plus a SUTVA/spillover caveat in §5.5.
- **Narrative consistency (C8):** employment/LFP/maternity are now framed as **not causally identified** (parallel trends rejected), not "null"; Table 3 notes flag them as descriptive.
- `08_referee_revision.R` and `09_supplement_validation.R` are sourced by `config/00_master_analysis.R` (which now also `p_load`s `fwildclusterboot` and `readxl`).

### Round 2 (second econ-GPT report, same day) — all addressed; paper now 52 pp
The reviewer judged the revised paper submission-level; remaining fixes were textual/documentation + one small empirical add:
- **No "precise zero" (C1):** TOST is inconclusive at ±0.5pp, so headline claims softened everywhere (abstract, §5.1, discussion, conclusion) to "small and statistically insignificant, 95% CI [−0.67, 0.51]". "precise nulls" kept only for worker earnings/hours (genuinely tight, not the flagged claim).
- **Covered-group not overclaimed (C2):** intro/§5.4/conclusion now say point estimates give "no evidence of an increase" but CLT/teleworkable are "too imprecise to establish equivalence" (CLT CI [−3.66, 0.92], CLT×tele [−7.25, 5.38]). Terminology: "eligible mothers/women" → "**age-eligible**" where the sample includes non-covered; "legally covered" reserved for CLT.
- **Earnings/hours causal-clean via diagnostic, not assumption (C3) — NEW Table 3b (`tab15_earnings_margins`, in `03_did.R`):** reports each of earnings & hours **worker-conditional** AND **unconditional over all women** (asinh earnings, non-employed=0), each with its pre-trend χ²(16). Result: worker-conditional **pass** (log-earn χ²=8.7 p=.93; hours χ²=9.4 p=.90) → clean nulls; unconditional **fail** (earn χ²=33.3 p=.007; hours χ²=36.3 p=.003) → inherit the employment extensive-margin trend. Footnote 6 de-circularized.
- **Wild-bootstrap description reconciled (C4):** the Webb bootstrap is of the **preferred individual-FE** estimate (via FWL demeaning), NOT the repeated-CS model. Table 11 row reordered (bootstrap grouped with the FE block, before the repeated-CS row) and its note rewritten to say so explicitly.
- **Table 13 relabeled (C5):** "Decomposition of the Identifying Variation" → "**Eligibility Paths among Women Observed Before and After the Reform**"; §5.5 no longer claims stable-status women identify β "overwhelmingly" (counts ≠ econometric weight).
- **Abstract (C6):** replaced with the reviewer's 143-word version (~134 words, under JoPE's 150 limit). Anonymized-repo link + DOIs still Fredie's to fill.
- **Global:** added `analysis/output/sample_construction_counts.txt` (sample funnel; generated in `01_descriptives.R`) in lieu of a flowchart.
