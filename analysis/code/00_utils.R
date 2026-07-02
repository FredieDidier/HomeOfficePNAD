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

postprocess_tex <- function(file, fontsize = "\\small", tabcolsep = 4) {
  tx <- readLines(file)
  tx <- tx[!grepl("standard-errors in parentheses", tx, fixed = TRUE)]
  tx <- sub("\\tabularnewline \\midrule \\midrule", "\\toprule", tx, fixed = TRUE)
  tx <- sub("^\\s*\\\\midrule \\\\midrule\\s*$", "\\\\bottomrule", tx)
  i  <- grep("\\begin{tabular}", tx, fixed = TRUE)[1]
  tx <- append(tx, paste0(fontsize, "\\setlength{\\tabcolsep}{", tabcolsep, "pt}"),
               after = i - 1)
  writeLines(tx, file)
}

# Standard significance legend used in every table note.
SIGNIF_NOTE <- "Significance levels: *** $p<0.01$, ** $p<0.05$, * $p<0.10$."
