# Draw differences already matched by mesh. Positive values mean higher AI with ET0.
# Limits are explicit so different comparisons can use identical colour scales.
#' 対応メッシュごとのAIの差を期間別に描く
#'
#' @param coords differencesと同じ行順のデータフレーム。lon・latは中心の経緯度（度）。
#' @param differences 行がメッシュ、列が期間の数値行列。列名をパネルの見出しに使います。
#'   差はAI（ET0）- AI（PET）として、呼び出し側で計算しておきます。
#' @param file 出力するPNGのパス。保存先フォルダは先に作成してください。
#' @param limits 列ごとの正の色上限。各列は-limitsから+limitsまでの線形尺度です。
#' @return 保存先fileを不可視で返します。主な出力は2400 x 1250ピクセルのPNGです。
#' @details 負は橙、0は白、正は青、非有限値は灰色で描きます。
#'   メッシュ番号の照合、AIの計算、limitsの決定は行いません。
#'   上下限を超える値は端の色にし、その件数を表示します。入力の数値は変更しません。
#'   経緯度上のメッシュ中心を描く図であり、等積図やポリゴン地図ではありません。
#'   既存の同名PNGは上書きします。Cairo対応のRグラフィックス環境が必要です。
plot_ai_difference_maps <- function(coords, differences, file, limits) {
  differences <- as.matrix(differences)
  stopifnot(nrow(coords) == nrow(differences),
    all(c("lon", "lat") %in% names(coords)),
    length(limits) == ncol(differences), all(is.finite(limits)), all(limits > 0),
    !is.null(colnames(differences)))
  palette <- colorRampPalette(c("#B35806", "#FFFFFF", "#2166AC"))(101)
  png(file, width = 2400, height = 1250, res = 180, type = "cairo")
  on.exit(dev.off())
  layout(rbind(seq_len(ncol(differences)), ncol(differences) + seq_len(ncol(differences))),
    heights = c(1, 0.22))
  par(oma = c(2, 0, 0, 0))
  for (i in seq_len(ncol(differences))) {
    value <- differences[, i]
    valid <- is.finite(value)
    scaled <- pmax(-1, pmin(1, value / limits[i]))
    colours <- palette[1L + round(50 * (scaled + 1))]
    colours[!valid] <- "grey80"
    par(mar = c(2.8, 3, 4, 0.8))
    plot(NA, xlim = c(122, 146), ylim = c(24, 46), asp = 1 / cos(35 * pi / 180),
      xlab = "Longitude", ylab = "Latitude", main = colnames(differences)[i],
      xaxs = "i", yaxs = "i")
    points(coords$lon, coords$lat, pch = 15, cex = 0.23, col = colours)
    mtext(sprintf("valid n=%s; beyond scale=%s", format(sum(valid), big.mark = ","),
      format(sum(abs(value[valid]) > limits[i]), big.mark = ",")), 3, line = 0.3, cex = 0.75)
    box()
  }
  for (i in seq_len(ncol(differences))) {
    par(mar = c(3, 3, 1, 0.8))
    z <- seq(-limits[i], limits[i], length.out = 101)
    image(z, 1, matrix(z, ncol = 1), col = palette, axes = FALSE,
      xlab = "", ylab = "", useRaster = TRUE)
    axis(1, at = limits[i] * c(-1, -0.5, 0, 0.5, 1))
  }
  mtext("Difference = AI(ET0) - AI(PET); orange: lower, blue: higher; NA: grey",
    side = 1, outer = TRUE, line = 0.5, cex = 0.95)
  invisible(file)
}
