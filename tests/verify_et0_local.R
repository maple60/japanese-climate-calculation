# Optional read-only verification of local exports. Run from the project root
# with Rscript (without --vanilla) so .Renviron supplies PROJECT_DATA_DIR.
source("R/et0_support.R")
bundle <- et0_data_dir()
normal <- read_monthly_csv(file.path(bundle, "data",
  "monthly_normals_2008_2018.csv.gz"))
stopifnot(nrow(normal) == 377449L, !anyNA(normal$mesh3_code),
  !anyDuplicated(normal$mesh3_code), all(normal$n_years == 11),
  all(normal$wind_height_m == 10))
primary <- sort(unique(substr(normal$mesh3_code, 1, 4)))
files <- file.path(bundle, "data", "yearly",
  sprintf("monthly_%s_2008_2018.csv.gz", primary))
stopifnot(length(files) == 153L, all(file.exists(files)))
columns <- c(paste0("et0_fao56_", month.abb),
  paste0("precipitation_", month.abb))
maximum_difference <- 0
total_rows <- 0L
total_cells <- 0L
for (path in files) {
  x <- read_monthly_csv(path)
  stopifnot(!anyNA(x[c("mesh3_code", "year")]),
    !anyDuplicated(x[c("mesh3_code", "year")]),
    all(x$year %in% 2008:2018), all(table(x$mesh3_code) == 11L),
    all(x$wind_height_m == 10))
  keys <- sort(unique(x$mesh3_code))
  stopifnot(all(substr(keys, 1, 4) == substr(basename(path), 9, 12)))
  total <- matrix(0, length(keys), length(columns))
  for (year in 2008:2018) {
    part <- x[x$year == year, ]
    idx <- match(keys, part$mesh3_code)
    stopifnot(!anyNA(idx))
    total <- total + as.matrix(part[idx, columns])
  }
  idx <- match(keys, normal$mesh3_code)
  stopifnot(!anyNA(idx))
  reference <- as.matrix(normal[idx, columns])
  means <- total / 11
  stopifnot(all(is.na(means) == is.na(reference)))
  difference <- max(c(0, abs(means - reference)), na.rm = TRUE)
  stopifnot(is.finite(difference), difference < 1e-8)
  maximum_difference <- max(maximum_difference, difference)
  total_rows <- total_rows + nrow(x)
  total_cells <- total_cells + length(keys)
}
for (prefix in c("et0_fao56", "precipitation")) {
  sums <- rowSums(normal[paste0(prefix, "_", month.abb)])
  annual <- normal[[paste0(prefix, "_year")]]
  stopifnot(all(is.na(sums) == is.na(annual)),
    max(c(0, abs(sums - annual)), na.rm = TRUE) < 1e-8)
}
stopifnot(total_cells == nrow(normal), total_rows == 4151939L)
cat(total_cells, "cells;", length(files), "blocks;", total_rows,
  "mesh-year rows; maximum monthly-mean difference:",
  format(maximum_difference, digits = 16), "mm\n")
