# =============================================================================
# 00b_network.R -- WGCNA co-activity networks of pathway activity
#
# One network per omics layer plus one for the fused score, all built on the
# same node set (pathways measured in every layer) so that topology can be
# compared without a coverage confound.
#
#   adjacency  a_ij = ((1 + r_ij)/2)^beta        (signed hybrid)
#   TOM        topological overlap
#   modules    dynamic tree cut on 1 - TOM
#   k          connectivity, row sum of the adjacency
#
# Requires 00_common.R to be sourced first.
# =============================================================================

suppressPackageStartupMessages({
  library(WGCNA)
  library(dynamicTreeCut)
  library(igraph)
})

#' Build (or load from cache) the five pathway co-activity networks.
#'
#' @param d      bundle from `load_mogsva()`
#' @param shared pathway ids measured in every layer (fair node set)
#' @param powers candidate soft-threshold powers
#' @param min_module minimum module size for the dynamic tree cut
build_networks <- function(d, shared = shared_pathways(d),
                           powers = 1:20, min_module = 10) {
  cache_rds(sprintf("networks_%d_%d", length(shared), min_module), {
    st <- activity_stack(d)
    out <- list()

    for (nm in names(st)) {
      x <- t(st[[nm]][shared, , drop = FALSE])          # tumours x pathways
      sft <- pickSoftThreshold(x, powerVector = powers,
                               networkType = "signed hybrid", verbose = 0)
      beta <- ifelse(is.na(sft$powerEstimate), 6, sft$powerEstimate)

      adj <- adjacency(x, power = beta, type = "signed hybrid")
      dimnames(adj) <- list(shared, shared)
      tom <- TOMsimilarity(adj, TOMType = "signed")
      dimnames(tom) <- list(shared, shared)
      diss <- 1 - tom
      hc <- hclust(as.dist(diss), method = "average")
      mod <- cutreeDynamic(hc, distM = diss, deepSplit = 2,
                           minClusterSize = min_module, verbose = 0)
      names(mod) <- shared

      k <- rowSums(adj)

      out[[nm]] <- list(
        name = nm, beta = beta, sft = sft, adj = adj, tom = tom, diss = diss,
        hclust = hc, module = mod, k = k,
        r = cor(x),
        n_module = length(unique(mod[mod > 0])),
        unassigned = sum(mod == 0)
      )
    }

    # modules renamed to stable labels M1, M2, ... ordered by size, grey = 0
    for (nm in names(out)) {
      mod <- out[[nm]]$module
      sizes <- sort(table(mod[mod > 0]), decreasing = TRUE)
      map <- setNames(seq_along(sizes), names(sizes))
      lab <- ifelse(mod == 0, "grey", paste0("M", map[as.character(mod)]))
      out[[nm]]$module_label <- factor(lab, levels = c(paste0("M", seq_along(sizes)), "grey"))
    }

    attr(out, "shared") <- shared
    out
  })
}

#' Binary graph from a TOM at a fixed number of strongest edges.
#'
#' A fixed edge count keeps the density identical across networks, so that
#' component structure and clustering can be compared directly.
tom_graph <- function(net, n_edges = 600) {
  tom <- net$tom
  ut <- tom[upper.tri(tom)]
  thr <- sort(ut, decreasing = TRUE)[n_edges]
  a <- tom * (tom >= thr)
  g <- graph_from_adjacency_matrix(a, mode = "undirected", weighted = TRUE, diag = FALSE)
  V(g)$name <- rownames(tom)
  V(g)$module <- net$module_label[match(V(g)$name, names(net$module))]
  V(g)$k <- net$k[V(g)$name]
  g
}

#' Topology summary of one network at a fixed edge budget.
net_topology <- function(net, n_edges = 600) {
  g <- tom_graph(net, n_edges)
  comp <- components(g)
  data.table(
    network        = net$name,
    beta           = net$beta,
    n_module       = net$n_module,
    unassigned_pct = 100 * net$unassigned / length(net$module),
    mean_k         = mean(net$k),
    max_k          = max(net$k),
    med_abs_r      = median(abs(net$r[upper.tri(net$r)])),
    pct_r_gt_0.3   = 100 * mean(abs(net$r[upper.tri(net$r)]) > 0.3),
    transitivity   = transitivity(g, type = "global"),
    n_component    = comp$no,
    largest_comp   = max(comp$csize),
    largest_pct    = 100 * max(comp$csize) / vcount(g)
  )
}

#' Adjusted Rand index between two module partitions.
ari <- function(a, b) {
  tab <- table(a, b)
  n <- sum(tab)
  if (n < 2) return(NA_real_)
  ai <- sum(choose(rowSums(tab), 2))
  bj <- sum(choose(colSums(tab), 2))
  nij <- sum(choose(tab, 2))
  e <- ai * bj / choose(n, 2)
  denom <- (ai + bj) / 2 - e
  if (denom == 0) return(0)
  (nij - e) / denom
}

#' Stable two-dimensional layout, reused across panels so that node positions
#' are comparable between networks.
net_layout <- function(g, seed = 20261028) {
  set.seed(seed)
  lay <- layout_with_fr(g, niter = 2000, grid = "nogrid")
  lay <- apply(lay, 2, function(v) (v - min(v)) / diff(range(v)))
  colnames(lay) <- c("x", "y")
  as.data.table(lay)[, name := V(g)$name]
}
