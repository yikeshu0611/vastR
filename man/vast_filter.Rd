\name{vast_filter}
\title{vast_filter (legacy name)}
\description{
Prefer \code{\link{filter.vast_tbl}}: \code{x \%>\% filter(...)}.
This function keeps the older \code{vast_filter(column, value)} calling style.
}
\usage{
vast_filter(.data, ..., op = "==", max_rows = NULL,
            from = NULL, to = NULL, open = FALSE, collect = TRUE)
}
