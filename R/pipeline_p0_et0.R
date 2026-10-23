# FAO-56 Penman-Monteith reference evapotranspiration (ET0) from daily data.
#
# Equation numbers refer to Allen et al. (1998), FAO Irrigation and Drainage
# Paper 56. Inputs are matrices with one row per cell and one column per day;
# `elevation` and `latitude` hold one value per cell and `day_of_year` one
# value per day. Units: degree C, MJ m-2 day-1, kPa, m s-1, mm day-1.
# A day with any missing input gives NA, never a partial value.

# Equation 11: saturation vapour pressure at temperature t (degree C).
pipeline_p0_saturation_vapour_pressure <- function(t) {
  0.6108 * exp(17.27 * t / (t + 237.3))
}

# Equation 13: slope of the saturation vapour pressure curve.
pipeline_p0_vapour_pressure_slope <- function(t) {
  4098 * pipeline_p0_saturation_vapour_pressure(t) / (t + 237.3)^2
}

# Equations 7-8: psychrometric constant (kPa per degree C) at the elevation.
pipeline_p0_psychrometric_constant <- function(elevation) {
  pressure <- 101.3 * ((293 - 0.0065 * elevation) / 293)^5.26
  0.000665 * pressure
}

# Equation 19: actual vapour pressure from mean relative humidity (percent).
pipeline_p0_actual_vapour_pressure_rh <- function(
  relative_humidity,
  maximum_temperature,
  minimum_temperature
) {
  relative_humidity / 100 * (
    pipeline_p0_saturation_vapour_pressure(maximum_temperature) +
      pipeline_p0_saturation_vapour_pressure(minimum_temperature)
  ) / 2
}

# Equation 48 with the dew point taken as the daily minimum temperature. This
# is the FAO-56 fallback for days without humidity, reasonable in humid climates.
pipeline_p0_actual_vapour_pressure_tmin <- function(minimum_temperature) {
  pipeline_p0_saturation_vapour_pressure(minimum_temperature)
}

# Equation 47: wind speed measured at `height` metres, converted to 2 m.
pipeline_p0_wind_at_2m <- function(wind, height) {
  wind * 4.87 / log(67.8 * height - 5.42)
}

# Equations 21-25: extra-terrestrial radiation (MJ m-2 day-1). Returns a
# matrix cells x days. Latitude is in degrees; polar day and night are not
# handled because the study area is far from the polar circles.
pipeline_p0_extraterrestrial_radiation <- function(latitude, day_of_year) {
  phi <- latitude * pi / 180
  inverse_distance <- 1 + 0.033 * cos(2 * pi * day_of_year / 365)
  declination <- 0.409 * sin(2 * pi * day_of_year / 365 - 1.39)
  sunset_argument <- -outer(tan(phi), tan(declination))
  if (any(abs(sunset_argument) > 1, na.rm = TRUE)) {
    pipeline_stop(
      "Extra-terrestrial radiation is undefined at polar day or night.",
      "pipeline_p0_invalid_input"
    )
  }
  sunset <- acos(sunset_argument)
  24 * 60 / pi * 0.0820 * rep(inverse_distance, each = length(phi)) * (
    sunset * outer(sin(phi), sin(declination)) +
      outer(cos(phi), cos(declination)) * sin(sunset)
  )
}

# Equation 37: clear-sky radiation for a station at `elevation` metres.
pipeline_p0_clear_sky_radiation <- function(extraterrestrial, elevation) {
  (0.75 + 2e-5 * elevation) * extraterrestrial
}

# Equations 38-40: net radiation from measured shortwave radiation.
pipeline_p0_net_radiation <- function(
  solar_radiation,
  clear_sky_radiation,
  maximum_temperature,
  minimum_temperature,
  actual_vapour_pressure,
  albedo = 0.23
) {
  stefan_boltzmann <- 4.903e-9
  relative_shortwave <- pmin(solar_radiation / clear_sky_radiation, 1)
  net_longwave <- stefan_boltzmann *
    ((maximum_temperature + 273.16)^4 + (minimum_temperature + 273.16)^4) / 2 *
    (0.34 - 0.14 * sqrt(actual_vapour_pressure)) *
    (1.35 * relative_shortwave - 0.35)
  (1 - albedo) * solar_radiation - net_longwave
}

# Equation 6 with the soil heat flux set to zero (daily step). `wind_2m` and
# `actual_vapour_pressure` are supplied so that the humidity and wind
# assumptions stay visible at the call site.
pipeline_p0_et0_fao56 <- function(
  mean_temperature,
  maximum_temperature,
  minimum_temperature,
  solar_radiation,
  actual_vapour_pressure,
  wind_2m,
  elevation,
  latitude,
  day_of_year
) {
  shape <- dim(mean_temperature)
  if (is.null(shape) || length(shape) != 2L) {
    pipeline_stop(
      "ET0 inputs must be matrices with one row per cell and one column per day.",
      "pipeline_p0_invalid_input"
    )
  }
  if (length(elevation) != shape[[1L]] || length(latitude) != shape[[1L]] ||
    length(day_of_year) != shape[[2L]]) {
    pipeline_stop(
      "Elevation and latitude need one value per row; day_of_year one per column.",
      "pipeline_p0_invalid_input"
    )
  }
  slope <- pipeline_p0_vapour_pressure_slope(mean_temperature)
  gamma <- pipeline_p0_psychrometric_constant(elevation)
  saturation <- (
    pipeline_p0_saturation_vapour_pressure(maximum_temperature) +
      pipeline_p0_saturation_vapour_pressure(minimum_temperature)
  ) / 2
  extraterrestrial <- pipeline_p0_extraterrestrial_radiation(
    latitude,
    day_of_year
  )
  clear_sky <- pipeline_p0_clear_sky_radiation(extraterrestrial, elevation)
  net_radiation <- pipeline_p0_net_radiation(
    solar_radiation,
    clear_sky,
    maximum_temperature,
    minimum_temperature,
    actual_vapour_pressure
  )
  # Values are returned as computed. A negative ET0 on a very cold, calm day is
  # a numerical artefact; the caller counts such days instead of clipping them.
  (
    0.408 * slope * net_radiation +
      gamma * 900 / (mean_temperature + 273) * wind_2m *
        (saturation - actual_vapour_pressure)
  ) / (slope + gamma * (1 + 0.34 * wind_2m))
}

# Sums a cells x days matrix into cells x months. `month` has one entry per
# day. A month with any missing day is NA.
pipeline_p0_monthly_sums <- function(daily, month) {
  months <- sort(unique(month))
  sums <- vapply(
    months,
    function(m) rowSums(daily[, month == m, drop = FALSE]),
    numeric(nrow(daily))
  )
  if (is.null(dim(sums))) {
    sums <- matrix(sums, nrow = nrow(daily))
  }
  colnames(sums) <- months
  sums
}
