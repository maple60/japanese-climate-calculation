# Base R support for the daily FAO-56 calculation and monthly export tables.
pipeline_stop <- function(message, ...) stop(message, call. = FALSE)

pipeline_p0_month_abbreviations <- function() month.abb

# No fallback to the repository: real tables belong under PROJECT_DATA_DIR.
et0_data_dir <- function() {
  root <- Sys.getenv("PROJECT_DATA_DIR")
  if (!nzchar(root)) stop("Set PROJECT_DATA_DIR in .Renviron.", call. = FALSE)
  file.path(root, "naro-et0", "2008-2018")
}

# Explicit types preserve leading zeros in mesh identifiers.
read_monthly_csv <- function(path) {
  columns <- names(read.csv(path, nrows = 0))
  classes <- ifelse(columns == "mesh3_code", "character", "numeric")
  read.csv(path, colClasses = classes)
}

# Copied from the standalone pipeline_p0_naro.R. Apply separately to RH and
# wind, separately for each calendar year; do not interpolate other inputs.
pipeline_p0_fill_short_gaps <- function(x, max_gap = 2L) {
  filled <- integer(nrow(x))
  rows <- which(rowSums(is.na(x)) > 0L & rowSums(!is.na(x)) > 0L)
  for (i in rows) {
    row <- x[i, ]
    runs <- rle(is.na(row))
    ends <- cumsum(runs$lengths)
    starts <- ends - runs$lengths + 1L
    for (k in which(runs$values & runs$lengths <= max_gap)) {
      first <- starts[[k]]
      last <- ends[[k]]
      if (first > 1L && last < length(row)) {
        before <- row[[first - 1L]]
        after <- row[[last + 1L]]
        row[first:last] <- before +
          (after - before) * seq_len(last - first + 1L) / (last - first + 2L)
        filled[[i]] <- filled[[i]] + (last - first + 1L)
      }
    }
    x[i, ] <- row
  }
  list(values = x, filled_days = filled)
}

# Months are calendar-month selections within each row, not a time sequence.
# Missing months propagate; non-positive denominators do not define AI.
period_summary <- function(data, months, label = "selected_period") {
  if (!is.numeric(months) || !length(months) || anyNA(months) ||
    anyDuplicated(months) || !all(months %in% 1:12)) {
    stop("months must contain distinct integers from 1 to 12.", call. = FALSE)
  }
  suffix <- month.abb[months]
  et0 <- rowSums(data[paste0("et0_fao56_", suffix)])
  rain <- rowSums(data[paste0("precipitation_", suffix)])
  ai <- rep(NA_real_, length(et0))
  ok <- is.finite(et0) & et0 > 0 & is.finite(rain)
  ai[ok] <- rain[ok] / et0[ok]
  keys <- intersect(c("mesh3_code", "year"), names(data))
  data.frame(data[keys], period = label, et0_mm = et0,
    precipitation_mm = rain, aridity_index = ai,
    water_balance_mm = rain - et0)
}

# Winter Y = December Y-1 plus January-February Y, aligned by mesh and year.
# Retain the input mesh/year rows; absent prior December produces NA.
winter_summary <- function(data) {
  if (!all(c("mesh3_code", "year") %in% names(data)) ||
    !is.numeric(data$year) || anyNA(data[c("mesh3_code", "year")]) ||
    any(!is.finite(data$year) | data$year != floor(data$year)) ||
    anyDuplicated(data[c("mesh3_code", "year")])) {
    stop("Unique, nonmissing mesh3_code and integer year keys are required.",
      call. = FALSE)
  }
  key <- paste(data$mesh3_code, data$year, sep = ":")
  previous <- match(paste(data$mesh3_code, data$year - 1L, sep = ":"), key)
  aligned <- data
  for (prefix in c("et0_fao56_", "precipitation_")) {
    column <- paste0(prefix, "Dec")
    aligned[[column]] <- data[[column]][previous]
  }
  period_summary(aligned, c(12, 1, 2), "Dec(previous year)-Feb")
}
