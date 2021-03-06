% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/positions.r
\name{get_global_i}
\alias{get_global_i}
\title{Compute global feature positions}
\usage{
get_global_i(tc, context_level = c("document", "sentence"),
  max_window_size = 200)
}
\arguments{
\item{tc}{tCorpus object}

\item{context_level}{either 'document' or 'sentence'}

\item{max_window_size}{Determines the size of the gap between documents. Called max_window_size because this gap determines what the maximum window size is for non-overlapping windows between documents}
}
\value{
a tCorpus object
}
\description{
Features are given global ids, with an added distance (max_window_size) between contexts (e.g., documents, sentences).
This way, the distance of features can be calculated across multiple contexts using a single vector
}

