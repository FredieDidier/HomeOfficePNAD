# The Labor-Market Effects on Mothers of a Telework Priority for Parents of Young Children: Evidence from Brazil — Replication Package

**Author:** Fredie Didier (fdidier@terra.com.br)


## Repository layout

```
config/
  config.R              # <-- THE ONLY FILE TO EDIT (set DROPBOX_ROOT)
  00_master_build.R     # runs the data build
  00_master_analysis.R  # runs all analysis scripts
build/01_pnadc.R        # download PNADC, build panels, merge main_data.RData
analysis/code/          # 00_utils.R, 01_descriptives.R … 09_supplement_validation.R
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

- **Option A — download the pre-built dataset (fastest).** On acceptance, a frozen snapshot of this repository together with the pre-built `main_data.RData` will be archived on Zenodo with a DOI (see *Replication package and archiving* below). Once available, place `main_data.RData` in `<DROPBOX_ROOT>/build/output/` and **skip step 2** (the build) below.
- **Option B — rebuild from the raw microdata.** Reconstruct `main_data.RData` from the public PNADC microdata with the R packages (step 2 below); no external download needed. This is the currently available path.

The underlying PNADC microdata are public and free from IBGE at
<https://www.ibge.gov.br/estatisticas/sociais/trabalho/9171-pesquisa-nacional-por-amostra-de-domicilios-continua-mensal.html>.
The proxy-validation exercise (Appendix D) additionally uses IBGE's aggregate 2022 telework supplement (Table 9471), expected at `<DROPBOX_ROOT>/build/input/2022_supplement_pnad.xlsx`; `09_supplement_validation.R` skips gracefully if the file is absent.

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

Tested with **R 4.4.2** on macOS. Packages are installed automatically by the master scripts via `pacman::p_load()`; the versions used were:

| Package | Version | Used by |
|---|---|---|
| `data.table` | 1.18.2.1 | build + all analysis |
| `fixest` | 0.12.1 | all regressions/event studies |
| `ggplot2` | 4.0.2 | all figures |
| `here` | 1.0.1 | path resolution |
| `pacman` | 0.5.1 | package loading (master scripts) |
| `PNADcIBGE` | 0.7.5 | build only (download PNADC) |
| `datazoom.social` | 0.1.0 | build only (panel reconstruction) |
| `fwildclusterboot` | 0.14.3 | wild cluster bootstrap (`08_referee_revision.R`) |
| `readxl` | 1.4.3 | proxy-validation supplement (`09_supplement_validation.R`) |

- **Random seeds.** The only stochastic step is the wild cluster bootstrap in `08_referee_revision.R`, which sets `set.seed(20260709)` and `dqrng::dqset.seed(20260709)` before `fwildclusterboot::boottest()`, so its p-value is reproducible.
- Running `config/00_master_analysis.R` regenerates every table and figure in `analysis/output/` from `main_data.RData` with no manual editing.

## Replication package and archiving

This GitHub repository is the browsable, developing version of the replication code. On acceptance, a **frozen snapshot** — the full code in this repository **together with the pre-built analytical dataset (`main_data.RData`)** — will be deposited on **Zenodo**, which mints a permanent DOI. That Zenodo record is the citable, archival replication package referenced in the paper's *Data availability and replication* statement; this GitHub repository mirrors it for convenience. (GitHub is mutable and not archival, which is why the citable record lives on Zenodo.)

## Exhibit crosswalk (paper exhibit → script → output file)

Table and figure numbers below are the numbers as they appear in the paper (main text: 1–8; appendix sections A, D, E).

### Main text

| Exhibit | Script | Output file |
|---|---|---|
| Table 1 — Summary statistics by group × period | `01_descriptives.R` | `tables/tab01_descriptives.tex` |
| Table 2 — Home-based-work specification ladder | `03_did.R` | `tables/tab02_did_firststage.tex` |
| Table 3 — Potential statutory reach (funnel) | `08_referee_revision.R` | `tables/tab03_statutory_reach.tex` |
| Table 4 — Home-based work by predetermined subsample (estimands) | `08_referee_revision.R` | `tables/tab04_estimands.tex` |
| Table 5 — Precision and equivalence (TOST) | `08_referee_revision.R` | `tables/tab05_equivalence.tex` |
| Table 6 — Moderation by baseline telework eligibility | `04_mechanisms.R` | `tables/tab06_mechanism_moderation.tex` |
| Table 7 — Telework-eligible occupation as outcome (sorting) | `04_mechanisms.R` | `tables/tab07_mechanism_allocation.tex` |
| Table 8 — Heterogeneity + Holm correction | `05_heterogeneity.R` | `tables/tab08_heterogeneity.tex` |
| Fig. 1 — Home-based-work trends by group | `01_descriptives.R` | `graphs/fig01_home_office_trends` |
| Fig. 2 — Event study, home-based work | `02_event_study.R` | `graphs/fig06_event_study_home_office` |

### Appendix

| Exhibit | Script | Output file |
|---|---|---|
| Table A.1 — Panel retention | `01_descriptives.R` | `tables/tabA1_panel_retention.tex` |
| Table D.1 — Proxy validation vs 2022 telework supplement | `09_supplement_validation.R` | `tables/tabD1_proxy_validation.tex` |
| Table E.1 — Robustness (longtable) | `06_robustness.R` | `tables/tabE1_robustness.tex` |
| Table E.2 — Inference and estimator robustness | `08_referee_revision.R` | `tables/tabE2_inference.tex` |
| Table E.3 — Outcomes, Control A | `03_did.R` | `tables/tabE3_did_outcomes_A.tex` |
| Table E.4 — Earnings and hours, worker-conditional vs unconditional | `03_did.R` | `tables/tabE4_earnings_margins.tex` |
| Table E.5 — Occupation transition matrix | `04_mechanisms.R` | `tables/tabE5_occupation_transition.tex` |
| Table E.6 — Attrition and IPW | `08_referee_revision.R` | `tables/tabE6_attrition.tex` |
| Table E.7 — Eligibility paths (before/after reform) | `08_referee_revision.R` | `tables/tabE7_identification.tex` |
| Table E.8 — Triple difference (home-based work) | `07_triple_diff.R` | `tables/tabE8_triple_diff.tex` |
| Table E.9 — Triple difference, all outcomes | `07_triple_diff.R` | `tables/tabE9_triple_diff_outcomes.tex` |
| Table E.10 — Outcomes, Control B | `03_did.R` | `tables/tabE10_did_outcomes_B.tex` |
| Fig. D.1 — Proxy validation scatter | `09_supplement_validation.R` | `graphs/fig10_proxy_validation` |
| Fig. E.1 — Event study, maternity leave | `02_event_study.R` | `graphs/fig09_event_study_maternity` |
| Fig. E.2 — Heterogeneity coefplot | `05_heterogeneity.R` | `graphs/fig07_heterogeneity_coefplot` |
| Fig. E.3 — Control-window sweep | `06_robustness.R` | `graphs/fig08_control_window_sweep` |
| Fig. E.4 — Home-based-work trends, telework-eligible subgroup | `01_descriptives.R` | `graphs/fig04_home_office_telework_eligible` |
| Fig. E.5 — LFP / employment trends | `01_descriptives.R` | `graphs/fig03_lfp_employment_trends` |

### Other output

| Item | Script | Output file |
|---|---|---|
| Sample-construction counts (funnel) | `01_descriptives.R` | `output/sample_construction_counts.txt` |

`01_descriptives.R` also generates an additional descriptive figure (`fig02_home_office_two_controls`) and a state map (`fig05_home_office_map_appendix`, under `maps/`) that are kept in the repository but not included in the paper.
