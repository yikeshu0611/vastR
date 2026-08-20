\name{vast_read}
\title{vast_read: read a line range}
\description{
Export a line range from the file currently open in Vast and read it into R
(without loading the whole file into memory).
}
\usage{
vast_read(from = 1L, to = NULL, n = 100L)
}
\arguments{
\item{from}{Start line (1-based).}
\item{to}{End line; default \code{from + n - 1}.}
\item{n}{Number of lines when \code{to} is omitted.}
}
\examples{
vast_read(1, n = 20)
}
