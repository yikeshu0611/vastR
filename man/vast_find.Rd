\name{vast_find}
\title{vast_find: find text}
\description{
Find text within the currently indexed range and jump to the matching line.
}
\usage{
vast_find(q, from = NULL)
}
\arguments{
\item{q}{String to find.}
\item{from}{Start line (1-based); default is after the current highlight.}
}
\examples{
vast_find("ERROR")
}
