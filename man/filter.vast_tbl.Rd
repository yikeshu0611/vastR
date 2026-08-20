\name{filter.vast_tbl}
\alias{filter.vast_tbl}
\alias{select.vast_tbl}
\alias{starts}
\alias{ends}
\alias{contains}
\alias{vast_filter}
\title{dplyr-style filter / select for vast_tbl}
\description{
\code{filter} / \code{select} share \code{starts} / \code{ends} / \code{contains}.
}
\usage{
\method{filter}{vast_tbl}(.data, ..., .by = NULL, .preserve = FALSE)

\method{select}{vast_tbl}(.data, ...)

starts(x, match = NULL, ignore.case = TRUE)

ends(x, match = NULL, ignore.case = TRUE)

contains(x, match = NULL, ignore.case = TRUE)

vast_filter(.data, ..., op = "==", max_rows = NULL,
            from = NULL, to = NULL, open = FALSE, collect = TRUE)
}
\arguments{
\item{.data}{A \code{vast_tbl}.}
\item{...}{\code{filter} predicates or \code{select} columns.}
\item{.by,.preserve}{dplyr-compatible signature; \code{.by} is not supported yet.}
\item{x}{For \code{select}: name prefix/suffix/substring; for \code{filter}: column (vector).}
\item{match}{\code{filter} only: string to match.}
\item{ignore.case}{Default \code{TRUE}; set \code{FALSE} for case-sensitive matching.}
\item{op,max_rows,from,to,open,collect}{Legacy \code{vast_filter} interface only.}
}
\examples{
\dontrun{
# select by column name
t <- vast_open("data.csv", delim = ",", header = 1)
select(t, starts("chart"))

# filter by cell value
filter(t, itemid == "2257526")
}
}
