\name{vast_view}
\alias{vast_view}
\title{vast_view: 查看数据框}
\description{
把 data.frame / matrix 写成临时 TSV 并在 Vast 中打开；若传入文件路径则等同 \code{vast_open}。
}
\usage{
vast_view(x, title = NULL, ...)
}
\arguments{
\item{x}{data.frame、matrix，或已存在的文件路径。}
\item{title}{临时文件名前缀。}
\item{...}{当 \code{x} 为路径时传给 \code{vast_open}。}
}
\examples{
\dontrun{
vast_view(mtcars)
}
}
