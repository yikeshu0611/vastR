\name{vast_filter}
\alias{vast_filter}
\title{vast_filter（兼容旧名）}
\description{
请优先使用 \code{\link{filter.vast_tbl}}：\code{x \%>\% filter(...)}。
本函数保留旧式 \code{vast_filter(column, value)} 调用。
}
\usage{
vast_filter(.data, ..., op = "==", max_rows = NULL,
            from = NULL, to = NULL, open = FALSE, collect = TRUE)
}
\seealso{
\code{\link{filter.vast_tbl}}
}
