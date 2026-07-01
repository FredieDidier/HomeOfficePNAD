# HomeOfficePNAD — Project Guide

## Project Overview

Empirical research paper studying whether **MP 1108/2022 (Art. 75-F)** — which mandates employers to give priority access to telework for employees with children or legal dependents under 4 years old — causally affected women's labor market outcomes and fertility decisions.

The article was enacted on **March 25, 2022**, published March 28, 2022, and converted into **Law 14.442 on September 2, 2022**.

**Art. 75-F (MP and Law):**
> "Employers must give priority to employees with disabilities and to employees with children or minors under judicial guardianship up to 4 years of age in the allocation of positions for activities that can be performed through telework or remote work."

**Authors:** Fredie Didier (fdidier@terra.com.br)

---

## Research Design

### Identification Strategy
**Difference-in-Differences (DiD) — Two complementary control groups**

The preferred design uses **two control groups in parallel**:

| Group | Role |
|---|---|
| Women with child ≤ 4 (treated) | Treatment group |
| Women with child 5–7 (control A) | Cleaner control — similar selection into motherhood; child just crossed legal threshold |
| Women without young children (control B) | Broad control — higher statistical power |

Running both comparisons enables a **dose-response falsification test**: we expect a large effect for treated vs. either control, and **zero effect** for child 5–7 vs. no children. If that pattern holds, it strongly supports the legal age cutoff as the causal mechanism.

### Why This Is an Intent-to-Treat (ITT) Design
Art. 75-F gives eligible employees a **priority claim**, not an automatic right, to telework — the employer must prioritize them when allocating teleworkable positions, but is not obligated to grant telework to every eligible employee, and not every job held by an eligible woman is teleworkable. We do not observe, in the PNADC, whether a given employer actually reassigned a given woman to telework because of the law (compliance/take-up is unobserved at the individual level).

What we DO observe is **eligibility** — i.e., whether a woman has a child ≤4 in the household, `has_child_u4` — and her **realized outcomes** (`home_office`, income, hours, etc.) before and after the law. Comparing outcomes for eligible vs. non-eligible women around the policy date therefore estimates the **Intent-to-Treat (ITT) effect**: the average effect of being *legally entitled to* priority telework access, regardless of whether the woman actually received it. This is the policy-relevant parameter — it tells us what happened to the population the law was designed to protect — but it understates the effect on women who were actually granted telework (the Treatment-on-the-Treated, unobserved here).

`home_office` itself is also the natural **first-stage / compliance proxy**: an ITT effect on `home_office` tells us how much the law actually moved telework take-up among eligible women, which calibrates how much weight to put on the reduced-form ITT estimates for wages, hours, and fertility.

- **Treatment group:** women who are household head or spouse (V2005 ∈ {1,2,3}) AND have at least one child ≤ 4 in the household (`has_child_u4 == 1`)
- **Control A (primary):** same position, with child 5–7 in household (to be created: `has_child_5_7`)
- **Control B (broad):** same position, without any child ≤ 7 in household
- **Post-period (main):** Q2 2022 onwards (`post_mp`, `year_quarter >= 20222`). MP fell in last week of Q1 2022, so Q1 2022 is treated as pre-period.
- **Post-period (robustness):** Q1 2022 onwards (`post_mp_alt`). If estimates are stable, the exact cutoff quarter does not drive findings.

### COVID-19 Contamination — Critical Design Issue
The pre-period overlaps with the COVID-19 pandemic, which caused a massive temporary shock to home office adoption (2020–2021). This is a major confounder:
- **2018–2019**: Clean pre-period (low, stable home office)
- **2020–2021**: COVID shock drives home office up for everyone — **contaminated pre-period**
- **2022**: MP enacted while home office is still elevated post-COVID
- **2022–2025**: Post-MP, home office gradually returns toward pre-COVID baseline

**Main spec**: TWFE on full 2018–2025, with individual + quarter FE. Quarter FE absorb aggregate time trends (including COVID) in levels. Standard and transparent. Concern: if COVID *differentially* affected home office for mothers of young children (e.g. school closures may have pushed treated women into home office more in 2020–2021), then pre-trends during the pandemic will not be parallel — visible in the event study plot.

**Robustness — COVID window (Robustness A)**: Drop 2020 and 2021 entirely. Use 2018–2019 as clean pre-period and 2022–2025 as post-period. Most credible alternative — completely removes the COVID contamination. If estimates are similar to the main spec, the pandemic years are not driving results.

**Robustness B**: `post_mp_alt` (Q1 2022 as post-period).

The event study plot (2018–2025) is the key diagnostic: inspect whether pre-trends diverge in 2020–2021 between treated and control groups before converging post-MP.

### Telework Eligibility (Potential Telework)
Following Góes et al. (2020) / Dingel & Neiman (2020) adapted for the Brazilian COD/PNADC (V4010), a list of ~120 occupation codes eligible for telework is available (see Table 2 of Costa et al. 2024, *Revista Brasileira de Economia de Empresas*).

**Strategy:**
- **Main sample**: all women (estimates ITT effect of the MP across all workers)
- **`potential_telework` variable**: flag based on V4010 ∈ COD eligible codes → used as a **heterogeneity moderator**, not as a sample restriction.
- **Appendix**: restricted sample (telework-eligible only) as robustness.

**Why NOT restrict the main sample to `potential_telework == 1`:**
Occupation is a potentially endogenous outcome of the MP itself. The policy may induce treated women (those with children ≤4) to switch into telework-eligible occupations — either because employers re-classify their role, because they actively seek telework-compatible positions, or because informal job redesign makes their existing job eligible. Conditioning on `potential_telework == 1` after the policy is enacted therefore conditions on a post-treatment variable: among the treated, we would only observe women who (a) were already in eligible jobs or (b) switched into them — missing the full treatment effect (including reduced-form effects via job composition). This is the classic "bad control" problem (Angrist & Pischke, *MHE*). Instead: use `potential_telework` as a moderator in heterogeneity analysis. The expected pattern is that the first stage (home office increase) is concentrated among women who were ALREADY in telework-eligible occupations at baseline, while women in non-eligible occupations serve as a within-sample placebo.

### Key Outcomes
1. `home_office` — whether worker performs telework (V4022 ∈ {4,5})
2. `income_habitual_real` — real habitual monthly income (all jobs)
3. `hours_usual` / `hours_effective` — weekly hours worked
4. Employment status (`employed`, `unemployed`, `in_labor_force`)
5. `on_maternity_leave` — proxy for recent birth (fertility effect)

### Sample
- Women aged 18–49 (main spec)
- From Q1 2018 onwards (V4022/home office variable available only from Q1 2018)
- Women who are household head or spouse (`is_head_or_spouse == 1`)
- Unit: individual × quarter (`id_panel` + `year_quarter`)
- Each individual appears 1–5 consecutive quarters (rotating panel; V1016 = interview round)

**Age restriction robustness:** Run the main DiD also for ages 20–35 and 20–40. Rationale: 18–19-year-olds rarely combine formal employment and children ≤4; 45–49-year-olds rarely have children ≤4 (mostly in Control B). The restricted age windows give cleaner treated/control comparability. This is standard in motherhood-penalty papers. Expected: estimates should be stable or slightly larger in magnitude since the treated group is more concentrated in prime childbearing + career years.

**Why NOT restrict to formal workers (CLT) only:**
The MP/Lei applies to formal employees (CLT empregados). However, restricting the sample to `formal == 1` would introduce selection bias: formal employment status is itself a potential outcome (the MP may affect whether women retain formal contracts or switch sectors). Restricting to formal workers conditions on a partially endogenous variable and would miss the full ITT effect. Main spec: all women (ITT). Heterogeneity table: compare effects for `formal == 1` vs. `formal == 0` subgroups — the effect should be concentrated in formal workers (where the law is binding), and close to zero for informal workers (which serves as a within-sample placebo).

---

## Stack

| Layer | Tools |
|---|---|
| Data download | R (`datazoom.social` — PUC-Rio package; [github.com/datazoompuc/datazoom.social](https://github.com/datazoompuc/datazoom.social)) |
| Data build & analysis | R (`data.table`, `fixest`, `ggplot2`) |
| Writing | LaTeX / Beamer |

**Note on `datazoom.social`:** Source of the Stage 3 advanced individual panel ID (`id_rs3`, Graph Theory fuzzy matching for fragmented interviews) and household ID (`id_dom`), plus pre-derived labor market variables (`ocupado`, `forca_trab`, `home_office`, `formal`, `informal`, `rendimento_habitual_real`, `faixa_educ`, `regiao`, `sigla_uf`, `cnae_2dig`, `cod_2dig`).

**Panel download strategy — see the header comment in `build/01_pnadc.R` for full detail.** In short: `download_pnadc_panels()` downloads one quarter at a time via `PNADcIBGE::get_pnadc()` (bypassing `load_pnadc()`'s wrapper), immediately prunes to the ~35 columns needed and filters to the target V1014 group, then calls the package's own `build_pnadc_panel(panel = "advanced_3")` once per group's full window. This was arrived at after two crashes on a 16GB/460GB machine — a RAM crash (bulk multi-year downloads holding ~210 columns in memory) and a disk crash (`get_pnadc()` leaves unzipped microdata in R's `tempdir()`, which accumulated ~350GB across quarters) — both fixes and the reasoning are documented in the script itself, not repeated here. **If a `Panel_{v}.RData` looks implausibly small or a run errors with "error writing to connection," delete that file manually before re-running** (the function skips any panel whose output already exists).

`id_rs3` is `NA` for individuals the algorithm could not match across quarters; **always use `id_panel` (not `id_rs3`) as the FE variable** — see `build_main_data()`'s header comment in `01_pnadc.R` for why. `panel_matched` flags genuine cross-quarter links (robustness subsample candidate).

Both the panel input files and the final analytical dataset are saved as **`.RData`**.

---

## Repository Layout

```
build/
  01_pnadc.R          Download PNADC, build panels (→ Dropbox/input), merge final dataset (→ Dropbox/output)

config/
  00_master_build.R   Entry point for data pipeline (sources build/01_pnadc.R)
  00_master_analysis.R Entry point for analysis (sources analysis/code/ scripts)

analysis/
  code/
    01_descriptives.R   Summary statistics, sample description, descriptive figures
    02_event_study.R    Event-study plot around MP 1108/2022 (to be created)
    03_did.R            DiD main estimates (to be created)
    04_mechanisms.R     Heterogeneity and mechanism analysis (to be created)
    05_robustness.R     Robustness checks and placebo tests (to be created)
  output/
    tables/           .tex table outputs (committed to git)
    graphs/           figure outputs — line/bar charts, event studies (committed to git)
    maps/             geographic map outputs — e.g. fig05 state map (committed to git)

dictionary/
  dicionario_PNADC_microdados_trimestral.xls   PNADC variable dictionary

CLAUDE.md             This file
README.md
```

---

## Data

Raw and intermediate data live in **Dropbox** (not git).

```
Dropbox/HomeOfficePNAD/
  build/
    input/    Panel files: Panel_6.RData … Panel_13.RData (one per rotating panel group)
    output/   main_data.RData  ← final analytical dataset
```

**Confirmed on the actual build (2026-06-30):** `main_data.RData` covers **2018Q1 through 2026Q1** (`year_quarter` 20181–20261) — the upper bound is simply whatever quarter IBGE had published at build time (Panel 13's own window runs through 2027, but later quarters aren't published yet and are silently skipped by `download_pnadc_panels()`). **3,684,610 observations.** Re-running the build later will naturally extend the upper bound as IBGE publishes new quarters.

**Dropbox path** is set via `DROPBOX_ROOT` at the top of `build/01_pnadc.R` — the only line to change on a new machine. GitHub paths use `here::here()`.

---

## Running the Pipeline

### Step 1 — Build the dataset
Open `config/00_master_build.R` and run it. This sources `build/01_pnadc.R`, which calls `build_main_data()` to merge the panel `.RData` files and save `main_data.RData`.

> **Note:** The panel files (Dropbox/build/input/) must exist as `Panel_{6..13}.RData`. To download them, uncomment `download_pnadc_panels()` at the bottom of `build/01_pnadc.R` and run. The function downloads one panel group at a time (to limit RAM usage) and saves each as `.RData`. See the function header in `01_pnadc.R` for details on the panel-by-panel strategy.

### Step 2 — Run analysis
Open `config/00_master_analysis.R` and run it. Uncomment scripts as they are created.

---

## Key Variables

| Variable | Description | Source |
|---|---|---|
| `id_rs3` | Stage 3 advanced individual panel ID — links same person across quarters (Graph Theory fuzzy matching). `NA` if unmatched. | datazoom.social |
| `id_panel` | FE variable for `feols(... \| id_panel)`. Equals `id_rs3` when matched; unique row-level ID (`unmatched_<row>`) otherwise — always non-missing. | Project-derived |
| `panel_matched` | = 1 if `id_rs3` is non-missing (individual successfully linked across quarters) | Project-derived |
| `id_dom` | Household ID | datazoom.social |
| `home_office` | = 1 if work location is own residence (V4022 ∈ {4,5}) | datazoom.social (Q1 2018+) |
| `ocupado` | = 1 if employed | datazoom.social |
| `forca_trab` | = 1 if in labor force | datazoom.social |
| `rendimento_habitual_real` | Real habitual monthly income (all jobs, deflated) | datazoom.social |
| `formal` / `informal` | Formal / informal employment flags | datazoom.social |
| `faixa_educ` | Education level group | datazoom.social |
| `regiao` / `sigla_uf` | Geographic region / state abbreviation | datazoom.social |
| `cnae_2dig` / `cod_2dig` | 2-digit CNAE sector / COD occupation group | datazoom.social |
| `has_child_u4` | = 1 if head/spouse with child ≤ 4 in HH — V2005 ∈ {4,5,6,10,11}: biological children of head+spouse (4), of head only (5), stepchildren (6), grandchildren (10) and great-grandchildren (11, separate PNADC code). Main treatment. | Household-level merge |
| `has_child_u4_no_gc` | = 1 if head/spouse with child ≤ 4 in HH, **excluding grandchildren/great-grandchildren** (V2005 ∈ {4,5,6}) | Robustness |
| `has_child_u4_no_sc` | = 1 if head/spouse with child ≤ 4 in HH, **excluding stepchildren** (V2005 ∈ {4,5,10,11}) | Robustness |
| `has_child_5_7` | = 1 if head/spouse with child aged 5–7 in HH (V2005 ∈ {4,5,6,10,11}) — donut DiD Control A | Household-level merge |
| `has_child_5_7_no_gc` | = 1 if head/spouse with child 5–7 in HH, excluding grandchildren/great-grandchildren (V2005 ∈ {4,5,6}) | Robustness |
| `has_child_5_7_no_sc` | = 1 if head/spouse with child 5–7 in HH, excluding stepchildren (V2005 ∈ {4,5,10,11}) | Robustness |
| `age_youngest_child` | Age of youngest qualifying child (NA if has_child_u4==0) | Household-level merge |
| `age_youngest_child_no_gc` | Same, excluding grandchildren | Robustness |
| `age_youngest_child_no_sc` | Same, excluding stepchildren | Robustness |
| `potential_telework` | = 1 if V4010 ∈ COD codes eligible for telework (Góes et al. 2020 / Costa et al. 2024) | Derived from V4010 |
| `is_head_or_spouse` | = 1 if V2005 ∈ {1,2,3} | V2005 |
| `treated` | = `has_child_u4` (DiD treatment indicator) | |
| `post_mp` | = 1 if `year_quarter >= 20222` (main spec) | |
| `post_mp_alt` | = 1 if `year_quarter >= 20221` (robustness) | |
| `treat_x_post` | = `treated × post_mp` (DiD interaction, main) | |
| `treat_x_post_alt` | = `treated × post_mp_alt` (DiD interaction, robustness) | |
| `year_quarter` | Numeric time ID: e.g. 20221 = Q1 2022 | Ano × 10 + Trimestre |
| `V1016` | Interview round (1–5) | PNADC |
| `income_habitual_real` | Real habitual monthly income: VD4019 × Habitual deflator | Derived |
| `hours_usual` | Usual weekly hours across all jobs (VD4031) | PNADC |
| `hours_effective` | Effective hours in reference week (VD4035) | PNADC |
| `on_maternity_leave` | = 1 if V4006A == 2 (maternity/paternity leave) | PNADC (Q4 2015+) |
| `VD4019` | Habitual monthly income, all jobs (nominal) | PNADC |
| `VD4001` / `VD4002` | Labor force / employment status | PNADC |

---

## Conventions

- All code and comments in **English**.
- Use `data.table` throughout — no `dplyr` or base R `merge` in build scripts.
- GitHub paths via `here::here()`; Dropbox via `DROPBOX_ROOT` global.
- Analysis output goes to `analysis/output/tables/` and `analysis/output/graphs/` — committed to git.
- Table outputs are `.tex` fragments for `\input{}` into LaTeX, not full documents.
- Main sample in analysis scripts: `is_head_or_spouse == 1` (already implied by `treated` construction, but filter explicitly for clarity).
- The `treated` variable is always `has_child_u4` (V2005 ∈ {4,5,6,10,11}, inclusive of stepchildren and grandchildren/great-grandchildren). Robustness: `has_child_u4_no_gc` (no grandchildren/great-grandchildren), `has_child_u4_no_sc` (no stepchildren).
- **V2005 code note:** "grandchild" (10) and "great-grandchild" (11) are SEPARATE PNADC codes — do not assume 10 covers both. `has_child_u4` includes both; `has_child_u4_no_gc` excludes both.
- DiD main interaction: `treat_x_post`. Robustness (Q1 2022 cutoff): `treat_x_post_alt`.
- Standard errors: cluster at `id_dom` level (household) in main specs; robustness at `UPA` level.
- **ggplot2 label text (titles, legends, facet strips) uses plain ASCII only** (`<=`, `-`), never Unicode symbols like `≤`/`–`. Some rendering pipelines lack the glyph and silently truncate to "...", which is why figure group labels read "child <= 4 years" / "5-7 years" rather than "≤"/"–". Unicode is fine in `.tex` table output (real LaTeX, e.g. `$\leq$`) and in this file/comments — the restriction is specific to plotted figure text.

---

## Empirical Strategy — Fixed Effects and Covariates

### Main TWFE specification

```r
feols(outcome ~ treat_x_post | id_panel + year_quarter,
      data    = dt[is_head_or_spouse == 1],
      weights = ~V1028,
      vcov    = ~id_dom)
```

**Survey weights (`V1028`) are used in EVERY specification, main and robustness alike — not an optional robustness axis.** PNADC's sampling design is not self-weighting (unequal selection probabilities across strata/PSUs), so unweighted estimates would not be representative of the population of interest. There is no "unweighted" version of any table in this project.

**Individual FE (`id_panel`):** YES — always include. The rotating panel allows us to control for all time-invariant individual characteristics (ability, preferences, baseline education, race, region). Without individual FE, parallel trends would require selection-on-observables; with it, identification comes from within-person changes over time. **Always use `id_panel`, never `id_rs3` alone** (unmatched observations would be pooled into one spurious FE).

**Checking `id_rs3` match quality (confirmed on the actual build, 2026-06-30):** `table(dt$panel_matched)` → 137,084 unmatched vs. 3,547,526 matched, i.e. **3.72% unmatched** out of 3,684,610 total observations. This is small, so `id_panel` behaves essentially like `id_rs3` and individual FE absorb what we expect — **use `id_panel` in the main spec**, and additionally run `panel_matched == 1` as a robustness subsample (Table A6) to confirm the small unmatched share isn't driving results.

**Hours worked is an OUTCOME, not a covariate.** `VD4031`/`VD4035` (`hours_usual`/`hours_effective`) are one of the key dependent variables (see Key Outcomes above) — telework access is expected to change how many hours women work (e.g., better scheduling flexibility, or conversely more unpaid domestic substitution). Including hours as a control on the right-hand side of the outcome regressions would condition on a post-treatment variable. Never use hours as a covariate; only as `outcome` in `feols(hours_usual ~ treat_x_post | id_panel + year_quarter)`.

**Quarter × Year FE (`year_quarter`):** YES — always include. Absorbs aggregate shocks common to all women: COVID, business cycles, national labor market trends.

### Additional specifications

| FE / Covariate | Recommended use | Rationale |
|---|---|---|
| Age (`V2009 + I(V2009^2)`) | Include in all specs as time-varying covariate | Age changes each quarter; correlated with outcomes and child probability; not absorbed by individual FE |
| State × Quarter FE (`sigla_uf^year_quarter`) | Robustness only | Controls for state-specific shocks; |
| Urban × time | Robustness | V1022 mostly stable → absorbed by individual FE; urban × year_quarter controls for city-specific COVID patterns |
| Race FE (`V2010`) | **Absorbed** by individual FE — do not add | Race is time-invariant |
| Education (`VD3004`) | Optional covariate in robustness | Mostly stable; can change during sample window |
| Occupation FE (`cod_2dig`) | **Do NOT include** | Occupation is endogenous to the MP (job switching is a mechanism). Including it would absorb part of the treatment effect ("bad control"). Use as heterogeneity dimension, not as a control. |
| Sector FE (`cnae_2dig`) | **Do NOT include** | Same reason as occupation — sector may respond to the policy |
| Employment status (`ocupado`, `forca_trab`) | **Do NOT include** | These are OUTCOMES — controlling for them conditions on post-treatment variables |
| Job tenure | **Do NOT include** | Potentially endogenous to the MP |

### Clustering
- **Main spec:** cluster at `id_dom` (household). Treats all interviews of the same household as correlated. Appropriate because child-presence flags are household-level variables and husbands/partners in the same household may be correlated.
- **Robustness:** cluster at `UPA` level (primary sampling unit / census tract). Larger clusters; better asymptotic justification for inference with geographic spillovers.

### Specification ladder (in paper)
1. **Baseline:** `treat_x_post | id_panel + year_quarter`, `vcov = ~id_dom`
2. **+ Age:** add `V2009 + I(V2009^2)` as controls
3. **+ State × Time:** add `sigla_uf^year_quarter` to absorb state-specific trends
4. **Cluster robustness:** re-run (1) with `vcov = ~UPA`

### Table reporting convention
Every regression table must report, below the coefficient(s): **N (obs)**, **N individuals** (`uniqueN(id_panel)`), **N households / clusters** (`uniqueN(id_dom)` — since `id_dom` is the clustering variable in the main spec), and within-R². Report the clustering variable used in a table note. When `vcov = ~UPA` (robustness), also report `uniqueN(UPA)`.

---

## Paper Output Plan — Main Text vs. Appendix

Journals in the target tier (see below) typically allow ~6–8 exhibits in the main text. Plan, mapped to the script that produces each:

### Data Quality (Appendix / Data Section — doesn't count against the main-text exhibit budget)
| # | Exhibit | Script |
|---|---|---|
| Table A0 | Panel retention diagnostics — households (`id_dom`) and individuals (`id_rs3`, matched only): share observed >=X quarters (Panel A) and quarter-to-quarter transition probability (Panel B). Confirmed on the actual build: households retain well (93.2% reach all 5 quarters); individuals less so (37.4% reach all 5 — Stage 3 matching + genuine attrition combined), transition probabilities 79.1% (households) / 70.8% (individuals). Exists to reassure the reader the advanced panel ID is capturing real repeated structure, justifying individual FE (`id_panel`) in every spec. | `01_descriptives.R` (done, `tabA0_panel_retention.tex`) |

**Why this table's numbers won't match a population-wide PNADC panel retention exercise:** ours is computed on the actual DiD estimation sample, not the unrestricted population, for two compounding reasons — neither is a bug:
1. **Sample restriction, not raw survey rotation.** A household counts as "retained" here only if it still contains a qualifying woman (18–49, head/spouse) each quarter — this measures persistence of a specific household *type*, which tends to read higher than unconditional household turnover in the full population.
2. **Age-window censoring mechanically deflates individual retention.** A woman aging out of 18–49 mid-panel "disappears" from the sample even though IBGE is still interviewing her and the matching algorithm still links her correctly — this is sample-definition censoring, not a matching failure, and is the main reason individual retention here reads lower than an unrestricted population would show.

**Bottom line:** this table answers the question that matters for this paper — does the actual DiD estimation sample have enough within-person repeated observations for individual FE to be meaningful — not "what is PNADC's population-wide panel retention?". A population-wide number, if ever needed, would require a separate, unrestricted computation over all ages/sexes.

### Main Results
| # | Exhibit | Script |
|---|---|---|
| Table 1 | Summary statistics by group × pre/post | `01_descriptives.R` (done) |
| Figure 1 | Event study — `home_office` around Q1/Q2 2022, treated vs. Control A and vs. Control B | `02_event_study.R` |
| Figure 2 | Home office rate by quarter and group, 2018–2025 (currently `fig01`) | `01_descriptives.R` (done) |
| Table 2 | Main DiD estimates, for both Control A and Control B. **Column 1 = First stage** (`home_office ~ treat_x_post`) — report prominently, not just as one outcome among others: it quantifies actual compliance/take-up and calibrates how the reader should read every other column (income, hours, employment, `on_maternity_leave`) — a weak first stage mechanically caps how large the reduced-form ITT effects can be, regardless of whether the underlying mechanism is real. | `03_did.R` |
| Figure X (CONDITIONAL — decide after seeing Table 2) | Event-study for `on_maternity_leave`, same layout as Figure 1 | `02_event_study.R` |

**On the maternity-leave figure:** do NOT build this preemptively. No map is needed for fertility (there's no geographic story). Whether it gets a dedicated event-study figure at all depends on the Table 2 result: a fertility effect is one of the three things flagged under "Target Journals" below as potentially elevating this paper, so if `on_maternity_leave` comes out significant, promote it to a Main Results figure; if it's null/noisy, leave it as a single column in Table 2 and skip the figure entirely. Decide once, after running `03_did.R` — don't build it "just in case."

### Mechanisms / Heterogeneity
| # | Exhibit | Script |
|---|---|---|
| Table 3 | Heterogeneity by `potential_telework` (first-stage concentrated in eligible occupations) | `04_mechanisms.R` |
| Table 4 | Heterogeneity by `formal` (effect should be near-zero for informal workers — within-sample placebo) | `04_mechanisms.R` |
| Figure 3 (optional) | Coefficient plot summarizing heterogeneity across subgroups | `04_mechanisms.R` |

### Robustness (Appendix)
| # | Exhibit | Script |
|---|---|---|
| Table A1 | Alt. post-MP cutoff (`treat_x_post_alt`, Q1 2022) | `05_robustness.R` |
| Table A2 | `has_child_u4_no_gc` / `has_child_u4_no_sc` treatment variants | `05_robustness.R` |
| Table A3 | COVID window robustness (drop 2020–2021) | `05_robustness.R` |
| Table A4 | Age-restricted samples (20–35, 20–40) | `05_robustness.R` |
| Table A5 | `UPA`-level clustering (vs. main `id_dom`) | `05_robustness.R` |
| Table A6 | Balanced/matched subsample (`panel_matched == 1` only) | `05_robustness.R` |
| Table A7 | Restricted sample: `potential_telework == 1` only | `05_robustness.R` |
| Table A8 | Placebo test — men (see list below) | `05_robustness.R` |
| Figure A1 | Labor force participation / employment trends (currently `fig03`) | `01_descriptives.R` (done) |
| Figure A2 | Home office trends, `potential_telework == 1` subgroup (currently `fig04`) | `01_descriptives.R` (done) |
| Figure A3 | Two-panel trends: Treated vs. A / Treated vs. B separately (currently `fig02`) | `01_descriptives.R` (done) |
| Figure A4 (optional) | State map — descriptive geographic distribution of `home_office` or treated-group share (saved to `analysis/output/maps/`, not `graphs/`) | `01_descriptives.R` (see below) |

**On the state map:** not required for identification (the DiD does not rely on geographic variation — `sigla_uf^year_quarter` is already a robustness FE, not the main design), but useful as a descriptive appendix figure to show the treated population and the first-stage effect are not concentrated in one region (supports external validity and the state×time robustness spec). Low priority — build only if main results are in good shape and there's room in the appendix. Implementation sketch (guarded by `requireNamespace`, since `geobr`/`sf` are optional): map `home_office` rate by state among treated women, post-MP, using `geobr::read_state()`.

### Additional robustness checks worth adding (not yet in the pending list)
- **Placebo/falsification — men:** `main_data.RData` is women-only by construction (`build_main_data()` filters `V2007 == 2` in Pass 2), so this placebo needs a **separate, parallel extraction**, not a filter on the existing dataset. Plan: add a small sibling function (e.g. `build_placebo_men_data()`, called from `05_robustness.R` or added to `01_pnadc.R`) that re-reads the same `Panel_*.RData` files and reuses Pass 1's household-level child lookup as-is (it is already sex-agnostic — it looks at V2005/V2009 of every household member regardless of sex) but repeats Pass 2 filtering to `V2007 == 1` (men) instead of `== 2`, saving `placebo_men_data.RData`. Deliberately kept as a separate function rather than a parameter on `build_main_data()`, so the main pipeline's tested logic and output stay untouched. The law's text is not gender-restricted, so a null `treat_x_post` for men on this parallel sample supports that the effect operates through the gendered channel this paper is about, not a generic shock correlated with having young children in the household.
- **Outlier sensitivity — winsorize income:** `rendimento_habitual_real` is heavy-tailed (self-employment/business income especially), so a handful of extreme values can dominate a level-outcome mean-effect estimate in a household survey. Winsorizing at the top 1% (or re-running in logs) checks that the main income result isn't an artifact of a few outliers rather than a broad shift in the distribution.
- **Public vs. private sector:** heterogeneity by sector (public administration / `VD4009`-derived employer type). Public-sector telework was governed by separate administrative rules and rolled out on different (often slower, agency-specific) timelines than Art. 75-F, which is a CLT/private-sector-oriented provision. Splitting the sample checks that the estimated effect is concentrated in the private sector, where the law actually binds, and is not picking up unrelated public-sector telework policy changes that happened to overlap in time.

---

## Policy Context

### MP 1108/2022 → Law 14.442/2022 (Art. 75-F — CLT)
- **MP enacted:** March 25, 2022 (published March 28, 2022 in DOU)
- **Converted to law:** September 2, 2022 (Law 14.442/2022)
- **Scope:** All formal employees (`empregados`) covered by CLT
- **Mechanism:** Priority (not mandate) for telework allocation — employer must prioritize, but no automatic right to remote work
- **Art. 75-B** (same MP): Broadened definition of telework — "preponderant or not" presence outside employer premises with ICT

### Interpretation for DiD
- The treatment is the **obligation on employers to prioritize** women with young children for available remote positions
- This is a **supply-side shock**: increases the probability that eligible women are offered/allocated to telework roles
- Expected first stage: increase in `home_office` for treated women post-MP
- Reduced form outcomes: wages (theory ambiguous — could rise via selection into telework, or fall via compensating differentials), hours (likely decrease if telework allows better scheduling), employment retention, fertility

### Q1 2022 Treatment Status
- MP published March 28, 2022 = last week of Q1 2022
- PNADC reference weeks are spread across all weeks of the quarter
- **Main spec:** Q1 2022 is pre-period (`post_mp = 0`)
- **Robustness:** Q1 2022 is post-period (`post_mp_alt = 1`)
- If point estimates are similar under both cutoffs → results do not hinge on this choice

---

## Current Status (as of 2026-06)

### Done
- [x] Data build pipeline (`build/01_pnadc.R`) — rewritten to download panel-by-panel (`.RData`) and read `.RData` in build step
- [x] `main_data.RData` build function with sample restrictions, treatment variables
- [x] Master scripts (`config/00_master_build.R`, `config/00_master_analysis.R`)
- [x] PNADC dictionary reviewed; research design finalized
- [x] `id_rs3` (Stage 3), `id_panel`, `panel_matched` added for safe FE usage
- [x] `potential_telework` variable (V4010 mapped to Góes et al. 2020 / Costa et al. 2024 COD codes)
- [x] `has_child_5_7`, `has_child_5_7_no_gc`, `has_child_5_7_no_sc` (donut DiD control variables)
- [x] `has_child_u4_no_sc` (excludes stepchildren/enteados, V2005=6 — new robustness variant)
- [x] Fixed V2005 labels in code and dictionary (4=child of head+spouse, 5=child of head only, 6=stepchild, 10=grandchild)
- [x] `analysis/01_descriptives.R` — Summary statistics and trend figures (awaiting panel files to run)

### Pending (download in progress as of 2026-06-30)
- [ ] **Download panel files** — `download_pnadc_panels()` in `build/01_pnadc.R` (in progress; re-run after fixing the tempdir-fill bug — see script header)
- [ ] **Run build** — `build_main_data()` → `main_data.RData`
- [ ] `analysis/code/02_event_study.R` — Event study around Q1/Q2 2022 (Main, Figure 1)
- [ ] `analysis/code/03_did.R` — Main DiD estimates, two control groups (Main, Table 2)
- [ ] `analysis/code/04_mechanisms.R` — Heterogeneity: `potential_telework`, `formal` (Mechanisms, Tables 3–4)
- [ ] `analysis/code/05_robustness.R` — full list in "Paper Output Plan" above (Tables A1–A8)
- [ ] LaTeX paper draft

---

## Target Journals

Tiered by probability of acceptance, conditional on obtaining clean estimates.

### High probability (publish here if results are solid and well-identified)
- **Journal of Human Resources** — perfect fit: gender, labor markets, policy quasi-experiment
- **Labour Economics** — strong fit for Brazilian context + DiD methodology
- **AEJ: Applied Economics** — ideal for clean DiD with policy-relevant findings
- **Journal of Development Economics** — good fit given Brazilian / developing-country context

### Medium probability (viable if identification is very clean + heterogeneity story is interesting)
- **Review of Economics and Statistics**
- **Journal of Labor Economics** — high bar; needs very sharp first stage and novel mechanism
- **Journal of Public Economics** — requires stronger fiscal / policy angle

### Low probability (needs striking results — large effects, compelling fertility mechanism, novel identification twist)
- **Quarterly Journal of Economics**
- **American Economic Review**
- **Review of Economic Studies**
- **Journal of Political Economy**

**Realistic target path:** Submit first to AEJ: Applied or JHR. If rejected, move to Labour Economics or JDE. The identification (MP as natural experiment + age-of-child threshold) is clean but not extraordinary on its own — what will elevate the paper is: (a) a strong fertility effect, (b) the dose-response pattern with children 5–7 as control, and/or (c) a compelling heterogeneity story on potential telework eligibility.