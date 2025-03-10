% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/multivariate_autoregressive_hmm_functions.R
\name{get_mar_mean}
\alias{get_mar_mean}
\title{Get mean corresponding to a given index in a multivariate autoregressive series}
\usage{
get_mar_mean(mu, phi, x, m, q, k, i)
}
\arguments{
\item{mu}{List of vectors of length m, means for white noise in each
state dependent distribution}

\item{phi}{List of k x (k x q) matrices, containing the autoregressive
parameters. Each matrix corresponds to a state. The first k x k entries
are the parameters for index i - 1, and so on up to index i - q.}

\item{x}{Observations coming from a multivariate autoregressive series,
in a matrix with k rows. Each row corresponds to a variable.}

\item{m}{Number of states}

\item{q}{Order of the autoregressive model}

\item{k}{Number of variables}

\item{i}{Index of the desired mean}
}
\value{
List of vectors of length m containing means corresponding to index i
for the given autoregressive model
}
\description{
Get mean corresponding to a given index in a multivariate autoregressive series
}
