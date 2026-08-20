\name{vast_export}
\alias{vast_export}
\title{vast_export: 导出行范围}
\description{
把当前文件的指定行范围写出到磁盘文件。
}
\usage{
vast_export(from, to, path, include_header = TRUE)
}
\arguments{
\item{from, to}{行范围（1 起算）。}
\item{path}{输出路径。}
\item{include_header}{若当前有标题行且导出区间在标题之后，是否先写出标题。}
}
\examples{
\dontrun{
vast_export(1, 1000, tempfile(fileext = ".tsv"))
}
}
