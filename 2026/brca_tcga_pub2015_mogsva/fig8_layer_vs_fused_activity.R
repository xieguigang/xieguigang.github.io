# =============================================================================
# Figure 8 -- pathway activity of each single omics layer versus the fused score
#   A  distribution of activity values per layer and after fusion
#   B  the same pathways and tumours side by side (row z-score heatmaps)
#   C  pathway dispersion: single layer versus fused
#   D  pathway-pathway coherence: how strongly pathways co-vary in each score
# =============================================================================

source(file.path(Sys.getenv("MOGSVA_SCRIPT_DIR",
                           "G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures"),
                 "00_common.R"))
suppressPackageStartupMessages(library(matrixStats))

d <- load_mogsva()
shared <- shared_pathways(d)
st <- activity_stack(d)
FUSED_COL <- "#2B2B2B"
PAL_SCORE <- c(PAL_OMICS, "moGSVA fused" = FUSED_COL)
LAB_SHORT <- c("Copy number alteration" = "CNA", "Methylation" = "Methylation",
               "Transcriptomics" = "Transcriptomics", "Proteomics" = "Proteomics",
               "moGSVA fused" = "Fused")
score_levels <- names(st)

## ---- A: distribution of activity values ------------------------------------
longA <- rbindlist(lapply(score_levels, function(nm) {
  v <- as.vector(st[[nm]][shared, , drop = FALSE])
  data.table(score = nm, value = v[!is.na(v)])
}))
longA[, score := factor(score, levels = score_levels)]
medA <- longA[, .(m = median(value)), by = score]

pA <- ggplot(longA, aes(score, value, fill = score)) +
  geom_hline(yintercept = 0, linetype = 3, linewidth = 0.3, colour = "grey55") +
  geom_violin(scale = "width", colour = NA, alpha = 0.85, trim = TRUE) +
  geom_boxplot(width = 0.12, outlier.shape = NA, fill = "white",
               colour = "grey20", linewidth = 0.25) +
  geom_point(data = medA, aes(score, m), shape = 21, size = 0.9,
             fill = "white", colour = "black", stroke = 0.25, inherit.aes = FALSE) +
  scale_fill_manual(values = PAL_SCORE, guide = "none") +
  scale_x_discrete(labels = LAB_SHORT[score_levels]) +
  labs(x = NULL, y = "Pathway activity score (ES)",
       title = "Single layers differ in scale and dispersion",
       subtitle = sprintf("%d pathways x %d tumours per score; open dot = median",
                          length(shared), d$n_sample)) +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(size = 5.6, angle = 22, hjust = 1))

## ---- B: five heatmaps on a common order ------------------------------------
top_b <- names(sort(rowVars(st[["moGSVA fused"]][shared, , drop = FALSE]),
                    decreasing = TRUE))[1:24]

S_fused <- st[["moGSVA fused"]][top_b, , drop = FALSE]
hc_col <- hclust(as.dist(1 - stats::cor(S_fused)), method = "average")
col_order <- hc_col$labels[hc_col$order]
col_split <- cutree(hc_col, k = 3)[col_order]
breaks <- which(diff(col_split) != 0) + 0.5      # cluster boundaries on the x axis

heat_dt <- rbindlist(lapply(score_levels, function(nm) {
  m <- row_z(st[[nm]][top_b, col_order, drop = FALSE])
  m[m > 2.5] <- 2.5; m[m < -2.5] <- -2.5
  dt <- as.data.table(as.table(m))
  setnames(dt, c("pathway", "sample", "z"))
  dt[, `:=`(score = factor(nm, levels = score_levels),
            x = match(sample, col_order),
            pathway = factor(pathway, levels = rev(top_b)))]
  dt
}))

pB <- ggplot(heat_dt, aes(x, pathway, fill = z)) +
  geom_tile(width = 1.04, height = 1) +
  geom_vline(xintercept = breaks, colour = "white", linewidth = 1.1) +
  facet_grid(~ score, scales = "free_x", space = "free_x",
             labeller = as_labeller(LAB_SHORT)) +
  scale_fill_gradient2(low = GRAD_LOW, mid = GRAD_MID, high = GRAD_HIGH,
                       midpoint = 0, limits = c(-2.5, 2.5),
                       breaks = c(-2.5, 0, 2.5),
                       labels = c("\u2264-2.5", "0", "\u22652.5"),
                       name = "Row z-score",
                       guide = guide_colourbar(direction = "horizontal",
                                               barwidth = unit(18, "mm"),
                                               barheight = unit(2.2, "mm"),
                                               title.vjust = 0.85)) +
  scale_x_continuous(expand = c(0, 0), breaks = NULL) +
  scale_y_discrete(labels = function(x) wrap_pathway(x, 42),
                   expand = c(0, 0)) +
  labs(x = "Tumours (columns in one shared order)", y = NULL,
       title = "Same pathways, same tumours, five activity scores",
       subtitle = "24 most variable pathways of the fused score; rows and tumours share one order, each panel row-scaled") +
  theme(panel.grid = element_blank(),
        panel.spacing.x = unit(1.6, "mm"),
        axis.text.y = element_text(size = 4.8, lineheight = 0.85),
        strip.background = element_rect(fill = "grey95", colour = NA),
        strip.text = element_text(size = 6, face = "bold"),
        legend.position = "bottom",
        legend.title = element_text(size = 5.4))

## ---- C: dispersion per pathway ---------------------------------------------
sdC <- rbindlist(lapply(OMICS_LEVELS, function(om) {
  a <- rowSds(st[[om]][shared, , drop = FALSE], na.rm = TRUE)
  f <- rowSds(st[["moGSVA fused"]][shared, , drop = FALSE], na.rm = TRUE)
  data.table(omics = om, layer = a, fused = f)
}))
sdC[, omics := factor(omics, levels = OMICS_LEVELS)]
ratioC <- sdC[, .(r = median(layer / fused)), by = omics]
ratioC[, lab := sprintf("%s %.2fx", LAB_SHORT[omics], r)]

ratio_lab <- setNames(sprintf("%s (%.2f\u00D7)", LAB_SHORT[ratioC$omics], ratioC$r),
                      ratioC$omics)

pC <- ggplot(sdC, aes(fused, layer, colour = omics)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, linewidth = 0.3, colour = "grey45") +
  geom_point(size = 0.45, alpha = 0.55, stroke = 0) +
  scale_colour_manual(values = PAL_OMICS, labels = ratio_lab, name = NULL) +
  scale_x_continuous(expand = expansion(mult = c(0.02, 0.04))) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.04))) +
  labs(x = "SD of the fused score", y = "SD of the single-layer score",
       title = "Fusion is less dispersed than any layer",
       subtitle = "One point per shared pathway; legend = median ratio to fused SD") +
  guides(colour = guide_legend(nrow = 2, override.aes = list(size = 1.3, alpha = 1))) +
  theme(legend.position = "bottom", legend.key.size = unit(6, "pt"))

## ---- D: pathway-pathway coherence ------------------------------------------
cohD <- rbindlist(lapply(score_levels, function(nm) {
  r <- stats::cor(t(st[[nm]][shared, , drop = FALSE]), use = "complete.obs")
  data.table(score = nm, r = abs(r[upper.tri(r)]))
}))
cohD[, score := factor(score, levels = score_levels)]
coh_sum <- cohD[, .(med = median(r)), by = score]

pD <- ggplot(cohD, aes(score, r, fill = score)) +
  geom_violin(scale = "width", colour = NA, alpha = 0.85, trim = TRUE) +
  geom_boxplot(width = 0.13, outlier.shape = NA, fill = "white",
               colour = "grey20", linewidth = 0.25) +
  geom_text(data = coh_sum, aes(x = score, y = Inf, label = sprintf("median |r| = %.2f", med)),
            inherit.aes = FALSE, vjust = 1.6, size = 2.0, colour = "grey15") +
  scale_fill_manual(values = PAL_SCORE, guide = "none") +
  scale_x_discrete(labels = LAB_SHORT[score_levels]) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.14))) +
  labs(x = NULL, y = "|Pearson r| between pathway pairs",
       title = "Coherence of the pathway co-activity structure",
       subtitle = sprintf("All %s pathway pairs of the %d shared pathways",
                          format(choose(length(shared), 2), big.mark = ","), length(shared))) +
  theme(panel.grid.major.x = element_blank())

## ---- assemble --------------------------------------------------------------
fig8 <- (pA | pC) / pB / pD +
  plot_layout(heights = c(1, 2.15, 0.78), widths = c(1.1, 1)) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(size = 10, face = "bold"))

save_fig(fig8, "Figure8_layer_vs_fused_activity", width_mm = 183, height_mm = 205)
