# Existing report functions; called by the analysis chunks in report.qmd.

#' 分母が正のときだけ降水量と蒸発散量の比を求める
#'
#' @param p 降水量の数値ベクトルまたは行列。単位はeとそろえます。
#' @param e pと同じ長さ・形の蒸発散量。ET0またはPETを渡します。
#' @return p / e。いずれかが非有限値、またはeが0以下ならNAにします。
#' @details 呼び出し側でメッシュ・期間・単位を対応付けておく必要があります。
#'   降水量が非負であることは、この関数では検証しません。
#' @examples
#' ratio(c(100, 100, NA), c(50, 0, 50))  # 2, NA, NA
ratio <- function(p, e) {
  out <- p / e
  out[!is.finite(p) | !is.finite(e) | e <= 0] <- NA_real_
  out
}

#' 3次メッシュ番号からメッシュ中心の経緯度を求める
#'
#' @param code 8桁の3次メッシュ番号を格納した文字列ベクトル。
#' @return codeと同じ行順のデータフレーム。lonは経度、latは緯度（度）。
#' @details メッシュ番号の各桁から中心座標を組み立てます。
#'   8桁の数字であることは呼び出し側で確認してください。
#'   座標参照系を持つ空間オブジェクトは作成しません。
#' @examples
#' mesh_xy("53394525")
mesh_xy <- function(code) {
  digit <- function(first, last = first) as.numeric(substr(code, first, last))
  data.frame(lon = 100 + digit(3, 4) + digit(6) / 8 + digit(8) / 80 + 1 / 160,
    lat = digit(1, 2) * 2 / 3 + digit(5) / 12 + digit(7) / 120 + 1 / 240)
}

#' AIの値を対数尺度の地図色に変換する
#'
#' @param x AIの数値ベクトル。
#' @return xと同じ長さの色名ベクトル。非有限値はgrey80です。
#' @details 本文で定義する長さ100のpaletteと、正の上下限ai_limitsを参照します。
#'   範囲外の有限値は端の色にしますが、x自体は変更しません。
#'   有限な0以下の値も下限色になるため、AIの妥当性は描画前に確認します。
#' @seealso draw_map, draw_legend
ai_colors <- function(x) {
  value <- pmin(pmax(x, ai_limits[1]), ai_limits[2])
  bin <- 1L + floor(99 * (log10(value) - log10(ai_limits[1])) / diff(log10(ai_limits)))
  result <- palette[bin]
  result[!is.finite(x)] <- "grey80"
  result
}
#' 1期間のAIを現在の描画領域に描く
#'
#' @param coords lon・lat（度）を持つ、valueと同じ行順のデータフレーム。
#' @param value 各メッシュのAIを格納した数値ベクトル。
#' @param title パネルの見出し。
#' @return 現在のグラフィックスデバイスに地図を描きます。
#' @details 日本を含む固定の経緯度範囲に、メッシュ中心を四角で描きます。
#'   色はai_colors()で決めます。この関数だけでは画像を保存しません。
#' @seealso ai_colors, monthly_maps
draw_map <- function(coords, value, title) {
  plot(NA, xlim = c(122, 146), ylim = c(24, 46), asp = 1 / cos(35 * pi / 180),
    xlab = "Longitude", ylab = "Latitude", main = title, cex.main = 1,
    xaxs = "i", yaxs = "i")
  points(coords$lon, coords$lat, pch = 15, cex = 0.19, col = ai_colors(value))
  box()
}
#' AI地図に共通の対数尺度の凡例を描く
#'
#' @return 現在のグラフィックスデバイスに凡例を描きます。
#' @details 本文のpaletteとai_limitsを参照します。draw_map()と同じ設定を使ってください。
#'   par(mar)を変更するため、地図と凡例を並べるlayout()内で使います。
#'   目盛りは、このレポートのAI範囲0.05から20に合わせて固定しています。
#' @seealso draw_map, monthly_maps
draw_legend <- function() {
  par(mar = c(2.7, 3, 1.5, 2))
  z <- seq(log10(ai_limits[1]), log10(ai_limits[2]), length.out = 100)
  image(z, 1, matrix(z, ncol = 1), col = palette, axes = FALSE,
    xlab = "", ylab = "", useRaster = TRUE)
  ticks <- c(0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20)
  axis(1, at = log10(ticks), labels = ticks)
  mtext("AI: low = dry (yellow), high = humid (purple); log scale; NA: grey", 3, line = 0)
}
#' 12か月のAIを共通の色の範囲でPNGに保存する
#'
#' @param coords lon・lat（度）を持つ、valuesと同じ行順のデータフレーム。
#' @param values 行がメッシュ、列が1月から12月のAIである数値行列。
#' @param file 出力PNGのパス。保存先フォルダは先に作成してください。
#' @param heading 図全体の見出し。
#' @return fileにPNGを保存し、dev.off()の返り値（デバイス番号）を返します。
#' @details paletteとai_limitsを先に定義します。12パネルと共通凡例を描きます。
#'   出力は2400 x 2200ピクセルで、既存の同名PNGは上書きします。
#' @seealso draw_map, draw_legend
monthly_maps <- function(coords, values, file, heading) {
  png(file, width = 2400, height = 2200, res = 180, type = "cairo")
  layout(rbind(matrix(1:12, nrow = 3, byrow = TRUE), rep(13, 4)),
    heights = c(1, 1, 1, 0.23))
  par(mar = c(2.5, 2.8, 2.3, 0.8), oma = c(0, 0, 2, 0))
  for (m in 1:12) draw_map(coords, values[, m], month.abb[m])
  draw_legend()
  mtext(heading, outer = TRUE, side = 3, line = 0.5, font = 2)
  dev.off()
}

#' 対応メッシュの値を2次元度数図で比較する
#'
#' @param x 横軸に使う数値ベクトル。yと同じメッシュ・期間の並びにそろえます。
#' @param y 縦軸に使う、xと同じ長さの数値ベクトル。
#' @param title パネルの見出し。
#' @param xlab 横軸の説明。
#' @param ylab 縦軸の説明。
#' @param logarithmic TRUEなら正の組だけを使い、両軸をlog10変換します。
#' @return 現在のグラフィックスデバイスに比較図を描きます。
#' @details 有効な組が存在し、表示範囲に幅がある入力を前提にします。
#'   両変数を合わせた0.25・99.75パーセンタイルを表示範囲とします。
#'   160 x 160の区画ごとの件数をlog10(件数 + 1)で色分けし、空区画は描きません。
#'   青い破線は1:1線です。表示範囲外の有効な組の件数も記載します。
#'   色の範囲はパネルごとに調整します。数値指標の集計は本文で別に行います。
density_panel <- function(x, y, title, xlab, ylab, logarithmic = FALSE) {
  valid <- is.finite(x) & is.finite(y)
  if (logarithmic) valid <- valid & x > 0 & y > 0
  x <- x[valid]; y <- y[valid]
  if (logarithmic) { x <- log10(x); y <- log10(y) }
  limits <- range(quantile(c(x, y), c(0.0025, 0.9975), names = FALSE))
  inside <- x >= limits[1] & x <= limits[2] & y >= limits[1] & y <= limits[2]
  nbin <- 160L
  breaks <- seq(limits[1], limits[2], length.out = nbin + 1L)
  ix <- pmin(findInterval(x[inside], breaks, all.inside = TRUE), nbin)
  iy <- pmin(findInterval(y[inside], breaks, all.inside = TRUE), nbin)
  counts <- matrix(tabulate(ix + (iy - 1L) * nbin, nbin * nbin), nbin)
  z <- log10(counts + 1); z[counts == 0] <- NA_real_
  centres <- (head(breaks, -1) + tail(breaks, -1)) / 2
  image(centres, centres, z, col = hcl.colors(100, "YlOrRd", rev = TRUE),
    xlim = limits, ylim = limits, xlab = xlab, ylab = ylab,
    main = title, axes = FALSE, asp = 1, useRaster = TRUE)
  if (logarithmic) {
    ticks <- pretty(limits)
    axis(1, ticks, format(10^ticks, digits = 2)); axis(2, ticks, format(10^ticks, digits = 2))
  } else { axis(1); axis(2) }
  abline(0, 1, lty = 2, col = "steelblue", lwd = 1.5)
  box()
  mtext(sprintf("valid n=%s; outside view=%s", format(length(x), big.mark = ","),
    format(sum(!inside), big.mark = ",")), 3, line = 0.25, cex = 0.65)
}

#' 表をgzip圧縮CSVに保存する
#'
#' @param x write.csv()で保存できる表。
#' @param path 保存先のCSV.gzパス。親フォルダは先に作成してください。
#' @return 指定したpathに圧縮CSVを保存します。
#' @details 行名は保存せず、欠測値はNAと書きます。既存の同名ファイルは上書きします。
#'   書き出し後には接続を閉じます。渡した表の数値は変更しません。
write_gzip <- function(x, path) {
  con <- gzfile(path, "wt")
  on.exit(close(con))
  write.csv(x, con, row.names = FALSE, na = "NA")
}
