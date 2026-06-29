import pandas as pd
import numpy as np
import pyreadstat

# Paths
w1_path = "/Users/matheusrech/Pictures/ELSI/ELSI Portugues (1a onda) stata13.dta"
w2_path = "/Users/matheusrech/Pictures/ELSI/ELSI Portugues (2a onda) stata13.dta"
w3_path = "/Users/matheusrech/Pictures/ELSI/ELSI Portugues (3a onda).dta"
stata_clean_path = "/Users/matheusrech/Pictures/ELSI/docs/generated/stata_analysis_dataset.csv"

print("Loading Stata cleaned dataset...")
df_stata = pd.read_csv(stata_clean_path, encoding='latin1')
print("Loaded. Shape:", df_stata.shape)

# Helper functions
def ynflag(df, col):
    if col not in df.columns:
        return pd.Series(np.nan, index=df.index)
    return df[col].map(lambda x: 1.0 if x == 1 else (0.0 if x == 0 else np.nan))

def numcopy_special(df, col):
    if col not in df.columns:
        return pd.Series(np.nan, index=df.index)
    special = {666, 777, 888, 999, 6666, 7777, 8888, 9999}
    return df[col].map(lambda x: np.nan if x in special else x)

def clone_or_missing(df, col):
    if col not in df.columns:
        return pd.Series(np.nan, index=df.index)
    return df[col]

def clean_days(series):
    return series.map(lambda x: x if (0 <= x <= 7) else np.nan)

def clean_minutes(series):
    return series.map(lambda x: x if (0 <= x <= 1440) else np.nan)

def process_wave(w, path):
    print(f"\nProcessing Wave {w} from {path}...")
    df_raw, meta = pyreadstat.read_dta(path, encoding='latin1')
    n = len(df_raw)
    df_clean = pd.DataFrame()
    df_clean['wave'] = [w] * n
    df_clean['anon_row_id'] = range(1, n + 1)
    
    # Design & Demographics
    df_clean['upa'] = clone_or_missing(df_raw, 'upa')
    df_clean['estrato'] = clone_or_missing(df_raw, 'estrato')
    df_clean['peso_calibrado'] = clone_or_missing(df_raw, 'peso_calibrado')
    df_clean['region'] = clone_or_missing(df_raw, 'regiao')
    df_clean['zone'] = clone_or_missing(df_raw, 'zona')
    df_clean['sex'] = clone_or_missing(df_raw, 'sexo')
    df_clean['race_ethnicity'] = clone_or_missing(df_raw, 'e9')
    df_clean['education_level'] = clone_or_missing(df_raw, 'e22')
    
    df_clean['age_years'] = numcopy_special(df_raw, 'idade')
    df_clean['individual_income'] = numcopy_special(df_raw, 'rendaind')
    df_clean['household_income_pc'] = numcopy_special(df_raw, 'rendadompc')
    
    # Age groups
    df_clean['age_group'] = np.nan
    df_clean.loc[(df_clean['age_years'] >= 50) & (df_clean['age_years'] <= 59), 'age_group'] = 1.0
    df_clean.loc[(df_clean['age_years'] >= 60) & (df_clean['age_years'] <= 69), 'age_group'] = 2.0
    df_clean.loc[(df_clean['age_years'] >= 70) & (df_clean['age_years'] <= 79), 'age_group'] = 3.0
    df_clean.loc[df_clean['age_years'] >= 80, 'age_group'] = 4.0
    
    # Chronic conditions
    df_clean['cancer_survivor'] = ynflag(df_raw, 'n60')
    df_clean['cancer_age_dx'] = numcopy_special(df_raw, 'n60_1')
    df_clean['cancer_recent_treatment'] = ynflag(df_raw, 'n60_3')
    df_clean['cancer_treatment_first'] = clone_or_missing(df_raw, 'n60_4')
    df_clean['cancer_course_2y'] = clone_or_missing(df_raw, 'n60_7')
    df_clean['cancer_chemo'] = ynflag(df_raw, 'n60_51')
    df_clean['cancer_surgery'] = ynflag(df_raw, 'n60_52')
    df_clean['cancer_radiation'] = ynflag(df_raw, 'n60_53')
    df_clean['cancer_symptom_medication'] = ynflag(df_raw, 'n60_54')
    df_clean['cancer_other_treatment'] = ynflag(df_raw, 'n60_57')
    
    df_clean['cancer_breast'] = ynflag(df_raw, 'n60_1_1')
    df_clean['cancer_uterus'] = ynflag(df_raw, 'n60_1_2')
    df_clean['cancer_ovary'] = ynflag(df_raw, 'n60_1_3')
    df_clean['cancer_prostate'] = ynflag(df_raw, 'n60_1_4')
    df_clean['cancer_lung'] = ynflag(df_raw, 'n60_1_5')
    df_clean['cancer_skin'] = ynflag(df_raw, 'n60_1_6')
    df_clean['cancer_gi'] = ynflag(df_raw, 'n60_1_7')
    df_clean['cancer_pancreas'] = ynflag(df_raw, 'n60_1_8')
    df_clean['cancer_liver'] = ynflag(df_raw, 'n60_1_9')
    df_clean['cancer_brain'] = ynflag(df_raw, 'n60_1_10')
    df_clean['cancer_leukemia'] = ynflag(df_raw, 'n60_1_11')
    df_clean['cancer_other_site'] = ynflag(df_raw, 'n60_1_12')
    
    df_clean['pap_smear_timing'] = clone_or_missing(df_raw, 'm13')
    df_clean['breast_exam_timing'] = clone_or_missing(df_raw, 'm14')
    df_clean['mammogram_timing'] = clone_or_missing(df_raw, 'm15')
    df_clean['colonoscopy_10y'] = ynflag(df_raw, 'n68_2')
    df_clean['colonoscopy_4y'] = ynflag(df_raw, 'n68_3')
    
    df_clean['stroke_survivor'] = ynflag(df_raw, 'n52')
    df_clean['stroke_age_dx'] = numcopy_special(df_raw, 'n53')
    df_clean['recurrent_stroke'] = ynflag(df_raw, 'n53_2')
    df_clean['stroke_medication'] = ynflag(df_raw, 'n53_4')
    df_clean['stroke_problem'] = ynflag(df_raw, 'n53_5')
    df_clean['stroke_rehab'] = ynflag(df_raw, 'n53_6')
    
    df_clean['chronic_spine_condition'] = ynflag(df_raw, 'n58')
    df_clean['hypertension'] = ynflag(df_raw, 'n28')
    df_clean['diabetes'] = ynflag(df_raw, 'n35')
    df_clean['depression_dx'] = ynflag(df_raw, 'n59')
    
    df_clean['physio_90d'] = ynflag(df_raw, 'u59_1')
    df_clean['occupational_therapy_90d'] = ynflag(df_raw, 'u62_1')
    df_clean['speech_therapy_90d'] = ynflag(df_raw, 'u65_1')
    df_clean['paid_physio_90d'] = ynflag(df_raw, 'u60')
    df_clean['paid_occupational_therapy_90d'] = ynflag(df_raw, 'u63')
    df_clean['paid_speech_therapy_90d'] = ynflag(df_raw, 'u66')
    
    # Frailty proxy exhaustion and weight loss
    df_clean['frailty_weight_loss'] = ynflag(df_raw, 'n69')
    df_clean['frailty_exhaustion'] = df_raw['n73'].map(lambda x: 1.0 if x in [3, 4] else (0.0 if x in [0, 1, 2] else np.nan))
    
    # Physical Activity
    df_clean['walk_days'] = clean_days(df_raw['l5'])
    df_clean['mod_days'] = clean_days(df_raw['l7'])
    df_clean['vig_days'] = clean_days(df_raw['l9'])
    
    if w == 1:
        df_clean['walk_minutes'] = clean_minutes(numcopy_special(df_raw, 'l6'))
        df_clean['mod_minutes'] = clean_minutes(numcopy_special(df_raw, 'l8'))
        df_clean['vig_minutes'] = clean_minutes(numcopy_special(df_raw, 'l10'))
        df_clean['sedentary_minutes_weekday'] = clean_minutes(numcopy_special(df_raw, 'l11'))
    else:
        # waves 2 and 3 use hours and minutes
        walk_hours = numcopy_special(df_raw, 'l6_1')
        walk_min_part = numcopy_special(df_raw, 'l6_2')
        df_clean['walk_minutes'] = clean_minutes(walk_hours * 60 + walk_min_part)
        
        mod_hours = numcopy_special(df_raw, 'l8_1')
        mod_min_part = numcopy_special(df_raw, 'l8_2')
        df_clean['mod_minutes'] = clean_minutes(mod_hours * 60 + mod_min_part)
        
        vig_hours = numcopy_special(df_raw, 'l10_1')
        vig_min_part = numcopy_special(df_raw, 'l10_2')
        df_clean['vig_minutes'] = clean_minutes(vig_hours * 60 + vig_min_part)
        
        sed_hours = numcopy_special(df_raw, 'l11_1')
        sed_min_part = numcopy_special(df_raw, 'l11_2')
        df_clean['sedentary_minutes_weekday'] = clean_minutes(sed_hours * 60 + sed_min_part)
        
    df_clean['walk_total'] = df_clean['walk_days'] * df_clean['walk_minutes']
    df_clean['mod_total'] = df_clean['mod_days'] * df_clean['mod_minutes']
    df_clean['vig_total'] = df_clean['vig_days'] * df_clean['vig_minutes']
    
    df_clean.loc[df_clean['walk_days'] == 0, 'walk_total'] = 0
    df_clean.loc[df_clean['mod_days'] == 0, 'mod_total'] = 0
    df_clean.loc[df_clean['vig_days'] == 0, 'vig_total'] = 0
    df_clean['weekly_activity_minutes'] = df_clean[['walk_total', 'mod_total', 'vig_total']].sum(axis=1, min_count=1)
    
    # Grip strength
    mf27_clean = clean_grip(df_raw, 'mf27')
    mf28_clean = clean_grip(df_raw, 'mf28')
    mf29_clean = clean_grip(df_raw, 'mf29')
    df_clean['grip_max_kg'] = pd.concat([mf27_clean, mf28_clean, mf29_clean], axis=1).max(axis=1)
    
    # Gait speed
    mf35s_clean = clean_gait(df_raw, 'mf35s')
    mf38s_clean = clean_gait(df_raw, 'mf38s')
    df_clean['gait_best_seconds'] = pd.concat([mf35s_clean, mf38s_clean], axis=1).min(axis=1)
    
    # Smoking
    l30 = df_raw['l30'] if 'l30' in df_raw.columns else pd.Series(np.nan, index=df_raw.index)
    l30_0 = df_raw['l30_0'] if 'l30_0' in df_raw.columns else pd.Series(np.nan, index=df_raw.index)
    df_clean['current_smoker'] = l30.map(lambda x: 1.0 if x in [1, 2] else (0.0 if x in [0, 3] else np.nan))
    df_clean.loc[df_clean['current_smoker'].isna() & (l30.isna() | (l30 == 8)) & l30_0.isin([0, 2]), 'current_smoker'] = 0.0
    
    df_clean['former_smoker'] = df_raw['l31'].map(lambda x: 1.0 if x in [1, 2] else np.nan)
    
    # Alcohol
    df_clean['alcohol_frequency'] = clone_or_missing(df_raw, 'l24')
    df_clean['alcohol_days_week'] = numcopy_special(df_raw, 'l25')
    df_clean['alcohol_any'] = df_raw['l24'].map(lambda x: 1.0 if x in [2, 3] else (0.0 if x == 1 else np.nan))
    df_clean.loc[df_clean['alcohol_any'].isna() & df_clean['alcohol_days_week'].notna() & (df_clean['alcohol_days_week'] > 0) & (df_clean['alcohol_days_week'] <= 7), 'alcohol_any'] = 1
    df_clean.loc[df_clean['alcohol_any'].isna() & (df_clean['alcohol_days_week'] == 0), 'alcohol_any'] = 0
    
    df_clean['fruit_days_week'] = numcopy_special(df_raw, 'l19')
    df_clean['vegetable_days_week'] = numcopy_special(df_raw, 'l15')
    
    # Rehab utilisation
    df_clean['rehab_util_any'] = df_clean[['physio_90d', 'occupational_therapy_90d', 'speech_therapy_90d']].max(axis=1)
    df_clean['rehab_paid_any'] = df_clean[['paid_physio_90d', 'paid_occupational_therapy_90d', 'paid_speech_therapy_90d']].max(axis=1)
    
    df_clean['any_rehab_90d'] = np.nan
    df_clean.loc[df_clean['rehab_util_any'].notna(), 'any_rehab_90d'] = df_clean['rehab_util_any']
    df_clean.loc[df_clean['any_rehab_90d'].isna() & df_clean['rehab_paid_any'].notna(), 'any_rehab_90d'] = df_clean['rehab_paid_any']
    
    return df_clean

def clean_grip(df, col):
    if col not in df.columns:
        return pd.Series(np.nan, index=df.index)
    return df[col].map(lambda x: x if (0 <= x <= 120) else np.nan)

def clean_gait(df, col):
    if col not in df.columns:
        return pd.Series(np.nan, index=df.index)
    return df[col].map(lambda x: x if (0.1 <= x <= 120) else np.nan)

# Process waves
w1 = process_wave(1, w1_path)
w2 = process_wave(2, w2_path)
w3 = process_wave(3, w3_path)

# Append all waves
df_all = pd.concat([w1, w2, w3], ignore_index=True)
print(f"\nAppended dataset shape: {df_all.shape} (expected: 30,134?)")
# Stata dataset has 9,412 + 9,949 + 10,773 = 30,134 rows. Let's see:
print("Total rows:", len(df_all))

# Compute cuts by wave
df_all['low_activity_cut'] = df_all.groupby('wave')['weekly_activity_minutes'].transform(lambda x: x.quantile(0.20))
df_all['slow_gait_cut'] = df_all.groupby('wave')['gait_best_seconds'].transform(lambda x: x.quantile(0.80))
df_all['weak_grip_cut'] = df_all.groupby(['wave', 'sex'])['grip_max_kg'].transform(lambda x: x.quantile(0.20))

# Calculate frailty components
df_all['frailty_low_activity'] = np.nan
df_all.loc[df_all['weekly_activity_minutes'].notna(), 'frailty_low_activity'] = (
    df_all.loc[df_all['weekly_activity_minutes'].notna(), 'weekly_activity_minutes'] <= df_all.loc[df_all['weekly_activity_minutes'].notna(), 'low_activity_cut']
).astype(float)

df_all['frailty_slow_gait'] = np.nan
df_all.loc[df_all['gait_best_seconds'].notna(), 'frailty_slow_gait'] = (
    df_all.loc[df_all['gait_best_seconds'].notna(), 'gait_best_seconds'] >= df_all.loc[df_all['gait_best_seconds'].notna(), 'slow_gait_cut']
).astype(float)

df_all['frailty_weak_grip'] = np.nan
df_all.loc[df_all['grip_max_kg'].notna(), 'frailty_weak_grip'] = (
    df_all.loc[df_all['grip_max_kg'].notna(), 'grip_max_kg'] <= df_all.loc[df_all['grip_max_kg'].notna(), 'weak_grip_cut']
).astype(float)

# frailty_available_components
df_all['frailty_available_components'] = df_all[[
    'frailty_weight_loss', 'frailty_exhaustion', 'frailty_low_activity', 'frailty_weak_grip', 'frailty_slow_gait'
]].notna().sum(axis=1)

# frailty_score
df_all['frailty_score'] = df_all[[
    'frailty_weight_loss', 'frailty_exhaustion', 'frailty_low_activity', 'frailty_weak_grip', 'frailty_slow_gait'
]].sum(axis=1)
# if available components < 3, set to NaN
df_all.loc[df_all['frailty_available_components'] < 3, 'frailty_score'] = np.nan

# frailty_group
df_all['frailty_group'] = None
df_all.loc[df_all['frailty_score'] == 0, 'frailty_group'] = "Robust"
df_all.loc[df_all['frailty_score'].isin([1, 2]), 'frailty_group'] = "Prefrail"
df_all.loc[df_all['frailty_score'] >= 3, 'frailty_group'] = "Frail"

# frail_binary
df_all['frail_binary'] = np.nan
df_all.loc[df_all['frailty_score'].notna(), 'frail_binary'] = (
    df_all.loc[df_all['frailty_score'].notna(), 'frailty_score'] >= 3
).astype(float)

# Compare with Stata dataset row by row
df_compare = pd.merge(df_all, df_stata, on=['wave', 'anon_row_id'], suffixes=('_py', '_stata'))

cols_to_compare = [
    'cancer_survivor', 'stroke_survivor', 'chronic_spine_condition',
    'current_smoker', 'former_smoker', 'alcohol_any',
    'weekly_activity_minutes', 'grip_max_kg', 'gait_best_seconds',
    'frailty_low_activity', 'frailty_weak_grip', 'frailty_slow_gait',
    'frailty_score', 'frailty_group', 'frail_binary'
]

print("\n--- Validation across all three waves ---")
for col in cols_to_compare:
    if col in ['weekly_activity_minutes', 'grip_max_kg', 'gait_best_seconds', 'frailty_score']:
        py_vals = df_compare[f'{col}_py'].fillna(-999)
        stata_vals = df_compare[f'{col}_stata'].fillna(-999)
        diff_mask = (py_vals - stata_vals).abs() > 1e-4
    else:
        diff_mask = (df_compare[f'{col}_py'] != df_compare[f'{col}_stata']) & ~(df_compare[f'{col}_py'].isna() & df_compare[f'{col}_stata'].isna())
    print(f"Mismatch for {col}: {diff_mask.sum()}")
    if diff_mask.sum() > 0:
        print("First 5 mismatches:")
        print(df_compare.loc[diff_mask, ['wave', 'anon_row_id', f'{col}_py', f'{col}_stata']].head(5))
        
# Save the cleaned datasets
df_all[df_all['wave'] == 1].to_csv("elsi_wave1_cleaned.csv", index=False)
df_all[df_all['wave'] == 2].to_csv("elsi_wave2_cleaned.csv", index=False)
df_all[df_all['wave'] == 3].to_csv("elsi_wave3_cleaned.csv", index=False)
print("\nSaved wave1, wave2, and wave3 cleaned files to workspace.")
