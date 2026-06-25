# PV-BESS Microgrid — Iraq (Baghdad) — Complete Project

## Article
**Title:** Techno-Economic Sizing and Dynamic Validation of a PV-BESS-Diesel
Microgrid for Iraqi Communities: A Multi-Scenario HOMER–Simulink Framework

**Authors:** Bilali Cissé et al.
**Target journal:** Q2/Q3 — Renewable Energy / Energy for Sustainable Development

---

## Project Structure

```
01_DATA/           → Raw input data (NASA POWER solar + 4 load profiles)
02_HOMER/          → HOMER Pro projects (.homer) + exported results (.csv)
03_SIMULINK/       → MATLAB/Simulink power-level model (all .m files)
04_RESULTS/        → All output figures (12 dynamic + 3 comparison + schemas)
05_ARTICLE/        → Manuscript + final figures for submission
```

---

## Quick Start

### Reproduce all 12 dynamic figures
```matlab
cd 03_SIMULINK/code
run_all_scenarios_homer
```

### Reproduce comparison figures (Table 4×8, Radar, Tornado)
```bash
python 04_RESULTS/comparison/gen_figures.py
```

---

## Optimal Sizes (from HOMER Pro 3.18.4)

| Scenario | PV (kWp) | BESS (kWh) | Diesel (kW) | LCOE ($/kWh) | IRR (%) | Payback (yr) |
|---|---|---|---|---|---|---|
| A — Industrial (Basra) | 819 | 650 | 640 | 0.101 | 17.1 | 5.6 |
| B — Rural (North) | 24 | 52 | 110 | 0.152 | 52.9 | 2.1 |
| C — Business (Baghdad) | 290 | 274 | 270 | 0.108 | 17.9 | 5.4 |
| D — Residential (Baghdad) | 198 | 196 | 200 | 0.113 | 18.5 | 5.4 |

---

## Files to Add Manually (from your PC/MATLAB Drive)

### 02_HOMER/projects/
- `scenario_A.homer`
- `scenario_B.homer`
- `scenario_C.homer`
- `scenario_D.homer`

### 03_SIMULINK/models/
- `microreseau_irak.slx`
- `microreseau_irak_sous_systemes.slx`

### 04_RESULTS/dynamic_figures/   (from MATLAB Drive)
- `Fig_1_A_Industriel_transition.png`
- `Fig_1_A_Industriel_journee.png`
- `Fig_1_A_Industriel_curtailment.png`
- `Fig_2_B_Rural_transition.png`
- `Fig_2_B_Rural_journee.png`
- `Fig_2_B_Rural_curtailment.png`
- `Fig_3_C_Affaires_transition.png`
- `Fig_3_C_Affaires_journee.png`
- `Fig_3_C_Affaires_curtailment.png`
- `Fig_4_D_Residentiel_transition.png`
- `Fig_4_D_Residentiel_journee.png`
- `Fig_4_D_Residentiel_curtailment.png`

### 04_RESULTS/schemas/            (from MATLAB Drive)
- `schema_simulink_compact.png`
- `schema_simulink_subsystems.png`

---

## Key Technical Choices
- **No EMT switching model** (divergence issue with original HQ model)
- **Power-level + frequency droop** model → no DC bus divergence
- **LPSP = 0%** all 4 scenarios (grid backup)
- **Validated**: offline simulation = Simulink results (isequal = 1)

---

## Tools
| Tool | Version | Purpose |
|---|---|---|
| HOMER Pro | 3.18.4 | Techno-economic sizing |
| MATLAB | R2020a+ | Simulation + figures |
| Simulink | Base (no toolbox) | Dynamic model |
| Python | 3.x | Comparison figures |
| NASA POWER | API | Solar resource data |
