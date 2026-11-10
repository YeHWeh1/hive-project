# -*- coding: utf-8 -*-
import pandas as pd, numpy as np, json
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, r2_score

df = pd.read_csv(r"E:\dssgz\kpi\daily.csv", encoding="utf-8-sig")
df["stat_date"] = pd.to_datetime(df["stat_date"])
df = df.sort_values("stat_date").set_index("stat_date")
g = df["gmv"].resample("W-MON").agg(["sum", "count"])
full = g[g["count"] == 7].copy()
full.columns = ["gmv", "days"]
full = full.reset_index().rename(columns={"stat_date": "week_end"})
full["lag1"] = full.gmv.shift(1); full["lag2"] = full.gmv.shift(2)
full["ma4"] = full.gmv.shift(1).rolling(4).mean()
full["woy"] = full.week_end.dt.isocalendar().week.astype(int)
w = full.dropna().reset_index(drop=True)
print("完整周数:", len(w), "范围", w.week_end.min().date(), "~", w.week_end.max().date())

cols = ["lag1", "lag2", "ma4", "woy"]
tr, te = w.iloc[:-8], w.iloc[-8:]
out = []
for name, m in [("线性回归", LinearRegression()),
                ("随机森林", RandomForestRegressor(n_estimators=300, max_depth=6, random_state=42))]:
    m.fit(tr[cols], tr.gmv)
    p = m.predict(te[cols])
    mape = float(np.mean(np.abs((te.gmv - p) / te.gmv)) * 100)
    out.append({"模型": name, "MAE(元)": round(mean_absolute_error(te.gmv, p), 2),
                "MAPE(%)": round(mape, 4), "R2": round(r2_score(te.gmv, p), 4)})
    print(f"{name}: MAE={mean_absolute_error(te.gmv,p):,.2f}  MAPE={mape:.4f}%  R2={r2_score(te.gmv,p):.4f}")

base = np.full(len(te), tr.gmv.mean())
bmape = float(np.mean(np.abs((te.gmv - base) / te.gmv)) * 100)
naive = te.gmv.shift(1).fillna(tr.gmv.mean()).values
nmape = float(np.mean(np.abs((te.gmv - naive) / te.gmv)) * 100)
print(f"基线(训练均值): MAPE={bmape:.4f}%　朴素(上周值): MAPE={nmape:.4f}%")

pd.DataFrame(out).to_csv(r"E:\dssgz\kpi\forecast_weekly_metrics.csv", index=False, encoding="utf-8-sig")
w.to_csv(r"E:\dssgz\kpi\forecast_weekly_series.csv", index=False, encoding="utf-8-sig")
print(json.dumps({"weeks": len(w), "baseline_mape": round(bmape,4), "naive_mape": round(nmape,4),
                  "metrics": out}, ensure_ascii=False))
