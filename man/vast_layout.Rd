\name{vast_layout}
\title{vast_layout: set delimiter and header}
\description{
Set the column delimiter and/or header row count for the current file.
}
\usage{
vast_layout(delim = NULL, header = NULL)
}
\arguments{
\item{delim}{\code{"tab"}, \code{","}, \code{""}/\code{"none"}, etc.}
\item{header}{Header row count; 0 means no header.}
}
\examples{
vast_layout(delim = ",", header = 1)
}
