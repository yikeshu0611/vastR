\name{vast_find}
\alias{vast_find}
\title{vast_find: 查找文本}
\description{
在当前已索引范围内查找文本，并跳转到匹配行。
}
\usage{
vast_find(q, from = NULL)
}
\arguments{
\item{q}{要查找的字符串。}
\item{from}{起始行（1 起算）；默认从当前高亮行之后开始。}
}
\examples{
\dontrun{
vast_find("ERROR")
}
}
