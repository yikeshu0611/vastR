\name{filter.vast_tbl}
\alias{filter.vast_tbl}
\alias{select.vast_tbl}
\alias{vast_filter}
\alias{starts}
\alias{ends}
\alias{contains}
\title{dplyr 风格的 filter / select（vast_tbl）}
\description{
\code{filter} / \code{select} 共用 \code{starts} / \code{ends} / \code{contains}。
}
\usage{
\method{filter}{vast_tbl}(.data, ..., .by = NULL, .preserve = FALSE)

\method{select}{vast_tbl}(.data, ...)

starts(x, match = NULL, ignore.case = TRUE)
ends(x, match = NULL, ignore.case = TRUE)
contains(x, match = NULL, ignore.case = TRUE)

vast_filter(.data, ..., op = "==", max_rows = NULL,
            from = NULL, to = NULL, open = FALSE, collect = TRUE)
}
\arguments{
\item{.data}{\code{vast_tbl}。}
\item{...}{\code{filter} 条件或 \code{select} 列。}
\item{.by,.preserve}{与 dplyr 签名兼容；\code{.by} 暂不支持。}
\item{x}{\code{select} 中为列名前缀/后缀/子串；\code{filter} 中为列（向量）。}
\item{match}{仅 \code{filter}：要匹配的字符串。}
\item{ignore.case}{默认 \code{TRUE}（忽略大小写）；设为 \code{FALSE} 则区分。}
\item{op,max_rows,from,to,open,collect}{仅 \code{vast_filter} 旧接口。}
}
\details{
\preformatted{
# select：按列名
select(starts("value"))
select(ends("id"))
select(contains("time"), ignore.case 写在 starts/ends/contains 里)

# filter：按单元格
filter(starts(value, "Ori"))
filter(ends(value, "RN"))
filter(contains(value, "line"))
}
}
\examples{
\dontrun{
library(vastR)
x <- vast_open("~/itemid~227969.txt")
x %>% select(starts("value"))
x %>% select(ends("id"))
x %>% filter(contains(value, "line"))
x %>% select(subject_id, starts("value")) %>% filter(starts(value, "Ori"))
}
}
