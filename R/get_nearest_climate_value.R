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
    stop("sf_climate は sf オブジェクトである必要があります。")
  }

  # 最近傍検索に使う geometry を決める
  # calc_by_centroid = TRUE の場合は、重心の座標を使う(こちらのほうが早い)
  if (calc_by_centroid) {
    if (!climate_lon_col %in% names(sf_climate)) {
      stop("climate_lon_col が sf_climate に存在しません: ", climate_lon_col)
    }
    if (!climate_lat_col %in% names(sf_climate)) {
      stop("climate_lat_col が sf_climate に存在しません: ", climate_lat_col)
    }

    sf_clim <- sf::st_as_sf(
      sf::st_drop_geometry(sf_climate),
      coords = c(climate_lon_col, climate_lat_col),
      crs = sf::st_crs(sf_climate),
      remove = FALSE
    )
  } else {
    # geometry をそのまま使う場合
    sf_clim <- sf_climate
  }

  # value_col = NULL の場合は、geometry 以外の全列を返す
  if (is.null(value_col)) {
    value_col <- names(sf::st_drop_geometry(sf_clim))
  }

  # value_col の存在確認
  missing_cols <- setdiff(value_col, names(sf_clim))
  if (length(missing_cols) > 0) {
    stop(
      "以下の value_col が sf_climate に存在しません: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  # 出力列名の処理
  if (is.null(output_col)) {
    output_col <- value_col
  }

  if (length(output_col) != length(value_col)) {
    stop("output_col は value_col と同じ長さである必要があります。")
  }

  # lon, lat が直接与えられた場合
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

  # data.frame が与えられた場合
  if (!is.null(df) && is.null(lon) && is.null(lat)) {
    if (!lon_col %in% names(df)) {
      stop("lon_col が df に存在しません: ", lon_col)
    }
    if (!lat_col %in% names(df)) {
      stop("lat_col が df に存在しません: ", lat_col)
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
    "lon と lat の両方を指定するか、df を指定してください。両方同時には指定しないでください。"
  )
}
