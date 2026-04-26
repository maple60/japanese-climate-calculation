get_nearest_climate_value <- function(
  sf_climate,
  lon = NULL,
  lat = NULL,
  df = NULL,
  lon_col = "longitude",
  lat_col = "latitude",
  value_col = "aridity_index",
  output_col = NULL,
  calc_by_centroid = TRUE,
  climate_lon_col = "longitude",
  climate_lat_col = "latitude"
) {
  if (!inherits(sf_climate, "sf")) {
    stop("sf_climate must be an sf object.")
  }

  # Select geometry used for nearest-neighbor search.
  # If calc_by_centroid = TRUE, centroid coordinates are used for faster lookup.
  if (calc_by_centroid) {
    if (!climate_lon_col %in% names(sf_climate)) {
      stop("climate_lon_col does not exist in sf_climate: ", climate_lon_col)
    }
    if (!climate_lat_col %in% names(sf_climate)) {
      stop("climate_lat_col does not exist in sf_climate: ", climate_lat_col)
    }

    sf_clim <- sf::st_as_sf(
      sf::st_drop_geometry(sf_climate),
      coords = c(climate_lon_col, climate_lat_col),
      crs = sf::st_crs(sf_climate),
      remove = FALSE
    )
  } else {
    # Use original geometry.
    sf_clim <- sf_climate
  }

  # If value_col = NULL, return all non-geometry columns.
  if (is.null(value_col)) {
    value_col <- names(sf::st_drop_geometry(sf_clim))
  }

  # Validate requested value columns.
  missing_cols <- setdiff(value_col, names(sf_clim))
  if (length(missing_cols) > 0) {
    stop(
      "The following value_col entries do not exist in sf_climate: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  # Process output column names.
  if (is.null(output_col)) {
    output_col <- value_col
  }

  if (length(output_col) != length(value_col)) {
    stop("output_col must have the same length as value_col.")
  }

  # If lon/lat are provided directly.
  if (!is.null(lon) && !is.null(lat) && is.null(df)) {
    pt <- sf::st_sfc(
      sf::st_point(c(lon, lat)),
      crs = sf::st_crs(sf_clim)
    )

    idx <- sf::st_nearest_feature(pt, sf_clim)

    out <- sf::st_drop_geometry(sf_clim[idx, value_col, drop = FALSE])
    names(out) <- output_col

    return(out)
  }

  # If a data.frame is provided.
  if (!is.null(df) && is.null(lon) && is.null(lat)) {
    if (!lon_col %in% names(df)) {
      stop("lon_col does not exist in df: ", lon_col)
    }
    if (!lat_col %in% names(df)) {
      stop("lat_col does not exist in df: ", lat_col)
    }

    pts <- sf::st_as_sf(
      df,
      coords = c(lon_col, lat_col),
      crs = sf::st_crs(sf_clim),
      remove = FALSE
    )

    idx <- sf::st_nearest_feature(pts, sf_clim)

    vals <- sf::st_drop_geometry(sf_clim[idx, value_col, drop = FALSE])
    names(vals) <- output_col

    out <- cbind(df, vals)

    return(out)
  }

  stop(
    "Specify both lon and lat, or specify df. Do not specify both input styles at once."
  )
}
