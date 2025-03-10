% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/multivariate_normal_hmm_functions.R
\name{mvnorm_hmm_pn2pw}
\alias{mvnorm_hmm_pn2pw}
\title{Transform multivariate normal natural parameters to working parameters}
\usage{
mvnorm_hmm_pn2pw(m, mu, sigma, gamma, delta = NULL, stationary = TRUE)
}
\arguments{
\item{m}{Number of states}

\item{mu}{List of vectors of length m, means for each
state dependent multivariate normal distribution}

\item{sigma}{List of matrices of size m x m, covariance matrices
for each state dependent multivariate normal distribution}

\item{gamma}{Transition probabiilty matrix, size m x m}

\item{delta}{Optional, vector of length m containing
initial distribution}

\item{stationary}{Boolean, whether the HMM is stationary or not}
}
\value{
Vector of working parameters
}
\description{
mu does not need to be transformed, as there are no constraints.
We only need to transform diagonal elements of sigma, since there
are no constraints on the covariances.
Include only the lower triangular and diagional elements
of the sigma matrix, since covariance matrices must be symmetric.
}
