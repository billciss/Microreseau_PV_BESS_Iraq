# PV-BESS Microgrid Iraq — Complete Research Project

> **Techno-Economic Sizing and Dynamic Validation of a PV-BESS-Diesel Microgrid
> for Iraqi Communities: A Multi-Scenario HOMER–Simulink Framework**
>
> *Bilali Cissé — 2025*

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Repository Structure](#2-repository-structure)
3. [Prerequisites](#3-prerequisites)
4. [Step-by-Step Guide](#4-step-by-step-guide)
5. [Key Results](#5-key-results)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Project Overview

Complete framework for sizing and validating PV-BESS-Diesel microgrids for Iraq.
Four community scenarios studied (Baghdad solar resource, 50 Hz IMER grid):

| Scenario | Location | Peak Load |
|---|---|---|
| A — Industrial | Basra | ~574 kW |
| B — Rural | North Iraq | ~50 kW |
| C — Business | Baghdad | ~200 kW |
| D — Residential | Baghdad | ~100 kW |

**Two-tool methodology:**
- **HOMER Pro** → optimal sizing + 8 techno-economic KPIs
- **MATLAB/Simulink** → dynamic validation (islanding, daily dispatch, curtailment)

---

## 2. Repository Structure

```
Microreseau_PV_BESS_Iraq/
├── 01_DATA/
│   ├── solar/nasa_power_bagdad.csv          ← NASA POWER hourly (10 yr)
│   └── load_profiles/
│       ├── profil_A_industriel_8760h.csv    ← 8760-h, kW, no header
│       ├── profil_B_rural_8760h.csv
│       ├── profil_C_affaires_8760h.csv
│       └── profil_D_residentiel_8760h.csv
├── 02_HOMER/
│   ├── projects/                            ← .homer project files
│   └── exports/                             ← CSV exported from Results > Tables
├── 03_SIMULINK/
│   ├── code/                                ← all .m files (keep together)
│   └── models/                              ← .slx models (auto-generated)
├── 04_RESULTS/
│   ├── dynamic_figures/                     ← 12 PNG figures
│   ├── schemas/                             ← Simulink architecture diagrams
│   └── comparison/                          ← Table 4x8, radar, tornado
└── 05_ARTICLE/
    └── figures/                             ← methodology figure (PNG + SVG)
```

---

## 3. Prerequisites

| Software | Version | Purpose |
|---|---|---|
| **HOMER Pro** | 3.18.4+ | Techno-economic sizing (Step 2) |
| **MATLAB + Simulink** | R2020a+ | Dynamic validation (Step 3) |
| **Python 3** | 3.8+ | Comparison figures (Step 4) |

Python dependencies (one-time install):
```bash
pip install matplotlib numpy
```

No additional MATLAB toolboxes needed — base Simulink only.

---

## 4. Step-by-Step Guide

---

### STEP 1 — Data
**Software:** none
**Status:** already in `01_DATA/` — nothing to do

Solar data: NASA POWER hourly GHI + temperature, Baghdad, 2015–2024
(validated against Solargis, deviation < 5%, annual average 5.36 kWh/m²/day)

Load data: 8760-h profiles, single column kW, no header, year 2015.

---

### STEP 2 — HOMER Pro Sizing
**Software:** HOMER Pro 3.18.4
**Time:** ~15 min per scenario
**Output:** optimal sizes + KPIs

#### 2a — Open existing project (recommended)
1. Open HOMER Pro
2. `FILE → Open` → `02_HOMER/projects/scenario_D.homer`
3. Click **Results** to view results

#### 2b — Re-run from scratch
1. `FILE → New`
2. **Home** tab → Baghdad (33.31°N, 44.37°E), UTC+3, discount 8%, inflation 2%, 25 yr
3. **LOAD tab → Electric #1** → `Import` → select load CSV → Year: **2015**
4. **COMPONENTS tab** → add and set costs:
   - PV: $900/kW capital, 85% derating, 33° slope, 25 yr lifetime
   - Storage Li-Ion: $250/kWh, 95% roundtrip, 15% min SoC
   - Generator Diesel: $400/kW, $0.45/L fuel, 25% min load
   - Converter: $300/kW, 95% efficiency, 15 yr
   - Grid: $0.04/kWh purchase, $0.00/kWh sellback
     → Grid → Scheduled Rates → Reliability → outage 365/yr, duration 8h
5. **RESOURCES tab → Solar GHI** → enter monthly averages:

   | Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec |
   |-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|
   | 3.08 | 3.96 | 5.07 | 6.20 | 7.12 | 7.97 | 7.65 | 6.96 | 5.97 | 4.42 | 3.25 | 2.70 |

6. Click **Calculate** → wait 5–15 min
7. **Results → Tables → row 1 → Simulation Details** → read all KPIs
8. **Results → Tables → Export** → save to `02_HOMER/exports/scenario_X_results.csv`

Repeat for all 4 scenarios (only change the load file at step 3).

#### Optimal sizes obtained:

| Scenario | PV (kWp) | BESS (kWh) | Diesel (kW) | Converter (kW) |
|---|---|---|---|---|
| A Industrial | 819 | 650 | 640 | 599 |
| B Rural | 24 | 52 | 110 | 25 |
| C Business | 290 | 274 | 270 | 219 |
| D Residential | 198 | 196 | 200 | 143 |

---

### STEP 3 — MATLAB/Simulink Dynamic Validation
**Software:** MATLAB R2020a+ with Simulink (base only)
**Time:** ~5 min total
**Output:** 12 PNG figures in `04_RESULTS/dynamic_figures/`

#### 3a — Navigate to code folder
```matlab
cd 03_SIMULINK/code
```

#### 3b — Quick physics check (no Simulink needed, run first)
```matlab
simulate_offline
```
Produces 3 offline figures in seconds. If these look correct, proceed.

#### 3c — Full run: all 4 scenarios with HOMER sizes
```matlab
run_all_scenarios_homer
```

This single command automatically:
- Injects HOMER optimal sizes for each scenario (A → B → C → D)
- Loads the matching load profile from `01_DATA/load_profiles/`
- Runs 3 dynamic validations per scenario:
  - **transition**: grid loss at t=1s, battery maintains frequency
  - **journee**: 24-hour daily profile with afternoon grid outage
  - **curtailment**: islanded day, battery fills to 90%, PV curtailed
- Saves 12 figures: `Fig_1_A_Industriel_transition.png` ... `Fig_4_D_Residentiel_curtailment.png`

Expected terminal output:
```
========== A — Industrial (Basra) ==========
PV=819 kWp | BESS=650 kWh | DG=640 kW | Conv=599 kW
  [transition]   fuel=0.0 L  | SoC=50%  → Fig saved
  [journee]      fuel=XX L   | SoC=15%  → Fig saved
  [curtailment]  fuel=XX L   | SoC=15%  → Fig saved
========== B — Rural ... (etc.)
Done. Figures saved in: .../03_SIMULINK/code
```

Then move the 12 PNG files to `04_RESULTS/dynamic_figures/`.

#### 3d — Export Simulink architecture diagrams
```matlab
% Compact model (for methodology section)
build_microgrid_irak
Simulink.BlockDiagram.arrangeSystem('microreseau_irak')
print('-smicroreseau_irak', '-dpng', '-r200', 'schema_simulink_compact.png')

% Subsystem model (clearer for the article)
run_simulink_subsystems
Simulink.BlockDiagram.arrangeSystem('microreseau_irak_sous_systemes')
print('-smicroreseau_irak_sous_systemes', '-dpng', '-r200', 'schema_simulink_subsystems.png')
```

Move both PNG to `04_RESULTS/schemas/`.

> **Why power-level model?**
> The original Hydro-Quebec EMT switching model diverged (DC bus → 3000V).
> This model uses power-level dispatch (kW) + frequency swing-equation.
> No DC bus → no divergence. Validated: offline = Simulink (isequal = 1).

---

### STEP 4 — Comparison Figures
**Software:** Python 3
**Time:** < 1 min
**Output:** 3 publication-ready figures in `04_RESULTS/comparison/`

```bash
cd 04_RESULTS/comparison
python gen_figures.py
```

Produces:
- `tableau_kpi_4x8.png` — Table 1: full 4-scenario × 8-KPI comparison
- `radar_kpi.png` — Fig 5a: normalised performance radar
- `tornado_lcoe.png` — Fig 5b: LCOE sensitivity ±20%

---

## 5. Key Results

| KPI | A Industrial | B Rural | C Business | D Residential |
|---|---|---|---|---|
| LCOE optimal ($/kWh) | 0.101 | 0.152 | 0.108 | 0.113 |
| LCOE reduction vs base | **−46%** | **−62%** | **−44%** | **−38%** |
| IRR (%) | 17.1 | **52.9** | 17.9 | 18.5 |
| Payback (yr) | 5.6 | **2.1** | 5.4 | 5.4 |
| LPSP (%) | **0** | **0** | **0** | **0** |
| CO₂ reduction | −77% | −63% | −68% | −56% |
| Renewable fraction | 62.5% | 31.6% | 54.6% | 46.7% |

**All 4 scenarios**: LPSP = 0%, LCOE reduced 38–62%, CO₂ reduced 56–77%.
Scenario B (rural) outstanding: IRR 52.9%, payback 2.1 yr.

---

## 6. Troubleshooting

**`Unable to find profil_X_8760h.csv`**
Make sure all 4 CSV files are in `01_DATA/load_profiles/`.
The script looks for them relative to its own location.

**`shade_island` or `safe_xlim` not found**
All .m files must be in the same folder. Run `addpath(pwd)` from `03_SIMULINK/code/`.

**HOMER "Could not connect to Internet"**
Normal — enter the 12 monthly GHI values manually (see Step 2b, point 5).

**Simulink DC bus divergence**
You opened the wrong model. Run `build_microgrid_irak` to create the correct one.

**Figures have French labels**
Make sure you are using the updated `plot_microgrid.m` from this repository (all labels are in English).

---

## Citation

```
Cissé, B. et al. (2025). Techno-Economic Sizing and Dynamic Validation of a
PV-BESS-Diesel Microgrid for Iraqi Communities: A Multi-Scenario
HOMER-Simulink Framework. [Journal Name, Volume, Pages].
```

## License

MIT — free to use with attribution.
