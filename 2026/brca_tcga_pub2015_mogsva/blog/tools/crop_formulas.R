# Crop each block equation out of the full-page transparent screenshot, trim the
# transparent margins, add 2 CSS px of transparent air, and write one PNG per
# formula together with its final size (CSS px, i.e. screenshot px / SCALE).
suppressPackageStartupMessages({
  library(jsonlite)
  library(png)
})

ROOT <- "G:/GCModeller/test/demo/HTS/GSVA/mogsva_figures/blog"
WORK <- file.path(ROOT, "_fx")
SCALE <- 3
PAD_X <- 14       # MathJax can under-report the box (italic correction, \right)
PAD_Y <- 14       # same for tall delimiters and deep subscripts
PAD_OUT <- 2      # CSS px of transparent air kept around the ink in the output
ALPHA_MIN <- 0.02 # ignore near-transparent anti-aliasing when trimming
INK <- c(0.114, 0.137, 0.169)   # #1d232b

jobs <- fromJSON(file.path(WORK, "manifest.json"), simplifyVector = FALSE)
out_jobs <- list()

for (job in jobs) {
  tag <- job$tag
  rows <- job$manifest
  entries <- list()

  if (length(rows) > 0) {
    by_png <- split(rows, vapply(rows, function(r) r$png, character(1)))
    for (grp in names(by_png)) {
      img <- readPNG(grp)
      cat(sprintf("%s: screenshot %d x %d (alpha=%s)\n", basename(grp),
                  dim(img)[2], dim(img)[1], dim(img)[3] == 4))

      for (r in by_png[[grp]]) {
        x0 <- max(1, round((r$x - PAD_X) * SCALE))
        y0 <- max(1, round((r$y - PAD_Y) * SCALE))
        x1 <- min(dim(img)[2], round((r$x + r$w + PAD_X) * SCALE))
        y1 <- min(dim(img)[1], round((r$y + r$h + PAD_Y) * SCALE))

        crop <- img[y0:y1, x0:x1, , drop = FALSE]
        a <- crop[, , 4]
        ink_r <- which(rowSums(a > ALPHA_MIN) > 0)
        ink_c <- which(colSums(a > ALPHA_MIN) > 0)
        if (length(ink_r) == 0) {
          warning(sprintf("blank crop for %s", r$file))
          next
        }
        tr <- range(ink_r); tc <- range(ink_c)
        trimmed <- crop[tr[1]:tr[2], tc[1]:tc[2], , drop = FALSE]

        # transparent air, filled with the ink colour so downscaling never haloes
        pad <- PAD_OUT * SCALE
        hh <- nrow(trimmed); ww <- ncol(trimmed)
        canvas <- array(0, dim = c(hh + 2 * pad, ww + 2 * pad, 4))
        canvas[, , 1] <- INK[1]; canvas[, , 2] <- INK[2]; canvas[, , 3] <- INK[3]
        canvas[, , 4] <- 0
        canvas[(pad + 1):(pad + hh), (pad + 1):(pad + ww), ] <- trimmed
        trimmed <- canvas

        dest <- file.path(ROOT, "formulas", r$file)
        dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
        writePNG(trimmed, dest)

        entries[[length(entries) + 1]] <- list(
          kind = r$kind, file = r$file, id = r$id, tex = r$tex,
          w = round(ncol(trimmed) / SCALE, 1),
          h = round(nrow(trimmed) / SCALE, 1),
          px_w = ncol(trimmed), px_h = nrow(trimmed)
        )
      }
    }
  } else {
    cat(sprintf("%s: no block equations\n", tag))
  }

  out_jobs[[tag]] <- list(tag = tag, entries = entries)
}

write_json(out_jobs, file.path(WORK, "cropped.json"), auto_unbox = TRUE, pretty = TRUE)
cat("done -> ", file.path(WORK, "cropped.json"), "\n")
