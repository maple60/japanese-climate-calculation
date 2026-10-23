# Base R support for the daily FAO-56 calculation and monthly export tables.
#' 呼び出し情報を付けずに処理を停止する
#'
#' パイプラインから共通の形式でエラーを出すための補助関数です。
#' @param message 表示するエラーメッセージ。
#' @param ... 呼び出しの互換性のための引数。現在の実装では使いません。
#' @return 値は返さず、エラーで処理を停止します。
#' @details このローカル比較レポートでは呼んでいません。
pipeline_stop <- function(message, ...) stop(message, call. = FALSE)

#' 1月から12月の英語略称を返す
#'
#' 月別列名の接尾辞に使う、R標準の月名を返します。
#' @return JanからDecまでの長さ12の文字列ベクトル。
#' @details このローカル比較レポートでは、同じ内容のmonth.abbを直接使います。
#' @examples
#' pipeline_p0_month_abbreviations()
pipeline_p0_month_abbreviations <- function() month.abb

# No fallback to the repository: real tables belong under PROJECT_DATA_DIR.
#' ET0データの保存先を環境変数から組み立てる
#'
#' @return PROJECT_DATA_DIRの下のnaro-et0/2008-2018を指す文字列。
#' @details PROJECT_DATA_DIRが未設定または空なら停止します。
#'   フォルダの存在確認や作成は行いません。
#'   このローカル比較レポートでは、本文で入力パスを直接組み立てています。
et0_data_dir <- function() {
  root <- Sys.getenv("PROJECT_DATA_DIR")
  if (!nzchar(root)) stop("Set PROJECT_DATA_DIR in .Renviron.", call. = FALSE)
  file.path(root, "naro-et0", "2008-2018")
}

# Explicit types preserve leading zeros in mesh identifiers.
#' メッシュ番号を文字列として月別CSVを読み込む
#'
#' @param path 月別CSVまたはCSV.gzのファイルパス。
#' @return 入力と同じ行・列を持つデータフレーム。
#'   mesh3_codeは文字列、それ以外の列は数値として読み込みます。
#' @details メッシュ番号の先頭の0を落とさないため、列の型を指定します。
#'   必須列・単位・対象期間の妥当性は、この関数では検証しません。
#'   ファイルは読み取るだけで変更しません。
#' @seealso period_summary
read_monthly_csv <- function(path) {
  columns <- names(read.csv(path, nrows = 0))
  classes <- ifelse(columns == "mesh3_code", "character", "numeric")
  read.csv(path, colClasses = classes)
}

# Copied from the standalone pipeline_p0_naro.R. Apply separately to RH and
# wind, separately for each calendar year; do not interpolate other inputs.
#' 前後に観測値がある短い日別欠測を線形補間する
#'
#' @param x 行がメッシュ、列が日付順の日別値である数値行列。
#' @param max_gap 補間する連続欠測の最大日数。既定値は2日。
#' @return values（補間後の行列）とfilled_days（各行で補間した日数）のリスト。
#' @details 湿度と風速のそれぞれに、暦年ごとに適用する前提です。
#'   行の先頭・末尾の欠測、max_gapを超える連続欠測は補間しません。
#'   他の気象変数や年をまたぐ補間には使いません。
#'   このローカル比較レポートでは日別値を再計算せず、この関数も呼びません。
#' @examples
#' x <- matrix(c(10, NA, NA, 16, NA), nrow = 1)
#' pipeline_p0_fill_short_gaps(x)$values  # 10, 12, 14, 16, NA
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
#' 選んだ月の降水量・ET0を合計してAIを求める
#'
#' @param data 選択月のet0_fao56_Jan等とprecipitation_Jan等を持つデータフレーム。
#'   値の単位は月合計mm。各行は同じメッシュ・期間に対応させます。
#' @param months 集計する月番号。1から12の重複しない整数を指定します。
#' @param label 出力のperiod列に入れる期間名。
#' @return 入力と同じ行順のデータフレーム。存在すればmesh3_code・yearを残し、
#'   period、et0_mm、precipitation_mm、aridity_index、water_balance_mmを追加します。
#' @details AIは降水量合計 / ET0合計、水収支は降水量合計 - ET0合計です。
#'   必要な月の欠測は合計にも残し、非有限値または0以下のET0合計ではAIをNAにします。
#'   月別AIの平均ではありません。月別平年値を渡した場合は平年値の合計同士の比です。
#'   monthsにc(12, 1, 2)を渡しても、前年12月の行を探す処理は行いません。
#' @seealso read_monthly_csv, winter_summary
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
#' 前年12月と当年1・2月を対応付けて冬季AIを求める
#'
#' @param data メッシュごと・年ごとの月別表。mesh3_code、整数のyearと、
#'   12月・1月・2月のET0・降水量の列が必要です。メッシュと年の組は重複不可です。
#' @return 入力と同じ行順の期間集計表。yearは1・2月の属する年です。
#'   列と単位はperiod_summary()と同じです。
#' @details 同じメッシュの前年の行から12月を取り出します。
#'   前年の行がなければ12月をNAとし、部分的な冬季合計は求めません。
#'   このローカル比較レポートは月別の多年平均を使うため、この関数を呼ばず、
#'   period_summary()で12月・1月・2月の平均値を足しています。
#' @seealso period_summary
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
