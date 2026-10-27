# =============================================================================
# Figure 10 -- topology of the pathway co-activity networks
#   A  degree distribution at matched density
#   B  network-level topology metrics
#   C  agreement of module partitions between scores
#   D  are the hubs of the fused network also hubs of a single layer?
# =============================================================================

source(file.path(Sys.getenv("MOGSVA_SCRIPT_DIR",
                           "G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures"),
                 "00_common.R"))
source(file.path(SCRIPT_DIR, "00b_network.R"))

d <- load_mogsva()
shared <- shared_pathways(d)
nets <- build_networks(d, shared)

FUSED_COL <- "#2B2B2B"
score_levels <- c(OMICS_LEVELS, "moGSVA fused")
PAL_SCORE <- c(PAL_OMICS, "moGSVA fused" = FUSED_COL)
LAB_SHORT <- c("Copy number alteration" = "CNA", "Methylation" = "Methylation",
               "Transcriptomics" = "Transcriptomics", "Proteomics" = "Proteomics",
               "moGSVA fused" = "Fused")
LAB_TINY <- c("Copy number alteration" = "CNA", "Methylation" = "MET",
              "Transcriptomics" = "TX", "Proteomics" = "PROT",
              "moGSVA fused" = "Fused")

N_EDGES <- 600
graphs <- lapply(nets, tom_graph, n_edges = N_EDGES)
topo <- rbindlist(lapply(nets, net_topology, n_edges = N_EDGES))
topo[, network := factor(network, levels = score_levels)]

## ---- A: degree distribution ------------------------------------------------
degA <- rbindlist(lapply(score_levels, function(nm) {
  k <- degree(graphs[[nm]])
  ks <- sort(unique(k[k >= 1]))
  data.table(network = nm, k = ks,
             ccdf = vapply(ks, function(x) mean(k >= x), numeric(1)))
}))
degA[, network := factor(network, levels = score_levels)]

pA <- ggplot(degA, aes(k, ccdf, colour = network)) +
  geom_step(linewidth = 0.5, direction = "hv") +
  scale_colour_manual(values = PAL_SCORE, labels = LAB_SHORT, name = NULL) +
  scale_x_log10(breaks = c(1, 2, 5, 10, 20, 50)) +
  scale_y_log10(breaks = c(0.01, 0.05, 0.1, 0.5, 1)) +
  labs(x = "Degree k (log scale)", y = "P(K \u2265 k), log scale",
       title = "Degree distributions at matched density",
       subtitle = sprintf("600 edges per network; tails diverge above k \u2248 20 (%d nodes)",
                          length(shared))) +
  guides(colour = guide_legend(nrow = 2, override.aes = list(linewidth = 0.6))) +
  theme(legend.position = "bottom", legend.key.size = unit(6, "pt"))

## ---- B: topology metrics ----------------------------------------------------
metB <- melt(topo[, .(network, transitivity = as.numeric(transitivity),
                      largest_pct = as.numeric(largest_pct),
                      n_module = as.numeric(n_module),
                      unassigned_pct = as.numeric(unassigned_pct))],
             id.vars = "network")
metB[, metric := factor(variable,
                        levels = c("transitivity", "largest_pct", "n_module", "unassigned_pct"),
                        labels = c("Clustering", "Largest comp", "Modules", "Unassigned"))]

pB <- ggplot(metB, aes(network, value, colour = network)) +
  geom_segment(aes(x = network, xend = network, y = 0, yend = value),
               linewidth = 0.35, colour = "grey82") +
  geom_point(size = 1.4) +
  facet_wrap(~ metric, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = PAL_SCORE, guide = "none") +
  scale_x_discrete(labels = LAB_TINY) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.14))) +
  labs(x = NULL, y = NULL,
       title = "No single layer reproduces the fused topology",
       subtitle = "Metrics on the matched-density graphs") +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(angle = 40, hjust = 1, size = 5.2),
        strip.text = element_text(size = 5.4),
        panel.spacing.x = unit(3, "mm"))

## ---- C: module partition agreement -----------------------------------------
ari_mat <- outer(seq_along(score_levels), seq_along(score_levels),
                 Vectorize(function(i, j) {
                   a <- nets[[score_levels[i]]]$module_label
                   b <- nets[[score_levels[j]]]$module_label
                   keep <- a != "grey" & b != "grey"
                   if (sum(keep) < 5) return(NA_real_)
                   ari(a[keep], b[keep])
                 }))
dimnames(ari_mat) <- list(score_levels, score_levels)

ariC <- as.data.table(as.table(ari_mat))
setnames(ariC, c("a", "b", "ari"))
ariC[, `:=`(a = factor(a, levels = rev(score_levels)),
            b = factor(b, levels = score_levels))]

pC <- ggplot(ariC, aes(b, a, fill = ari)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.2f", ari)), size = 2.2, colour = "grey10") +
  scale_fill_gradient2(low = "#B2182B", mid = "#F7F7F7", high = "#1F4E79",
                       midpoint = 0, limits = c(-0.2, 1),
                       breaks = c(-0.2, 0, 0.5, 1),
                       name = "ARI",
                       guide = guide_colourbar(barwidth = unit(2.4, "mm"),
                                               barheight = unit(17, "mm"))) +
  scale_x_discrete(labels = LAB_TINY, position = "top") +
  scale_y_discrete(labels = LAB_TINY) +
  labs(x = NULL, y = NULL,
       title = "Fused modules track the transcriptome",
       subtitle = "Adjusted Rand index over jointly assigned pathways") +
  theme(panel.grid = element_blank(),
        axis.text.x.top = element_text(angle = 0, hjust = 0.5, size = 5.6))

## ---- D: hub consistency -----------------------------------------------------
n_hub <- 15
fused_hubs <- names(sort(nets[["moGSVA fused"]]$k, decreasing = TRUE))[1:n_hub]
rank_mat <- sapply(nets, function(net) rank(-net$k, ties.method = "first"))
pct <- apply(rank_mat, 2, function(r) 100 * (1 - (r - 1) / (length(r) - 1)))
rownames(pct) <- rownames(rank_mat)
overlap <- vapply(score_levels, function(nm) {
  top <- names(sort(nets[[nm]]$k, decreasing = TRUE))[1:20]
  sum(fused_hubs %in% top)
}, numeric(1))
xlab_hub <- sprintf("%s\n(%d/%d)", LAB_TINY[score_levels], overlap, n_hub)

hubD <- as.data.table(as.table(pct[fused_hubs, ]))
setnames(hubD, c("pathway", "network", "pct"))
hubD[, is_hub := as.vector(rank_mat[fused_hubs, ] <= 20)]
hubD[, `:=`(pathway = factor(pathway, levels = rev(fused_hubs)),
            network = factor(network, levels = score_levels))]

pD <- ggplot(hubD, aes(network, pathway, fill = pct)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_point(data = hubD[is_hub == TRUE], shape = 16, size = 0.7, colour = "white") +
  scale_fill_gradient(low = "#F7F7F7", high = "#1F4E79", limits = c(0, 100),
                      name = "Connectivity\npercentile",
                      guide = guide_colourbar(barwidth = unit(2.2, "mm"),
                                              barheight = unit(15, "mm"))) +
  scale_x_discrete(labels = xlab_hub, position = "top") +
  scale_y_discrete(labels = function(x) wrap_pathway(x, 40)) +
  labs(x = NULL, y = NULL,
       title = "Fused hubs are only partly layer hubs",
       subtitle = "Top 15 fused hubs; white dot = top-20 hub in that layer") +
  theme(panel.grid = element_blank(),
        axis.text.x.top = element_text(angle = 0, hjust = 0.5, size = 5.0, lineheight = 0.95),
        axis.text.y = element_text(size = 5.0, lineheight = 0.88))

## ---- assemble --------------------------------------------------------------
fig10 <- (pA | pB) / (pC | pD) +
  plot_layout(heights = c(0.95, 1.25), widths = c(1, 1.2)) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(size = 10, face = "bold"))

save_fig(fig10, "Figure10_network_topology", width_mm = 183, height_mm = 170)
