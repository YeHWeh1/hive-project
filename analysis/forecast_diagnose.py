# -*- coding: utf-8 -*-
import pandas as pd, numpy as np, json
df = pd.read_csv(r"E:\dssgz\kpi\daily.csv", encoding="utf-8-sig")
df["stat_date"] = pd.to_datetime(df["stat_date"])
s = df.set_index("stat_date")["gmv"].astype(float)

# 自相关
print("=== 自相关系数 ===")
acf = {f"lag{k}": round(float(s.autocorr(lag=k)), 4) for k in range(1, 8)}
for k, v in acf.items(): print(f"  {k}: {v:+.4f}")

# 星期效应
print("=== 星期均值 ===")
dow = s.groupby(s.index.day_of_week).agg(["mean","std","count"])
names = ["周一","周二","周三","周四","周五","周六","周日"]
for i, row in dow.iterrows():
    print(f"  {names[i]}: 均值 {row['mean']:,.0f}　标准差 {row['std']:,.0f}")
rng = dow["mean"].max() - dow["mean"].min()
print(f"  星期均值极差: {rng:,.0f} 元（占均值 {rng/s.mean()*100:.2f}%）")

# 趋势
print("=== 趋势 ===")
x = np.arange(len(s))
slope = np.polyfit(x, s.values, 1)[0]
print(f"  线性趋势斜率: {slope:,.2f} 元/天（全年变化约 {slope*365:,.0f} 元，占均值 {abs(slope*365)/s.mean()*100:.2f}%）")

# 月度
m = s.resample("MS").sum()
print("=== 月度 GMV ===")
for d, v in m.items(): print(f"  {d.strftime('%Y-%m')}: {v:,.0f}")
print(f"  月度极差: {m.max()-m.min():,.0f}（{((m.max()-m.min())/m.mean()*100):.2f}%）")

json.dump({"acf": acf, "dow_mean": {names[i]: round(float(r),2) for i,r in dow["mean"].items()},
           "dow_range_pct": round(float(rng/s.mean()*100),2),
           "trend_per_day": round(float(slope),2),
           "trend_year_pct": round(float(abs(slope*365)/s.mean()*100),2),
           "monthly_range_pct": round(float((m.max()-m.min())/m.mean()*100),2),
           "gmv_mean": round(float(s.mean()),2), "gmv_std": round(float(s.std()),2),
           "cv": round(float(s.std()/s.mean()),4)},
          open(r"E:\dssgz\kpi\forecast_diag.json","w",encoding="utf-8"), ensure_ascii=False, indent=2)
