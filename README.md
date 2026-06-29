# ELSI-Brazil (Brazilian Longitudinal Study of Aging) Waves 1-3 Pipeline

This repository hosts the data cleaning, harmonization, survey-weighted statistical modeling, and relational database packaging pipeline for the **Brazilian Longitudinal Study of Aging (ELSI-Brazil)**.

Coordinated by the Federal University of Minas Gerais (UFMG) and the Oswaldo Cruz Foundation (FIOCRUZ-MG), and funded by the Brazilian Ministry of Health, ELSI-Brazil is a representative longitudinal study of community-dwelling adults aged 50+.

---

## Cohort Profile Overview
* **Wave 1 (2015-16)**: $N = 9,412$ participants
* **Wave 2 (2019-21)**: $N = 9,949$ participants
* **Wave 3 (2023-24)**: $N = 10,773$ participants
* **Total Pooled Cohort**: $N = 30,134$ observations

### Reference Citations:
1. Lima-Costa MF, et al. Objectives and Design. *Am J Epidemiol.* 2018;187(7):1345-1353.
2. Lima-Costa MF, et al. Cohort Profile. *Int J Epidemiol.* 2023;52(1):e57-e65.

---

## Project Architecture & Directory Guide

```text
.
├── R/                          # Original R cleaning/analysis scripts
├── stata/                      # Original Stata building/modeling scripts
├── dataconnect/                # Firebase SQL Connect (GraphQL relational backend)
│   ├── dataconnect.yaml        # Service config
│   ├── schema/schema.gql       # GraphQL schema for Participant and WaveMeasurement
│   └── connector/              # Queries and mutations definitions
├── hf_dataset/                 # Hugging Face deployment dataset card
├── elsi_waves_1_2_3_analysis.ipynb  # Joint jupyter notebook (analysis, models, plots)
├── elsi_wave1_analysis.ipynb   # Baseline wave 1 jupyter notebook
├── elsi_brazil.db              # SQLite relational database (git-ignored)
├── generate_plots.py           # Verification plot generator script
├── load_to_sqlite.py           # SQLite database compiler loader script
├── run_all_models.py           # Weighted logistic regression verifier script
├── run_analysis.py             # Main pipeline orchestrator script
├── upload_to_hf.py             # Hugging Face Datasets uploader script
└── requirements.txt            # Python dependencies
```

---

## How to Replicate

### 1. Environment Setup
Install dependencies in a virtual environment:
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Generate Local SQLite Database
Run the loader script to compile the clean CSVs into a relational SQLite database `elsi_brazil.db`:
```bash
python load_to_sqlite.py
```
This compiles four relational tables:
* `wave1` (9,412 rows)
* `wave2` (9,949 rows)
* `wave3` (10,773 rows)
* `pooled_waves` (30,134 rows)

### 3. Run Survey-Weighted Models
To fit survey-weighted GLM models with cluster-robust standard errors grouped by primary sampling unit (`upa`) and verify odds ratios against Stata outputs:
```bash
python run_all_models.py
```

### 4. Upload to Hugging Face
Export your token and execute the deployment helper CLI script:
```bash
export HF_TOKEN="your_write_token"
python upload_to_hf.py
```

### 5. Start Firebase SQL Connect Relational Emulator
Verify local database schemas and GraphQL connections:
```bash
npx firebase emulators:start --only dataconnect
```
