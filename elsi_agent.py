import os
import sqlite3
import re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import statsmodels.api as sm
import statsmodels.formula.api as smf
import asyncio
from google.antigravity import Agent, LocalAgentConfig

# Database file location
DB_PATH = "elsi_brazil.db"

# ---------------------------------------------------------
# Custom Tool Definitions
# ---------------------------------------------------------

def execute_read_only_query(sql_query: str) -> str:
    """Executes a read-only SQL query against the ELSI-Brazil SQLite database.
    
    Args:
        sql_query: A read-only SQL query string starting with SELECT.
    """
    # Enforce read-only constraint
    clean_query = sql_query.strip()
    if not clean_query.upper().startswith("SELECT"):
        return "Error: Only SELECT statements are allowed."
        
    disallowed = ["DROP", "DELETE", "UPDATE", "INSERT", "ALTER", "CREATE", "REPLACE", "TRUNCATE"]
    if any(cmd in clean_query.upper() for cmd in disallowed):
        return "Error: Write operations are not allowed."
        
    try:
        conn = sqlite3.connect(DB_PATH)
        df = pd.read_sql_query(clean_query, conn)
        conn.close()
        return df.to_string(index=False)
    except Exception as e:
        return f"Error executing query: {e}"


def fit_weighted_regression(wave: int, outcome: str, exposure: str, covariates: str = "") -> str:
    """Fits a survey-weighted logistic regression model using statsmodels.
    It automatically applies weight (peso_calibrado) and clusters robust standard errors on PSU (upa).
    
    Args:
        wave: The dataset wave to use (1, 2, or 3).
        outcome: The outcome variable name (e.g. 'frail_binary', 'stroke_rehab').
        exposure: The exposure variable name (e.g. 'cancer_survivor', 'stroke_survivor').
        covariates: Comma-separated list of additional covariates. Defaults to 'age_years, sex, region, zone'.
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        table_name = f"wave{wave}"
        df = pd.read_sql_query(f"SELECT * FROM {table_name}", conn)
        conn.close()
        
        # Build covariates list
        cov_list = ["age_years", "sex", "region", "zone"]
        if covariates:
            cov_list = [c.strip() for c in covariates.split(",") if c.strip()]
            
        required_cols = [outcome, exposure, "peso_calibrado", "upa"] + [c for c in cov_list if c not in ["sex", "region", "zone"]]
        df_model = df.dropna(subset=required_cols).copy()
        
        # Build formula
        formula_terms = []
        # Check if exposure is categorical or numerical
        if df_model[exposure].nunique() <= 5:
            formula_terms.append(f"C({exposure})")
        else:
            formula_terms.append(exposure)
            
        for cov in cov_list:
            if cov in ["sex", "region", "zone"] and df_model[cov].nunique() > 1:
                formula_terms.append(f"C({cov})")
            elif cov in df_model.columns:
                formula_terms.append(cov)
                
        formula = f"{outcome} ~ " + " + ".join(formula_terms)
        
        # Fit model
        model = smf.glm(
            formula,
            data=df_model,
            family=sm.families.Binomial(),
            var_weights=df_model['peso_calibrado']
        )
        results = model.fit(cov_type='cluster', cov_kwds={'groups': df_model['upa']})
        
        # Extract Odd Ratios
        summary_lines = []
        summary_lines.append(f"Model: {formula}")
        summary_lines.append(f"Observations (N): {len(df_model)}")
        summary_lines.append(f"{'Variable':<30} {'Odds Ratio':<12} {'95% CI':<20} {'P-value':<10}")
        summary_lines.append("-" * 75)
        
        for index in results.params.index:
            if index == 'Intercept':
                continue
            coef = results.params[index]
            se = results.bse[index]
            pval = results.pvalues[index]
            odds_ratio = np.exp(coef)
            ci_low = np.exp(coef - 1.96 * se)
            ci_high = np.exp(coef + 1.96 * se)
            
            summary_lines.append(f"{index:<30} {odds_ratio:<12.4f} [{ci_low:.4f}, {ci_high:.4f}] {pval:<10.4f}")
            
        return "\n".join(summary_lines)
    except Exception as e:
        return f"Error fitting regression: {e}"


def generate_gait_or_grip_plot(wave: int, plot_type: str) -> str:
    """Generates a distribution plot for physical measures (gait speed or grip strength) and saves it as an image.
    
    Args:
        wave: The wave of data to plot (1, 2, or 3).
        plot_type: The type of plot to generate. Must be either 'grip_strength' or 'gait_speed'.
    """
    if plot_type not in ['grip_strength', 'gait_speed']:
        return "Error: plot_type must be 'grip_strength' or 'gait_speed'."
        
    try:
        conn = sqlite3.connect(DB_PATH)
        df = pd.read_sql_query(f"SELECT * FROM wave{wave}", conn)
        conn.close()
        
        sns.set_theme(style="whitegrid")
        plt.figure(figsize=(10, 6))
        
        if plot_type == 'grip_strength':
            sns.histplot(data=df.dropna(subset=['grip_max_kg', 'sex']), x='grip_max_kg', hue='sex', kde=True, palette='coolwarm')
            plt.title(f"ELSI-Brazil Wave {wave}: Distribution of Maximum Grip Strength (kg) by Sex")
            plt.xlabel("Maximum Grip Strength (kg)")
        else:
            sns.histplot(data=df.dropna(subset=['gait_best_seconds']), x='gait_best_seconds', kde=True, color='teal')
            plt.title(f"ELSI-Brazil Wave {wave}: Distribution of Best Gait Speed (seconds for 3-meter walk)")
            plt.xlabel("Walk Time (seconds)")
            
        output_file = f"agent_plot_{plot_type}_wave{wave}.png"
        plt.tight_layout()
        plt.savefig(output_file, dpi=300)
        plt.close()
        
        abs_path = os.path.abspath(output_file)
        return f"Plot generated and saved successfully to: {abs_path}"
    except Exception as e:
        return f"Error generating plot: {e}"

# ---------------------------------------------------------
# Agent Configuration & Orchestration
# ---------------------------------------------------------

async def run_chat():
    config = LocalAgentConfig(
        tools=[execute_read_only_query, fit_weighted_regression, generate_gait_or_grip_plot],
        system_instructions=(
            "You are a Senior AI Epidemiological Researcher. Your goal is to analyze the "
            "ELSI-Brazil cohort dataset. You have access to three custom tools:\n"
            "1. execute_read_only_query: to execute read-only queries against tables (wave1, wave2, wave3, pooled_waves).\n"
            "2. fit_weighted_regression: to fit survey-weighted GLM logit models with robust errors clustered on PSU (upa).\n"
            "3. generate_gait_or_grip_plot: to generate distribution plots for grip strength and gait speed.\n\n"
            "Whenever asked a scientific question, use these tools to inspect variables, run weighted regressions, "
            "and plot distributions. Always present odds ratios with 95% confidence intervals and p-values."
        )
    )
    
    print("Initializing Antigravity Researcher Agent...")
    async with Agent(config=config) as agent:
        print("\nAgent initialized. Type exit to quit.")
        while True:
            user_input = input("\nYou: ")
            if user_input.strip().lower() in ['exit', 'quit']:
                break
                
            response = await agent.chat(user_input)
            print("Agent: ", end="")
            async for chunk in response:
                print(chunk, end="", flush=True)
            print()

if __name__ == "__main__":
    # If running interactively, run:
    # asyncio.run(run_chat())
    pass
