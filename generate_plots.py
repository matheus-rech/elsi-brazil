import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Set style
sns.set_theme(style="whitegrid")
plt.rcParams["figure.figsize"] = (10, 6)
plt.rcParams["font.size"] = 12

# Load clean datasets
df1 = pd.read_csv("elsi_wave1_cleaned.csv")
df2 = pd.read_csv("elsi_wave2_cleaned.csv")
df3 = pd.read_csv("elsi_wave3_cleaned.csv")

# Append them
df_all = pd.concat([df1, df2, df3], ignore_index=True)
df_all['wave_label'] = df_all['wave'].map({1: 'Wave 1 (2015-16)', 2: 'Wave 2 (2019-21)', 3: 'Wave 3 (2023-24)'})
df_all['sex_label'] = df_all['sex'].map({0: 'Feminino', 1: 'Masculino'})
df_all['region_label'] = df_all['region'].map({1: 'Norte', 2: 'Nordeste', 3: 'Sudeste', 4: 'Sul', 5: 'Centro-Oeste'})
df_all['zone_label'] = df_all['zone'].map({1: 'Urbano', 2: 'Rural'})

# 1. Plot: Frailty Group Trends across Waves
plt.figure(figsize=(10, 6))
# Calculate weighted percentages for each wave
# To be mathematically precise, we should use survey weights
def get_weighted_pct(df_group, weight_col, val_col):
    # returns value counts weighted
    weighted_counts = df_group.groupby(val_col)[weight_col].sum()
    return weighted_counts / weighted_counts.sum() * 100

frailty_trends = []
for w, label in [(1, '2015-16'), (2, '2019-21'), (3, '2023-24')]:
    sub = df_all[df_all['wave'] == w].dropna(subset=['frailty_group', 'peso_calibrado'])
    w_pcts = get_weighted_pct(sub, 'peso_calibrado', 'frailty_group')
    for g in ['Robust', 'Prefrail', 'Frail']:
        frailty_trends.append({
            'Wave': label,
            'Status': g,
            'Percentage': w_pcts.get(g, 0)
        })
df_trends = pd.DataFrame(frailty_trends)

sns.lineplot(data=df_trends, x='Wave', y='Percentage', hue='Status', marker='o', linewidth=2.5, palette=['#5ab4ac', '#f5f5f5', '#d8b365'])
plt.title("ELSI-Brazil: Trends in Frailty Status Across Waves (Weighted %)")
plt.xlabel("Study Wave (Years)")
plt.ylabel("Prevalence (%)")
plt.ylim(0, 70)
for idx, row in df_trends.iterrows():
    plt.text(row['Wave'], row['Percentage'] + 1.5, f"{row['Percentage']:.1f}%", ha='center')
plt.tight_layout()
plt.savefig("plot_frailty_trends.png", dpi=300)
plt.close()

# 2. Plot: Rehabilitation Access among Stroke Survivors in Waves 2 & 3
stroke_sub = df_all[df_all['stroke_survivor'] == 1].copy()
rehab_trends = []
for w, label in [(2, 'Wave 2 (2019-21)'), (3, 'Wave 3 (2023-24)')]:
    sub = stroke_sub[(stroke_sub['wave'] == w) & stroke_sub['stroke_rehab'].notna()]
    weighted_rehab = sub.groupby('stroke_rehab')['peso_calibrado'].sum()
    pct = (weighted_rehab.get(1.0, 0) / weighted_rehab.sum()) * 100
    rehab_trends.append({
        'Wave': label,
        'Rehabilitation Access (%)': pct
    })
df_rehab = pd.DataFrame(rehab_trends)

plt.figure(figsize=(8, 6))
sns.barplot(data=df_rehab, x='Wave', y='Rehabilitation Access (%)', palette='Blues_d', edgecolor='black')
plt.title("Rehabilitation Access among Stroke Survivors (Weighted %)")
plt.ylabel("Received Rehab (%)")
plt.ylim(0, 100)
for idx, row in df_rehab.iterrows():
    plt.text(idx, row['Rehabilitation Access (%)'] + 2, f"{row['Rehabilitation Access (%)']:.1f}%", ha='center', fontweight='bold')
plt.tight_layout()
plt.savefig("plot_stroke_rehab_wave.png", dpi=300)
plt.close()

# 3. Plot: Rehabilitation Access by Region (Waves 2 & 3 combined)
# We pool Waves 2 and 3 stroke survivors to examine regional disparities
stroke_w23 = stroke_sub[stroke_sub['wave'].isin([2, 3])].dropna(subset=['stroke_rehab', 'region_label'])
rehab_reg = []
for reg in ['Norte', 'Nordeste', 'Sudeste', 'Sul', 'Centro-Oeste']:
    sub = stroke_w23[stroke_w23['region_label'] == reg]
    weighted = sub.groupby('stroke_rehab')['peso_calibrado'].sum()
    pct = (weighted.get(1.0, 0) / weighted.sum()) * 100
    rehab_reg.append({
        'Region': reg,
        'Rehab Access (%)': pct,
        'N (unweighted)': len(sub)
    })
df_rehab_reg = pd.DataFrame(rehab_reg)

plt.figure(figsize=(10, 6))
sns.barplot(data=df_rehab_reg, x='Region', y='Rehab Access (%)', palette='GnBu_r', edgecolor='black')
plt.title("Rehabilitation Access among Stroke Survivors by Region (Waves 2-3 Pooled)")
plt.ylabel("Received Rehab (%)")
plt.ylim(0, 100)
for idx, row in df_rehab_reg.iterrows():
    plt.text(idx, row['Rehab Access (%)'] + 2, f"{row['Rehab Access (%)']:.1f}%\n(N={row['N (unweighted)']})", ha='center', fontsize=10)
plt.tight_layout()
plt.savefig("plot_rehab_by_region.png", dpi=300)
plt.close()

# 4. Plot: Rehab Access by Zone (Waves 2 & 3 combined)
stroke_zone = stroke_sub[stroke_sub['wave'].isin([2, 3])].dropna(subset=['stroke_rehab', 'zone_label'])
rehab_zone = []
for zone in ['Urbano', 'Rural']:
    sub = stroke_zone[stroke_zone['zone_label'] == zone]
    weighted = sub.groupby('stroke_rehab')['peso_calibrado'].sum()
    pct = (weighted.get(1.0, 0) / weighted.sum()) * 100
    rehab_zone.append({
        'Zone': zone,
        'Rehab Access (%)': pct,
        'N (unweighted)': len(sub)
    })
df_rehab_zone = pd.DataFrame(rehab_zone)

plt.figure(figsize=(8, 6))
sns.barplot(data=df_rehab_zone, x='Zone', y='Rehab Access (%)', palette='Oranges_d', edgecolor='black')
plt.title("Rehabilitation Access among Stroke Survivors by Urban/Rural Zone (Waves 2-3 Pooled)")
plt.ylabel("Received Rehab (%)")
plt.ylim(0, 100)
for idx, row in df_rehab_zone.iterrows():
    plt.text(idx, row['Rehab Access (%)'] + 2, f"{row['Rehab Access (%)']:.1f}%\n(N={row['N (unweighted)']})", ha='center', fontweight='bold')
plt.tight_layout()
plt.savefig("plot_rehab_by_zone.png", dpi=300)
plt.close()

print("Cross-wave plots generated successfully!")
