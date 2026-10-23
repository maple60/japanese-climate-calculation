# Run from the repository root: Rscript --vanilla tests/test_et0.R
# No NARO inputs, external test framework or new packages are required.
source("R/et0_support.R")
source("R/pipeline_p0_et0.R")
checks <- 0L
check <- function(label, condition) {
  if (!isTRUE(condition)) stop("FAILED: ", label, call. = FALSE)
  checks <<- checks + 1L
}
fails <- function(expr) inherits(tryCatch(force(expr), error = identity), "error")

x <- list(mean_temperature = matrix(16.9),
  maximum_temperature = matrix(21.5), minimum_temperature = matrix(12.3),
  solar_radiation = matrix(22.07), actual_vapour_pressure = matrix(1.409),
  wind_2m = matrix(pipeline_p0_wind_at_2m(10 / 3.6, 10)),
  elevation = 100, latitude = 50.8, day_of_year = 187)
check("FAO Uccle ET0", abs(as.numeric(do.call(pipeline_p0_et0_fao56, x)) - 3.9) < 0.08)
check("wind conversion", abs(as.numeric(x$wind_2m) - 2.078) < 0.002)
check("vapour-pressure slope", abs(pipeline_p0_vapour_pressure_slope(16.9) - 0.122) < 0.001)
check("psychrometric constant", abs(pipeline_p0_psychrometric_constant(100) - 0.0666) < 0.0001)
check("mean-RH approximation", abs(pipeline_p0_actual_vapour_pressure_rh(73.5, 21.5, 12.3) - 1.468) < 0.002)
ra <- pipeline_p0_extraterrestrial_radiation(50.8, 187)
check("extraterrestrial radiation", abs(as.numeric(ra) - 41.09) < 0.02)
check("clear-sky radiation", abs(as.numeric(pipeline_p0_clear_sky_radiation(ra, 100)) - 30.90) < 0.02)
for (name in names(x)) {
  missing <- x
  missing[[name]][] <- NA_real_
  check(paste("missing", name), is.na(as.numeric(do.call(pipeline_p0_et0_fao56, missing))))
}
bad <- x
bad$mean_temperature <- 16.9
check("matrix requirement", fails(do.call(pipeline_p0_et0_fao56, bad)))
bad <- x
bad$day_of_year <- c(187, 188)
check("day dimension requirement", fails(do.call(pipeline_p0_et0_fao56, bad)))
cold <- x
cold$wind_2m[] <- 5
cold$actual_vapour_pressure[] <- 3
check("negative ET0 retained", as.numeric(do.call(pipeline_p0_et0_fao56, cold)) < 0)
# Check cell-wise elevation/latitude recycling against independent calls.
multi <- x
for (name in names(x)[1:6]) multi[[name]] <- matrix(rep(x[[name]], 4), 2, 2)
multi$elevation <- c(100, 500)
multi$latitude <- c(50.8, 35)
multi$day_of_year <- c(187, 188)
result <- do.call(pipeline_p0_et0_fao56, multi)
single <- x
single$elevation <- 500
single$latitude <- 35
single$day_of_year <- 188
check("multiple cells and days", abs(result[2, 2] - do.call(pipeline_p0_et0_fao56, single)[1, 1]) < 1e-12)

gaps <- rbind(c(NA, 1, NA, NA, 4, NA, NA, NA, 8, NA), rep(NA, 10))
filled <- pipeline_p0_fill_short_gaps(gaps)
check("short interior gaps only", identical(as.numeric(filled$values[1, ]),
  c(NA, 1, 2, 3, 4, NA, NA, NA, 8, NA)))
check("filled-day diagnostic", identical(filled$filled_days, c(2L, 0L)))
check("all-missing row", all(is.na(filled$values[2, ])))
check("no interpolation across years", is.na(pipeline_p0_fill_short_gaps(matrix(c(1, NA), 1))$values[1, 2]))
dates <- seq(as.Date("2008-01-01"), as.Date("2008-12-31"), by = "day")
values <- matrix(1, 1, length(dates))
sums <- pipeline_p0_monthly_sums(values, as.integer(format(dates, "%m")))
check("leap February", sums[1, "2"] == 29 && sum(sums) == 366)
values[1, 10] <- NA
sums <- pipeline_p0_monthly_sums(values, as.integer(format(dates, "%m")))
check("missing day propagates within month", is.na(sums[1, "1"]) && sums[1, "2"] == 29)

monthly <- read_monthly_csv("data/examples/et0_monthly_synthetic.csv")
check("character mesh identifiers", identical(monthly$mesh3_code[1], "00000001"))
sample <- monthly[1, ]
sample$precipitation_Jan <- 50
sample$precipitation_Feb <- 200
sample$et0_fao56_Jan <- 100
sample$et0_fao56_Feb <- 50
p <- period_summary(sample, 1:2)
check("ratio of sums", abs(p$aridity_index - 250 / 150) < 1e-12)
check("water balance", p$water_balance_mm == 100)
sample$et0_fao56_Jan <- -50
check("zero denominator", is.na(period_summary(sample, 1:2)$aridity_index))
sample$et0_fao56_Jan <- -100
check("negative denominator", is.na(period_summary(sample, 1:2)$aridity_index))
sample$et0_fao56_Jan <- NA
check("missing ET0 month", is.na(period_summary(sample, 1:2)$aridity_index))
sample$et0_fao56_Jan <- 100
sample$precipitation_Jan <- NA
check("missing rain month", is.na(period_summary(sample, 1:2)$aridity_index))
check("distinct months required", fails(period_summary(monthly, c(1, 1))))
check("valid months required", fails(period_summary(monthly, c(0, 1))))

shuffled <- monthly[c(6, 1, 4, 3, 2, 5), ]
winter <- winter_summary(shuffled)
idx <- which(shuffled$mesh3_code == "00000001" & shuffled$year == 2009)
previous <- monthly[monthly$mesh3_code == "00000001" & monthly$year == 2008, ]
current <- shuffled[idx, ]
check("winter matched by mesh and year", winter$et0_mm[idx] ==
  previous$et0_fao56_Dec + current$et0_fao56_Jan + current$et0_fao56_Feb)
check("winter precipitation aligned", winter$precipitation_mm[idx] ==
  previous$precipitation_Dec + current$precipitation_Jan + current$precipitation_Feb)
check("winter unavailable at boundary", all(is.na(winter$et0_mm[winter$year == 2008])))
check("winter preserves input keys", identical(winter[c("mesh3_code", "year")], shuffled[c("mesh3_code", "year")]))
check("duplicate winter keys rejected", fails(winter_summary(rbind(monthly, monthly[1, ]))))
missing_dec <- monthly
missing_dec$et0_fao56_Dec[missing_dec$year == 2008] <- NA
check("missing previous December", all(is.na(winter_summary(missing_dec)$et0_mm[monthly$year == 2009])))
missing_year <- monthly[monthly$year != 2009, ]
check("missing prior year", all(is.na(winter_summary(missing_year)$et0_mm)))

# A ratio of climatological sums differs from the arithmetic yearly mean.
year_ai <- period_summary(monthly, 7:9)
check("yearly ratio distinction", abs(sum(year_ai$precipitation_mm) /
  sum(year_ai$et0_mm) - mean(year_ai$aridity_index)) > 0.01)
cat(checks, "ET0 checks passed (synthetic and published FAO inputs only).\n")
