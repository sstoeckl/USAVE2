# ── usave1.R ── Human Capital Calculator ──────────────────────────
# Self-contained wrapper for WebR (no package dependencies)

calculateHumanCapital <- function(annualAfterTaxSalary = 0,
                                  growthRateOfSalary = 0,
                                  valuationRate = 0,
                                  currentAge = 0,
                                  retirementAge = 0,
                                  warnings = TRUE) {
  if (length(annualAfterTaxSalary) > 1) annualAfterTaxSalary <- annualAfterTaxSalary[1]
  if (length(growthRateOfSalary) > 1) growthRateOfSalary <- growthRateOfSalary[1]
  if (length(valuationRate) > 1) valuationRate <- valuationRate[1]
  if (length(currentAge) > 1) currentAge <- currentAge[1]
  if (length(retirementAge) > 1) retirementAge <- retirementAge[1]
  if (warnings) {
    if (currentAge >= retirementAge) stop("'currentAge' must be below 'retirementAge'")
    if (retirementAge > 122) stop("'retirementAge' must be below 122")
    if (annualAfterTaxSalary < 0) stop("'annualAfterTaxSalary' must be >= 0")
  }
  sav_years <- retirementAge - currentAge
  laborincome <- annualAfterTaxSalary * (1 + growthRateOfSalary)^(seq(sav_years) - 1)
  names(laborincome) <- currentAge:(retirementAge - 1)
  disc_laborincome <- laborincome * (1 + valuationRate)^(-seq(sav_years))
  humanCapital <- sum(disc_laborincome)
  discs <- (1 + valuationRate)^(-seq(sav_years))
  disc_laborincome_m <- matrix(laborincome * discs, nrow = sav_years, ncol = sav_years, byrow = FALSE)
  disc_laborincome_m[upper.tri(disc_laborincome_m)] <- 0
  humanCapitals <- c(apply(t(apply(disc_laborincome_m, 1, function(x) x * c(1, 1/discs[-sav_years]))), 2, sum), 0)
  names(humanCapitals) <- currentAge:retirementAge
  list(laborincome = laborincome,
       disc_laborincome = disc_laborincome,
       humanCapital = humanCapital,
       humanCapitals = humanCapitals)
}

usave1 <- function(salary, growth, discount, currentAge, retirementAge) {
  hc <- calculateHumanCapital(
    annualAfterTaxSalary = salary,
    growthRateOfSalary   = growth,
    valuationRate        = discount,
    currentAge           = currentAge,
    retirementAge        = retirementAge,
    warnings             = FALSE
  )
  ages <- currentAge:(retirementAge - 1)
  list(
    ok      = TRUE,
    inputs  = list(salary = salary, growth = growth, discount = discount,
                   currentAge = currentAge, retirementAge = retirementAge),
    results = list(
      ages             = ages,
      laborincome      = as.numeric(hc$laborincome),
      disc_laborincome = as.numeric(hc$disc_laborincome),
      humanCapital     = hc$humanCapital,
      humanCapitals    = as.numeric(hc$humanCapitals),
      hcAges           = currentAge:retirementAge
    )
  )
}
