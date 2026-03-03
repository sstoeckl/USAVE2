# ── usave2.R ── Optimal Life-Cycle Plan (Model 1) ─────────────────
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

model1OptimalConsumption <- function(changeOfConsumption = 0,
                                     economicNetWorth = 0,
                                     valuationRate = 0,
                                     currentAge = 0,
                                     expectedAgeOfDeath = 0) {
  economicNetWorth / ((1 - ((1 + changeOfConsumption)^(expectedAgeOfDeath - currentAge) *
    (1 + valuationRate)^(currentAge - expectedAgeOfDeath))) / (valuationRate - changeOfConsumption))
}

consumptionSmoothing <- function(minAge = 25, maxAge = 122,
                                 currentAge = 25, retirementAge = 65,
                                 expectedAgeOfDeath = 90,
                                 grossHumanCapital = 0, financialCapital = 3000,
                                 economicNetWorth = 1372536, salary = 50500,
                                 growthRateOfSalary = 0.01,
                                 consumption = 38185, changeOfConsumption = 0.01,
                                 valuationRate = 0.03) {
  if (expectedAgeOfDeath < retirementAge) return(NULL)
  ages <- currentAge:expectedAgeOfDeath
  agesToPension <- currentAge:(retirementAge - 1)
  range <- minAge:maxAge
  salaryCalc <- rep(0, maxAge)
  consumptionCalc <- rep(0, maxAge)
  savingsCalc <- rep(NA, maxAge)
  financialCapitalCalcP <- rep(NA, maxAge)
  grossHumanCapitalCalcP <- rep(NA, maxAge)
  financialCapitalCalcU <- rep(NA, maxAge)
  economicNetWorthU <- rep(NA, maxAge)
  economicNetWorthP <- rep(NA, maxAge)
  salaryCalc[agesToPension] <- salary * cumprod(c(1, rep((1 + growthRateOfSalary), length(agesToPension) - 1)))
  consumptionCalc[ages] <- consumption * c(1, cumprod(rep((1 + changeOfConsumption), length(ages) - 1)))
  savingsCalc <- salaryCalc - consumptionCalc
  salaryCalc[salaryCalc == 0] <- NA
  consumptionCalc[consumptionCalc == 0] <- NA
  savingsCalc[savingsCalc == 0] <- NA
  if (length(ages) > 1) {
    for (t in ages) {
      if (t == ages[1]) {
        financialCapitalCalcP[t] <- financialCapital
      } else {
        financialCapitalCalcP[t] <- financialCapitalCalcU[t - 1]
      }
      if (t < retirementAge) {
        grossHumanCapitalCalcP[t] <- calculateHumanCapital(
          annualAfterTaxSalary = salaryCalc[t],
          growthRateOfSalary = growthRateOfSalary,
          valuationRate = valuationRate,
          currentAge = t,
          retirementAge = retirementAge
        )$humanCapital
      }
      financialCapitalCalcU[t] <- financialCapitalCalcP[t] * (1 + valuationRate) + savingsCalc[t]
      economicNetWorthU[t] <- consumptionCalc[t] * ((1 - (1 + valuationRate)^(t + 1 - expectedAgeOfDeath)) / valuationRate)
      if (t == tail(ages, 1)) {
        financialCapitalCalcU[t] <- NA
        economicNetWorthU[t] <- NA
      }
    }
  }
  grossHumanCapitalCalcU <- c(grossHumanCapitalCalcP[-1], 0)
  economicNetWorthP[ages] <- c(economicNetWorth, head(economicNetWorthU[ages], -1))
  list(
    ages = range,
    salaryCalc = salaryCalc[range],
    consumptionCalc = consumptionCalc[range],
    savingsCalc = savingsCalc[range],
    financialCapitalCalcP = financialCapitalCalcP[range],
    financialCapitalCalcU = financialCapitalCalcU[range],
    grossHumanCapitalCalcP = grossHumanCapitalCalcP[range],
    grossHumanCapitalCalcU = grossHumanCapitalCalcU[range],
    economicNetWorthP = economicNetWorthP[range],
    economicNetWorthU = economicNetWorthU[range]
  )
}

usave2 <- function(currentAge, retirementAge, deathAge, salary, salaryGrowth,
                   discountRate, consumptionGrowth, financialCapital) {
  hc <- calculateHumanCapital(
    annualAfterTaxSalary = salary,
    growthRateOfSalary = salaryGrowth,
    valuationRate = discountRate,
    currentAge = currentAge,
    retirementAge = retirementAge,
    warnings = FALSE
  )
  enw <- hc$humanCapital + financialCapital
  optC <- model1OptimalConsumption(
    changeOfConsumption = consumptionGrowth,
    economicNetWorth = enw,
    valuationRate = discountRate,
    currentAge = currentAge,
    expectedAgeOfDeath = deathAge
  )
  plan <- consumptionSmoothing(
    minAge = currentAge, maxAge = deathAge,
    currentAge = currentAge, retirementAge = retirementAge,
    expectedAgeOfDeath = deathAge,
    grossHumanCapital = hc$humanCapital,
    financialCapital = financialCapital,
    economicNetWorth = enw,
    salary = salary, growthRateOfSalary = salaryGrowth,
    consumption = optC, changeOfConsumption = consumptionGrowth,
    valuationRate = discountRate
  )
  na2null <- function(x) { x[is.na(x)] <- 0; x }
  list(
    ok      = TRUE,
    inputs  = list(currentAge = currentAge, retirementAge = retirementAge,
                   deathAge = deathAge, salary = salary, salaryGrowth = salaryGrowth,
                   discountRate = discountRate, consumptionGrowth = consumptionGrowth,
                   financialCapital = financialCapital),
    results = list(
      ages               = plan$ages,
      salaryCalc         = na2null(plan$salaryCalc),
      consumptionCalc    = na2null(plan$consumptionCalc),
      savingsCalc        = na2null(plan$savingsCalc),
      financialCapitalP  = na2null(plan$financialCapitalCalcP),
      humanCapitalP      = na2null(plan$grossHumanCapitalCalcP),
      economicNetWorthP  = na2null(plan$economicNetWorthP),
      optimalConsumption = optC,
      humanCapital       = hc$humanCapital,
      economicNetWorth   = enw
    )
  )
}
