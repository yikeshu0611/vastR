\name{vast_open}
\alias{vast_open}
\title{vast_open: 在 Vast 中打开文件}
\description{
打开大文件并返回 \code{vast_tbl} 句柄（不会把整表读进 R）。
可用 \code{colnames()} / \code{head()} 预览，再用管道筛选。
}
\usage{
vast_open(path, delim = NULL, header = NULL, tail_bytes = NULL)
}
\arguments{
\item{path}{文件路径。}
\item{delim}{\code{NULL} 自动猜；\code{""}/\code{"none"} 不分列；\code{"tab"} 或 \code{","}。}
\item{header}{标题行数；\code{NULL} 自动猜。}
\item{tail_bytes}{若 >0，只映射文件末尾若干字节。}
}
\value{
\code{vast_tbl} 对象。
}
\examples{
\dontrun{
library(vastR)
x <- vast_open("~/data.tsv")
colnames(x)
head(x)
x |> filter(value == "Oriented by RN")
x |> select(subject_id, value) |> filter(value == "Oriented by RN")
}
}
