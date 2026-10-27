# =============================================================================
# Figure 9 -- WGCNA co-activity networks of pathway activity
#   A  soft-threshold diagnostics for the five scores
#   B-F  one network per omics layer and one for the fused score
#
# Nodes are the 156 pathways measured in all four layers; edges are the 600
# strongest topological-overlap pairs, so every panel has the same density.
# =============================================================================

source(file.path(Sys.getenv("MOGSVA_SCRIPT_DIR",
                           "G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures"),
                 "00_common.R"))
source(file.path(SCRIPT_DIR, "00b_network.R"))

d <- load_mogsva()
shared <- shared_pathways(d)
nets <- build_networks(d, shared)

FUSED_COL <- "#2B2B2B"
PAL_SCORE <- c(PAL_OMICS, "moGSVA fused" = FUSED_COL)
LAB_SHORT <- c("Copy number alteration" = "CNA", "Methylation" = "Methylation",
               "Transcriptomics" = "Transcriptomics", "Proteomics" = "Proteomics",
               "moGSVA fused" = "Fused")
score_levels <- c(OMICS_LEVELS, "moGSVA fused")

PAL_MODULE <- c("M1" = "#2F5D8C", "M2" = "#C0504D", "M3" = "#2E8B70",
                "M4" = "#E1A33A", "M5" = "#7B6AA8", "grey" = "#D5D5D5")

## ---- A: soft-threshold diagnostics -----------------------------------------
sftA <- rbindlist(lapply(score_levels, function(nm) {
  fi <- nets[[nm]]$sft$fitIndices
  data.table(score = nm, power = fi$Power, r2 = pmax(fi$SFT.R.sq, 0))
}))
sftA <- sftA[power <= 12]
sftA[, score := factor(score, levels = score_levels)]
chosen <- data.table(score = factor(score_levels, levels = score_levels),
                     power = vapply(score_levels, function(nm) nets[[nm]]$beta, numeric(1)))
chosen <- merge(chosen, sftA, by = c("score", "power"))

pA <- ggplot(sftA, aes(power, r2, colour = score)) +
  geom_hline(yintercept = 0.8, linetype = 2, linewidth = 0.3, colour = "grey45") +
  geom_line(linewidth = 0.45) +
  geom_point(size = 0.55) +
  geom_point(data = chosen, aes(power, r2), size = 1.7, shape = 21,
             fill = "white", stroke = 0.6, show.legend = FALSE) +
  annotate("text", x = 0.6, y = 0.82, hjust = 0, vjust = -0.4, size = 2.0,
           colour = "grey35", label = "scale-free fit = 0.80") +
  scale_colour_manual(values = PAL_SCORE, labels = LAB_SHORT, name = NULL) +
  scale_x_continuous(breaks = c(1, 3, 5, 7, 9, 11)) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25)) +
  labs(x = "Soft-thresholding power (\u03B2)", y = expression("Scale-free fit " * R^2),
       title = "Soft thresholds differ between scores",
       subtitle = "Open circles mark the power used below") +
  guides(colour = guide_legend(nrow = 2, override.aes = list(size = 1.2))) +
  theme(legend.position = "bottom", legend.key.size = unit(6, "pt"))

## ---- B-F: network panels ----------------------------------------------------
max_k_all <- max(vapply(nets, function(x) max(x$k), numeric(1)))

draw_net <- function(nm) {
  net <- nets[[nm]]
  g <- tom_graph(net, n_edges = 600)
  lay <- net_layout(g, seed = 20261028)
  lay[, `:=`(module = V(g)$module[match(name, V(g)$name)],
             k = V(g)$k[match(name, V(g)$name)])]

  ed <- as.data.table(as_edgelist(g))
  setnames(ed, c("from", "to"))
  ed[, weight := E(g)$weight]
  ed <- merge(ed, lay[, .(from = name, x, y)], by = "from")
  ed <- merge(ed, lay[, .(to = name, xend = x, yend = y)], by = "to")

  ggplot() +
    geom_segment(data = ed, aes(x, y, xend = xend, yend = yend, linewidth = weight),
                 colour = "grey55", alpha = 0.28, lineend = "round") +
    geom_point(data = lay, aes(x, y, fill = module, size = k),
               shape = 21, colour = "grey15", stroke = 0.15) +
    scale_linewidth_continuous(range = c(0.06, 0.35), guide = "none") +
    scale_size_continuous(range = c(0.25, 2.0), guide = "none") +
    scale_fill_manual(values = PAL_MODULE, name = "Module", drop = FALSE) +
    scale_x_continuous(expand = expansion(mult = 0.03)) +
    scale_y_continuous(expand = expansion(mult = 0.03)) +
    labs(title = LAB_SHORT[[nm]],
         subtitle = sprintf("beta = %d  |  %d modules  |  %.0f%% unassigned",
                            net$beta, net$n_module,
                            100 * net$unassigned / length(shared))) +
    coord_equal(clip = "off") +
    theme_void(base_size = 7) +
    theme(
      plot.title = element_text(size = 7.2, face = "bold", hjust = 0,
                                colour = if (nm == "moGSVA fused") FUSED_COL else "grey15"),
      plot.subtitle = element_text(size = 5.4, hjust = 0, colour = "grey30"),
      plot.margin = margin(2, 2, 3, 2),
      plot.background = element_rect(
        fill = if (nm == "moGSVA fused") "#F4F6F8" else "white",
        colour = if (nm == "moGSVA fused") FUSED_COL else NA, linewidth = 0.5),
      legend.position = "none"
    )
}

net_panels <- lapply(score_levels, draw_net)
names(net_panels) <- score_levels

## ---- assemble --------------------------------------------------------------
# one shared module legend, drawn once on the top-left panel
pB <- net_panels[["Copy number alteration"]]

fig9 <- (pA | pB | net_panels[["Methylation"]]) /
  (net_panels[["Transcriptomics"]] | net_panels[["Proteomics"]] | net_panels[["moGSVA fused"]]) +
  plot_layout(heights = c(1, 1)) +
  plot_annotation(
    tag_levels = "A",
    caption = paste0("Node colour: co-activity module, numbered by size within each network (M1 largest); grey = unassigned.  ",
                     "Node size: connectivity, scaled within each panel.  Edges: the 600 strongest topological-overlap pairs.\n",
                     "Node set: the 156 pathways measured in all four layers.")) &
  theme(plot.caption = element_text(size = 5.4, colour = "grey30", hjust = 0)) &
  theme(plot.tag = element_text(size = 10, face = "bold"))
save_fig(fig9, "Figure9_wgcna_networks", width_mm = 183, height_mm = 150)
