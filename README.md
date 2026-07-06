# The Labor Market Effects of a Telework Priority Mandate for Mothers of Young Children in Brazil — Replication Package

**Author:** Fredie Didier (fdidier@terra.com.br)


## Repository layout

```
config/
  config.R              # <-- THE ONLY FILE TO EDIT (set DROPBOX_ROOT)
  00_master_build.R     # runs the data build
  00_master_analysis.R  # runs all analysis scripts
build/01_pnadc.R        # download PNADC, build panels, merge main_data.RData
analysis/code/          # 00_utils.R, 01_descriptives.R … 07_triple_diff.R
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
