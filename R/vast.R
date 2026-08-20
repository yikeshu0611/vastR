`%||%` <- function(x, y) {
  if (is.null(x) || (length(x) == 1L && is.na(x))) y else x
}

vast_api_candidates <- function() {
  if (.Platform$OS.type == "windows") {
    return(file.path(Sys.getenv("APPDATA"), "com.qo.vast", "api.json"))
  }
  home <- Sys.getenv("HOME")
  c(
    # Direct / Developer ID build
    file.path(home, "Library", "Application Support", "com.qo.vast", "api.json"),
    # Mac App Store sandboxed container (bundle id com.qo.vast)
    file.path(
      home, "Library", "Containers", "com.qo.vast", "Data",
      "Library", "Application Support", "com.qo.vast", "api.json"
    )
  )
}

vast_api_file <- function() {
  cands <- vast_api_candidates()
  existing <- cands[file.exists(cands)]
  if (!length(existing)) return(cands[[1]])
  # Prefer the newest file that points at a live Vast process.
  info_ok <- NULL
  newest_mtime <- -Inf
  newest_path <- existing[[1]]
  for (f in existing) {
    mt <- file.info(f)$mtime
    if (!is.na(mt) && as.numeric(mt) >= newest_mtime) {
      newest_mtime <- as.numeric(mt)
      newest_path <- f
    }
    parsed <- tryCatch(jsonlite::fromJSON(f, simplifyVector = TRUE), error = function(e) NULL)
    if (is.null(parsed)) next
    pid <- parsed$pid
    if (!is.null(pid) && pid_running(pid)) {
      return(f)
    }
  }
  newest_path
}

vast_log_path <- function() {
  if (.Platform$OS.type == "windows") {
    return(file.path(Sys.getenv("APPDATA"), "com.qo.vast", "vast.log"))
  }
  home <- Sys.getenv("HOME")
  cands <- c(
    file.path(home, "Library", "Application Support", "com.qo.vast", "vast.log"),
    file.path(
      home, "Library", "Containers", "com.qo.vast", "Data",
      "Library", "Application Support", "com.qo.vast", "vast.log"
    )
  )
  existing <- cands[file.exists(cands)]
  if (length(existing)) existing[[1]] else cands[[1]]
}

vast_app_path <- function() {
  if (.Platform$OS.type == "windows") {
    candidates <- c(
      file.path(Sys.getenv("ProgramFiles"), "Vast", "Vast.exe"),
      file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Vast", "Vast.exe")
    )
    for (p in candidates) if (file.exists(p)) return(normalizePath(p, winslash = "/"))
    candidates[[1]]
  } else {
    "/Applications/Vast.app"
  }
}

pid_running <- function(pid) {
  pid <- suppressWarnings(as.integer(pid))
  if (length(pid) != 1L || is.na(pid) || pid <= 0L) return(FALSE)
  if (.Platform$OS.type == "windows") {
    out <- suppressWarnings(
      system2("tasklist", c("/FI", paste0("PID eq ", pid), "/NH"), stdout = TRUE, stderr = FALSE)
    )
    length(out) > 0L && any(grepl(as.character(pid), out, fixed = TRUE))
  } else {
    out <- suppressWarnings(system2("ps", c("-p", pid, "-o", "pid="), stdout = TRUE, stderr = FALSE))
    length(out) > 0L && any(grepl(as.character(pid), out, fixed = TRUE))
  }
}

vast_api_info <- function() {
  f <- vast_api_file()
  if (!file.exists(f)) return(NULL)
  info <- tryCatch(fromJSON(f, simplifyVector = TRUE), error = function(e) NULL)
  if (is.null(info) || is.null(info$port) || is.null(info$token)) return(NULL)
  if (!pid_running(info$pid)) return(NULL)
  info
}

vast_is_running <- function() {
  !is.null(vast_api_info())
}

vast_ensure <- function(timeout = 15) {
  info <- vast_api_info()
  if (!is.null(info)) return(info)
  app <- vast_app_path()
  if (.Platform$OS.type == "windows") {
    if (!file.exists(app)) {
      stop("找不到 Vast.exe。请先安装到 Program Files\\Vast\\Vast.exe", call. = FALSE)
    }
    cmd <- sprintf(
      "powershell -NoProfile -WindowStyle Hidden -Command \"Start-Process -FilePath '%s' -ArgumentList '--api' -WindowStyle Hidden\"",
      gsub("'", "''", normalizePath(app, winslash = "\\"))
    )
    ok <- suppressWarnings(system(cmd, wait = FALSE, invisible = TRUE))
  } else {
    if (!dir.exists(app)) {
      stop("找不到 Vast.app。请先安装到 /Applications/Vast.app", call. = FALSE)
    }
    ok <- system2("open", c("-g", "-j", "-a", app, "--args", "--api"),
                  stdout = FALSE, stderr = FALSE)
  }
  if (!is.null(ok) && !identical(ok, 0L) && !identical(ok, 0)) {
    stop("无法启动 Vast", call. = FALSE)
  }
  t0 <- Sys.time()
  repeat {
    info <- vast_api_info()
    if (!is.null(info)) return(info)
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout) {
      stop("Vast 已启动，但 API 未就绪。请确认应用版本 >= 0.6.2", call. = FALSE)
    }
    Sys.sleep(0.2)
  }
}

vast_request <- function(method, route, body = NULL, timeout = 30) {
  info <- vast_ensure()
  args <- c(
    "-sS", "--max-time", as.character(as.integer(timeout)),
    "-X", method,
    "-H", paste0("X-Vast-Token:", info$token),
    "-H", "Content-Type:application/json"
  )
  tmp <- NULL
  if (!is.null(body)) {
    if (length(body) == 0L) {
      body <- NULL
    }
  }
  if (!is.null(body)) {
    tmp <- tempfile(fileext = ".json")
    writeLines(toJSON(body, auto_unbox = TRUE, null = "null"), tmp, useBytes = TRUE)
    args <- c(args, "--data-binary", paste0("@", tmp))
  }
  url <- sprintf("http://127.0.0.1:%s%s", info$port, route)
  args <- c(args, url)
  out <- suppressWarnings(system2("curl", args, stdout = TRUE, stderr = TRUE))
  if (!is.null(tmp) && file.exists(tmp)) unlink(tmp)
  text <- paste(out, collapse = "\n")
  parsed <- tryCatch(fromJSON(text, simplifyVector = TRUE), error = function(e) NULL)
  if (is.null(parsed)) {
    stop("Vast API 请求失败: ", text, call. = FALSE)
  }
  if (isFALSE(parsed$ok)) {
    stop(parsed$error %||% "request failed", call. = FALSE)
  }
  parsed
}

normalize_delim <- function(delim) {
  if (is.null(delim)) return(NULL)
  if (isTRUE(delim)) return(",")
  if (identical(delim, FALSE)) return("")
  delim <- as.character(delim)[[1]]
  d <- tolower(delim)
  if (d %in% c("none", "off", "false")) return("")
  # Prefer named tokens over raw "\t" so JSON never embeds a tab character.
  if (d %in% c("tab", "\\t", "tsv") || identical(delim, "\t")) return("tab")
  if (d %in% c("comma", "csv", ",") || identical(delim, ",")) return(",")
  delim
}

# Fixed cache file: parent of session tempdir() / vast.txt
# e.g. tempdir() = .../T/RtmpXXX/  →  .../T/vast.txt
vast_cache_path <- function() {
  file.path(dirname(tempdir()), "vast.txt")
}

# Convert stored / API delim to the wire form Vast expects.
delim_for_api <- function(delim) {
  if (is.null(delim) || !nzchar(as.character(delim)[[1]])) return(NULL)
  d <- as.character(delim)[[1]]
  if (identical(d, "\t") || tolower(d) %in% c("tab", "tsv")) return("tab")
  if (identical(d, ",") || tolower(d) %in% c("comma", "csv")) return(",")
  if (tolower(d) %in% c("none", "off")) return("")
  d
}

vast_read_path <- function(path, delim = "\t", header = 1L) {
  has_header <- isTRUE(as.integer(header) > 0L)
  data.frame(vroom::vroom(
    path,
    delim = "\t",
    col_names = has_header,
    quote = "\"",
    show_col_types = FALSE,
    progress = FALSE
  ), check.names = FALSE, stringsAsFactors = FALSE)
}

# ---- vast_tbl: 0-row data.frame shell (for RStudio column completion) ----

vast_tbl_meta <- function(x, which) {
  attr(x, which, exact = TRUE)
}

empty_df_with_names <- function(nms) {
  nms <- as.character(nms)
  if (!length(nms)) {
    return(data.frame(check.names = FALSE, stringsAsFactors = FALSE))
  }
  as.data.frame(
    setNames(lapply(nms, function(...) character()), nms),
    optional = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )[0L, , drop = FALSE]
}

peek_column_names <- function(header = 1L) {
  hdr <- max(0L, as.integer(header)[[1]])
  from <- hdr + 1L
  df <- tryCatch(vast_read(from = from, n = 1L), error = function(e) NULL)
  if (is.null(df)) return(character())
  names(df)
}

new_vast_tbl <- function(status, col_names = NULL, delim = NULL, header = NULL) {
  path <- status$path
  if (is.null(path) || (length(path) == 1L && is.na(path))) {
    stop("Vast 未打开文件", call. = FALSE)
  }
  if (is.null(delim)) {
    delim <- as.character(status$delim %||% "")
    dn <- tolower(as.character(status$delim_name %||% ""))
    if (!nzchar(delim) && dn %in% c("tab", "tsv")) delim <- "tab"
    if (!nzchar(delim) && dn %in% c("comma", "csv")) delim <- ","
    if (identical(delim, "\t")) delim <- "tab"
  }
  if (is.null(header)) header <- as.integer(status$header %||% 0L)
  header <- as.integer(header)[[1]]

  if (is.null(col_names) || !length(col_names)) {
    col_names <- peek_column_names(header)
  }

  df <- empty_df_with_names(col_names)
  structure(
    df,
    path = as.character(path)[[1]],
    delim = as.character(delim)[[1]],
    header = header,
    status = status,
    class = c("vast_tbl", "data.frame")
  )
}

vast_tbl_ensure <- function(x) {
  if (!inherits(x, "vast_tbl")) stop("需要 vast_tbl（由 vast_open() 返回）", call. = FALSE)
  path <- vast_tbl_meta(x, "path")
  delim <- vast_tbl_meta(x, "delim")
  header <- vast_tbl_meta(x, "header")
  st <- tryCatch(vast_request("GET", "/v1/status"), error = function(e) NULL)
  cur <- if (!is.null(st)) as.character(st$path %||% "") else ""
  want <- normalizePath(path, winslash = "/", mustWork = FALSE)
  same <- nzchar(cur) && normalizePath(cur, winslash = "/", mustWork = FALSE) == want
  api_delim <- delim_for_api(delim)
  if (!same) {
    body <- list(path = want, activate = FALSE)
    if (!is.null(api_delim)) body$delim <- api_delim
    if (!is.null(header)) body$header <- as.integer(header)
    st <- vast_request("POST", "/v1/open", body)
  } else if (!is.null(api_delim) || !is.null(header)) {
    body <- list()
    if (!is.null(api_delim)) body$delim <- api_delim
    if (!is.null(header)) body$header <- as.integer(header)
    if (length(body)) st <- vast_request("POST", "/v1/layout", body)
  }
  st <- vast_request("GET", "/v1/status")
  if (!is.null(api_delim) && !nzchar(as.character(st$delim %||% "")) &&
      !identical(tolower(as.character(st$delim_name %||% "")), "tab") &&
      !identical(tolower(as.character(st$delim_name %||% "")), "comma")) {
    st <- vast_request("POST", "/v1/layout", list(
      delim = api_delim,
      header = as.integer(header %||% 1L)
    ))
  }
  st
}

#' @export
print.vast_tbl <- function(x, ...) {
  st <- tryCatch(vast_tbl_ensure(x), error = function(e) attr(x, "status"))
  cat("<vast_tbl>\n", sep = "")
  cat("  path: ", vast_tbl_meta(x, "path"), "\n", sep = "")
  if (!is.null(st)) {
    cat("  lines: ", format(st$lines %||% NA, scientific = FALSE),
        if (isTRUE(st$indexing)) " (indexing…)" else "",
        "\n", sep = "")
    cat("  delim: ", st$delim_name %||% st$delim %||% "?",
        "  header: ", st$header %||% vast_tbl_meta(x, "header"), "\n", sep = "")
  }
  cat("  columns: ", paste(names(x), collapse = ", "), "\n", sep = "")
  attached <- attr(x, "indexes", exact = TRUE)
  if (!is.null(attached) && length(attached)) {
    cat("  indexes: ", paste(attached, collapse = ", "), " (attached)\n", sep = "")
  } else if (!is.null(st) && !is.null(st$attached_indexes) && length(st$attached_indexes)) {
    nms <- vapply(st$attached_indexes, function(a) as.character(a$column_name %||% ""), "")
    cat("  indexes: ", paste(nms, collapse = ", "), " (attached)\n", sep = "")
  }
  cat("\n")
  print(utils::head(x, 6L))
  invisible(x)
}

#' @export
dim.vast_tbl <- function(x) {
  st <- tryCatch(vast_tbl_ensure(x), error = function(e) NULL)
  hdr <- as.integer(vast_tbl_meta(x, "header") %||% 0L)
  nr <- if (!is.null(st)) {
    lines <- as.numeric(st$lines %||% NA)
    if (!is.na(lines)) max(0, lines - hdr) else NA_real_
  } else NA_real_
  c(nr, length(names(x)))
}

# Prefer data.frame names (0-row shell) for RStudio completions — no custom names().

#' @export
as.data.frame.vast_tbl <- function(x, row.names = NULL, optional = FALSE, ..., n = 100L) {
  utils::head(x, n = as.integer(n)[[1]])
}

#' @export
`.DollarNames.vast_tbl` <- function(x, pattern = "") {
  nms <- names(x)
  if (!nzchar(pattern)) return(nms)
  grep(pattern, nms, value = TRUE)
}

vast_open <- function(path, delim = NULL, header = NULL, tail_bytes = NULL) {
  path <- path.expand(path)
  if (!file.exists(path)) stop("文件不存在: ", path, call. = FALSE)
  body <- list(path = normalizePath(path, winslash = "/", mustWork = TRUE))
  delim <- normalize_delim(delim)
  if (!is.null(delim)) body$delim <- delim_for_api(delim) %||% delim
  if (!is.null(header)) body$header <- as.integer(header)
  if (!is.null(tail_bytes)) body$tail_bytes <- as.numeric(tail_bytes)
  body$activate <- FALSE
  status <- vast_request("POST", "/v1/open", body)

  # Temporary handle to push layout, then peek column names for autocomplete shell.
  tmp <- new_vast_tbl(status, col_names = character(), delim = delim %||% NULL, header = header)
  if (!is.null(delim)) attr(tmp, "delim") <- delim
  if (!is.null(header)) attr(tmp, "header") <- as.integer(header)
  vast_tbl_ensure(tmp)
  status <- vast_request("GET", "/v1/status")
  cols <- peek_column_names(attr(tmp, "header") %||% 1L)
  new_vast_tbl(
    status,
    col_names = cols,
    delim = attr(tmp, "delim"),
    header = attr(tmp, "header")
  )
}

vast_view <- function(x, title = NULL, ...) {
  if (is.character(x) && length(x) == 1L && file.exists(path.expand(x))) {
    return(vast_open(x, ...))
  }
  if (is.null(title)) title <- deparse(substitute(x))
  if (!is.data.frame(x)) x <- as.data.frame(x, stringsAsFactors = FALSE)
  x[] <- lapply(x, function(col) {
    if (is.list(col)) vapply(col, function(v) paste(v, collapse = ","), "") else col
  })
  dir <- file.path(tempdir(), "vast-r")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  safe <- gsub("[^A-Za-z0-9._-]+", "_", title)
  if (!nzchar(safe)) safe <- "data"
  path <- file.path(dir, paste0(safe, ".tsv"))
  write.table(x, file = path, sep = "\t", row.names = FALSE, quote = TRUE,
              fileEncoding = "UTF-8", qmethod = "double")
  vast_open(path, delim = "\t", header = 1L)
}

vast_status <- function() {
  vast_request("GET", "/v1/status")
}

vast_resolve_index_path <- function(x, path) {
  path <- path.expand(as.character(path)[[1]])
  if (!nzchar(path)) return(path)
  if (substr(path, 1L, 1L) == "/" ||
      (.Platform$OS.type == "windows" && grepl("^[A-Za-z]:[/\\\\]", path))) {
    return(normalizePath(path, winslash = "/", mustWork = FALSE))
  }
  src <- vast_tbl_meta(x, "path")
  if (is.null(src) || !nzchar(src)) {
    stop("vast_tbl 缺少源文件路径", call. = FALSE)
  }
  base <- dirname(normalizePath(src, winslash = "/", mustWork = TRUE))
  normalizePath(file.path(base, path), winslash = "/", mustWork = FALSE)
}

#' Build a on-disk unique-value index for one column (does not attach).
#' Returns the path where the index was saved.
#' @param path optional output file; relative paths are resolved next to the
#'   opened data file. Default is a temp \code{.vidx} file.
#' @export
vast_build_index <- function(x, column, path = NULL, force = FALSE) {
  if (!inherits(x, "vast_tbl")) {
    stop("需要 vast_tbl（由 vast_open() 返回）", call. = FALSE)
  }
  vast_tbl_ensure(x)
  body <- list(column = column, force = isTRUE(force))
  if (!is.null(path) && nzchar(as.character(path)[[1]])) {
    body$path <- vast_resolve_index_path(x, path)
  }
  res <- vast_request(
    "POST", "/v1/index/build",
    body,
    timeout = 3600
  )
  as.character(res$path)
}

parse_vast_arrange_expr <- function(expr, env) {
  if (is.call(expr)) {
    fn <- deparse(expr[[1]])[[1]]
    if (fn %in% c("desc", "dplyr::desc")) {
      col <- eval(expr[[2]], envir = env)
      return(list(column = as.character(col)[[1]], order = "desc"))
    }
  }
  col <- eval(expr, envir = env)
  list(column = as.character(col)[[1]], order = "asc")
}

#' Sort rows by one column (writes a new TSV; returns a new \code{vast_tbl}).
#'
#' Fast path: uses an attached or cached column index when available
#' (build with \code{vast_build_index()}). Otherwise external merge sort.
#' @param column column name or 1-based index
#' @param order \code{"asc"} or \code{"desc"}
#' @param type \code{"auto"}, \code{"string"}, or \code{"numeric"}
#' @param path output file; default \code{<source>.sorted-<column>.tsv}
#' @param na_last place empty / non-numeric keys last when \code{type="numeric"}
#' @param max_rows stop after writing this many data rows (\code{0} = all)
#' @export
vast_sort <- function(x, column, order = c("asc", "desc"),
                      type = c("auto", "string", "numeric"),
                      path = NULL, na_last = TRUE, max_rows = 0) {
  if (!inherits(x, "vast_tbl")) {
    stop("需要 vast_tbl（由 vast_open() 返回）", call. = FALSE)
  }
  order <- match.arg(order)
  type <- match.arg(type)
  vast_tbl_ensure(x)
  src <- vast_tbl_meta(x, "path")
  cn <- as.character(column)[[1]]
  if (is.null(path) || !nzchar(as.character(path)[[1]])) {
    base <- tools::file_path_sans_ext(basename(src))
    path <- file.path(
      dirname(normalizePath(src, winslash = "/", mustWork = TRUE)),
      paste0(base, ".sorted-", cn, ".tsv")
    )
  }
  out_path <- vast_resolve_index_path(x, path)
  body <- list(
    column = column,
    path = out_path,
    order = order,
    type = type,
    na_last = isTRUE(na_last),
    max_rows = as.numeric(max_rows)[[1]]
  )
  if (is.na(body$max_rows) || body$max_rows < 0) body$max_rows <- 0
  meta <- vast_request("POST", "/v1/sort", body, timeout = 3600)
  if (isTRUE(meta$via_index)) {
    message(sprintf(
      "vast: sort via index  rows=%s",
      format(meta$rows %||% NA, scientific = FALSE)
    ))
  } else {
    message(sprintf(
      "vast: sort full scan  rows=%s scanned=%s",
      format(meta$rows %||% NA, scientific = FALSE),
      format(meta$scanned %||% NA, scientific = FALSE)
    ))
  }
  hdr <- as.integer(meta$header %||% vast_tbl_meta(x, "header") %||% 1L)
  out <- vast_open(out_path, delim = "\t", header = hdr)
  attr(out, "vast_sort") <- meta
  out
}

#' Load a previously built index into the Vast session (manual attach).
#' @param path index file from \code{vast_build_index()}; required if built to temp.
#' @export
vast_attach_index <- function(x, column, path = NULL) {
  if (!inherits(x, "vast_tbl")) {
    stop("需要 vast_tbl（由 vast_open() 返回）", call. = FALSE)
  }
  vast_tbl_ensure(x)
  body <- list(column = column)
  if (!is.null(path) && nzchar(as.character(path)[[1]])) {
    body$path <- vast_resolve_index_path(x, path)
  }
  res <- vast_request("POST", "/v1/index/attach", body)
  cn <- as.character(res$column_name %||% column)
  idx <- attr(x, "indexes", exact = TRUE) %||% character()
  attr(x, "indexes") <- unique(c(idx, cn))
  paths <- attr(x, "index_paths", exact = TRUE)
  if (is.null(paths)) paths <- list()
  paths[[cn]] <- as.character(res$path)
  attr(x, "index_paths") <- paths
  invisible(x)
}

#' Detach column index from session. Omit \code{column} to detach all.
#' @export
vast_detach_index <- function(x, column = NULL) {
  if (!inherits(x, "vast_tbl")) {
    stop("需要 vast_tbl（由 vast_open() 返回）", call. = FALSE)
  }
  vast_tbl_ensure(x)
  body <- list()
  if (!is.null(column)) body$column <- column
  res <- vast_request("POST", "/v1/index/detach", body)
  if (is.null(column)) {
    attr(x, "indexes") <- character()
  } else {
    cn <- as.character(column)
    idx <- attr(x, "indexes", exact = TRUE) %||% character()
    attr(x, "indexes") <- setdiff(idx, cn)
  }
  invisible(x)
}

vast_goto <- function(line) {
  invisible(vast_request("POST", "/v1/goto", list(line = as.integer(line))))
}

vast_find <- function(q, from = NULL) {
  body <- list(q = as.character(q)[[1]])
  if (!is.null(from)) body$from <- as.integer(from)
  vast_request("POST", "/v1/find", body)
}

vast_layout <- function(delim = NULL, header = NULL) {
  body <- list()
  delim <- normalize_delim(delim)
  if (!is.null(delim)) body$delim <- delim
  if (!is.null(header)) body$header <- as.integer(header)
  if (!length(body)) stop("请提供 delim 或 header", call. = FALSE)
  invisible(vast_request("POST", "/v1/layout", body))
}

vast_export <- function(from, to, path, include_header = TRUE) {
  path <- path.expand(path)
  body <- list(
    from = as.integer(from),
    to = as.integer(to),
    path = path,
    include_header = isTRUE(include_header)
  )
  vast_request("POST", "/v1/export", body)
}

vast_read <- function(from = 1L, to = NULL, n = 100L) {
  if (is.null(to)) to <- as.integer(from) + as.integer(n) - 1L
  path <- vast_cache_path()
  meta <- vast_export(from, to, path, include_header = TRUE)
  vast_read_path(path, meta$delim, meta$header)
}

# Parse dplyr-like filter expression: col == "a", col >= 1, contains(col, "kg")
parse_vast_filter_expr <- function(expr, env) {
  if (is.character(expr) && length(expr) == 1L) {
    return(list(column = expr, value = NULL, op = NULL, incomplete = TRUE))
  }
  if (!is.call(expr) && !is.language(expr)) {
    stop("无法解析筛选表达式", call. = FALSE)
  }
  op <- as.character(expr[[1]])

  if (op %in% c("==", "=", "!=", ">", "<", ">=", "<=")) {
    if (length(expr) != 3L) stop("比较表达式需要左右两侧", call. = FALSE)
    lhs <- expr[[2]]
    rhs <- expr[[3]]
    if (!is.symbol(lhs) && !(is.character(lhs) && length(lhs) == 1L)) {
      stop("左侧应为列名，例如 value == \"...\"", call. = FALSE)
    }
    column <- if (is.symbol(lhs)) as.character(lhs) else as.character(lhs)[[1]]
    value <- eval(rhs, envir = env)
    return(list(column = column, value = value, op = if (op == "=") "==" else op))
  }

  if (op %in% c("%in%", "in")) {
    if (length(expr) != 3L) stop("%in% 需要左右两侧", call. = FALSE)
    lhs <- expr[[2]]
    rhs <- expr[[3]]
    if (!is.symbol(lhs) && !(is.character(lhs) && length(lhs) == 1L)) {
      stop("左侧应为列名，例如 value %in% c(\"a\", \"b\")", call. = FALSE)
    }
    column <- if (is.symbol(lhs)) as.character(lhs) else as.character(lhs)[[1]]
    value <- eval(rhs, envir = env)
    return(list(column = column, value = value, op = "in", ignore_case = TRUE))
  }

  if (op %in% c("contains", "starts", "ends", "startsWith", "endsWith", "grepl")) {
    ignore_case <- TRUE
    args <- as.list(expr)[-1L]
    nms <- names(args)
    if (is.null(nms)) nms <- rep("", length(args))
    ic <- nms %in% c("ignore.case", "ignore_case", "ignoreCase")
    if (any(ic)) {
      ignore_case <- isTRUE(eval(args[[which(ic)[1]]], envir = env))
      args <- args[!ic]
      nms <- nms[!ic]
    }

    if (op == "grepl") {
      if (length(args) < 2L) stop("grepl(pattern, column)", call. = FALSE)
      pat <- eval(args[[1]], envir = env)
      col <- args[[2]]
      if (!is.symbol(col)) stop("grepl 的第二参数应为列名", call. = FALSE)
      return(list(
        column = as.character(col), value = as.character(pat)[[1]],
        op = "contains", ignore_case = ignore_case
      ))
    }
    # contains(col, "kg") / starts(col, "x") / ends(col, "y")
    if (length(args) < 2L) stop(op, "(column, value)", call. = FALSE)
    col <- args[[1]]
    val <- eval(args[[2]], envir = env)
    if (length(args) >= 3L) {
      ignore_case <- isTRUE(eval(args[[3]], envir = env))
    }
    if (!is.symbol(col) && !(is.character(col) && length(col) == 1L)) {
      stop(op, " 的第一参数应为列名", call. = FALSE)
    }
    column <- if (is.symbol(col)) as.character(col) else as.character(col)[[1]]
    mop <- op
    if (op %in% c("startsWith", "starts")) mop <- "starts"
    if (op %in% c("endsWith", "ends")) mop <- "ends"
    if (op == "contains") mop <- "contains"
    return(list(column = column, value = val, op = mop, ignore_case = ignore_case))
  }

  stop("不支持的表达式: ", paste(deparse(expr), collapse = " "),
       "\n可用: col == val, col %in% c(\"a\",\"b\"), contains(col, \"x\")",
       call. = FALSE)
}

vast_filter_exec <- function(column, value, op = "==", max_rows = NULL,
                             from = NULL, to = NULL, open = FALSE, collect = TRUE,
                             ignore_case = TRUE) {
  path <- vast_cache_path()
  op <- as.character(op)[[1]]
  vals <- as.character(value)
  vals <- vals[!is.na(vals)]
  if (identical(op, "in") || length(vals) > 1L) {
    op <- "in"
    json_value <- vals
  } else {
    json_value <- vals[[1]]
  }
  body <- list(
    column = column,
    value = json_value,
    op = op,
    path = path,
    open = isTRUE(open),
    ignore_case = isTRUE(ignore_case)
  )
  if (!is.null(max_rows) && !is.na(max_rows) && as.numeric(max_rows) > 0) {
    body$max_rows <- as.numeric(max_rows)
  } else {
    body$max_rows <- 0
  }
  if (!is.null(from)) body$from <- as.integer(from)
  if (!is.null(to)) body$to <- as.integer(to)
  meta <- vast_request("POST", "/v1/filter", body, timeout = 3600)
  if (isTRUE(meta$via_index)) {
    message(sprintf("vast: filter via index  matched=%s",
                    format(meta$matched %||% NA, scientific = FALSE)))
  } else {
    message(sprintf("vast: filter full scan  matched=%s scanned=%s",
                    format(meta$matched %||% NA, scientific = FALSE),
                    format(meta$scanned %||% NA, scientific = FALSE)))
  }
  if (isTRUE(open)) {
    return(invisible(meta))
  }
  if (!isTRUE(collect)) {
    meta$local_path <- path
    return(invisible(meta))
  }
  out <- vast_read_path(path, meta$delim, meta$header)
  attr(out, "vast_filter") <- meta
  attr(out, "path") <- path
  out
}

apply_vast_select <- function(df, x) {
  sel <- attr(x, "select", exact = TRUE)
  if (is.null(sel) || !length(sel)) return(df)
  keep <- intersect(as.character(sel), names(df))
  if (!length(keep)) return(df[, FALSE, drop = FALSE])
  df[, keep, drop = FALSE]
}

rebuild_vast_tbl <- function(x, col_names, select = NULL) {
  out <- empty_df_with_names(col_names)
  structure(
    out,
    path = attr(x, "path", exact = TRUE),
    delim = attr(x, "delim", exact = TRUE),
    header = attr(x, "header", exact = TRUE),
    select = select %||% attr(x, "select", exact = TRUE),
    status = attr(x, "status", exact = TRUE),
    class = c("vast_tbl", "data.frame")
  )
}

#' @export
head.vast_tbl <- function(x, n = 6L, ...) {
  st <- vast_tbl_ensure(x)
  hdr <- max(0L, as.integer(st$header %||% vast_tbl_meta(x, "header") %||% 0L))
  n <- as.integer(n)[[1]]
  if (is.na(n) || n < 1L) n <- 6L
  apply_vast_select(vast_read(from = hdr + 1L, n = n), x)
}

# ---- dplyr verbs: filter / select ----

#' @export
#' @importFrom dplyr filter
filter.vast_tbl <- function(.data, ..., .by = NULL, .preserve = FALSE) {
  if (!is.null(.by)) {
    stop("vast_tbl 的 filter() 暂不支持 .by", call. = FALSE)
  }
  vast_tbl_ensure(.data)
  dots <- as.list(substitute(list(...)))[-1L]
  if (!length(dots)) return(.data)

  # First predicate runs in Vast (full-file scan). Extra predicates applied in R.
  spec <- parse_vast_filter_expr(dots[[1]], env = parent.frame())
  out <- vast_filter_exec(
    column = spec$column,
    value = spec$value,
    op = spec$op %||% "==",
    collect = TRUE,
    ignore_case = isTRUE(spec$ignore_case %||% TRUE)
  )
  if (length(dots) > 1L) {
    # Evaluate remaining filters on the collected data.frame
    env <- parent.frame()
    for (i in seq(2L, length(dots))) {
      keep <- eval(dots[[i]], envir = out, enclos = env)
      if (!is.logical(keep) || length(keep) != nrow(out)) {
        stop("额外的 filter 条件必须返回与行数相同的逻辑向量", call. = FALSE)
      }
      out <- out[keep %in% TRUE, , drop = FALSE]
    }
  }
  apply_vast_select(out, .data)
}

# ---- dplyr verbs: arrange ----

#' @export
#' @importFrom dplyr arrange
arrange.vast_tbl <- function(.data, ..., .by_group = FALSE) {
  if (isTRUE(.by_group)) {
    stop("vast_tbl 的 arrange() 暂不支持 .by_group", call. = FALSE)
  }
  vast_tbl_ensure(.data)
  dots <- as.list(substitute(list(...)))[-1L]
  if (!length(dots)) return(.data)
  if (length(dots) > 1L) {
    warning("vast_tbl arrange 暂只支持单列；其余排序键已忽略", call. = FALSE)
  }
  env <- parent.frame()
  spec <- parse_vast_arrange_expr(dots[[1]], env)
  vast_sort(.data, column = spec$column, order = spec$order)
}

# ---- starts / ends / contains: same names in select() and filter() ----
# select:  starts("value")            → 列名以 value 开头
# filter:  starts(value, "Ori")       → 单元格以 Ori 开头（由 parse_vast_filter_expr 解析）
# 若在 data.frame 上求值（第二条 filter 条件），走向量匹配。

starts <- function(x, match = NULL, ignore.case = TRUE) {
  if (!is.null(match)) {
    needle <- as.character(match)[[1]]
    hay <- as.character(x)
    if (isTRUE(ignore.case)) {
      return(startsWith(tolower(hay), tolower(needle)))
    }
    return(startsWith(hay, needle))
  }
  tidyselect::starts_with(x, ignore.case = ignore.case)
}

ends <- function(x, match = NULL, ignore.case = TRUE) {
  if (!is.null(match)) {
    needle <- as.character(match)[[1]]
    hay <- as.character(x)
    if (isTRUE(ignore.case)) {
      return(endsWith(tolower(hay), tolower(needle)))
    }
    return(endsWith(hay, needle))
  }
  tidyselect::ends_with(x, ignore.case = ignore.case)
}

contains <- function(x, match = NULL, ignore.case = TRUE) {
  if (!is.null(match)) {
    needle <- as.character(match)[[1]]
    hay <- as.character(x)
    return(grepl(needle, hay, ignore.case = isTRUE(ignore.case), fixed = TRUE))
  }
  tidyselect::contains(x, ignore.case = ignore.case)
}

#' @export
select.vast_tbl <- function(.data, ...) {
  loc <- tidyselect::eval_select(rlang::expr(c(!!!rlang::enexprs(...))), data = .data)
  keep <- names(loc)
  if (!length(keep)) {
    stop("select() 未选中任何列", call. = FALSE)
  }
  rebuild_vast_tbl(.data, col_names = keep, select = keep)
}

#' @export
unique.vast_tbl <- function(x, incomparables = FALSE, fromLast = FALSE, ...) {
  vast_tbl_ensure(x)
  cols <- names(x)
  if (!length(cols)) {
    stop("没有列可取唯一值，请先 select()", call. = FALSE)
  }
  path <- vast_cache_path()
  body <- list(columns = as.list(cols), path = path)
  vast_request("POST", "/v1/unique", body, timeout = 3600)
  vast_read_path(path, "\t", 1L)
}

#' @export
distinct.vast_tbl <- function(.data, ..., .keep_all = FALSE) {
  if (!missing(...) && length(rlang::enexprs(...)) > 0) {
    .data <- dplyr::select(.data, ...)
  }
  if (isTRUE(.keep_all)) {
    stop("vast_tbl 的 distinct() 暂不支持 .keep_all = TRUE", call. = FALSE)
  }
  unique(.data)
}

#' @rdname filter.vast_tbl
#' @export
vast_filter <- function(.data, ..., op = "==", max_rows = NULL,
                        from = NULL, to = NULL, open = FALSE, collect = TRUE) {
  if (inherits(.data, "vast_tbl")) {
    if (!missing(max_rows) || !missing(from) || !missing(to) || !missing(open) ||
        (!missing(collect) && !isTRUE(collect))) {
      vast_tbl_ensure(.data)
      dots <- as.list(substitute(list(...)))[-1L]
      if (!length(dots)) stop("用法: x %>% filter(col == value)", call. = FALSE)
      spec <- parse_vast_filter_expr(dots[[1]], env = parent.frame())
      out <- vast_filter_exec(
        column = spec$column, value = spec$value, op = spec$op %||% "==",
        max_rows = max_rows, from = from, to = to, open = open, collect = collect,
        ignore_case = isTRUE(spec$ignore_case %||% TRUE)
      )
      if (is.data.frame(out)) out <- apply_vast_select(out, .data)
      return(out)
    }
    return(dplyr::filter(.data, ...))
  }

  # Legacy: vast_filter(column, value, op = "==")
  column <- .data
  dots <- list(...)
  if (!length(dots)) {
    stop("用法: filter(x, col == value) 或 vast_filter(column, value)", call. = FALSE)
  }
  value <- dots[[1]]
  if (length(dots) >= 2L && is.character(dots[[2]]) &&
      dots[[2]] %in% c("==", "!=", ">", "<", ">=", "<=", "contains", "starts", "ends")) {
    op <- dots[[2]]
  }
  vast_filter_exec(
    column = column, value = value, op = op,
    max_rows = max_rows, from = from, to = to, open = open, collect = collect
  )
}
