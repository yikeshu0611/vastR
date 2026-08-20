\name{vast_open}
\title{vast_open: open a file in Vast}
\description{
Open a large file and return a \code{vast_tbl} handle (does not load the whole
table into R). Use \code{colnames()} / \code{head()} to preview, then filter with pipes.
}
\usage{
vast_open(path, delim = NULL, header = NULL, tail_bytes = NULL)
}
\arguments{
\item{path}{File path.}
\item{delim}{\code{NULL} to auto-detect; \code{""}/\code{"none"} for no split; \code{"tab"} or \code{","}.}
\item{header}{Header row count; \code{NULL} to auto-detect.}
\item{tail_bytes}{If >0, map only the last N bytes of the file.}
}
\value{
A \code{vast_tbl} object.
}
\examples{
\dontrun{
t <- vast_open("~/data/huge.csv", delim = ",", header = 1)
head(t)
}
}
