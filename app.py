import streamlit as st
import pandas as pd
import numpy as np
import sqlite3
import statsmodels.api as sm
import statsmodels.formula.api as smf
import matplotlib.pyplot as plt
import seaborn as sns

# Set page layout and aesthetics
st.set_page_config(
    page_title="ELSI-Brazil Cohort Dashboard",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom premium styling inject
st.markdown("""
<style>
    .metric-card {
        background-color: #f8f9fa;
        padding: 20px;
        border-radius: 10px;
        border-left: 5px solid #2b6cb0;
        box-shadow: 2px 2px 5px rgba(0,0,0,0.05);
    }
    .metric-value {
        font-size: 28px;
        font-weight: bold;
        color: #2d3748;
    }
    .metric-label {
        font-size: 14px;
        color: #718096;
        text-transform: uppercase;
        letter-spacing: 1px;
    }
</style>
""", unsafe_allow_html=True)

DB_PATH = "elsi_brazil.db"

# Cache database connection for performance
def get_data(query):
    conn = sqlite3.connect(DB_PATH)
    df = pd.read_sql_query(query, conn)
    conn.close()
    return df

st.title("ELSI-Brazil: Longitudinal Study of Aging Dashboard")
st.markdown("""
Coordinated by **UFMG** and **FIOCRUZ-MG**, and funded by the **Brazilian Ministry of Health**, 
ELSI-Brazil is a representative cohort study of community-dwelling adults aged 50+. This dashboard provides 
exploratory analysis, descriptive analytics, and live survey-weighted statistical modeling across Waves 1, 2, and 3.
""")

# Sidebar settings
st.sidebar.header("Cohort Settings")
selected_wave = st.sidebar.selectbox("Select Study Wave", [1, 2, 3], format_func=lambda x: f"Wave {x} ({'2015-16' if x==1 else '2019-21' if x==2 else '2023-24'})")

# Retrieve wave data
try:
    df_wave = get_data(f"SELECT * FROM wave{selected_wave}")
    df_pooled = get_data("SELECT * FROM pooled_waves")
except Exception as e:
    st.error(f"Error loading SQLite database: {e}. Please ensure elsi_brazil.db is generated.")
    st.stop()

# 1. KPI Panel
st.header("1. Core Cohort Metrics")
col1, col2, col3, col4 = st.columns(4)

# Calculate weighted metrics
n_obs = len(df_wave)
# Frailty % (weighted)
df_frail_valid = df_wave.dropna(subset=['frail_binary', 'peso_calibrado'])
weighted_frail_sum = df_frail_valid.groupby('frail_binary')['peso_calibrado'].sum()
frail_pct = (weighted_frail_sum.get(1.0, 0) / weighted_frail_sum.sum()) * 100

# Spine condition % (weighted)
df_spine_valid = df_wave.dropna(subset=['chronic_spine_condition', 'peso_calibrado'])
weighted_spine_sum = df_spine_valid.groupby('chronic_spine_condition')['peso_calibrado'].sum()
spine_pct = (weighted_spine_sum.get(1.0, 0) / weighted_spine_sum.sum()) * 100

# Rehab access % (weighted, Wave 2-3 only)
rehab_str = "N/A (Wave 1)"
if selected_wave in [2, 3]:
    df_rehab_valid = df_wave[df_wave['stroke_survivor'] == 1].dropna(subset=['stroke_rehab', 'peso_calibrado'])
    if len(df_rehab_valid) > 0:
        weighted_rehab_sum = df_rehab_valid.groupby('stroke_rehab')['peso_calibrado'].sum()
        rehab_pct = (weighted_rehab_sum.get(1.0, 0) / weighted_rehab_sum.sum()) * 100
        rehab_str = f"{rehab_pct:.1f}%"
    else:
        rehab_str = "0.0%"

with col1:
    st.markdown(f'<div class="metric-card"><div class="metric-label">Sample Size (N)</div><div class="metric-value">{n_obs:,}</div></div>', unsafe_allow_html=True)
with col2:
    st.markdown(f'<div class="metric-card"><div class="metric-label">Frailty Prevalence</div><div class="metric-value">{frail_pct:.1f}%</div></div>', unsafe_allow_html=True)
with col3:
    st.markdown(f'<div class="metric-card"><div class="metric-label">Spine Conditions</div><div class="metric-value">{spine_pct:.1f}%</div></div>', unsafe_allow_html=True)
with col4:
    st.markdown(f'<div class="metric-card"><div class="metric-label">Stroke Rehab Access</div><div class="metric-value">{rehab_str}</div></div>', unsafe_allow_html=True)

st.write("")

# 2. Visualization Panel
st.header("2. Explanatory Visualizations")
vis_col1, vis_col2 = st.columns(2)

with vis_col1:
    st.subheader("Physical Measure: Grip Strength Distribution")
    # Histplot of grip max
    fig_grip, ax_grip = plt.subplots(figsize=(6, 4))
    sns.histplot(data=df_wave.dropna(subset=['grip_max_kg', 'sex']), x='grip_max_kg', hue='sex', kde=True, palette='coolwarm', ax=ax_grip)
    ax_grip.set_title("Maximum Grip Strength (kg) by Sex")
    ax_grip.set_xlabel("Strength (kg)")
    st.pyplot(fig_grip)

with vis_col2:
    st.subheader("Physical Activity Cuts (20th Percentile)")
    # Density plot of physical activity
    fig_act, ax_act = plt.subplots(figsize=(6, 4))
    sns.kdeplot(data=df_wave.dropna(subset=['weekly_activity_minutes']), x='weekly_activity_minutes', fill=True, color='teal', ax=ax_act)
    # Add vertical line for 20th cut
    cut_20 = df_wave['weekly_activity_minutes'].quantile(0.20)
    ax_act.axvline(cut_20, color='red', linestyle='--', linewidth=2, label=f"20th Percentile ({cut_20:.1f} mins)")
    ax_act.set_title("Weekly Physical Activity Minutes")
    ax_act.set_xlabel("Minutes / Week")
    ax_act.legend()
    st.pyplot(fig_act)

# 3. Survey-Weighted Modeling Panel
st.header("3. Survey-Weighted Statistical Modeling (GLM Logit)")
st.markdown("""
Observational study analysis must account for complex survey designs. This section automatically fits a survey-weighted **Generalized Linear Model (GLM)** with binomial family and logit link, clustering standard errors on primary sampling units (`upa`) to match Stata/R outputs.
""")

model_col1, model_col2 = st.columns([1, 2])

with model_col1:
    st.subheader("Configure Regression Model")
    outcome_var = st.selectbox("Outcome (Y)", ['frail_binary', 'stroke_rehab', 'hypertension', 'diabetes'])
    exposure_var = st.selectbox("Exposure (X)", ['cancer_survivor', 'stroke_survivor', 'chronic_spine_condition', 'current_smoker', 'alcohol_any'])
    
    st.write("Adjusting Covariates:")
    adj_age = st.checkbox("Age (years)", value=True)
    adj_sex = st.checkbox("Sex (Feminino/Masculino)", value=True)
    adj_region = st.checkbox("Region", value=True)
    adj_zone = st.checkbox("Zone (Urbano/Rural)", value=True)
    
    fit_clicked = st.button("Fit Logistic Model", type="primary")

with model_col2:
    st.subheader("Model Results & Interpretation")
    if fit_clicked:
        # Build formula
        cov_list = []
        if adj_age: cov_list.append("age_years")
        if adj_sex: cov_list.append("C(sex)")
        if adj_region: cov_list.append("C(region)")
        if adj_zone: cov_list.append("C(zone)")
        
        formula = f"{outcome_var} ~ C({exposure_var})"
        if cov_list:
            formula += " + " + " + ".join(cov_list)
            
        with st.spinner("Fitting survey GLM model..."):
            try:
                required_cols = [outcome_var, exposure_var, "peso_calibrado", "upa"]
                for c in ["age_years", "sex", "region", "zone"]:
                    if c in formula:
                        required_cols.append(c)
                model_df = df_wave.dropna(subset=required_cols).copy()
                
                # Fit weighted GLM
                model = smf.glm(
                    formula,
                    data=model_df,
                    family=sm.families.Binomial(),
                    var_weights=model_df['peso_calibrado']
                )
                results = model.fit(cov_type='cluster', cov_kwds={'groups': model_df['upa']})
                
                # Expose results
                res_df = []
                for index in results.params.index:
                    coef = results.params[index]
                    se = results.bse[index]
                    pval = results.pvalues[index]
                    or_val = np.exp(coef)
                    ci_low = np.exp(coef - 1.96 * se)
                    ci_high = np.exp(coef + 1.96 * se)
                    
                    res_df.append({
                        "Term": index,
                        "Odds Ratio (OR)": f"{or_val:.4f}",
                        "95% Confidence Interval": f"[{ci_low:.4f}, {ci_high:.4f}]",
                        "P-value": f"{pval:.4f}"
                    })
                    
                st.dataframe(pd.DataFrame(res_df), use_container_width=True)
                st.success(f"Successfully fit GLM on N = {len(model_df):,} observations.")
                
                # Narrative explanation
                exp_idx = f"C({exposure_var})[T.1.0]"
                if exp_idx in results.params.index:
                    or_exp = np.exp(results.params[exp_idx])
                    pval_exp = results.pvalues[exp_idx]
                    sig_str = "significantly" if pval_exp < 0.05 else "not significantly"
                    st.info(f"**Interpretation**: Adjusting for covariates, exposure **{exposure_var}** is {sig_str} associated with outcome **{outcome_var}** (OR = **{or_exp:.2f}**, $p$ = **{pval_exp:.4f}**).")
            except Exception as e:
                st.error(f"Error fitting model: {e}. Please ensure variables are correctly mapped.")
    else:
        st.write("Click 'Fit Logistic Model' to view survey regression outputs.")
