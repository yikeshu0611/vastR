\name{vast_export}
\title{vast_export: export a line range}
\description{
Write a line range from the current Vast file to disk.
}
\usage{
vast_export(from, to, path, include_header = TRUE)
}
\arguments{
\item{from, to}{Line range (1-based).}
\item{path}{Output path.}
\item{include_header}{If the file has header rows and the export range is after them,
whether to write the header first.}
}
\examples{
vast_export(1, 1000, tempfile(fileext = ".tsv"))
}
