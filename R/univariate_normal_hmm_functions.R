#' Get univariate normal marginal distribution
#' from an HMM.
#'
#' @param start Smallest value in range.
#' @param end Largest value in range.
#' @param n
#' @param mod List of HMM parameters
#' @param stationary Boolean, whether the HMM is stationary or not
#'
#' @return Dataframe
#' @export
#'
#' @examples
norm_marginal <- function(start, end, n, mod, stationary) {
  if (stationary){
    delta <- solve(t(diag(mod$m) - mod$gamma + 1), rep(1, mod$m))
  }
  else{
    delta <- mod$delta
  }
  x <- seq(start, end, length.out = n)
  mnorm <- delta[1] * dnorm(x, mean = mod$mu[1], sd = mod$sigma[1])
  for (i in 2:mod$m) {
    mnorm <- mnorm + delta[i] * dnorm(x, mean = mod$mu[i], sd = mod$sigma[i])
  }
  return(data_frame(x = x, mnorm = mnorm))
}

#' Transform normal natural parameters to working parameters
#'
#' mu does not need to be transformed, as there are no constraints.
#'
#' @param m Number of states
#' @param mu Vector of length m, containing means for each
#' state dependent normal distribution
#' @param sigma Vector of length m, containing standard
#' deviations for each state dependent normal distribution
#' @param gamma Transition probabiilty matrix, size m x m
#' @param delta Optional, vector of length m containing
#' initial distribution
#' @param stationary Boolean, whether the HMM is stationary or not
#'
#' @return Vector of working parameters
#' @export
#'
#' @examples
norm_hmm_pn2pw <- function(m, mu, sigma, gamma,
                           delta = NULL, stationary = TRUE) {
  tsigma <- log(sigma)
  foo <- log(gamma / diag(gamma))
  tgamma <- as.vector(foo[!diag(m)])
  if (stationary) {
    tdelta <- NULL
  }
  else {
    tdelta <- log(delta[-1] / delta[1])
  }
  parvect <- c(mu, tsigma, tgamma, tdelta)
  return(parvect)
}

#' Transform normal working parameters to natural parameters
#'
#' @param parvect Vector of working parameters
#' @inheritParams norm_hmm_pn2pw
#'
#' @return List of natural parameters mu, sigma, gamma, delta
#' @export
#'
#' @examples
norm_hmm_pw2pn <- function(m, parvect, stationary = TRUE) {
  mu <- parvect[1:m]
  sigma <- exp(parvect[(m + 1):(2 * m)])
  gamma <- diag(m)
  gamma[!gamma] <- exp(parvect[(2 * m + 1):(m + m * m)])
  gamma <- gamma / apply(gamma, 1, sum)
  if (stationary) {
    delta <- solve(t(diag(m) - gamma + 1), rep(1, m))
  }
  else {
    foo <- c(1, exp(parvect[(m + m * m + 1):(m * m + 2 * m - 1)]))
    delta <- foo / sum(foo)
  }
  return(list(mu = mu, sigma = sigma, gamma = gamma, delta = delta))
}

#' Get negative log-likelihood from the working parameters
#'
#' @param x Vector of observations
#' @inheritParams norm_hmm_pn2pw
#'
#' @return Negative log-likelihood
#' @export
#'
#' @examples
norm_hmm_mllk <- function(parvect, x, m, stationary = TRUE) {
  n <- length(x)
  pn <- norm_hmm_pw2pn(m, parvect, stationary = stationary)
  p <- norm_densities(x, pn, m, n)
  foo <- matrix(pn$delta, ncol = m)
  lscale <- foralg(n, m, foo, pn$gamma, p)
  mllk <- -lscale
  return(mllk)
}

#' Returns normal densities
#'
#' @inheritParams norm_hmm_mllk
#' @param mod List of HMM parameters
#' @param n Number of observations
#'
#' @return Matrix of normal densities, dimensions n x m
#' @export
#'
#' @examples
norm_densities <- function(x, mod, m, n) {
  p <- matrix(nrow = n, ncol = m)
  for (i in 1:n) {
    p[i, ] <- dnorm(x[i], mod$mu, mod$sigma)
  }
  return(p)
}

#' Maximum likelihood estimation of univariate normal parameters
#'
#' @param mu0 Vector of length m, initial values for means
#' @param sigma0 Vector of length m, initial values for standard deviations
#' @param gamma0 Matrix of size m x m, initial values for transition probability matrix
#' @param delta0 Optional, vector of length m, initial values for
#' initial distribution
#' @param hessian Boolean, whether to return the inverse hessian
#' @inheritParams norm_hmm_mllk
#'
#' @return List of results
#' @export
#'
#' @examples
norm_hmm_mle <- function(x, m, mu0, sigma0, gamma0,
                         delta0 = NULL, stationary = TRUE,
                         hessian = FALSE) {
  parvect0 <- norm_hmm_pn2pw(m, mu0, sigma0, gamma0, delta0,
                             stationary = stationary)
  mod <- nlm(norm_hmm_mllk, parvect0, x = x, m = m,
             stationary = stationary,
             hessian = hessian)
  pn <- norm_hmm_pw2pn(m, mod$estimate,
                       stationary = stationary)
  mllk <- mod$minimum

  np <- length(parvect0)
  aic <- 2 * (mllk + np)
  n <- sum(!is.na(x))
  bic <- 2 * mllk + np * log(n)

  if (hessian) {
    return(list(
      m = m, mu = pn$mu, sigma = pn$sigma,
      gamma = pn$gamma, delta = pn$delta,
      code = mod$code, mllk = mllk,
      aic = aic, bic = bic, hessian = mod$hessian, np = np
    ))
  }
  else {
    return(list(
      m = m, mu = pn$mu, sigma = pn$sigma, gamma = pn$gamma, delta = pn$delta,
      code = mod$code, mllk = mllk, aic = aic, bic = bic
    ))
  }
}

#' Generate sample from HMM with normal distribution
#'
#' @param ns Sample size
#' @param mod List of HMM parameters
#'
#' @return Dataframe including index, state, obs
#' @export
#'
#' @examples
norm_hmm_generate_sample <- function(ns, mod) {
  mvect <- 1:mod$m
  state <- numeric(ns)
  state[1] <- sample(mvect, 1, prob = mod$delta)
  for (i in 2:ns) state[i] <- sample(mvect, 1, prob = mod$gamma[state[i - 1], ])
  x <- rnorm(ns, mean = mod$mu[state], sd = mod$sigma[state])
  return(data_frame(index = c(1:ns), state = state, obs = x))
}

#' Global decoding of states
#'
#' @param x Vector of observations
#' @param mod List of maximum likelihood estimation results
#'
#' @return Dataframe of decoded states and index
#' @export
#'
#' @examples
norm_hmm_viterbi <- function(x, mod) {
  n <- length(x)
  xi <- matrix(0, n, mod$m)
  foo <- mod$delta * dnorm(x[1], mod$mu, mod$sigma)
  xi[1, ] <- foo / sum(foo)
  for (t in 2:n) {
    foo <- apply(xi[t - 1, ] * mod$gamma, 2, max) *
      dnorm(x[t], mod$mu, mod$sigma)
    xi[t, ] <- foo / sum(foo)
  }
  iv <- numeric(n)
  iv[n] <- which.max(xi[n, ])
  for (t in (n - 1):1) {
    iv[t] <- which.max(mod$gamma[, iv[t + 1]] * xi[t, ])
  }
  return(data_frame(index = 1:n, state = iv))
}

#' Get forward probabilities
#'
#' @inheritParams norm_hmm_viterbi
#'
#' @return Matrix of forward probabilities
#' @export
#'
#' @examples
norm_hmm_lforward <- function(x, mod) {
  n <- length(x)
  lalpha <- matrix(NA, mod$m, n)
  foo <- mod$delta * dnorm(x[1], mod$mu, mod$sigma)
  sumfoo <- sum(foo)
  lscale <- log(sumfoo)
  foo <- foo / sumfoo
  lalpha[, 1] <- lscale + log(foo)
  for (i in 2:n) {
    foo <- foo %*% mod$gamma * dnorm(x[i], mod$mu, mod$sigma)
    sumfoo <- sum(foo)
    lscale <- lscale + log(sumfoo)
    foo <- foo / sumfoo
    lalpha[, i] <- log(foo) + lscale
  }
  return(lalpha)
}

#' Get backward probabilities
#'
#' @inheritParams norm_hmm_viterbi
#'
#' @return Matrix of backward probabilities
#' @export
#'
#' @examples
norm_hmm_lbackward <- function(x, mod) {
  n <- length(x)
  m <- mod$m
  lbeta <- matrix(NA, m, n)
  lbeta[, n] <- rep(0, m)
  foo <- rep(1 / m, m)
  lscale <- log(m)
  for (i in (n - 1):1) {
    foo <- mod$gamma %*% (dnorm(x[i + 1], mod$mu, mod$sigma) * foo)
    lbeta[, i] <- log(foo) + lscale
    sumfoo <- sum(foo)
    foo <- foo / sumfoo
    lscale <- lscale + log(sumfoo)
  }
  return(lbeta)
}

#' Generate pseudo residuals
#'
#' @inheritParams norm_hmm_viterbi
#' @param type Type of pseudo-residual, either "ordinary" or "forecast"
#' @param stationary Boolean, whether the HMM is stationary or not
#'
#' @return Dataframe of pseudo-residuals, observations, index
#' @export
#'
#' @examples
norm_hmm_pseudo_residuals <- function(x, mod, type, stationary) {
  if (stationary) {
    delta <- solve(t(diag(mod$m) - mod$gamma + 1), rep(1, mod$m))
  }
  else {
    delta <- mod$delta
  }
  if (type == "ordinary") {
    n <- length(x)
    la <- norm_hmm_lforward(x, mod)
    lb <- norm_hmm_lbackward(x, mod)
    lafact <- apply(la, 2, max)
    lbfact <- apply(lb, 2, max)

    p <- matrix(NA, n, mod$m)
    for (i in 1:n) {
      p[i, ] <- pnorm(x[i], mean = mod$mu, sd = mod$sigma)
    }

    npsr <- rep(NA, n)
    npsr[1] <- qnorm(delta %*% p[1, ])
    for (i in 2:n) {
      a <- exp(la[, i - 1] - lafact[i])
      b <- exp(lb[, i] - lbfact[i])
      foo <- (a %*% mod$gamma) * b
      foo <- foo / sum(foo)
      npsr[i] <- qnorm(foo %*% p[i, ])
    }

    return(data_frame(npsr, x, index = c(1:n)))
  }
  else if (type == "forecast") {
    n <- length(x)
    la <- norm_hmm_lforward(x, mod)

    p <- matrix(NA, n, mod$m)
    for (i in 1:n) {
      p[i, ] <- pnorm(x[i], mean = mod$mu, sd = mod$sigma)
    }

    npsr <- rep(NA, n)
    npsr[1] <- qnorm(delta %*% p[1, ])
    for (i in 2:n) {
      la_max <- max(la[, i - 1])
      a <- exp(la[, i - 1] - la_max)
      npsr[i] <- qnorm(t(a) %*% (mod$gamma / sum(a)) %*% p[i, ])
    }

    return(data_frame(npsr, x, index = c(1:n)))
  }
}

#' Get inverse of hessian matrix
#'
#' Transform hessian associated with working parameters
#' outputted by nlm.
#' If not stationary, exclude values associated with delta parameter
#' from the hessian matrix.
#'
#'
#' @param mod List of maximum likelihood estimation results
#' @param stationary Boolean, whether the HMM is stationary or not
#'
#' @return Inverse hessian matrix
#' @export
#'
#' @examples
norm_inv_hessian <- function(mod, stationary = TRUE){
  if (!stationary) {
    np2 <- mod$np - mod$m + 1
    h <- mod$hessian[1:np2, 1:np2]
  }
  else {
    np2 <- mod$np
    h <- mod$hessian
  }
  h <- solve(h)
  jacobian <- norm_jacobian(mod, np2)
  h <- t(jacobian) %*% h %*% jacobian
  return(h)
}

#' Get Jacobian matrix
#'
#' @param mod List of maximum likelihood estimation results
#' @param n Total number of working parameters (excluding delta)
#'
#' @return Jacobian matrix, size n x n
#' @export
#'
#' @examples
norm_jacobian <- function(mod, n) {
  m <- mod$m
  jacobian <- matrix(0, nrow = n, ncol = n)
  jacobian[1:m, 1:m] <- diag(m)
  jacobian[(m + 1):(2 * m), (m + 1):(2 * m)] <- diag(mod$sigma)
  count <- 0
  for (i in 1:m) {
    for (j in 1:m) {
      if (j != i) {
        count <- count + 1
        foo <- -mod$gamma[i, j] * mod$gamma[i, ]
        foo[j] <- mod$gamma[i, j] * (1 - mod$gamma[i, j])
        foo <- foo[-i]
        jacobian[2 * m + count,
                 (2 * m + (i - 1) * (m - 1) + 1):(2 * m + i * (m - 1))] <- foo
      }
    }
  }
  return(jacobian)
}

#' Get bootstrapped estimates of parameters
#'
#' @param mod List of maximum likelihood estimation results
#' @param n Number of bootstrap samples
#' @param len Number of observations
#' @param stationary Boolean, whether the HMM is stationary or not
#'
#' @return List of estimates
#' @export
#'
#' @examples
norm_bootstrap_estimates <- function(mod, n, len, stationary) {
  m <- mod$m
  mu_estimate <- numeric(n * m)
  sigma_estimate <- numeric(n * m)
  gamma_estimate <- numeric(n * m * m)
  delta_estimate <- numeric(n * m)
  for (i in 1:n) {
    sample <- norm_hmm_generate_sample(len, mod)
    mod2 <- norm_hmm_mle(sample$obs, m, mod$mu, mod$sigma, mod$gamma,
                         mod$delta, stationary = stationary, hessian = FALSE)
    mu_estimate[((i - 1) * m + 1):(i * m)] <- mod2$mu
    sigma_estimate[((i - 1) * m + 1):(i * m)] <- mod2$sigma
    gamma_estimate[((i - 1) * m * m + 1):(i * m * m)] <- mod2$gamma
    delta_estimate[((i - 1) * m + 1):(i * m)] <- mod2$delta
  }
  return(list(mu = mu_estimate, sigma = sigma_estimate,
              gamma = gamma_estimate, delta = delta_estimate))
}

#' Estimate covariance matrix of parameters from bootstrap estimates
#'
#' @param bootstrap List of bootstrap estimates of parameters
#' @param m Number of states
#' @param n Number of bootstrap samples
#'
#' @return Estimate of covariance matrix of parameters
#' @export
#'
#' @examples
norm_bootstrap_covariance <- function(bootstrap, m, n) {
  size <- (m + 3) * m
  cov <- matrix(rep(0, size * size), size)
  foo <- rep(0, size)
  for (i in 1:n) {
    estimates <- c(bootstrap$mu[((i - 1) * m + 1):(i * m)],
                   bootstrap$sigma[((i - 1) * m + 1):(i * m)],
                   bootstrap$gamma[((i - 1) * m * m + 1):(i * m * m)],
                   bootstrap$delta[((i - 1) * m + 1):(i * m)])
    foo <- foo + estimates
  }
  foo <- foo / n
  for (i in 1:n) {
    estimates <- c(bootstrap$mu[((i - 1) * m + 1):(i * m)],
                   bootstrap$sigma[((i - 1) * m + 1):(i * m)],
                   bootstrap$gamma[((i - 1) * m * m + 1):(i * m * m)],
                   bootstrap$delta[((i - 1) * m + 1):(i * m)])
    cov <- cov + ((estimates - foo) %o% (estimates - foo))
  }
  cov <- cov / (n - 1)
  return(cov)
}

#' Confidence intervals for estimated parameters by bootstrapping
#'
#' @param mod Maximum likelihood estimates of parameters
#' @param bootstrap Bootstrapped estimates for parameters
#' @param alpha Confidence level
#' @param m Number of states
#'
#' @return List of lower and upper bounds for confidence intervals
#' for each parameter
#' @export
#'
#' @examples
norm_bootstrap_ci <- function(mod, bootstrap, alpha, m) {
  mu_lower <- rep(NA, m)
  mu_upper <- rep(NA, m)
  sigma_lower <- rep(NA, m)
  sigma_upper <- rep(NA, m)
  gamma_lower <- rep(NA, m * m)
  gamma_upper <- rep(NA, m * m)
  delta_lower <- rep(NA, m)
  delta_upper <- rep(NA, m)
  bootstrap1 <- data_frame(mu = bootstrap$mu,
                           sigma = bootstrap$sigma,
                           delta = bootstrap$delta)
  bootstrap2 <- data_frame(gamma = bootstrap$gamma)
  for (i in 1:m) {
    if (i == m) {
      foo <- bootstrap1 %>% dplyr::filter((row_number() %% m) == 0)
    }
    else {
      foo <- bootstrap1 %>% dplyr::filter((row_number() %% m) == i)
    }
    mu_lower[i] <- 2 * mod$mu[i] -
      quantile(foo$mu, 1 - (alpha / 2), names = FALSE)
    mu_upper[i] <- 2 * mod$mu[i] -
      quantile(foo$mu, alpha / 2, names = FALSE)
    sigma_lower[i] <- 2 * mod$sigma[i] -
      quantile(foo$sigma, 1 - (alpha / 2), names = FALSE)
    sigma_upper[i] <- 2 * mod$sigma[i] -
      quantile(foo$sigma, alpha / 2, names = FALSE)
    delta_lower[i] <- 2 * mod$delta[i] -
      quantile(foo$delta, 1 - (alpha / 2), names = FALSE)
    delta_upper[i] <- 2 * mod$delta[i] -
      quantile(foo$delta, alpha / 2, names = FALSE)
  }
  for (i in 1:(m * m)) {
    if (i == (m * m)) {
      foo <- bootstrap2 %>% dplyr::filter((row_number() %% (m * m)) == 0)
    }
    else {
      foo <- bootstrap2 %>% dplyr::filter((row_number() %% (m * m)) == i)
    }

    gamma_lower[i] <- 2 * mod$gamma[i] -
      quantile(foo$gamma, 1 - (alpha / 2), names = FALSE)
    gamma_upper[i] <- 2 * mod$gamma[i] -
      quantile(foo$gamma, alpha / 2, names = FALSE)
  }
  return(list(
    mu_lower = mu_lower, mu_upper = mu_upper,
    sigma_lower = sigma_lower, sigma_upper = sigma_upper,
    gamma_lower = gamma_lower, gamma_upper = gamma_upper,
    delta_lower = delta_lower, delta_upper = delta_upper
  ))
}
