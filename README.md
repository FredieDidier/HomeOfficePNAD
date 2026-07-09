# The Labor-Market Effects on Mothers of a Telework Priority for Parents of Young Children: Evidence from Brazil — Replication Package

**Author:** Fredie Didier (fdidier@terra.com.br)


## Repository layout

```
config/
  config.R              # <-- THE ONLY FILE TO EDIT (set DROPBOX_ROOT)
  00_master_build.R     # runs the data build
  00_master_analysis.R  # runs all analysis scripts
build/01_pnadc.R        # download PNADC, build panels, merge main_data.RData
analysis/code/          # 00_utils.R, 01_descriptives.R … 08_referee_revision.R
analysis/output/        # tables/, graphs/, maps/ (committed)
latex/                  # paper.tex, appendix.tex, refs.bib
dictionary/             # variable_dictionary.xlsx + build script
```

## Data

The microdata are **not** in this repository. They live in a (Dropbox) folder:

```
<DROPBOX_ROOT>/build/input/    Panel_6.RData … Panel_13.RData   (rotating panels)
<DROPBOX_ROOT>/build/output/   main_data.RData                  (final dataset)
```

`main_data.RData` covers 2018Q1–2026Q1.

### Getting the data — two options

- **Option A — download the pre-built dataset (fastest).** Upon publication, the pre-built `main_data.RData` will be deposited on Zenodo (with a DOI) and its download link added here. Once available, place the file in `<DROPBOX_ROOT>/build/output/` and **skip step 2** (the build) below.
- **Option B — rebuild from the raw microdata.** Reconstruct `main_data.RData` from the public PNADC microdata with the R packages (step 2 below); no external download needed. This is the currently available path.

## Reproducing the results

First, clone this repository and enter it:

```
git clone https://github.com/FredieDidier/HomeOfficePNAD.git
cd HomeOfficePNAD
```

Then:

1. **Open the project, then set the data path.** Open `HomeOfficePNAD.Rproj` in RStudio (or otherwise set the working directory to the repository root) **before running anything** — this is what lets `here::here()` and the `source()` calls below resolve paths correctly. Then edit the single line in `config/config.R`:

   ```r
   DROPBOX_ROOT <- "/path/to/your/HomeOfficePNAD"
   ```

   This is the only path that changes per machine; all repository paths are resolved automatically with `here::here()`.

2. **Build the dataset** (skip if `main_data.RData` already exists):

   ```r
   source("config/00_master_build.R")
   ```

   The two master scripts (`config/00_master_build.R`, `config/00_master_analysis.R`) install any missing R packages automatically (via `pacman::p_load()`) before `source()`-ing the individual `build/`/`analysis/code/*.R` files, so there is no need to run `install.packages()` by hand. The individual scripts do not load packages themselves — always run them through a master script (or `pacman::p_load()` the same packages by hand first if you want to source one individually). Downloading the raw PNADC from IBGE is commented out at the bottom of `build/01_pnadc.R`; uncomment `download_pnadc_panels()` there only to (re-)download.

3. **Run the analysis** (writes all tables and figures to `analysis/output/`):

   ```r
   source("config/00_master_analysis.R")
   ```

## Software environment

- **R** 4.4.x. Packages are installed automatically by the master scripts via `pacman::p_load()`. The analysis pipeline uses `data.table`, `fixest`, `ggplot2`, `here`, and `fwildclusterboot` (the wild cluster bootstrap in `08_referee_revision.R`); the build additionally uses `PNADcIBGE` and `datazoom.social`.
- **Random seeds.** The only stochastic step is the wild cluster bootstrap in `08_referee_revision.R`, which sets `set.seed(20260709)` and `dqrng::dqset.seed(20260709)` before `fwildclusterboot::boottest()`, so its p-value is reproducible.
- Running `config/00_master_analysis.R` regenerates every table and figure in `analysis/output/` from `main_data.RData` with no manual editing.

## Exhibit crosswalk (script → output file)

| Exhibit | Script | Output file |
|---|---|---|
| Table 1 — Descriptives | `01_descriptives.R` | `tables/tab01_descriptives.tex` |
| Table 2 — Home-based-work specification ladder | `03_did.R` | `tables/tab02_did_firststage.tex` |
| Table 3 — Outcomes, Control A / B | `03_did.R` | `tables/tab03a_did_outcomes_A.tex`, `tab03b_did_outcomes_B.tex` |
| Table 3b — Earnings/hours, conditional vs unconditional | `03_did.R` | `tables/tab15_earnings_margins.tex` |
| Table 4 — Moderation by baseline telework eligibility | `04_mechanisms.R` | `tables/tab04_mechanism_moderation.tex` |
| Table 5 / 5b — Occupational sorting; transition matrix | `04_mechanisms.R` | `tables/tab05_mechanism_allocation.tex`, `tab05b_occupation_transition.tex` |
| Table 6 — Heterogeneity + Holm | `05_heterogeneity.R` | `tables/tab06_heterogeneity.tex` |
| Table 7 — Robustness (longtable) | `06_robustness.R` | `tables/tab07_robustness.tex` |
| Table 8 / 8b — Triple difference | `07_triple_diff.R` | `tables/tab08_triple_diff.tex`, `tab08b_triple_diff_outcomes.tex` |
| Table 9 — Home-based work by predetermined subsample (estimands) | `08_referee_revision.R` | `tables/tab09_estimands.tex` |
| Table 10 — Precision and equivalence (TOST) | `08_referee_revision.R` | `tables/tab10_equivalence.tex` |
| Table 11 — Inference and estimator robustness | `08_referee_revision.R` | `tables/tab11_inference.tex` |
| Table 12 — Attrition and IPW | `08_referee_revision.R` | `tables/tab12_attrition.tex` |
| Table 13 — Eligibility paths (before/after reform) | `08_referee_revision.R` | `tables/tab13_identification.tex` |
| Table 14 — Proxy validation vs 2022 telework supplement | `09_supplement_validation.R` | `tables/tab14_proxy_validation.tex`, `graphs/fig10_proxy_validation` |
| Table A.1 — Panel retention | `01_descriptives.R` | `tables/tabA1_panel_retention.tex` |
| Sample-construction counts (funnel) | `01_descriptives.R` | `output/sample_construction_counts.txt` |
| Fig. 1–4 — Descriptive trends | `01_descriptives.R` | `graphs/fig01…fig04` |
| Fig. 6 / 9 — Event studies (home-based work; maternity) | `02_event_study.R` | `graphs/fig06_event_study_home_office`, `fig09_event_study_maternity` |
| Fig. 7 — Heterogeneity coefplot | `05_heterogeneity.R` | `graphs/fig07_heterogeneity_coefplot` |
| Fig. 8 — Control-window sweep | `06_robustness.R` | `graphs/fig08_control_window_sweep` |

> When this repository is shared with editors and referees, deposit it as an anonymized copy (e.g. via anonymous.4open.science) and paste the anonymized URL into the paper's *Data availability and replication* statement (currently a placeholder).
