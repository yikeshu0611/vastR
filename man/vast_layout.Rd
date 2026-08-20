\name{vast_layout}
\alias{vast_layout}
\title{vast_layout: 设置分列与标题}
\description{
设置当前文件的分列符和/或标题行数。
}
\usage{
vast_layout(delim = NULL, header = NULL)
}
\arguments{
\item{delim}{\code{"tab"}、\code{","}、\code{""}/\code{"none"} 等。}
\item{header}{标题行数；0 表示无标题。}
}
\examples{
\dontrun{
vast_layout(delim = ",", header = 1)
}
}
