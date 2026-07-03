# HomeOfficePNAD

Replication code for **"A Priority That Does Not Bind: Telework Mandates and Mothers of Young Children in Brazil."** The paper evaluates whether Brazil's 2022 telework-priority reform (MP 1108/2022 → Law 14.442/2022, Art. 75-F) changed the labor-market outcomes of eligible women, using the rotating panel of the PNAD Contínua and a difference-in-differences design. The result is a precisely-estimated null.

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

`main_data.RData` covers 2018Q1–2026Q1 and holds both sexes; women are the analysis sample.

## Reproducing the results

1. **Set the data path.** Edit the single line in `config/config.R`:

   ```r
   DROPBOX_ROOT <- "/path/to/your/HomeOfficePNAD"
   ```

   This is the only path that changes per machine; all repository paths are resolved automatically with `here::here()`.

2. **Install R packages** (once):

   ```r
   install.packages(c("data.table", "fixest", "ggplot2", "here", "readxl",
                      "PNADcIBGE", "remotes"))
   remotes::install_github("datazoompuc/datazoom.social")
   # optional, only for the descriptive state map (not used in the paper):
   install.packages(c("geobr", "sf"))
   ```

3. **Build the dataset** (skip if `main_data.RData` already exists):

   ```r
   source("config/00_master_build.R")
   ```

   Downloading the raw PNADC from IBGE is commented out at the bottom of `build/01_pnadc.R`; uncomment `download_pnadc_panels()` there only to (re-)download.

4. **Run the analysis** (writes all tables and figures to `analysis/output/`):

   ```r
   source("config/00_master_analysis.R")
   ```

5. **Compile the paper** (run the full cycle, or use `latexmk`):

   ```
   cd latex && latexmk -pdf paper.tex
   # or: pdflatex paper && bibtex paper && pdflatex paper && pdflatex paper
   ```

## Author

Fredie Didier — fdidier@terra.com.br
