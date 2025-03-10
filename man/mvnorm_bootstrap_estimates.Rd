% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/multivariate_normal_hmm_functions.R
\name{mvnorm_bootstrap_estimates}
\alias{mvnorm_bootstrap_estimates}
\title{Get bootstrapped estimates of parameters}
\usage{
mvnorm_bootstrap_estimates(mod, n, k, len, stationary)
}
\arguments{
\item{mod}{List of maximum likelihood estimation results}

\item{n}{Number of bootstrap samples}

\item{k}{Number of variables}

\item{len}{Number of observations}

\item{stationary}{Boolean, whether the HMM is stationary or not}
}
\value{
List of estimates
}
\description{
Get bootstrapped estimates of parameters
}
