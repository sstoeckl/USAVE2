# ── usave3.R ── Disability Insurance ──────────────────────────────
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
  list(laborincome = laborincome, disc_laborincome = disc_laborincome,
       humanCapital = humanCapital, humanCapitals = humanCapitals)
}

model1OptimalConsumption <- function(changeOfConsumption = 0,
                                     economicNetWorth = 0,
                                     valuationRate = 0,
                                     currentAge = 0,
                                     expectedAgeOfDeath = 0) {
  economicNetWorth / ((1 - ((1 + changeOfConsumption)^(expectedAgeOfDeath - currentAge) *
    (1 + valuationRate)^(currentAge - expectedAgeOfDeath))) / (valuationRate - changeOfConsumption))
}

consumptionSmoothingDisability <- function(minAge = 25, maxAge = 90,
    currentAge = 25, retirementAge = 65, expectedAgeOfDeath = 90,
    grossHumanCapital = 0, financialCapital = 3000, economicNetWorth = 1372536,
    salary = 50500, growthRateOfSalary = 0.01, consumption = 38185,
    changeOfConsumption = 0.01, valuationRate = 0.03,
    disabilityAge = 50, disabilityCoverageOfSalary = 0.8, insuranceFee = 0.01) {
  if (expectedAgeOfDeath < retirementAge) return(NULL)
  ages <- currentAge:expectedAgeOfDeath
  agesToDisability <- currentAge:(disabilityAge - 1)
  agesAtDisability <- disabilityAge:(retirementAge - 1)
  agesToPension <- currentAge:(retirementAge - 1)
  range <- minAge:maxAge
  salaryCalc <- rep(0, maxAge)
  salaryCalcNoCoverage <- rep(0, maxAge)
  consumptionCalc <- rep(0, maxAge)
  savingsCalc <- rep(NA, maxAge)
  savingsCalcNoCoverage <- rep(NA, maxAge)
  financialCapitalCalcP <- rep(NA, maxAge)
  financialCapitalCalcPNoCoverage <- rep(NA, maxAge)
  grossHumanCapitalCalcP <- rep(NA, maxAge)
  grossHumanCapitalCalcPNoCoverage <- rep(NA, maxAge)
  financialCapitalCalcU <- rep(NA, maxAge)
  financialCapitalCalcUNoCoverage <- rep(NA, maxAge)
  economicNetWorthU <- rep(NA, maxAge)
  economicNetWorthP <- rep(NA, maxAge)
  consumptionCalc[ages] <- consumption * c(1, cumprod(rep((1 + changeOfConsumption), length(ages) - 1)))
  salaryCalc[agesToPension] <- salary * cumprod(c(1, rep((1 + growthRateOfSalary), length(agesToPension) - 1)))
  salaryCalc[agesToDisability] <- salaryCalc[agesToDisability] * (1 - insuranceFee)
  salaryCalc[agesAtDisability] <- salaryCalc[agesAtDisability] * disabilityCoverageOfSalary
  savingsCalc <- salaryCalc - consumptionCalc
  salaryCalc[salaryCalc == 0] <- NA
  savingsCalc[savingsCalc == 0] <- NA
  salaryCalcNoCoverage[agesToDisability] <- salary * cumprod(c(1, rep((1 + growthRateOfSalary), length(agesToDisability) - 1)))
  savingsCalcNoCoverage <- salaryCalcNoCoverage - consumptionCalc
  salaryCalcNoCoverage[salaryCalcNoCoverage == 0] <- NA
  savingsCalcNoCoverage[savingsCalcNoCoverage == 0] <- NA
  consumptionCalc[consumptionCalc == 0] <- NA
  if (length(ages) > 1) {
    for (t in ages) {
      if (t == ages[1]) { financialCapitalCalcP[t] <- financialCapital
      } else { financialCapitalCalcP[t] <- financialCapitalCalcU[t - 1] }
      if (t < retirementAge) {
        grossHumanCapitalCalcP[t] <- calculateHumanCapital(
          annualAfterTaxSalary = salaryCalc[t], growthRateOfSalary = growthRateOfSalary,
          valuationRate = valuationRate, currentAge = t, retirementAge = retirementAge
        )$humanCapital
      }
      financialCapitalCalcU[t] <- financialCapitalCalcP[t] * (1 + valuationRate) + savingsCalc[t]
      economicNetWorthU[t] <- consumptionCalc[t] * ((1 - (1 + valuationRate)^(t + 1 - expectedAgeOfDeath)) / valuationRate)
      if (t == tail(ages, 1)) { financialCapitalCalcU[t] <- NA; economicNetWorthU[t] <- NA }
    }
  }
  if (length(ages) > 1) {
    for (t in ages) {
      if (t == ages[1]) { financialCapitalCalcPNoCoverage[t] <- financialCapital
      } else { financialCapitalCalcPNoCoverage[t] <- financialCapitalCalcUNoCoverage[t - 1] }
      if (t < disabilityAge) {
        grossHumanCapitalCalcPNoCoverage[t] <- calculateHumanCapital(
          annualAfterTaxSalary = salaryCalcNoCoverage[t], growthRateOfSalary = growthRateOfSalary,
          valuationRate = valuationRate, currentAge = t, retirementAge = retirementAge
        )$humanCapital
      }
      financialCapitalCalcUNoCoverage[t] <- financialCapitalCalcPNoCoverage[t] * (1 + valuationRate) + savingsCalcNoCoverage[t]
      if (t == tail(ages, 1)) { financialCapitalCalcUNoCoverage[t] <- NA }
    }
  }
  grossHumanCapitalCalcU <- c(grossHumanCapitalCalcP[-1], 0)
  grossHumanCapitalCalcUNoCoverage <- c(grossHumanCapitalCalcPNoCoverage[-1], 0)
  economicNetWorthP[ages] <- c(economicNetWorth, head(economicNetWorthU[ages], -1))
  na2null <- function(x) { x[is.na(x)] <- 0; x }
  list(
    ages = range,
    salaryCalc = na2null(salaryCalc[range]),
    salaryCalcNoCoverage = na2null(salaryCalcNoCoverage[range]),
    consumptionCalc = na2null(consumptionCalc[range]),
    savingsCalc = na2null(savingsCalc[range]),
    savingsCalcNoCoverage = na2null(savingsCalcNoCoverage[range]),
    financialCapitalCalcP = na2null(financialCapitalCalcP[range]),
    financialCapitalCalcPNoCoverage = na2null(financialCapitalCalcPNoCoverage[range]),
    grossHumanCapitalCalcP = na2null(grossHumanCapitalCalcP[range]),
    grossHumanCapitalCalcPNoCoverage = na2null(grossHumanCapitalCalcPNoCoverage[range]),
    economicNetWorthP = na2null(economicNetWorthP[range])
  )
}

usave3 <- function(currentAge, retirementAge, deathAge, salary, salaryGrowth,
                   discountRate, consumptionGrowth, financialCapital,
                   disabilityAge, coverage, insuranceFee) {
  hc <- calculateHumanCapital(
    annualAfterTaxSalary = salary, growthRateOfSalary = salaryGrowth,
    valuationRate = discountRate, currentAge = currentAge,
    retirementAge = retirementAge, warnings = FALSE
  )
  enw <- hc$humanCapital + financialCapital
  optC <- model1OptimalConsumption(
    changeOfConsumption = consumptionGrowth, economicNetWorth = enw,
    valuationRate = discountRate, currentAge = currentAge,
    expectedAgeOfDeath = deathAge
  )
  plan <- consumptionSmoothingDisability(
    minAge = currentAge, maxAge = deathAge,
    currentAge = currentAge, retirementAge = retirementAge,
    expectedAgeOfDeath = deathAge,
    grossHumanCapital = hc$humanCapital, financialCapital = financialCapital,
    economicNetWorth = enw, salary = salary, growthRateOfSalary = salaryGrowth,
    consumption = optC, changeOfConsumption = consumptionGrowth,
    valuationRate = discountRate,
    disabilityAge = disabilityAge,
    disabilityCoverageOfSalary = coverage,
    insuranceFee = insuranceFee
  )
  list(
    ok      = TRUE,
    inputs  = list(currentAge = currentAge, retirementAge = retirementAge,
                   deathAge = deathAge, disabilityAge = disabilityAge),
    results = list(
      ages                     = plan$ages,
      salaryCalc               = plan$salaryCalc,
      salaryCalcNoCoverage     = plan$salaryCalcNoCoverage,
      consumptionCalc          = plan$consumptionCalc,
      financialCapitalP        = plan$financialCapitalCalcP,
      financialCapitalPNoCov   = plan$financialCapitalCalcPNoCoverage,
      humanCapitalP            = plan$grossHumanCapitalCalcP,
      humanCapitalPNoCov       = plan$grossHumanCapitalCalcPNoCoverage,
      economicNetWorthP        = plan$economicNetWorthP,
      optimalConsumption       = optC,
      humanCapital             = hc$humanCapital,
      economicNetWorth         = enw
    )
  )
}
