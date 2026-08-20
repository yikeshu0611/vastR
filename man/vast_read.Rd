\name{vast_read}
\alias{vast_read}
\title{vast_read: 读取行范围}
\description{
从 Vast 当前打开的文件中导出指定行范围并读入 R（不会把整个文件载入内存）。
}
\usage{
vast_read(from = 1L, to = NULL, n = 100L)
}
\arguments{
\item{from}{起始行（1 起算）。}
\item{to}{结束行；默认 \code{from + n - 1}。}
\item{n}{未指定 \code{to} 时读取的行数。}
}
\examples{
\dontrun{
head(vast_read(1, 20))
}
}
