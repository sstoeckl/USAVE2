# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Development Workflow

**There is no build step.** This is a static website — edit files and open in a browser.

```bash
# Serve locally (required for WebR — fetch() needs a server, not file://)
cd docs && python -m http.server 8080
# then open http://localhost:8080

# Or with R:
# servr::httd("docs")
```

**Deploy**: push to `master` → GitHub Pages auto-serves from `docs/` (no CI needed).

**Test a specific app**: open `http://localhost:8080/usave1.html?debug=true&lang=en`

**Export data to JSON** (run once in R before dashboard works):
```r
library(usavePKG); library(jsonlite)
data("totalReturn"); data("totalReturnInflationAdjusted")
write_json(totalReturn, "docs/assets/data/totalReturn.json", digits=8)
write_json(totalReturnInflationAdjusted, "docs/assets/data/totalReturnInflationAdjusted.json", digits=8)
```

---

## Project Overview — USAVE2: Understanding Saving in Europe

This file provides complete context for Claude Code to continue work across sessions in this repository.

---

## Project Overview

**USAVE2** ("Understanding Saving in Europe 2") is an Erasmus+ educational project building interactive web apps and a public project website for personal finance literacy. It is the spiritual successor to **UNPIE2** (Understanding Pensions in Europe 2) and follows the same architecture.

- **Live website target**: `https://www.sebastianstoeckl.com/usave2/` (via GitHub Pages)
- **Redirect domains**: `savingineurope.eu` → website URL
- **Erasmus+ Project ID**: 2019-1-LI01-KA203-000125
- **Original project website** (for content reference): https://savingineurope.eu
- **GitHub repo target**: `https://github.com/sstoeckl/USAVE2`

### Sibling projects (reference implementations)
| Project | Path | Website | Notes |
|---------|------|---------|-------|
| IMAG | `D:/OneDrive - University of Liechtenstein/ROOT/Packages/IMAG` | `sstoeckl.github.io/IMAG` | Quarto-based; has `CLAUDE.md` |
| UNPIE2 | `D:/OneDrive - University of Liechtenstein/ROOT/Packages/UNPIE2` | `sstoeckl.github.io/UNPIE2` | **Primary pattern reference** — WebR + Chart.js + Tailwind; has `CLAUDE.md` |

### R Package Sources (read-only — do not modify these)
| Package | Path | Content |
|---------|------|---------|
| `usavepkg2` | `D:/OneDrive - University of Liechtenstein/ROOT/Packages/usavepkg2` | Main R functions (v2, with `checks.R`, `checks_opt.R`) |
| `usavepkg` | `D:/OneDrive - University of Liechtenstein/ROOT/Packages/usavepkg` | Original R functions (v1, subset of v2) |
| `usavedata` | `D:/OneDrive - University of Liechtenstein/ROOT/Packages/usavedata` | Historical return data + VAR simulated scenarios |

---

## Architecture

Identical to UNPIE2 — a **fully static website** with no build step and no backend:

```
USAVE2/
└── docs/                       ← GitHub Pages root
    ├── index.html              ← Landing page (static HTML, Tailwind CSS)
    ├── apps.html               ← App overview / filter page
    ├── dashboard.html          ← Investment Dashboard (flagship app)
    ├── usave1.html … usaveN.html  ← Individual WebR apps
    ├── r/                      ← R function sources (loaded by WebR at runtime)
    │   ├── usave1.R
    │   ├── usave2.R
    │   └── …
    └── assets/
        ├── logos/              ← Partner/institution logos
        ├── team/               ← Team member photos
        ├── events/             ← Event photos & PDFs
        ├── screenshots/        ← App screenshots (16:9, for cards)
        └── data/               ← Pre-exported JSON data for dashboard
            └── totalReturn.json   ← Historical Ibbotson data (from usavedata)
```

### Technology Stack (identical to UNPIE2)
- **R logic**: [WebR](https://webr.r-wasm.org/) (R compiled to WASM), loaded from CDN
- **Visualizations**: Chart.js 4.4.1 (via CDN)
- **Styling**: Tailwind CSS (static pages) / vanilla CSS (apps)
- **No build step** — direct file editing and push to deploy

---

## R Functions Available (from `usavepkg2`)

### Core Functions

| File | Function | Description |
|------|----------|-------------|
| `calculateHumanCapital.R` | `calculateHumanCapital()` | Discounted present value of all future labor income. Returns `laborincome`, `disc_laborincome`, `humanCapital`, `humanCapitals` (vector over ages). |
| `consumptionSmoothing.R` | `consumptionSmoothing()` | Deterministic optimal consumption path over life. Returns `ages`, `consumptionCalc`, `salaryCalc`, `savingsCalc`, `financialCapitalCalcP/U`, `grossHumanCapitalCalcP/U`, `economicNetWorthP/U`. |
| `consumptionSmoothingDisability.R` | `consumptionSmoothingDisability()` | Like above but with a disability event, showing insurance impact. |
| `model1OptimalConsumption.R` | `model1OptimalConsumption()` | Optimal annual consumption under constant-growth preference (fast formula). |
| `model2OptimalConsumption.R` | `model2OptimalConsumption()` | Optimal consumption with Epstein-Zin utility. |
| `calculateTotalCashflow.R` | `calculateTotalCashflow()` | Stochastic wealth paths over lifetime (returns `consumptionPath`, `wealth`, `pf_ret`, `laborincome` matrices). Requires scenario data. |
| `calculateLifetimeUtility.R` | `calculateLifetimeUtility()` | Expected utility of a full lifetime plan. Used inside optimizer. |
| `calculatePortfolioReturns.R` | `calculatePortfolioReturns()` | Given portfolio weights + date range, returns cumulative returns, risk-adjusted returns, portfolio statistics. |
| `optimizeLifetimeUtility.R` | `optimizeLifetimeUtility()` | Full numerical optimizer — finds optimal c, growth, alpha, portfolio weights. **Very slow** — not suitable for interactive WebR. |

### Data (from `usavepkg2` package data)

| Dataset | Format | Description |
|---------|--------|-------------|
| `totalReturn` | data.frame | Monthly nominal total returns: Date, LargeStocks, SmallStocks, CorporateBonds, GovernmentBonds, TBill, Inflation. Ibbotson SBBI data ~1926-2020. |
| `totalReturnInflationAdjusted` | data.frame | Same but inflation-adjusted: `r_real = (1+r)/(1+pi) - 1` |
| `totalReturnScenarios` | array [98,6,N] | VAR-simulated monthly return scenarios (nominal), N=5000 or 10000 |
| `totalReturnInflationAdjustedScenarios` | array [98,6,N] | Same but inflation-adjusted |

**Asset classes** (columns 1-6): LargeStocks, SmallStocks, CorporateBonds, GovernmentBonds, TBill, Inflation

---

## Planned Apps

### Module 1 — Human Capital & Deterministic Life-cycle Savings

| App | HTML file | R file | R Function(s) | Description |
|-----|-----------|--------|---------------|-------------|
| App 1 | `usave1.html` | `r/usave1.R` | `calculateHumanCapital` | Human Capital Calculator: given salary, growth, valuation rate, retirement age → show present value of human capital + discounted income schedule |
| App 2 | `usave2.html` | `r/usave2.R` | `model1OptimalConsumption` + `consumptionSmoothing` | Optimal Life-cycle Plan (Model 1): deterministic savings/consumption path over lifetime. Shows salary, consumption, savings, financial capital evolution. |
| App 3 | `usave3.html` | `r/usave3.R` | `consumptionSmoothingDisability` | Disability Insurance: extends App 2 with a disability event + insurance, showing how insurance changes the consumption path. |
| App 4 | `usave4.html` | `r/usave4.R` | `model2OptimalConsumption` | Model 2 Optimal Consumption: Epstein-Zin utility, shows how risk aversion (theta) and patience (beta) affect optimal consumption. |

### Module 2 — Investment Dashboard (Flagship)

| App | HTML file | R file | R Function(s) | Description |
|-----|-----------|--------|---------------|-------------|
| Dashboard | `dashboard.html` | `r/dashboard.R` | `calculatePortfolioReturns` | **Investment Dashboard**: select asset weights (5 sliders), date range, nominal/real toggle → show: (1) cumulative portfolio return chart vs benchmarks, (2) portfolio statistics table (Ann. Return, StdDev, Sharpe, VaR, Skew, Kurt, MaxDrawdown), (3) bar chart of risk-adjusted returns. Uses `totalReturn.json` loaded as JS, passed to WebR. |

### Module 3 — Stochastic Lifetime Planning

| App | HTML file | R file | R Function(s) | Description |
|-----|-----------|--------|---------------|-------------|
| App 5 | `usave5.html` | `r/usave5.R` | `calculateTotalCashflow` | Stochastic Wealth Paths: given personal parameters + portfolio weights → show fan chart of wealth over lifetime (percentile bands: 5th, 25th, median, 75th, 95th). Uses pre-loaded scenario subset (500 scenarios). |
| App 6 | `usave6.html` | `r/usave6.R` | `calculateTotalCashflow` | Retirement Ruin Probability: given spending level, retirement wealth, portfolio → show probability of ruin by age / years to ruin distribution. |

### Notes on WebR feasibility
- Apps 1–4, 6: Fast — suitable for interactive sliders (< 1 second)
- App 5 (TCF): Needs scenario data. Pre-subset to 500 scenarios. First load ~5-10s. Subsequent calls fast.
- Dashboard: Needs historical return data. Export `totalReturn` to `assets/data/totalReturn.json`. Pass to WebR via `webr.evalR()`.
- `optimizeLifetimeUtility`: Too slow for interactive use. Skip or pre-compute optimal solutions.

---

## UNPIE2 App Pattern (follow exactly)

Each app (`docs/usaveN.html`) uses this pattern:

```javascript
import { WebR } from "https://webr.r-wasm.org/latest/webr.mjs";
const webr = new WebR();
await webr.init();
// Load R function from server
const code = await fetch('r/usave1.R').then(r => r.text());
await webr.evalR(code);
// On slider change:
const result = await webr.evalR(`usave1(salary=${val}, ...)`);
// Update Chart.js chart with result
```

**R function return convention** — every function wrapper returns:
```r
list(
  ok      = TRUE,
  inputs  = list(...),    # echo of inputs
  results = list(...)     # computed values for charting/display
)
```

**Layout** — two-column grid (320px controls + chart), collapses to single column < 900px.

**i18n** — `const I18N = { en_en: {...}, de_de: {...} }`, switch via `?lang=en` or `?lang=de`.

**Debug mode** — `?debug=true` shows hidden debug pane.

---

## Website (index.html) Sections

Following the exact structure of UNPIE2's `docs/index.html`:

1. **Header** — sticky nav: Project | Team | Outcomes | Events | Apps | Dashboard | Contact
2. **Hero** — title "Understanding Saving in Europe (USAVE)", short description, CTA buttons (Explore Apps, Investment Dashboard)
3. **Project** — about section with project description, Erasmus+ badge
4. **Events** — project meetings and conferences with accordion for photos/programs
5. **Team** — partner institutions (ULI, UniBZ, Alguru ApS) with team member cards
6. **Outcomes** — online courses (MOOCs), apps, publications
7. **Apps** — accordion of app groups with screenshot cards + English/German links
8. **Dashboard** — highlighted card for the investment dashboard
9. **Contact / Footer**

### Partner Institutions (from savingineurope.eu)
- **University of Liechtenstein** (lead) — Prof. Dr. Sebastian Stöckl (coordinator), Prof. Dr. Michael Hanke
- **Free University of Bozen-Bolzano** (UniBZ) — Prof. Dr. Alex Weissensteiner
- **Alguru ApS** (Denmark) — Emil Ahlmann Østergaard (R package `usavepkg` author)

---

## Data Export Task (required for Dashboard)

The investment dashboard needs historical return data as JSON. This needs to be done once in R:

```r
# Run in R (with usavepkg2 loaded):
library(usavepkg2)
data("totalReturn")
data("totalReturnInflationAdjusted")
library(jsonlite)
write_json(totalReturn, "D:/OneDrive - University of Liechtenstein/ROOT/Packages/USAVE2/docs/assets/data/totalReturn.json", digits=8)
write_json(totalReturnInflationAdjusted, "D:/OneDrive - University of Liechtenstein/ROOT/Packages/USAVE2/docs/assets/data/totalReturnInflationAdjusted.json", digits=8)
```

**Note**: Also consider a 500-scenario subset for TCF apps:
```r
data("totalReturnInflationAdjustedScenarios")
ret500 <- totalReturnInflationAdjustedScenarios[,,1:500]
# serialize as RDS → then load in WebR, or convert to a compact JSON
```

---

## Investment Dashboard — Detailed Design

The flagship app (`dashboard.html`) should be a significantly improved version of what exists. Design goals:

### UI Layout
```
┌─ Controls (left panel, 360px) ──────────────────────────────────┐
│ Portfolio Weights                                                 │
│  Large Stocks [====|====] 20%                                    │
│  Small Stocks [=====|===] 20%                                    │
│  Corp Bonds   [====|====] 20%                                    │
│  Govt Bonds   [====|====] 20%                                    │
│  T-Bill       [====|====] 20%    ← auto-fills to 100%           │
│  [ ] Include Cash (T-Bill)                                       │
│                                                                   │
│ Settings                                                          │
│  Start Date [1926] → End Date [2020]                             │
│  Rebalance: Monthly / Quarterly / Annually                       │
│  [ ] Inflation-Adjusted (Real Returns)                           │
│  Transaction Cost [0.0%]                                         │
│                                                                   │
│ Benchmarks to compare                                             │
│  [x] 100% Large Stocks (S&P 500 proxy)                          │
│  [x] 60/40 (Stocks/Bonds)                                        │
│  [x] Equal Weight                                                 │
└──────────────────────────────────────────────────────────────────┘

┌─ Charts & Stats (right panel) ───────────────────────────────────┐
│ Tab: [Growth of $100] [Annual Returns] [Rolling Stats]           │
│                                                                   │
│ [Chart.js line chart - cumulative growth]                        │
│                                                                   │
│ ┌─ Statistics Table ─────────────────────────────────────────┐  │
│ │              Custom  100%EQ  60/40  EqWt                   │  │
│ │ Ann. Return  7.2%   10.1%   7.8%   8.3%                    │  │
│ │ Ann. StdDev  12.3%  20.1%   11.2%  15.4%                   │  │
│ │ Sharpe Ratio 0.58   0.50    0.70   0.54                     │  │
│ │ Max Drawdown -42%   -55%    -35%   -47%                     │  │
│ │ VaR (95%)    -3.1%  -5.2%   -2.8%  -4.1%                   │  │
│ │ Skewness     -0.3   -0.5    -0.2   -0.4                     │  │
│ │ Kurtosis      4.1    5.2     3.8    4.6                     │  │
│ └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Improvements over any existing version
1. **Multiple benchmarks** compared simultaneously (not just custom portfolio)
2. **Tabbed charts**: Growth of $100 | Histogram of annual returns | Rolling 5Y return
3. **Efficient frontier overlay** (optional toggle) — pre-compute MV frontier points
4. **Color-coded statistics** (green/red relative to benchmark)
5. **"Normalize to risk"** toggle — shows risk-adjusted returns
6. **Export button** — download statistics as CSV
7. **Loading state** — WebR spinner with progress

---

## CI/CD (to be set up, following UNPIE2 model)

Since this is a static site (no build step), CI is minimal:
- GitHub Actions workflow: on push to `master`, just verify HTML is valid (optional)
- GitHub Pages: serve from `docs/` on `master`
- No Quarto rendering needed

---

## TODO List

### PHASE 1 — Repository & Infrastructure
- [ ] **1.1** Create GitHub repository `sstoeckl/USAVE2` (or verify it exists)
- [ ] **1.2** Initialize `docs/` folder structure (see Architecture above)
- [ ] **1.3** Create `.gitignore` (ignore `.Rproj.user/`, `renv/`, etc.)
- [ ] **1.4** Set up GitHub Pages to serve from `docs/` on `master`
- [ ] **1.5** Create `docs/assets/` subfolder structure (logos, team, events, screenshots, data)

### PHASE 2 — Data Export
- [ ] **2.1** Export `totalReturn` to `docs/assets/data/totalReturn.json` (run in R)
- [ ] **2.2** Export `totalReturnInflationAdjusted` to `docs/assets/data/totalReturnInflationAdjusted.json` (run in R)
- [ ] **2.3** Export a 500-scenario subset for TCF apps (decide format: RDS vs JSON vs JS array)

### PHASE 3 — Landing Page
- [ ] **3.1** Create `docs/index.html` — full landing page following UNPIE2 structure
  - Hero with project description and CTA buttons
  - About / Project section (content from savingineurope.eu)
  - Team section (ULI, UniBZ, Alguru with accordion team members)
  - Outcomes section
  - Events section (add known events from savingineurope.eu)
  - Apps section (accordion cards with screenshots + EN/DE links)
  - Dashboard highlight card
  - Contact / Footer

### PHASE 4 — Apps Module 1 (Human Capital & Deterministic)
- [ ] **4.1** Create `docs/r/usave1.R` — wrapper for `calculateHumanCapital()`
- [ ] **4.2** Create `docs/usave1.html` — Human Capital Calculator
- [ ] **4.3** Create `docs/r/usave2.R` — wrapper for `consumptionSmoothing()` + `model1OptimalConsumption()`
- [ ] **4.4** Create `docs/usave2.html` — Optimal Life-cycle Plan (Model 1)
- [ ] **4.5** Create `docs/r/usave3.R` — wrapper for `consumptionSmoothingDisability()`
- [ ] **4.6** Create `docs/usave3.html` — Disability Insurance App
- [ ] **4.7** Create `docs/r/usave4.R` — wrapper for `model2OptimalConsumption()`
- [ ] **4.8** Create `docs/usave4.html` — Model 2 Optimal Consumption (Epstein-Zin)

### PHASE 5 — Investment Dashboard (Flagship)
- [ ] **5.1** Create `docs/r/dashboard.R` — WebR wrapper around `calculatePortfolioReturns()` logic (using JSON data)
- [ ] **5.2** Create `docs/dashboard.html` — full Investment Dashboard
  - Portfolio weight sliders (5 asset classes, auto-normalize)
  - Date range selector
  - Nominal/real toggle
  - Rebalancing frequency selector
  - Benchmark comparison (3 pre-set portfolios)
  - Tabbed charts: Growth of $100 | Annual return histogram | Rolling 5Y Sharpe
  - Statistics table (color-coded)
  - "Normalize to risk" toggle
  - Export to CSV button
  - Transaction cost slider

### PHASE 6 — Apps Module 3 (Stochastic)
- [ ] **6.1** Create `docs/r/usave5.R` — wrapper for `calculateTotalCashflow()` (500-scenario subset)
- [ ] **6.2** Create `docs/usave5.html` — Stochastic Wealth Paths (fan chart)
- [ ] **6.3** Create `docs/r/usave6.R` — retirement ruin probability
- [ ] **6.4** Create `docs/usave6.html` — Ruin Probability App

### PHASE 7 — Apps Overview Page
- [ ] **7.1** Create `docs/apps.html` — app overview/filter page (like UNPIE2's `apps.html`)

### PHASE 8 — Polish & Assets
- [ ] **8.1** Add partner logos to `docs/assets/logos/`
- [ ] **8.2** Add team photos to `docs/assets/team/`
- [ ] **8.3** Take/add screenshots of each app (16:9, ~1280×720) to `docs/assets/screenshots/`
- [ ] **8.4** Full German (de_de) translations for all apps
- [ ] **8.5** Test all apps in browser (WebR loading, chart rendering, responsive layout)
- [ ] **8.6** Add GitHub Actions workflow for pages deployment (if needed)

---

## Current Status

> **Session started 2026-03-03.** Repository is empty (only `.Rproj` file exists). No `docs/` folder yet.
>
> **Next action**: Begin PHASE 1 (repository/infrastructure setup), then PHASE 3 (landing page), then PHASE 5 (Investment Dashboard as flagship), then PHASE 4 (individual apps).

### Completed Tasks
*(none yet)*

### In Progress
*(none yet)*

### Known Issues / Decisions Pending
- Confirm exact GitHub repository name and URL (need to create on GitHub)
- Decide format for stochastic scenario data (JSON is large: ~98×6×500 floats ≈ ~300KB; RDS loaded via WebR is possible but more complex)
- Confirm which events from savingineurope.eu to include on the website
- Confirm exact team member list and photos availability
- The `optimizeLifetimeUtility` function is too slow for interactive WebR — consider either: (a) pre-compute optimal solution and show it as a reference line in App 2, (b) skip it as a standalone app

---

## Key Conventions

- All app HTML files use **vanilla CSS** (not Tailwind) for the tight app layout — same as UNPIE2
- The **landing page** (`index.html`) uses **Tailwind CSS** via CDN — same as UNPIE2
- All source files in `docs/` are HTML (not Quarto). The `docs/` folder IS the build output.
- R functions in `docs/r/` must be self-contained (no package dependencies except those available in WebR WASM)
- For functions needing data: data is passed as arguments from JS (loaded as JSON first)
- Use `?lang=en` or `?lang=de` URL parameter to switch language in all apps
- Use `?debug=true` to show hidden debug pane in all apps

---

## WebR Gotchas

1. **Package availability**: Not all R packages are available in WebR. Check https://webr.r-wasm.org/packages/ before adding imports.
   - Available: `stats`, `utils`, `base` — always available
   - Available (installable in WebR): `xts`, `PerformanceAnalytics`, `MortalityTables` — needs `webr.installPackages()`
   - **Problem**: Installing packages takes 10-30s. Pre-load in a `<webr-init>` or during the loading spinner.
2. **Large data arrays**: Loading 10000 scenarios × 98 ages × 6 assets in WebR may cause memory issues. Use 500 scenarios max.
3. **Serialization**: Use `webr.evalR()` with typed array results for large numeric arrays (faster than list serialization).
4. **CORS**: The `docs/r/*.R` files are loaded via `fetch()` — this works with GitHub Pages (same origin). For local testing, use a local server (e.g., `python -m http.server`).

---

## Links & References

- UNPIE2 CLAUDE.md: `D:/OneDrive - University of Liechtenstein/ROOT/Packages/UNPIE2/CLAUDE.md`
- UNPIE2 sample app (pattern): `D:/OneDrive - University of Liechtenstein/ROOT/Packages/UNPIE2/docs/case1.html`
- UNPIE2 landing page (pattern): `D:/OneDrive - University of Liechtenstein/ROOT/Packages/UNPIE2/docs/index.html`
- usavepkg2 functions: `D:/OneDrive - University of Liechtenstein/ROOT/Packages/usavepkg2/R/`
- usavedata raw data: `D:/OneDrive - University of Liechtenstein/ROOT/Packages/usavedata/`
- savingineurope.eu (content source): https://savingineurope.eu
- WebR docs: https://webr.r-wasm.org/
- WebR package list: https://repo.r-wasm.org/
- Chart.js docs: https://www.chartjs.org/docs/
