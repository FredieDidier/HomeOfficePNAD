# =============================================================================
# 00_utils.R — shared helpers for the analysis scripts.
#
# postprocess_tex(): cleans a fixest `etable()` LaTeX file into the project's
# house style, so every regression table matches the hand-built booktabs tables
# (tab01, tab06, tab07). It:
#   1. drops the automatic "... standard-errors in parentheses" footer row
#      (that information is stated once, in the table note instead);
#   2. converts fixest's double \midrule top/bottom rules to booktabs
#      \toprule / \bottomrule;
#   3. injects a font-size and \tabcolsep setting so wide multi-column tables
#      stay within the text margins.
# Call it right after each etable() that writes to `file`, and pass the
# significance legend through etable's own `notes =` argument together with
# `signif.code = NA` (which removes the redundant "Signif. Codes" row).
# =============================================================================

postprocess_tex <- function(file, fontsize = "\\small", tabcolsep = 4, addspace = TRUE) {
  tx <- readLines(file)
  tx <- tx[!grepl("standard-errors in parentheses", tx, fixed = TRUE)]
  tx <- tx[!grepl("Signif. Codes", tx, fixed = TRUE)]  # our own legend is in the note
  tx <- sub("\\begin{table}[htbp]", "\\begin{table}[H]", tx, fixed = TRUE)  # float placement
  tx <- sub("\\tabularnewline \\midrule \\midrule", "\\toprule", tx, fixed = TRUE)
  tx <- sub("^\\s*\\\\midrule \\\\midrule\\s*$", "\\\\bottomrule", tx)
  # Add a small vertical gap after each standard-error row (rows whose first cell
  # is empty and that carry a parenthesized SE) so each coefficient is visually
  # grouped with its own SE, keeping successive variables clearly separated.
  if (addspace) {
    se <- grepl("^\\s*&.*\\([0-9]", tx)
    if (any(se)) {
      out <- vector("list", length(tx))
      for (k in seq_along(tx)) out[[k]] <- if (se[k]) c(tx[k], "\\addlinespace[2pt]") else tx[k]
      tx <- unlist(out)
    }
  }
  i  <- grep("\\begin{tabular}", tx, fixed = TRUE)[1]
  tx <- append(tx, paste0(fontsize, "\\setlength{\\tabcolsep}{", tabcolsep, "pt}"),
               after = i - 1)
  writeLines(tx, file)
}

# =============================================================================
# Shared note fragments, so every regression-table note follows one house style:
#   1. what each column/row estimates, with a green hyperlink to Eq. (1);
#   2. the sample;
#   3. units of the outcomes (0/1 indicators, log earnings, hours);
#   4. weighting; 5. clustering; 6. significance legend.
# Build a note as paste(<lead sentence(s), EQ_REF inline>, WEIGHT_NOTE,
# CLUSTER_NOTE, SIGNIF_NOTE). Each constant is a full sentence ending in a
# period so paste()'s spaces read cleanly.
# =============================================================================

# Standard significance legend used in every table note.
SIGNIF_NOTE <- "Significance levels: *** $p<0.01$, ** $p<0.05$, * $p<0.10$."

# Green hyperlink to the difference-in-differences equation (Eq. 1). Renders as
# "Eq. (1)" with the "(1)" coloured like a cross-reference (green in this draft).
EQ_REF <- "Eq.~\\eqref{eq:did}"

# Weighting and clustering sentences, identical across the main specifications.
WEIGHT_NOTE  <- "All regressions are weighted by the survey weights."
CLUSTER_NOTE <- "Standard errors are clustered at the household level in parentheses."

# Units sentence for the multi-outcome tables. Real earnings enter in logs (as in
# the robustness table), so their coefficient is an approximate proportional effect.
UNITS_NOTE <- "Home office, employed, in labor force, and maternity leave are 0/1 indicators, so a coefficient of $0.01$ corresponds to one percentage point; log earnings is the natural logarithm of real monthly labor earnings, so its coefficient is an approximate proportional effect, and usual hours are usual weekly hours---both defined only for workers."
