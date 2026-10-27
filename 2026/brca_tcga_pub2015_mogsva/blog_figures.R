# =============================================================================
# blog_figures.R -- teaching figures for the two blog posts
#
#   figA  how a single gene becomes a rank, and how a pathway becomes a walk
#   figB  the feature-balanced weight curve
#   figC  the consistency reward as a function of the agreement value
#
# Output: blog/figures/*.svg (vector, embedded inline in the HTML posts)
# =============================================================================

source(file.path(Sys.getenv("MOGSVA_SCRIPT_DIR",
                           "G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures"),
                 "00_common.R"))
suppressPackageStartupMessages({
  library(svglite)
  library(matrixStats)
})

BLOG_DIR <- file.path(SCRIPT_DIR, "blog")
FIG_DIR <- file.path(BLOG_DIR, "figures")
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)

save_svg <- function(p, name, w = 7.2, h = 2.6) {
  f <- file.path(FIG_DIR, paste0(name, ".svg"))
  svglite(f, width = w, height = h, bg = "white")
  print(p)
  dev.off()

  # raster twin for previews and for readers whose platform drops inline SVG
  g <- file.path(FIG_DIR, paste0(name, ".png"))
  ragg::agg_png(g, width = w, height = h, units = "in", res = 300, background = "white")
  print(p)
  dev.off()

  message("  ", f)
}

## ---- A: KDE -> rank -> walk ------------------------------------------------
# one real pathway in one real tumour, transcriptome layer
expr <- data.table::fread(file.path(RAW_DIR, "mrna.txt"))
genes <- expr[[1]]
mat <- as.matrix(expr[, -1]); rownames(mat) <- genes
gmt_lines <- readLines(file.path(RAW_DIR, "kegg_v3.gmt"))
gmt_fields <- strsplit(gmt_lines, "\t")
sets <- setNames(lapply(gmt_fields, function(v) v[-(1:2)]),
                 vapply(gmt_fields, `[`, character(1), 1))
pw <- "Glycolysis / Gluconeogenesis"
members <- intersect(sets[[pw]], rownames(mat))

s <- colnames(mat)[1]
x <- mat[, s]
o <- order(x, decreasing = TRUE)
ranked <- x[o]
hit <- names(ranked) %in% members
N <- length(ranked); Nh <- sum(hit)
w <- abs(ranked)^0                      # unweighted KS walk, for teaching
step_hit <- w / sum(w[hit])
step_miss <- -1 / (N - Nh)
inc <- ifelse(hit, step_hit, step_miss)
walk <- cumsum(inc)

pA1 <- ggplot(data.table(g = seq_len(length(ranked)), v = walk), aes(g, v)) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.25) +
  geom_vline(xintercept = which(hit), colour = "#E64B35", alpha = 0.30, linewidth = 0.22) +
  geom_line(colour = "#3C5488", linewidth = 0.55) +
  annotate("text", x = N * 0.98, y = max(walk) * 0.95, hjust = 1, size = 2.5,
           colour = "grey20",
           label = sprintf("%d of %d genes are members", Nh, length(members))) +
  labs(x = "Genes ordered by expression (rank)", y = "Running enrichment score",
       title = "Step 3  a random walk over the ranked list") +
  theme_paper(7)

# KDE of one gene across tumours
g1 <- "ALDOA"
d1 <- density(mat[g1, ], n = 256)
pA2 <- ggplot(data.table(x = d1$x, y = d1$y), aes(x, y)) +
  geom_area(fill = "#4DBBD5", alpha = 0.35, colour = NA) +
  geom_line(colour = "#2C7FA0", linewidth = 0.5) +
  geom_rug(data = data.table(x = mat[g1, ]), aes(x = x), inherit.aes = FALSE,
           sides = "b", colour = "grey35", alpha = 0.35, length = unit(0.6, "mm")) +
  labs(x = sprintf("%s expression (log2 RSEM)", g1), y = "Density",
       title = "Step 1  one gene, one distribution") +
  theme_paper(7)

# ECDF mapping of three genes
g3 <- c("ALDOA", "PKM", "HK2")
ec <- rbindlist(lapply(g3, function(g) {
  f <- ecdf(mat[g, ])
  xs <- seq(min(mat[g, ]), max(mat[g, ]), length.out = 120)
  data.table(gene = g, x = xs, F = f(xs))
}))
pA3 <- ggplot(ec, aes(x, F, colour = gene)) +
  geom_line(linewidth = 0.55) +
  scale_colour_manual(values = c(ALDOA = "#4DBBD5", PKM = "#E64B35", HK2 = "#3C5488"),
                      name = NULL) +
  labs(x = "Expression", y = "F(x)  (percentile of this gene)",
       title = "Step 2  every gene becomes a percentile") +
  theme_paper(7) +
  theme(legend.position = c(0.02, 0.98), legend.justification = c(0, 1),
        legend.background = element_rect(fill = "white", colour = NA),
        legend.key.size = unit(6, "pt"))

figA <- (pA2 | pA3 | pA1) + plot_layout(widths = c(1, 1, 1.15))
save_svg(figA, "figA_gsva_steps", w = 7.4, h = 2.35)

## ---- B: weight curve -------------------------------------------------------
nn <- seq(0, 400, by = 1)
b <- data.table(n = nn, w = 1 / log2(2 + nn))
marks <- data.table(
  layer = c("Proteomics", "Methylation", "CNA", "Transcriptomics"),
  n = c(8, 68, 78, 78)
)
marks[, w := 1 / log2(2 + n)]

pB <- ggplot(b, aes(n, w)) +
  geom_line(colour = "#3C5488", linewidth = 0.6) +
  geom_point(data = marks, aes(n, w, colour = layer), size = 1.9) +
  annotate("text", x = 14, y = 1 / log2(2 + 8) + 0.06, hjust = 0, size = 2.2,
           colour = PAL_OMICS[["Proteomics"]],
           label = "Proteomics, 8 members") +
  annotate("segment", x = 62, y = 0.205, xend = 78, yend = 1 / log2(2 + 78) + 0.012,
           linewidth = 0.25, colour = "grey55") +
  annotate("text", x = 96, y = 0.205, hjust = 0, size = 2.2, colour = "grey25",
           label = "methylation 68 / CNA 78 / transcriptome 78 members") +
  scale_colour_manual(values = PAL_OMICS, guide = "none") +
  scale_x_continuous(limits = c(0, 230), breaks = c(0, 50, 100, 150, 200),
                     expand = expansion(mult = c(0.01, 0.02))) +
  labs(x = "Members of the pathway measured in this layer", y = "Balance factor b_k",
       title = "Small gene sets are compensated with a larger weight",
       subtitle = "b = 1 / log2(2 + |S|), then normalised across layers") +
  theme_paper(7)

save_svg(pB, "figB_weight_curve", w = 4.6, h = 2.5)

## ---- C: consistency reward -------------------------------------------------
a <- seq(-1, 1, by = 0.01)
lam <- c(0.25, 0.5, 1)
d <- rbindlist(lapply(lam, function(l) data.table(a = a, f = (1 + l * a) / (1 + l), lambda = l)))
obs <- data.table(a = c(-1, -1/3, 0, 1), f = (1 + 0.25 * c(-1, -1/3, 0, 1)) / 1.25)

pC <- ggplot(d, aes(a, f, colour = factor(lambda))) +
  geom_vline(xintercept = 0, linetype = 3, linewidth = 0.25, colour = "grey55") +
  geom_hline(yintercept = 1, linetype = 3, linewidth = 0.25, colour = "grey55") +
  geom_line(linewidth = 0.55) +
  geom_point(data = obs, inherit.aes = FALSE, aes(a, f), shape = 21, size = 1.5,
             fill = "white", colour = "#A6362A", stroke = 0.6) +
  scale_colour_manual(values = c("0.25" = "#A6362A", "0.5" = "#E1A33A", "1" = "#7B6AA8"),
                      name = "lambda") +
  scale_x_continuous(breaks = c(-1, -1/3, 0, 1),
                     labels = c("-1", "-1/3", "0", "1")) +
  labs(x = "Agreement a between layers", y = "Retained fraction of ES_raw",
       title = "Disagreement is damped, agreement is untouched",
       subtitle = "ES_multi = ES_raw x (1 + lambda a)/(1 + lambda); open dots = attainable values") +
  theme_paper(7) +
  theme(legend.position = c(0.02, 0.98), legend.justification = c(0, 1),
        legend.background = element_rect(fill = "white", colour = NA),
        legend.key.size = unit(6, "pt"))

save_svg(pC, "figC_consistency", w = 4.4, h = 2.6)
