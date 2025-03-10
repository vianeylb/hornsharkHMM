#' Get mean corresponding to a given index in a multivariate autoregressive series
#'
#' @param mu List of vectors of length m, means for white noise in each
#' state dependent distribution
#' @param phi List of k x (k x q) matrices, containing the autoregressive
#' parameters. Each matrix corresponds to a state. The first k x k entries
#' are the parameters for index i - 1, and so on up to index i - q.
#' @param x Observations coming from a multivariate autoregressive series,
#' in a matrix with k rows. Each row corresponds to a variable.
#' @param m Number of states
#' @param q Order of the autoregressive model
#' @param k Number of variables
#' @param i Index of the desired mean
#'
#' @return List of vectors of length m containing means corresponding to index i
#' for the given autoregressive model
#' @export
#'
#' @examples
get_mar_mean <- function(mu, phi, x, m, q, k, i) {
  if (i == 1) {
    mean <- mu
  }
  else {
    mean <- list()
    if (i <= q) {
      x_lag <- as.vector(x[, (i - 1):1])
      for (j in 1:m) {
        mean[[j]] <- mu[[j]] + phi[[j]][, 1:((i - 1) * k)] %*% x_lag
      }
    }
    else {
      x_lag <- as.vector(x[, (i - 1):(i - q)])
      for (j in 1:m) {
        mean[[j]] <- mu[[j]] + phi[[j]] %*% x_lag
      }
    }
  }
  return(mean)
}

#' Get all means for multivariate autoregressive series
#'
#' @param mod List of HMM parameters
#' @inheritParams get_mar_mean
#'
#' @return List of autoregressive means corresponding to
#' each state. Means are in a n x k matrix, where
#' n is the number of observations.
#' @export
#'
#' @examples
get_all_mar_means <- function(x, mod, m, q, k) {
  n <- ncol(x)
  x_lags <- matrix(0, nrow = n, ncol = k * q)
  for (i in 1:q){
    x_lags[-c(1:i), ((i - 1) * k  + 1):(k * i)] <- t(x[, -c((n - i + 1):n)])
  }

  means <- list()
  for(i in 1:m){
    mu_matrix <- matrix(mod$mu[[i]], nrow = n, ncol = k, byrow = TRUE)
    means[[i]] <- mu_matrix + x_lags %*% t(mod$phi[[i]])
  }

  return(means)
}

#'Generate samples from HMM with multivariate autoregressive model
#'
#' @param ns Number of samples
#' @param mod List of model parameters
#'
#' @return List including vector of indices, vector of states,
#' and k x ns matrix containing generated samples
#' (where k is the number of variables)
#' @export
#'
#' @examples
mar_hmm_generate_sample <- function(ns, mod) {
  mvect <- 1:mod$m
  state <- numeric(ns)
  state[1] <- sample(mvect, 1, prob = mod$delta)
  if (ns > 1) {
    for (i in 2:ns) {
      state[i] <- sample(mvect, 1, prob = mod$gamma[state[i - 1], ])
    }
  }
  x <- matrix(nrow = mod$k, ncol = ns)
  for (i in 1:ns) {
    mean <- get_mar_mean(mod$mu, mod$phi, x, mod$m, mod$q, mod$k, i)
    x[, i] <- rmvnorm(1, mean = mean[[state[i]]], sigma = mod$sigma[[state[i]]])
  }
  return(list(index = c(1:ns), state = state, obs = x))
}

#' Transform multivariate autoregressive natural parameters to working parameters
#'
#' mu and phi do not need to be transformed, as there are no constraints.
#' We only need to transform diagonal elements of sigma, since there
#' are no constraints on the covariances.
#' Include only the lower triangular and diagional elements
#' of the sigma matrix, since covariance matrices must be symmetric.
#'
#' @param sigma List of matrices of size m x m, covariance matrices
#' for each state dependent distribution
#' @param gamma Transition probabiilty matrix, size m x m
#' @param delta Optional, vector of length m containing
#' initial distribution
#' @param stationary Boolean, whether the HMM is stationary or not
#' @inheritParams get_mar_mean
#'
#' @return Vector of working parameters
#' @export
#'
#' @examples
mar_hmm_pn2pw <- function(m, mu, sigma, gamma, phi,
                          delta = NULL, stationary = TRUE) {
  mu <- unlist(mu, use.names = FALSE)
  tsigma <- lapply(sigma, diag_log_lower)
  tsigma <- unlist(tsigma, use.names = FALSE)
  foo <- log(gamma / diag(gamma))
  tgamma <- as.vector(foo[!diag(m)])
  tphi <- unlist(phi, use.names = FALSE)
  if (stationary) {
    tdelta <- NULL
  }
  else {
    tdelta <- log(delta[-1] / delta[1])
  }
  parvect <- c(mu, tsigma, tgamma, tphi, tdelta)
  return(parvect)
}

#' Transform multivariate autoregressive working parameters to natural parameters
#'
#' @inheritParams mar_hmm_pn2pw
#' @param parvect Vector of working parameters
#'
#' @return List of natural parameters
#' @export
#'
#' @examples
mar_hmm_pw2pn <- function(m, q, k, parvect, stationary = TRUE) {
  mu <- list()
  count <- 1
  for (i in 1:m) {
    mu[[i]] <- parvect[count:(i * k)]
    count <- count + k
  }

  tsigma <- list()
  t <- triangular_num(k)
  for (i in 1:m) {
    tsigma_vals <- parvect[count:(count + t - 1)]
    foo <- diag(k)
    foo[lower.tri(foo, diag = TRUE)] <- tsigma_vals
    foo <- t(foo)
    foo[lower.tri(foo, diag = TRUE)] <- tsigma_vals
    tsigma[[i]] <- foo
    count <- count + t
  }
  sigma <- lapply(tsigma, diag_exp)

  tgamma <- parvect[count:(count + m * (m - 1) - 1)]
  count <- count + m * (m - 1)
  gamma <- diag(m)
  gamma[!gamma] <- exp(tgamma)
  gamma <- gamma / apply(gamma, 1, sum)

  tphi <- parvect[(count:(count + k * k * q * m))]
  count <- count + k * k * q * m
  phi <- list()
  for (i in 1:m) {
    foo <- tphi[((i - 1) * k * k * q + 1):(i * k * k * q)]
    phi[[i]] <- matrix(foo, nrow = k)
  }

  if (stationary) {
    delta <- solve(t(diag(m) - gamma + 1), rep(1, m))
  }
  else {
    tdelta <- parvect[count:(count + m - 2)]
    foo <- c(1, exp(tdelta))
    delta <- foo / sum(foo)
  }
  return(list(mu = mu, sigma = sigma, gamma = gamma, phi = phi, delta = delta))
}

#' Get negative log-likelihood from the working parameters
#'
#' @param x Matrix of observations, rows represent each variable
#' @inheritParams mar_hmm_pw2pn
#'
#' @return Negative log-likelihood
#' @export
#'
#' @examples
mar_hmm_mllk <- function(parvect, x, m, q, k, stationary = TRUE) {
  n <- ncol(x)
  pn <- mar_hmm_pw2pn(m, q, k, parvect, stationary = stationary)
  p <- mar_densities(x, pn, m, q, k, n)
  foo <- matrix(pn$delta, ncol = m)
  lscale <- foralg(n, m, foo, pn$gamma, p)
  mllk <- -lscale
  return(mllk)
}


#' Get matrix of state dependent probability densities
#'
#' @inheritParams mar_hmm_mllk
#' @param mod List of parameters
#' @param n Number of observations
#'
#' @return n x m matrix of state dependent probability densities
#' @export
#'
#' @examples
mar_densities <- function(x, mod, m, q, k, n) {
  p <- matrix(nrow = n, ncol = m)
  cores <- detectCores()
  means <- get_all_mar_means(x, mod, m, q, k)
  for (i in 1:n) {
    for (j in 1:m) {
      p[i, j] <- dmvnrm_arma_mc(matrix(x[, i], ncol = k),
                                means[[j]][i, ],
                                mod$sigma[[j]],
                                cores = cores)
    }
  }
  return(p)
}

#' Maximum likelihood estimation of multivariate normal parameters
#'
#' @inheritParams mar_hmm_mllk
#' @param mu0 List of vectors of length m, initial values for means for
#' white noise
#' @param sigma0 List of matrices of size m x m,
#' initial values for covariance matrices
#' @param gamma0 Initial values for ransition probabiilty matrix, size m x m
#' @param phi0 List of matrices of size k x (k x q), initial values for
#' autoregressive parameters
#' @param delta0 Optional, vector of length m containing initial values
#' initial distribution
#' @param hessian Boolean, whether to return the inverse hessian
#'
#' @return List of results
#' @export
#'
#' @examples
mar_hmm_mle <- function(x, m, q, k, mu0, sigma0, gamma0, phi0, delta0 = NULL,
                        stationary = TRUE, hessian = FALSE) {
  parvect0 <- mar_hmm_pn2pw(m, mu0, sigma0, gamma0, phi0, delta0,
                            stationary = stationary
  )
  mod <- nlm(mar_hmm_mllk, parvect0,
             x = x, m = m, q = q, k = k,
             stationary = stationary, hessian = hessian, steptol = 0.00001
  )
  pn <- mar_hmm_pw2pn(
    m = m, q = q, k = k, parvect = mod$estimate,
    stationary = stationary
  )
  mllk <- mod$minimum

  np <- length(parvect0)
  aic <- 2 * (mllk + np)
  n <- sum(!is.na(x))
  bic <- 2 * mllk + np * log(n)

  if (hessian) {
    return(list(
      m = m, q = q, k = k, mu = pn$mu, sigma = pn$sigma,
      gamma = pn$gamma, phi = pn$phi, delta = pn$delta,
      code = mod$code, mllk = mllk,
      aic = aic, bic = bic, hessian = mod$hessian, np = np
    ))
  }
  else {
    return(list(
      m = m, q = q, k = k, mu = pn$mu, sigma = pn$sigma,
      gamma = pn$gamma, phi = pn$phi, delta = pn$delta,
      code = mod$code, mllk = mllk, aic = aic, bic = bic
    ))
  }
}

#' Global decoding of states
#'
#' @param x Matrix of observations, rows represent each variable
#' @param mod List of maximum likelihood estimation results
#'
#' @return Dataframe of decoded states and index
#' @export
#'
#' @examples
mar_hmm_viterbi <- function(x, mod) {
  n <- ncol(x)
  xi <- matrix(0, n, mod$m)
  p <- mar_densities(x, mod, mod$m, mod$q, mod$k, n)
  foo <- mod$delta * p[1, ]
  xi[1, ] <- foo / sum(foo)
  for (t in 2:n) {
    foo <- apply(xi[t - 1, ] * mod$gamma, 2, max) * p[t, ]
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
#' @inheritParams mar_hmm_viterbi
#'
#' @return Matrix of forward probabilities
#' @export
#'
#' @examples
mar_hmm_lforward <- function(x, mod) {
  n <- ncol(x)
  lalpha <- matrix(NA, mod$m, n)
  p <- mar_densities(x, mod, mod$m, mod$q, mod$k, n)
  foo <- mod$delta * p[1, ]
  sumfoo <- sum(foo)
  lscale <- log(sumfoo)
  foo <- foo / sumfoo
  lalpha[, 1] <- lscale + log(foo)
  for (i in 2:n) {
    foo <- foo %*% mod$gamma * p[i, ]
    sumfoo <- sum(foo)
    lscale <- lscale + log(sumfoo)
    foo <- foo / sumfoo
    lalpha[, i] <- log(foo) + lscale
  }
  return(lalpha)
}

#' Get backward probabilities
#'
#' @inheritParams mar_hmm_viterbi
#'
#' @return Matrix of backward probabilities
#' @export
#'
#' @examples
mar_hmm_lbackward <- function(x, mod) {
  n <- ncol(x)
  m <- mod$m
  p <- mar_densities(x, mod, mod$m, mod$q, mod$k, n)
  lbeta <- matrix(NA, m, n)
  lbeta[, n] <- rep(0, m)
  foo <- rep(1 / m, m)
  lscale <- log(m)
  for (i in (n - 1):1) {
    foo <- mod$gamma %*% (p[i + 1, ] * foo)
    lbeta[, i] <- log(foo) + lscale
    sumfoo <- sum(foo)
    foo <- foo / sumfoo
    lscale <- lscale + log(sumfoo)
  }
  return(lbeta)
}

#' Generate pseudo residuals
#'
#' @inheritParams mar_hmm_viterbi
#' @param type Type of pseudo-residual, either "ordinary" or "forecast"
#' @param stationary Boolean, whether the HMM is stationary or not
#'
#' @return Dataframe of pseudo-residuals, observations, index
#' @export
#'
#' @examples
mar_hmm_pseudo_residuals <- function(x, mod, type, stationary) {
  if (stationary) {
    delta <- solve(t(diag(mod$m) - mod$gamma + 1), rep(1, mod$m))
  }
  else {
    delta <- mod$delta
  }
  if (type == "ordinary") {
    n <- ncol(x)
    la <- mar_hmm_lforward(x, mod)
    lb <- mar_hmm_lbackward(x, mod)
    lafact <- apply(la, 2, max)
    lbfact <- apply(lb, 2, max)
    p <- mar_dist_mat(x, mod, n)
    npsr <- rep(NA, n)
    npsr[1] <- qnorm(delta %*% p[1, ])
    for (i in 2:n) {
      a <- exp(la[, i - 1] - lafact[i])
      b <- exp(lb[, i] - lbfact[i])
      foo <- (a %*% mod$gamma) * b
      foo <- foo / sum(foo)
      npsr[i] <- qnorm(foo %*% p[i, ])
    }
    return(data_frame(npsr, index = c(1:n)))
  }
  else if (type == "forecast") {
    n <- ncol(x)
    la <- mar_hmm_lforward(x, mod)
    p <- mar_dist_mat(x, mod, n)
    npsr <- rep(NA, n)
    npsr[1] <- qnorm(delta %*% p[1, ])
    for (i in 2:n) {
      la_max <- max(la[, i - 1])
      a <- exp(la[, i - 1] - la_max)
      npsr[i] <- qnorm(t(a) %*% (mod$gamma / sum(a)) %*% p[i, ])
    }
    return(data_frame(npsr, index = c(1:n)))
  }
}

#' Get multivariate autoregressive distribution function
#'
#' @inheritParams mar_hmm_viterbi
#' @param n Number of observations
#'
#' @return Matrix of multivariate autoregressive probabilities
#' @export
#'
#' @examples
mar_dist_mat <- function(x, mod, n) {
  p <- matrix(NA, n, mod$m)
  means <- get_all_mar_means(x, mod, mod$m, mod$q, mod$k)
  for (i in 1:n) {
    for (j in 1:mod$m) {
      p[i, j] <- pmvnorm(
        lower = rep(-Inf, mod$k),
        upper = x[, i],
        mean = as.vector(means[[j]][i, ]),
        sigma = mod$sigma[[j]]
      )
    }
  }
  return(p)
}

#' Get inverse of hessian matrix
#'
#' Transform hessian associated with working parameters
#' outputted by nlm.
#' If not stationary, exclude values associated with delta parameter
#' from the hessian matrix.
#'
#' @param mod List of maximum likelihood estimation results
#' @param stationary Boolean, whether the HMM is stationary or not
#'
#' @return Inverse hessian matrix
#' @export
#'
#' @examples
mar_inv_hessian <- function(mod, stationary = TRUE){
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
#' @return Jacobian matrix
#' @export
#'
#' @examples
mar_jacobian <- function(mod, n) {
  m <- mod$m
  q <- mod$q
  k <- mod$k

  jacobian <- matrix(0, nrow = n, ncol = n)
  jacobian[1:(m * k), 1:(m * k)] <- diag(m * k)

  rowcount <- m * k + 1
  t <- triangular_num(k)
  for (i in 1:m) {
    sigma <- mod$sigma[[i]]
    sigma[lower.tri(sigma, diag = FALSE)] <-
      rep(1, length(sigma[lower.tri(sigma, diag = FALSE)]))
    sigma <- sigma[lower.tri(sigma, diag = TRUE)]
    jacobian[
      rowcount:(rowcount + t - 1),
      rowcount:(rowcount + t - 1)
      ] <- diag(sigma)
    rowcount <- rowcount + t
  }

  colcount <- rowcount
  for (i in 1:m) {
    for (j in 1:m) {
      if (j != i) {
        foo <- -mod$gamma[i, j] * mod$gamma[i, ]
        foo[j] <- mod$gamma[i, j] * (1 - mod$gamma[i, j])
        foo <- foo[-i]
        jacobian[rowcount, colcount:(colcount + m - 2)] <- foo
        rowcount <- rowcount + 1
      }
    }
    colcount <- colcount + m - 1
  }

  phi <- unlist(mod$phi, use.names = FALSE)
  jacobian[rowcount:n, colcount:n] <- diag(phi)

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
mar_bootstrap_estimates <- function(mod, n, len, stationary) {
  m <- mod$m
  k <- mod$k
  q <- mod$q
  mu_estimate <- numeric(n * m * k)
  sigma_estimate <- numeric(n * m * k * k)
  gamma_estimate <- numeric(n * m * m)
  phi_estimate <- numeric(n * m * k * k * q)
  delta_estimate <- numeric(n * m)
  for (i in 1:n) {
    sample <- mar_hmm_generate_sample(len, mod)
    mod2 <- mar_hmm_mle(sample$obs, m, q, k, mod$mu, mod$sigma,
                        mod$gamma, mod$phi, mod$delta,
                        stationary = stationary
    )
    mu_estimate[((i - 1) * m * k + 1):(i * m * k)] <-
      unlist(mod2$mu, use.names = FALSE)
    sigma_estimate[((i - 1) * m * k * k + 1):(i * m * k * k)] <-
      unlist(mod2$sigma, use.names = FALSE)
    gamma_estimate[((i - 1) * m * m + 1):(i * m * m)] <- mod2$gamma
    phi_estimate[((i - 1) * m * k * k * q + 1):(i * m * k * k * q)] <-
      unlist(mod2$phi, use.names = FALSE)
    delta_estimate[((i - 1) * m + 1):(i * m)] <- mod2$delta
  }
  return(list(
    mu = mu_estimate,
    sigma = sigma_estimate,
    gamma = gamma_estimate,
    phi = phi_estimate,
    delta = delta_estimate
  ))
}

#' Confidence intervals for estimated parameters by bootstrapping
#'
#' @param mod Maximum likelihood estimates of parameters
#' @param bootstrap Bootstrapped estimates for parameters
#' @param alpha Confidence level
#'
#' @return List of lower and upper bounds for confidence intervals
#' for each parameter
#' @export
#'
#' @examples
mar_bootstrap_ci <- function(mod, bootstrap, alpha) {
  m <- mod$m
  k <- mod$k

  mu_lower <- matrix(NA, m, k)
  mu_upper <- matrix(NA, m, k)
  bootstrap_mu <- data_frame(mu = bootstrap$mu)
  mu <- unlist(mod$mu, use.names = FALSE)
  for (i in 1:m) {
    for (j in 1:k) {
      if (i == m & j == k) {
        foo <- bootstrap_mu %>%
          filter((row_number() %% (m * k)) == 0)
      }
      else {
        foo <- bootstrap_mu %>%
          filter((row_number() %% (m * k)) == (i - 1) * k + j)
      }
      mu_lower[i, j] <- 2 * mu[(i - 1) * k + j] -
        quantile(foo$mu, 1 - (alpha / 2), names = FALSE)
      mu_upper[i, j] <- 2 * mu[(i - 1) * k + j] -
        quantile(foo$mu, alpha / 2, names = FALSE)
    }
  }

  t <- triangular_num(k)
  mat <- matrix(c(1:(k * k)), k)
  tvect <- mat[lower.tri(mat, diag = TRUE)]
  sigma_lower <- matrix(NA, 3, t)
  sigma_upper <- matrix(NA, 3, t)
  bootstrap_sigma <- data_frame(sigma = bootstrap$sigma)
  sigma <- unlist(mod$sigma, use.names = FALSE)
  for (i in 1:m) {
    for (j in 1:t) {
      tj <- tvect[j]
      if (i == m & j == t) {
        foo <- bootstrap_sigma %>%
          filter((row_number() %% (m * k * k)) == 0)
      }
      else {
        foo <- bootstrap_sigma %>%
          filter((row_number() %% (m * k * k)) == (i - 1) * k * k + tj)
      }
      sigma_lower[i, j] <- 2 * sigma[(i - 1) * k * k + tj] -
        quantile(foo$sigma, 1 - (alpha / 2), names = FALSE)
      sigma_upper[i, j] <- 2 * sigma[(i - 1) * k * k + tj] -
        quantile(foo$sigma, alpha / 2, names = FALSE)
    }
  }

  gamma_lower <- rep(NA, m * m)
  gamma_upper <- rep(NA, m * m)
  bootstrap_gamma <- data_frame(gamma = bootstrap$gamma)
  gamma <- mod$gamma
  for (i in 1:(m * m)) {
    if (i == (m * m)) {
      foo <- bootstrap_gamma %>%
        filter((row_number() %% (m * m)) == 0)
    }
    else {
      foo <- bootstrap_gamma %>%
        filter((row_number() %% (m * m)) == i)
    }
    gamma_lower[i] <- 2 * gamma[i] -
      quantile(foo$gamma, 1 - (alpha / 2), names = FALSE)
    gamma_upper[i] <- 2 * gamma[i] -
      quantile(foo$gamma, alpha / 2, names = FALSE)
  }

  phi_lower <- matrix(NA, nrow = m * k, ncol = k * q)
  phi_upper <- matrix(NA, nrow = m * k, ncol = k * q)
  bootstrap_phi <- data_frame(phi = bootstrap$phi)
  phi <- unlist(mod$phi, use.names = FALSE)
  for (i in 1:(m * k * k * q)) {
    if (i == (m * k * k * q)) {
      foo <- bootstrap_phi %>%
        filter((row_number() %% (m * k * k * q)) == 0)
    }
    else {
      foo <- bootstrap_phi %>%
        filter((row_number() %% (m * k * k * q)) == i)
    }
    phi_lower[i] <- 2 * phi[i] -
      quantile(foo$phi, 1 - (alpha / 2), names = FALSE)
    phi_upper[i] <- 2 * phi[i] -
      quantile(foo$phi, alpha / 2, names = FALSE)
  }

  delta_lower <- rep(NA, m)
  delta_upper <- rep(NA, m)
  bootstrap_delta <- data_frame(delta = bootstrap$delta)
  delta <- mod$delta
  for (i in 1:m) {
    if (i == m) {
      foo <- bootstrap_delta %>% filter((row_number() %% m) == 0)
    }
    else {
      foo <- bootstrap_delta %>% filter((row_number() %% m) == i)
    }
    delta_lower[i] <- 2 * delta[i] -
      quantile(foo$delta, 1 - (alpha / 2), names = FALSE)
    delta_upper[i] <- 2 * delta[i] -
      quantile(foo$delta, alpha / 2, names = FALSE)
  }

  return(list(
    mu_lower = mu_lower, mu_upper = mu_upper,
    sigma_lower = sigma_lower, sigma_upper = sigma_upper,
    gamma_lower = gamma_lower, gamma_upper = gamma_upper,
    phi_lower = phi_lower, phi_upper = phi_upper,
    delta_lower = delta_lower, delta_upper = delta_upper
  ))
}
