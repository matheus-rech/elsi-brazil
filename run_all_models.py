import pandas as pd
import numpy as np
import statsmodels.api as sm
import statsmodels.formula.api as smf

# Load the merged and cleaned dataset we created
df_compare = pd.read_csv("/Users/matheusrech/Pictures/ELSI/docs/generated/stata_analysis_dataset.csv", encoding='latin1')
print("Total rows:", len(df_compare))

# Load Stata model results for validation
stata_models = pd.read_csv("/Users/matheusrech/Pictures/ELSI/docs/generated/stata_survey_models.csv")

# We will fit all models for wave 1, 2, and 3
results_list = []

def run_py_model(w, outcome, exposure, subpop=None):
    df_w = df_compare[df_compare['wave'] == w].copy()
    if subpop:
        df_w = df_w[df_w[subpop] == 1].copy()
        
    # Drop missing values in the variables used in the model
    model_df = df_w.dropna(subset=[outcome, exposure, 'age_years', 'sex', 'region', 'zone', 'peso_calibrado', 'upa']).copy()
    
    # Check if there is enough data
    if len(model_df) < 100:
        return None
        
    # Check variation
    if model_df[outcome].nunique() < 2 or model_df[exposure].nunique() < 2:
        return None
        
    # Formulate GLM. Exposure is categorical if it is not age_years
    if exposure in ['age_years', 'individual_income', 'household_income_pc']:
        formula = f"{outcome} ~ {exposure} + age_years + C(sex) + C(region) + C(zone)"
    else:
        formula = f"{outcome} ~ C({exposure}) + age_years + C(sex) + C(region) + C(zone)"
        
    try:
        model = smf.glm(
            formula,
            data=model_df,
            family=sm.families.Binomial(),
            var_weights=model_df['peso_calibrado']
        )
        results = model.fit(cov_type='cluster', cov_kwds={'groups': model_df['upa']})
        
        # Extract coefs for the exposure
        # If exposure is categorical, print the terms
        params = results.params
        bse = results.bse
        pvalues = results.pvalues
        
        terms = [t for t in params.index if exposure in t]
        for term in terms:
            b = params[term]
            se = bse[term]
            or_val = np.exp(b)
            ci_low = np.exp(b - 1.96 * se)
            ci_high = np.exp(b + 1.96 * se)
            p_val = pvalues[term]
            
            results_list.append({
                'wave': w,
                'outcome': outcome,
                'exposure': exposure,
                'term': term,
                'py_or': or_val,
                'py_ci_low': ci_low,
                'py_ci_high': ci_high,
                'py_p_val': p_val,
                'py_n': len(model_df)
            })
    except Exception as e:
        print(f"Error for wave {w}, outcome {outcome}, exposure {exposure}: {e}")

# Run standard models
for w in [1, 2, 3]:
    run_py_model(w, 'frail_binary', 'cancer_survivor')
    run_py_model(w, 'frail_binary', 'chronic_spine_condition')
    run_py_model(w, 'frail_binary', 'stroke_survivor')

# Run rehab models (waves 2 and 3 only)
for w in [2, 3]:
    run_py_model(w, 'stroke_rehab', 'frail_binary', subpop='stroke_survivor')
    run_py_model(w, 'stroke_rehab', 'region', subpop='stroke_survivor')
    run_py_model(w, 'stroke_rehab', 'zone', subpop='stroke_survivor')

df_py_models = pd.DataFrame(results_list)

# Compare with Stata models
print("\n--- Model Verification (Python vs Stata Survey Models) ---")
# Merge Stata models with Python models
# Stata terms are like '1.cancer_survivor', '1.chronic_spine_condition', '1.stroke_survivor', '1.frail_binary', '2.region', '3.region', '4.region', '5.region', '2.zone'
# Python terms are like 'C(cancer_survivor)[T.1.0]', 'C(region)[T.2.0]', 'C(zone)[T.2.0]'
# We need to map python terms to Stata terms for clean merging
def map_term(row):
    term = row['term']
    exp = row['exposure']
    if exp in ['cancer_survivor', 'chronic_spine_condition', 'stroke_survivor', 'frail_binary']:
        return f"1.{exp}"
    elif exp == 'region':
        # term is like C(region)[T.2.0] -> 2.region
        val = term.split('[T.')[1].split('.0]')[0]
        return f"{val}.region"
    elif exp == 'zone':
        val = term.split('[T.')[1].split('.0]')[0]
        return f"{val}.zone"
    return term

df_py_models['stata_term'] = df_py_models.apply(map_term, axis=1)

df_merged = pd.merge(
    df_py_models,
    stata_models,
    left_on=['wave', 'outcome', 'exposure', 'stata_term'],
    right_on=['wave', 'outcome', 'exposure', 'term'],
    suffixes=('_py', '_stata')
)

print(f"Merged {len(df_merged)} model terms out of {len(df_py_models)} Python terms.")

df_merged['or_diff'] = (df_merged['py_or'] - df_merged['odds_ratio']).abs()
print("Max Odds Ratio discrepancy:", df_merged['or_diff'].max())

# Print comparison table
print("\nVerifying odds ratios:")
for idx, row in df_merged.iterrows():
    print(f"Wave {row['wave']} | Outcome: {row['outcome']} | Exposure: {row['stata_term']}")
    print(f"  Py OR: {row['py_or']:.4f} (95% CI: [{row['py_ci_low']:.4f}, {row['py_ci_high']:.4f}])")
    print(f"  Stata OR: {row['odds_ratio']:.4f} (95% CI: [{row['ci_low']:.4f}, {row['ci_high']:.4f}])")
    print(f"  OR Diff: {row['or_diff']:.6f} | P-value (Py vs Stata): {row['py_p_val']:.4f} vs {row['p_value']:.4f}")

df_merged.to_csv("verified_survey_models.csv", index=False)
print("\nSaved verified_survey_models.csv successfully!")
