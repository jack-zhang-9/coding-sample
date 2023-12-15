import pandas as pd
import numpy as np
import math
import matplotlib.pyplot as plt

#  Set working directory
data_path = "D:/张知遥/武汉大学/刘淼RA/Are Chinese Growth and Inflation Too Smooth Evidence from Engel Curves/Replication_1995-2022/data"
est_1995_2011 = pd.read_stata(f"{data_path}/Estimation Region 1995-2011.dta")
expfood_2012_2022 = pd.read_excel(f"{data_path}/ExpenditureFood 2012-2022.xlsx", skiprows=1,
                                  names=["year", "region", "scope", "total_exp", "food_exp"])
CPIfood_2012_2022 = pd.read_excel(f"{data_path}/PriceIndexFood 2012-2022.xlsx", skiprows=1,
                                  names=["year", "region", "CPIoverall", "CPIfood"])

# 2. Combine data
est_food_1995_2011 = est_1995_2011[est_1995_2011['year'] >= 1995][['year', 'region', 'CPIFood', 'expenditureFood', 'CPIOverall', 'TotalExpenditures']]
region_nm_transition = pd.read_excel(f"{data_path}/RegionNameTransition.xlsx", header=0)
est_food_1995_2011 = (est_food_1995_2011.rename(columns={'region': 'region_nm'})
                      .merge(region_nm_transition, left_on='region_nm', right_on='region_nm')
                      .drop('region_nm', axis=1)
                      .rename(columns={'expenditureFood': 'food_exp', 'TotalExpenditures': 'total_exp', 'CPIOverall': 'CPIoverall', 'CPIFood': 'CPIfood'}))
est_food_2012_2022 = (expfood_2012_2022.merge(CPIfood_2012_2022, on=['year', 'region'])
                      .query('year >= 2012 and region not in [156, 540000]'))

est_food = pd.concat([est_food_1995_2011, est_food_2012_2022]).sort_values(by=['region', 'year'])

# 3. Calculate chained inflation and relative price
def chained_inflation(CPI):
    chain_infl = np.zeros(len(CPI))
    CPI = CPI / 100
    for i in range(len(CPI)):
        if not math.isnan(CPI[i]):
            if i == 0 or math.isnan(CPI[i - 1]):
                chain_infl[i] = 1
            else:
                chain_infl[i] = chain_infl[i - 1] * CPI[i]
        else:
            chain_infl[i] = np.nan
    return chain_infl

est_food = (est_food.groupby('region')
            .apply(lambda x: x.sort_values(by='year'))
            .assign(chain_infl_overall=lambda x: chained_inflation(x['CPIoverall']),
                    chain_infl_food=lambda x: chained_inflation(x['CPIfood']),
                    food_exp_share=lambda x: x['food_exp'] / x['total_exp'],
                    price_CPI_food=lambda x: np.log(x['chain_infl_food']) - np.log(x['chain_infl_overall']),
                    real_total_exp=lambda x: np.log(x['total_exp']) - np.log(x['chain_infl_overall']))
            .reset_index(drop=True))

# 4. Merge other control variables
household = pd.read_excel(f"{data_path}/household.xlsx")
unemployment = pd.read_excel(f"{data_path}/unemployment.xlsx")
dependencyrate = pd.read_excel(f"{data_path}/dependencyrate.xlsx")

control = (household[household['year'] >= 1995]
           .query('region not in [156, 540000]')
           .merge(unemployment, on=['year', 'region'], how='left')
           .merge(dependencyrate, on=['year', 'region'], how='left'))

est_food = (est_food.merge(control, on=['year', 'region'], how='left')
            .filter(items=['year', 'region'] + list(est_food.columns)))

# Write to Stata file
est_food.to_stata(f"{data_path}/Estimation Food.dta")

# 5. Data check
est_food_long = pd.melt(est_food, id_vars=['year'], value_vars=['price_CPI_food', 'food_exp_share', 'real_total_exp'])

plt.figure(figsize=(10, 6))
plt.subplot(3, 1, 1)
plt.title('price_CPI_food')
sns.boxplot(x='year', y='value', data=est_food_long[est_food_long['variable'] == 'price_CPI_food'])
plt.subplot(3, 1, 2)
plt.title('food_exp_share')
sns.boxplot(x='year', y='value', data=est_food_long[est_food_long['variable'] == 'food_exp_share'])
plt.subplot(3, 1, 3)
plt.title('real_total_exp')
sns.boxplot(x='year', y='value', data=est_food_long[est_food_long['variable'] == 'real_total_exp'])
plt.tight_layout()
plt.show()
