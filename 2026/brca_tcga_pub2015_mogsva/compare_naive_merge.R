# =============================================================================
# compare_naive_merge.R -- moGSVA versus "per-omics GSVA then merge"
#
# Builds the classical Baseline-1 alternative from layer_scores.csv:
#   merge_mean : equal-weight mean of the per-omics ES of a pathway
#   merge_z    : the same after z-scoring each layer's ES across tumours
# and compares it with the moGSVA fused score on the metrics that matter for a
# paper: score geometry, layer attribution, conflict handling, and downstream
# association with ER status and overall survival.
#
#   Rscript compare_naive_merge.R
# =============================================================================

source(file.path(Sys.getenv("MOGSVA_SCRIPT_DIR",
                           "G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures"),
                 "00_common.R"))
suppressPackageStartupMessages({
  library(matrixStats)
  library(survival)
})

d <- load_mogsva()
S <- d$scores
P <- d$pooled
an <- d$annotation

## ---- build the two merge baselines -----------------------------------------
ls <- d$layer_scores
mats <- lapply(OMICS_LEVELS, function(om) {
  w <- dcast(ls[omics == om], pathway ~ sample, value.var = "score")
  m <- as.matrix(w[, -1]); rownames(m) <- w$pathway
  full <- matrix(NA_real_, nrow(S), ncol(S), dimnames = dimnames(S))
  cc <- intersect(rownames(m), rownames(S))
  full[cc, ] <- m[cc, colnames(S)]
  full
})
names(mats) <- OMICS_LEVELS

arr <- array(NA_real_, dim = c(length(OMICS_LEVELS), nrow(S), ncol(S)),
             dimnames = list(OMICS_LEVELS, rownames(S), colnames(S)))
for (om in OMICS_LEVELS) arr[om, , ] <- mats[[om]]

n_obs <- apply(!is.na(arr), c(2, 3), sum)          # layers per observation
merge_mean <- apply(arr, c(2, 3), function(v) if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE))

z <- arr
for (om in OMICS_LEVELS) {
  m <- mats[[om]]
  zs <- t(scale(t(m)))                              # z-score across tumours
  z[om, , ] <- zs
}
merge_z <- apply(z, c(2, 3), function(v) if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE))

dimnames(merge_mean) <- dimnames(S)
dimnames(merge_z) <- dimnames(S)

methods <- list(
  "moGSVA fused"       = S,
  "Merge (equal mean)" = merge_mean,
  "Merge (z-scored)"   = merge_z
)
multi <- which(apply(!is.na(arr), 2, sum) >= 1)     # every pathway has >= 1 layer

## ---- 1. geometry ------------------------------------------------------------
cat("== score geometry ==\n")
geo <- rbindlist(lapply(names(methods), function(k) {
  m <- methods[[k]]
  data.table(method = k,
             mean_abs = mean(abs(m), na.rm = TRUE),
             median_sd = median(rowSds(m), na.rm = TRUE),
             min = min(m, na.rm = TRUE), max = max(m, na.rm = TRUE))
}))
print(geo)
cat("\nagreement between methods (Spearman, per pathway median):\n")
cmb <- combn(names(methods), 2, simplify = FALSE)
for (p in cmb) {
  r <- sapply(rownames(S), function(pw) {
    suppressWarnings(cor(methods[[p[1]]][pw, ], methods[[p[2]]][pw, ], method = "spearman"))
  })
  cat(sprintf("  %-20s vs %-20s median rho = %.3f\n", p[1], p[2], median(r, na.rm = TRUE)))
}

## ---- 2. which layer the score follows --------------------------------------
cat("\n== correlation of each score with the per-layer ES (median over pathways) ==\n")
layer_r <- rbindlist(lapply(names(methods), function(k) {
  rbindlist(lapply(OMICS_LEVELS, function(om) {
    r <- sapply(rownames(S), function(pw) {
      suppressWarnings(cor(methods[[k]][pw, ], mats[[om]][pw, ]))
    })
    data.table(method = k, layer = om, median_r = median(r, na.rm = TRUE))
  }))
}))
print(dcast(layer_r, method ~ layer, value.var = "median_r"), digits = 2)

# variance share each layer contributes to the merged score (linear decomposition)
cat("\n== variance budget of each composite score ==\n")
for (k in c("moGSVA fused", "Merge (equal mean)", "Merge (z-scored)")) {
  v <- var(as.vector(methods[[k]]), na.rm = TRUE)
  cat(sprintf("  %-20s total variance = %.5f\n", k, v))
}

## ---- 3. conflict handling ---------------------------------------------------
cat("\n== conflict handling ==\n")
low_agree <- d$cons < 0.5            # at least one layer disagrees with the majority
big_naive <- abs(merge_mean) > 0.15
cat(sprintf("  observations with a < 0.5 : %s (%.1f%%)\n",
            format(sum(low_agree), big.mark = ","), 100 * mean(low_agree)))
cat(sprintf("  of these, |merge| > 0.15  : %s (naive merge still reports a confident score)\n",
            format(sum(low_agree & big_naive, na.rm = TRUE), big.mark = ",")))
cat(sprintf("  of these, |fusion| > 0.15 : %s\n",
            format(sum(low_agree & abs(S) > 0.15, na.rm = TRUE), big.mark = ",")))
cat(sprintf("  median |merge| / |fusion| on low-agreement observations: %.2f\n",
            median(abs(merge_mean[low_agree]) / abs(S[low_agree]), na.rm = TRUE)))

## ---- 4. downstream: ER status ----------------------------------------------
cat("\n== ER contrast ==\n")
er <- an$er; keep <- !is.na(er) & er %in% c("Positive", "Negative")
er_res <- rbindlist(lapply(names(methods), function(k) {
  m <- methods[[k]][, keep]
  p <- apply(m, 1, function(x) wilcox.test(x ~ factor(er[keep]))$p.value)
  delta <- apply(m, 1, function(x)
    median(x[er[keep] == "Positive"]) - median(x[er[keep] == "Negative"]))
  q <- p.adjust(p, "BH")
  data.table(method = k, pathway = rownames(m), p = p, q = q, delta = delta)
}))
summ <- er_res[, .(n_fdr05 = sum(q < 0.05),
                   n_fdr01 = sum(q < 0.01),
                   median_abs_delta_sig = median(abs(delta[q < 0.05])),
                   up_ERpos = sum(q < 0.05 & delta > 0),
                   up_ERneg = sum(q < 0.05 & delta < 0)),
               by = method]
print(summ)

# do the methods agree on the direction of the ER effect?
w <- dcast(er_res, pathway ~ method, value.var = "delta")
cat("\n  correlation of ER effect sizes between methods:\n")
for (p in combn(names(methods), 2, simplify = FALSE)) {
  cat(sprintf("    %-20s vs %-20s r = %.3f\n", p[1], p[2],
              cor(w[[p[1]]], w[[p[2]]], use = "complete.obs")))
}

## ---- 4b. three-way comparison on the pathways scored by all three methods ---
# the pooled baseline drops one pathway and filters differently, so the fair
# comparison runs on the intersection (285 pathways)
Pc <- P[intersect(rownames(S), rownames(P)), , drop = FALSE]
common <- rownames(Pc)[complete.cases(Pc)]
methods3 <- c(methods, list("Pooled baseline" = Pc))
three <- rbindlist(lapply(names(methods3), function(k) {
  m <- methods3[[k]][common, , drop = FALSE]
  p <- apply(m[, keep], 1, function(x) wilcox.test(x ~ factor(er[keep]))$p.value)
  q <- p.adjust(p, "BH")
  time <- an$os_time; event <- an$os_event
  ok2 <- !is.na(time) & !is.na(event) & time > 0
  po <- vapply(rownames(m), function(pw) {
    x <- m[pw, ok2]; g <- factor(x > median(x), levels = c(FALSE, TRUE))
    pchisq(survdiff(Surv(time[ok2], event[ok2]) ~ g)$chisq, 1, lower.tail = FALSE)
  }, numeric(1))
  data.table(method = k,
             n_pathway = length(common),
             ER_fdr05 = sum(q < 0.05),
             ER_min_q = min(q),
             OS_fdr05 = sum(p.adjust(po, "BH") < 0.05))
}))
cat("\n== three-way comparison on the 285 shared pathways ==\n")
print(three)
fwrite(three, file.path(OUT_DIR, "comparison_three_way.csv"))

## ---- 5. downstream: overall survival ---------------------------------------
cat("\n== overall survival ==\n")
time <- an$os_time; event <- an$os_event
ok <- !is.na(time) & !is.na(event) & time > 0
os_res <- rbindlist(lapply(names(methods), function(k) {
  m <- methods[[k]][, ok]
  p <- vapply(rownames(m), function(pw) {
    x <- m[pw, ]
    g <- factor(x > median(x), levels = c(FALSE, TRUE))
    pchisq(survdiff(Surv(time[ok], event[ok]) ~ g)$chisq, 1, lower.tail = FALSE)
  }, numeric(1))
  data.table(method = k, pathway = rownames(m), p = p, q = p.adjust(p, "BH"))
}))
print(os_res[, .(n_p05 = sum(p < 0.05), n_fdr05 = sum(q < 0.05), min_p = min(p)), by = method])

## ---- 6. attribution ---------------------------------------------------------
cat("\n== layer attribution ==\n")
cat("  moGSVA exports a per-tumour contribution share for every layer (contributions.csv),\n")
cat("  so the driving layer is identifiable. Both merge baselines output a single number\n")
cat("  per pathway and tumour and cannot say which layer produced it.\n")
ct <- d$contributions
share_sd <- ct[, .(sd_share = sd(share)), by = .(pathway, omics)]
cat(sprintf("  median within-pathway SD of the contribution share across tumours: %.3f\n",
            median(share_sd$sd_share)))
cat("  (i.e. the leading layer changes from tumour to tumour, which a fixed 1/K average cannot represent)\n")

## ---- write a tidy summary ---------------------------------------------------
tab <- data.table(
  metric = c("mean |score|", "median pathway SD",
             "ER: pathways at FDR < 0.05", "ER: median |delta| of hits",
             "OS: pathways at FDR < 0.05", "layer attribution"),
  `moGSVA fused` = c(sprintf("%.3f", geo[method == "moGSVA fused", mean_abs]),
                     sprintf("%.3f", geo[method == "moGSVA fused", median_sd]),
                     summ[method == "moGSVA fused", n_fdr05],
                     sprintf("%.3f", summ[method == "moGSVA fused", median_abs_delta_sig]),
                     os_res[method == "moGSVA fused", sum(q < 0.05)],
                     "yes (contribution share)"),
  `Merge (equal mean)` = c(sprintf("%.3f", geo[method == "Merge (equal mean)", mean_abs]),
                           sprintf("%.3f", geo[method == "Merge (equal mean)", median_sd]),
                           summ[method == "Merge (equal mean)", n_fdr05],
                           sprintf("%.3f", summ[method == "Merge (equal mean)", median_abs_delta_sig]),
                           os_res[method == "Merge (equal mean)", sum(q < 0.05)],
                           "no"),
  `Merge (z-scored)` = c(sprintf("%.3f", geo[method == "Merge (z-scored)", mean_abs]),
                         sprintf("%.3f", geo[method == "Merge (z-scored)", median_sd]),
                         summ[method == "Merge (z-scored)", n_fdr05],
                         sprintf("%.3f", summ[method == "Merge (z-scored)", median_abs_delta_sig]),
                         os_res[method == "Merge (z-scored)", sum(q < 0.05)],
                         "no")
)
cat("\n== summary table ==\n")
print(tab)
fwrite(tab, file.path(OUT_DIR, "comparison_naive_merge.csv"))
fwrite(er_res, file.path(OUT_DIR, "comparison_ER_effects.csv"))
cat("\nwritten: comparison_naive_merge.csv, comparison_ER_effects.csv\n")
