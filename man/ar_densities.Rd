% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/univariate_autoregressive_hmm_functions.R
\name{ar_densities}
\alias{ar_densities}
\title{Returns densities for autoregressive model}
\usage{
ar_densities(x, mod, m, q, n)
}
\arguments{
\item{x}{Vector of observations}

\item{mod}{List of HMM parameters}

\item{m}{Number of states}

\item{n}{Number of observations}
}
\value{
n x m matrix of densities for autoregressive model
}
\description{
Returns densities for autoregressive model
}
