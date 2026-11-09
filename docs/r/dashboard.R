# ── dashboard.R ── Investment Dashboard ───────────────────────────
# Self-contained wrapper for WebR (base R and stats only). Reimplements the
# logic of usavepkg2::calculatePortfolioReturns(), which needs xts and
# PerformanceAnalytics. Two deliberate differences from the package:
#   * Sharpe ratios are measured against the T-Bill instead of Rf = 0.
#   * The series starts in the first selected month. Return.portfolio() drops
#     the first rebalancing period.

.dash <- new.env()

# Called once after the JSON data has been written to the WebR file system.
dashboard_load <- function(ymPath, nominalPath, realPath, n) {
  ym <- readBin(ymPath, "double", n)
  .dash$year  <- floor(ym / 100)
  .dash$month <- ym %% 100
  .dash$nominal <- matrix(readBin(nominalPath, "double", 6 * n), nrow = n, ncol = 6)
  .dash$real    <- matrix(readBin(realPath, "double", 6 * n), nrow = n, ncol = 6)
  invisible(TRUE)
}

dash_period <- function(year, month, rebalance) {
  switch(rebalance,
         months   = year * 12 + month,
         quarters = year * 4 + ceiling(month / 3),
         years    = year,
         stop("unknown rebalancing frequency"))
}

# Buy-and-hold within a period, reset to target weights when a new period
# starts. Costs are charged on turnover and subtracted from the return.
dash_portfolio <- function(R, w, period, cost) {
  n <- nrow(R)
  net <- numeric(n)
  eop <- w
  for (t in seq_len(n)) {
    newPeriod <- t == 1 || period[t] != period[t - 1]
    bop <- if (newPeriod) w else eop
    trading <- if (t > 1) sum(abs(bop - eop)) * cost else 0
    grown <- bop * (1 + R[t, ])
    total <- sum(grown)
    net[t] <- total - 1 - trading
    eop <- grown / total
  }
  net
}

dash_stats <- function(r, rf) {
  n <- length(r)
  dev <- r - mean(r)
  wealth <- cumprod(1 + r)
  excess <- r - rf
  list(
    annReturn = prod(1 + r)^(12 / n) - 1,
    annSd     = sd(r) * sqrt(12),
    sharpe    = mean(excess) / sd(excess) * sqrt(12),
    maxDD     = min(wealth / cummax(c(1, wealth))[-1] - 1, 0),
    var95     = as.numeric(quantile(r, 0.05)),
    skew      = mean(dev^3) / mean(dev^2)^1.5,
    kurt      = mean(dev^4) / mean(dev^2)^2 - 3
  )
}

# Scales each portfolio, year by year, to the risk of the custom portfolio.
dash_scale <- function(r, reference, year) {
  for (y in unique(year)) {
    i <- which(year == y)
    k <- sd(reference[i]) / sd(r[i])
    if (is.finite(k)) r[i] <- r[i] * k
  }
  pmax(r, -0.99)
}

dash_rolling <- function(r, rf, window = 60) {
  n <- length(r)
  x <- r - rf
  logSum <- c(0, cumsum(log1p(r)))
  sum1 <- c(0, cumsum(x))
  sum2 <- c(0, cumsum(x^2))
  end <- (window + 1):(n + 1)
  m <- (sum1[end] - sum1[end - window]) / window
  v <- (sum2[end] - sum2[end - window] - window * m^2) / (window - 1)
  list(
    ret    = exp((logSum[end] - logSum[end - window]) * 12 / window) - 1,
    sharpe = m / sqrt(pmax(v, 1e-16)) * sqrt(12)
  )
}

# Exact long-only mean-variance frontier: for a target return, solve the
# equality-constrained problem on every subset of assets and keep the feasible
# solution with the smallest variance.
dash_frontier <- function(R, useCash) {
  X <- R[, if (useCash) 1:5 else 1:4, drop = FALSE]
  mu <- colMeans(X) * 12
  S <- cov(X) * 12
  k <- ncol(X)
  subsets <- lapply(seq_len(2^k - 1), function(b) which(bitwAnd(b, 2^(0:(k - 1))) > 0))

  solveFor <- function(target = NULL) {
    best <- NULL
    for (s in subsets) {
      m <- length(s)
      if (!is.null(target) && m < 2) next
      if (is.null(target)) {
        A <- rbind(cbind(2 * S[s, s, drop = FALSE], 1), c(rep(1, m), 0))
        b <- c(rep(0, m), 1)
      } else {
        A <- rbind(cbind(2 * S[s, s, drop = FALSE], 1, mu[s]),
                   c(rep(1, m), 0, 0),
                   c(mu[s], 0, 0))
        b <- c(rep(0, m), 1, target)
      }
      x <- tryCatch(solve(A, b), error = function(e) NULL)
      if (is.null(x)) next
      w <- x[seq_len(m)]
      if (any(w < -1e-9)) next
      variance <- as.numeric(t(w) %*% S[s, s, drop = FALSE] %*% w)
      if (is.null(best) || variance < best$variance) {
        best <- list(variance = variance, ret = sum(w * mu[s]))
      }
    }
    best
  }

  mvp <- solveFor()
  top <- which.max(mu)
  targets <- seq(mvp$ret, mu[top], length.out = 32)[-c(1, 32)]
  points <- Filter(Negate(is.null), lapply(targets, solveFor))
  list(
    sd      = c(sqrt(mvp$variance), sapply(points, function(p) sqrt(p$variance)), sqrt(S[top, top])),
    mean    = c(mvp$ret, sapply(points, function(p) p$ret), mu[[top]]),
    assetSd   = sqrt(diag(S)),
    assetMean = as.numeric(mu)
  )
}

dashboard <- function(weights, startYear, endYear, rebalance = "months", real = FALSE,
                      cost = 0, useLarge = TRUE, useSixty = TRUE, useEqual = TRUE,
                      useCash = TRUE, riskAdjust = FALSE, frontier = FALSE) {
  keep <- .dash$year >= startYear & .dash$year <= endYear
  if (sum(keep) < 24) return(list(ok = FALSE, error = "period"))

  year  <- .dash$year[keep]
  month <- .dash$month[keep]
  data  <- if (real) .dash$real else .dash$nominal
  R  <- data[keep, 1:5, drop = FALSE]
  rf <- R[, 5]
  period <- dash_period(year, month, rebalance)

  if (!useCash) weights[5] <- 0
  if (sum(weights) <= 0) weights <- c(1, 1, 1, 1, if (useCash) 1 else 0)
  weights <- weights / sum(weights)

  equal <- if (useCash) rep(0.2, 5) else c(0.25, 0.25, 0.25, 0.25, 0)
  book <- list(custom = weights)
  if (useLarge) book$large <- c(1, 0, 0, 0, 0)
  if (useSixty) book$sixty <- c(0.6, 0, 0, 0.4, 0)
  if (useEqual) book$equal <- equal

  actual <- lapply(book, function(w) dash_portfolio(R, w, period, cost))
  shown <- actual
  if (riskAdjust) shown <- lapply(actual, dash_scale, reference = actual$custom, year = year)

  fullYears <- as.numeric(names(which(table(year) == 12)))
  annual <- lapply(shown, function(r) {
    sapply(fullYears, function(y) prod(1 + r[year == y]) - 1)
  })
  bins <- lapply(annual, function(x) floor(x * 10 + 1e-9))
  binRange <- seq(min(unlist(bins)), max(unlist(bins)))

  hasRolling <- length(rf) >= 61
  rolling <- if (hasRolling) lapply(shown, dash_rolling, rf = rf) else NULL

  list(
    ok = TRUE,
    inputs = list(weights = weights, startYear = startYear, endYear = endYear,
                  rebalance = rebalance, real = real, cost = cost),
    results = list(
      ids     = names(book),
      labels  = sprintf("%d-%02d", year, month),
      growth  = lapply(shown, function(r) 100 * cumprod(1 + r)),
      stats   = lapply(actual, dash_stats, rf = rf),
      histLo  = binRange / 10,
      hist    = lapply(bins, function(b) tabulate(match(b, binRange), length(binRange))),
      hasRolling = hasRolling,
      rollingLabels = if (hasRolling) sprintf("%d-%02d", year[60:length(year)], month[60:length(year)]) else character(0),
      rollReturn = if (hasRolling) lapply(rolling, `[[`, "ret") else list(none = 0),
      rollSharpe = if (hasRolling) lapply(rolling, `[[`, "sharpe") else list(none = 0),
      pointSd    = lapply(actual, function(r) sd(r) * sqrt(12)),
      pointMean  = lapply(actual, function(r) mean(r) * 12),
      frontier   = if (frontier) dash_frontier(R, useCash) else list(none = 0)
    )
  )
}
