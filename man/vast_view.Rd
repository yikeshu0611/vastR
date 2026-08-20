\name{vast_view}
\title{vast_view: view a data frame}
\description{
Write a data.frame / matrix to a temporary TSV and open it in Vast.
If \code{x} is an existing file path, behaves like \code{vast_open}.
}
\usage{
vast_view(x, title = NULL, ...)
}
\arguments{
\item{x}{A data.frame, matrix, or existing file path.}
\item{title}{Prefix for the temporary file name.}
\item{...}{Passed to \code{vast_open} when \code{x} is a path.}
}
\examples{
vast_view(mtcars)
}
