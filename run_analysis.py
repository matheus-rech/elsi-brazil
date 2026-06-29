import pandas as pd
import numpy as np
import pyreadstat
import matplotlib.pyplot as plt
import seaborn as sns
import statsmodels.api as sm
import statsmodels.formula.api as smf

# Set styling
sns.set_theme(style="whitegrid")
plt.rcParams["figure.figsize"] = (10, 6)
plt.rcParams["font.size"] = 12

w1_path = "/Users/matheusrech/Pictures/ELSI/ELSI Portugues (1a onda) stata13.dta"
print("Loading raw Wave 1 Stata file...")
df_raw, meta = pyreadstat.read_dta(w1_path)
print("Loaded. Shape:", df_raw.shape)

# Create a clean DataFrame mimicking Stata/R code
df_clean = pd.DataFrame()
df_clean['wave'] = [1] * len(df_raw)
df_clean['anon_row_id'] = range(1, len(df_raw) + 1)

# Helper function for ynflag
def ynflag(series):
    return series.map(lambda x: 1.0 if x == 1 else (0.0 if x == 0 else np.nan))

# Helper function for numcopy with special values
def numcopy_special(series):
    special = {666, 777, 888, 999, 6666, 7777, 8888, 9999}
    return series.map(lambda x: np.nan if x in special else x)

# Map simple fields
df_clean['upa'] = df_raw['upa']
df_clean['estrato'] = df_raw['estrato']
df_clean['peso_calibrado'] = df_raw['peso_calibrado']
df_clean['region_code'] = df_raw['regiao']
df_clean['zone_code'] = df_raw['zona']
df_clean['sex'] = df_raw['sexo']
df_clean['age_years'] = numcopy_special(df_raw['idade'])
df_clean['individual_income'] = df_raw['rendaind']
df_clean['household_income_pc'] = df_raw['rendadompc']

# Mapping region and zone names
region_map = {1: 'Norte', 2: 'Nordeste', 3: 'Sudeste', 4: 'Sul', 5: 'Centro-Oeste'}
df_clean['region'] = df_clean['region_code'].map(region_map)
zone_map = {1: 'Urbano', 2: 'Rural'}
df_clean['zone'] = df_clean['zone_code'].map(zone_map)
sex_map = {0: 'Feminino', 1: 'Masculino'}
df_clean['sex_label'] = df_clean['sex'].map(sex_map)

# Chronic conditions
df_clean['cancer_survivor'] = ynflag(df_raw['n60'])
df_clean['stroke_survivor'] = ynflag(df_raw['n52'])
df_clean['chronic_spine_condition'] = ynflag(df_raw['n58'])
df_clean['hypertension'] = ynflag(df_raw['n28'])
df_clean['diabetes'] = ynflag(df_raw['n35'])
df_clean['depression_dx'] = ynflag(df_raw['n59'])

# Smoking & Alcohol
df_clean['current_smoker'] = df_raw['l30'].map(lambda x: 1.0 if x in [1, 2] else (0.0 if x in [0, 3] else np.nan))
df_clean['former_smoker'] = df_raw['l31'].map(lambda x: 1.0 if x in [1, 2] else np.nan)
df_clean['alcohol_days_week'] = numcopy_special(df_raw['l25'])
df_clean['alcohol_any'] = df_raw['l24'].map(lambda x: 1.0 if x in [2, 3] else (0.0 if x == 1 else np.nan))
df_clean.loc[df_clean['alcohol_any'].isna() & df_clean['alcohol_days_week'].notna() & (df_clean['alcohol_days_week'] > 0) & (df_clean['alcohol_days_week'] <= 7), 'alcohol_any'] = 1
df_clean.loc[df_clean['alcohol_any'].isna() & (df_clean['alcohol_days_week'] == 0), 'alcohol_any'] = 0

# Physical Activity (l5 to l11)
def clean_days(series):
    return series.map(lambda x: x if (0 <= x <= 7) else np.nan)

def clean_minutes(series):
    cleaned = numcopy_special(series)
    return cleaned.map(lambda x: x if (0 <= x <= 1440) else np.nan)

df_clean['walk_days'] = clean_days(df_raw['l5'])
df_clean['walk_minutes'] = clean_minutes(df_raw['l6'])
df_clean['mod_days'] = clean_days(df_raw['l7'])
df_clean['mod_minutes'] = clean_minutes(df_raw['l8'])
df_clean['vig_days'] = clean_days(df_raw['l9'])
df_clean['vig_minutes'] = clean_minutes(df_raw['l10'])

# Calculate totals
df_clean['walk_total'] = df_clean['walk_days'] * df_clean['walk_minutes']
df_clean['mod_total'] = df_clean['mod_days'] * df_clean['mod_minutes']
df_clean['vig_total'] = df_clean['vig_days'] * df_clean['vig_minutes']

df_clean.loc[df_clean['walk_days'] == 0, 'walk_total'] = 0
df_clean.loc[df_clean['mod_days'] == 0, 'mod_total'] = 0
df_clean.loc[df_clean['vig_days'] == 0, 'vig_total'] = 0
df_clean['weekly_activity_minutes'] = df_clean[['walk_total', 'mod_total', 'vig_total']].sum(axis=1, min_count=1)

# Grip strength
def clean_grip(series):
    return series.map(lambda x: x if (0 <= x <= 120) else np.nan)
df_clean['mf27_clean'] = clean_grip(df_raw['mf27'])
df_clean['mf28_clean'] = clean_grip(df_raw['mf28'])
df_clean['mf29_clean'] = clean_grip(df_raw['mf29'])
df_clean['grip_max_kg'] = df_clean[['mf27_clean', 'mf28_clean', 'mf29_clean']].max(axis=1)

# Gait speed
def clean_gait(series):
    return series.map(lambda x: x if (0.1 <= x <= 120) else np.nan)
df_clean['mf35s_clean'] = clean_gait(df_raw['mf35s'])
df_clean['mf38s_clean'] = clean_gait(df_raw['mf38s'])
df_clean['gait_best_seconds'] = df_clean[['mf35s_clean', 'mf38s_clean']].min(axis=1)

# Exhaustion (n73): inlist(n73_raw, 3, 4) -> 1, inlist(0, 1, 2) -> 0, else NaN
df_clean['frailty_exhaustion'] = df_raw['n73'].map(lambda x: 1.0 if x in [3, 4] else (0.0 if x in [0, 1, 2] else np.nan))

# Weight loss (n69)
df_clean['frailty_weight_loss'] = ynflag(df_raw['n69'])

# Percentile cuts for Wave 1
low_activity_cut = df_clean['weekly_activity_minutes'].quantile(0.20)
slow_gait_cut = df_clean['gait_best_seconds'].quantile(0.80)
grip_cut_f = df_clean.loc[df_clean['sex'] == 0, 'grip_max_kg'].quantile(0.20)
grip_cut_m = df_clean.loc[df_clean['sex'] == 1, 'grip_max_kg'].quantile(0.20)

print(f"Low activity cut: {low_activity_cut}")
print(f"Slow gait cut: {slow_gait_cut}")
print(f"Grip cut (Female): {grip_cut_f}, (Male): {grip_cut_m}")

# Calculate frailty components
df_clean['frailty_low_activity'] = np.nan
df_clean.loc[df_clean['weekly_activity_minutes'].notna(), 'frailty_low_activity'] = (
    df_clean.loc[df_clean['weekly_activity_minutes'].notna(), 'weekly_activity_minutes'] <= low_activity_cut
).astype(float)

df_clean['frailty_slow_gait'] = np.nan
df_clean.loc[df_clean['gait_best_seconds'].notna(), 'frailty_slow_gait'] = (
    df_clean.loc[df_clean['gait_best_seconds'].notna(), 'gait_best_seconds'] >= slow_gait_cut
).astype(float)

df_clean['frailty_weak_grip'] = np.nan
df_clean.loc[(df_clean['sex'] == 0) & df_clean['grip_max_kg'].notna(), 'frailty_weak_grip'] = (
    df_clean.loc[(df_clean['sex'] == 0) & df_clean['grip_max_kg'].notna(), 'grip_max_kg'] <= grip_cut_f
).astype(float)
df_clean.loc[(df_clean['sex'] == 1) & df_clean['grip_max_kg'].notna(), 'frailty_weak_grip'] = (
    df_clean.loc[(df_clean['sex'] == 1) & df_clean['grip_max_kg'].notna(), 'grip_max_kg'] <= grip_cut_m
).astype(float)

# frailty_available_components
df_clean['frailty_available_components'] = df_clean[[
    'frailty_weight_loss', 'frailty_exhaustion', 'frailty_low_activity', 'frailty_weak_grip', 'frailty_slow_gait'
]].notna().sum(axis=1)

# frailty_score
df_clean['frailty_score'] = df_clean[[
    'frailty_weight_loss', 'frailty_exhaustion', 'frailty_low_activity', 'frailty_weak_grip', 'frailty_slow_gait'
]].sum(axis=1)
# if available components < 3, set to NaN
df_clean.loc[df_clean['frailty_available_components'] < 3, 'frailty_score'] = np.nan

# frailty_group
df_clean['frailty_group'] = None
df_clean.loc[df_clean['frailty_score'] == 0, 'frailty_group'] = "Robust"
df_clean.loc[df_clean['frailty_score'].isin([1, 2]), 'frailty_group'] = "Prefrail"
df_clean.loc[df_clean['frailty_score'] >= 3, 'frailty_group'] = "Frail"

# frail_binary
df_clean['frail_binary'] = np.nan
df_clean.loc[df_clean['frailty_score'].notna(), 'frail_binary'] = (
    df_clean.loc[df_clean['frailty_score'].notna(), 'frailty_score'] >= 3
).astype(float)

# Save cleaned dataset for Wave 1
df_clean.to_csv("elsi_wave1_cleaned.csv", index=False)
print("Saved elsi_wave1_cleaned.csv successfully!")

# Age groups for plotting
df_clean['age_group'] = pd.cut(
    df_clean['age_years'],
    bins=[50, 59, 69, 79, 120],
    labels=["50-59", "60-69", "70-79", "80+"],
    include_lowest=True
)

# Plot 1: Grip Strength by Sex
plt.figure(figsize=(10, 5))
sns.histplot(data=df_clean.dropna(subset=['grip_max_kg', 'sex_label']), x='grip_max_kg', hue='sex_label', kde=True, bins=30, palette='Set2')
plt.axvline(x=grip_cut_f, color='orange', linestyle='--', label=f'Female 20th percentile ({grip_cut_f:.1f} kg)')
plt.axvline(x=grip_cut_m, color='teal', linestyle='--', label=f'Male 20th percentile ({grip_cut_m:.1f} kg)')
plt.title("Distribution of Maximum Grip Strength by Sex (Wave 1)")
plt.xlabel("Maximum Grip Strength (kg)")
plt.ylabel("Count")
plt.legend()
plt.tight_layout()
plt.savefig("plot_grip_strength.png", dpi=300)
plt.close()

# Plot 2: Physical Activity Distribution
plt.figure(figsize=(10, 5))
sns.histplot(data=df_clean.dropna(subset=['weekly_activity_minutes']), x='weekly_activity_minutes', kde=True, bins=40, color='purple')
plt.axvline(x=low_activity_cut, color='red', linestyle='--', label=f'Low Activity Cut ({low_activity_cut:.1f} min)')
plt.title("Distribution of Weekly Physical Activity Minutes (Wave 1)")
plt.xlabel("Weekly Physical Activity (minutes)")
plt.ylabel("Count")
plt.legend()
plt.tight_layout()
plt.savefig("plot_activity.png", dpi=300)
plt.close()

# Plot 3: Frailty by Age Group
plt.figure(figsize=(10, 5))
frailty_age = pd.crosstab(df_clean['age_group'], df_clean['frailty_group'], normalize='index') * 100
frailty_age.plot(kind='bar', stacked=True, color=['#d8b365', '#f5f5f5', '#5ab4ac'], edgecolor='black', ax=plt.gca())
plt.title("Prevalence of Frailty Status by Age Group (Wave 1)")
plt.xlabel("Age Group")
plt.ylabel("Prevalence (%)")
plt.xticks(rotation=0)
plt.legend(title="Frailty Status")
plt.tight_layout()
plt.savefig("plot_frailty_by_age.png", dpi=300)
plt.close()

# Plot 4: Frailty by Region
plt.figure(figsize=(10, 5))
frailty_reg = pd.crosstab(df_clean['region'], df_clean['frailty_group'], normalize='index') * 100
frailty_reg.plot(kind='bar', stacked=True, color=['#e0f3db', '#a8ddb5', '#43a2ca'], edgecolor='black', ax=plt.gca())
plt.title("Prevalence of Frailty Status by Region (Wave 1)")
plt.xlabel("Region")
plt.ylabel("Prevalence (%)")
plt.xticks(rotation=45)
plt.legend(title="Frailty Status")
plt.tight_layout()
plt.savefig("plot_frailty_by_region.png", dpi=300)
plt.close()
print("Plots saved successfully!")

# Models fitting
exposures = {
    'cancer_survivor': 'Cancer Survivor',
    'chronic_spine_condition': 'Chronic Spine Condition',
    'stroke_survivor': 'Stroke Survivor'
}

results_summary = []
for exp, exp_label in exposures.items():
    model_df = df_clean.dropna(subset=['frail_binary', exp, 'age_years', 'sex', 'region', 'zone', 'peso_calibrado', 'upa']).copy()
    formula = f"frail_binary ~ C({exp}) + age_years + C(sex) + C(region) + C(zone)"
    model = smf.glm(
        formula,
        data=model_df,
        family=sm.families.Binomial(),
        var_weights=model_df['peso_calibrado']
    )
    results = model.fit(cov_type='cluster', cov_kwds={'groups': model_df['upa']})
    
    or_val = np.exp(results.params[f'C({exp})[T.1.0]'])
    se = results.bse[f'C({exp})[T.1.0]']
    ci_low = np.exp(results.params[f'C({exp})[T.1.0]'] - 1.96 * se)
    ci_high = np.exp(results.params[f'C({exp})[T.1.0]'] + 1.96 * se)
    p_val = results.pvalues[f'C({exp})[T.1.0]']
    
    results_summary.append({
        'Exposure': exp_label,
        'Odds Ratio': round(or_val, 4),
        '95% CI Low': round(ci_low, 4),
        '95% CI High': round(ci_high, 4),
        'P-value': p_val,
        'N (unweighted)': int(results.nobs)
    })

df_models = pd.DataFrame(results_summary)
df_models.to_csv("elsi_wave1_models.csv", index=False)
print("Saved models results to elsi_wave1_models.csv!")
print(df_models.to_string(index=False))
