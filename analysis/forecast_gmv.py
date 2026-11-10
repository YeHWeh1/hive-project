# -*- coding: utf-8 -*-
"""第 3 周 · 子任务 2：每日 GMV 时间序列分析与 7 天预测

关键设计（区别于部署手册的做法）：
  1. 时间切分：前 11 个月训练、最后 1 个月验证，避免"用训练集自评"
  2. 多模型对比：线性回归 vs 随机森林
  3. 特征包含滞后项、移动平均、星期与月份周期
  4. 未来 7 天用"递归单步预测"，不使用长期外推
"""
import json
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei"]
plt.rcParams["axes.unicode_minus"] = False

DATA = r"E:\dssgz\kpi\daily.csv"
OUT_DIR = r"E:\hive-project\docs\screenshots"
OUT_DATA = r"E:\dssgz\kpi"
os.makedirs(OUT_DIR, exist_ok=True)

# ---------- 1. 数据准备 ----------
df = pd.read_csv(DATA, encoding="utf-8-sig")
df["stat_date"] = pd.to_datetime(df["stat_date"])
df = df.sort_values("stat_date").reset_index(drop=True)
df["gmv"] = df["gmv"].astype(float)
print(f"数据范围 {df.stat_date.min().date()} ~ {df.stat_date.max().date()}，共 {len(df)} 天")
print(f"GMV 均值 {df.gmv.mean():,.2f}　标准差 {df.gmv.std():,.2f}　变异系数 {df.gmv.std()/df.gmv.mean():.4f}")

# ---------- 2. 特征工程 ----------
def add_features(d):
    d = d.copy()
    d["lag1"] = d["gmv"].shift(1)
    d["lag7"] = d["gmv"].shift(7)
    d["lag14"] = d["gmv"].shift(14)
    d["ma7"] = d["gmv"].shift(1).rolling(7).mean()
    d["ma30"] = d["gmv"].shift(1).rolling(30).mean()
    d["dow"] = d["stat_date"].dt.dayofweek
    d["month"] = d["stat_date"].dt.month
    d["is_weekend"] = (d["dow"] >= 5).astype(int)
    return d


df = add_features(df)
feat_cols = ["lag1", "lag7", "lag14", "ma7", "ma30", "dow", "month", "is_weekend"]
model_df = df.dropna(subset=feat_cols).reset_index(drop=True)

# ---------- 3. 时间切分 ----------
split_date = pd.Timestamp("2024-12-01")
train = model_df[model_df.stat_date < split_date]
test = model_df[model_df.stat_date >= split_date]
print(f"训练集 {len(train)} 天（~2024-11-30），验证集 {len(test)} 天（2024-12）")

X_train, y_train = train[feat_cols], train["gmv"]
X_test, y_test = test[feat_cols], test["gmv"]

# ---------- 4. 建模与评估 ----------
models = {
    "线性回归": LinearRegression(),
    "随机森林": RandomForestRegressor(n_estimators=300, max_depth=8, random_state=42, n_jobs=-1),
}

results = []
preds = {}
for name, model in models.items():
    model.fit(X_train, y_train)
    p = model.predict(X_test)
    preds[name] = p
    mae = mean_absolute_error(y_test, p)
    rmse = np.sqrt(mean_squared_error(y_test, p))
    mape = np.mean(np.abs((y_test - p) / y_test)) * 100
    r2 = r2_score(y_test, p)
    results.append({"模型": name, "MAE(元)": round(mae, 2), "RMSE(元)": round(rmse, 2),
                    "MAPE(%)": round(mape, 4), "R2": round(r2, 4)})
    print(f"{name}: MAE={mae:,.2f}  RMSE={rmse:,.2f}  MAPE={mape:.4f}%  R2={r2:.4f}")

res_df = pd.DataFrame(results)
best_name = res_df.sort_values("MAPE(%)").iloc[0]["模型"]
print(f"最优模型（按 MAPE）：{best_name}")

# 基线：用训练集均值预测
base_pred = np.full(len(y_test), y_train.mean())
base_mape = np.mean(np.abs((y_test - base_pred) / y_test)) * 100
print(f"基线（训练集均值）MAPE={base_mape:.4f}%")

# ---------- 5. 未来 7 天递归预测 ----------
final_model = models[best_name]
full = add_features(df)
y_all = full["gmv"].values
hist = full[["stat_date", "gmv"]].copy()

# 用全量数据重训
X_all = full.dropna(subset=feat_cols)[feat_cols]
y_all_train = full.dropna(subset=feat_cols)["gmv"]
final_model.fit(X_all, y_all_train)

last_date = df["stat_date"].max()
future_rows = []
series = df.set_index("stat_date")["gmv"].copy()

for i in range(1, 8):
    d = last_date + pd.Timedelta(days=i)
    tmp = pd.DataFrame({"stat_date": list(series.index) + [d],
                        "gmv": list(series.values) + [np.nan]})
    tmp = add_features(tmp)
    row = tmp.iloc[-1]
    x = row[feat_cols].astype(float).values.reshape(1, -1)
    yhat = float(final_model.predict(x)[0])
    yhat = max(yhat, 0)
    series.loc[d] = yhat
    future_rows.append({"date": d.strftime("%Y-%m-%d"), "pred_gmv": round(yhat, 2)})

fut_df = pd.DataFrame(future_rows)
print("\n未来 7 天预测：")
print(fut_df.to_string(index=False))

# ---------- 6. 图表 ----------
# 图 1：全期 GMV + 30 日移动平均
fig, ax = plt.subplots(figsize=(11, 4))
ax.plot(df.stat_date, df.gmv, lw=0.8, color="#8faadc", label="每日 GMV")
ax.plot(df.stat_date, df.gmv.rolling(30).mean(), lw=2, color="#1f3864", label="30 日移动平均")
ax.set_title("每日 GMV 与 30 日移动平均（2024 全年）", fontsize=13)
ax.set_ylabel("GMV（元）")
ax.legend()
ax.grid(alpha=0.3)
fig.autofmt_xdate()
fig.tight_layout()
fig.savefig(os.path.join(OUT_DIR, "forecast_1_daily.png"), dpi=130)
plt.close(fig)

# 图 2：验证集 实际 vs 预测
fig, ax = plt.subplots(figsize=(11, 4))
ax.plot(test.stat_date, y_test.values, marker="o", ms=3, lw=1.2, label="实际 GMV", color="#1f3864")
for name, p in preds.items():
    ax.plot(test.stat_date, p, marker="s", ms=3, lw=1.2, ls="--", label=f"{name} 预测")
ax.set_title("验证集（2024-12）：实际 vs 预测", fontsize=13)
ax.set_ylabel("GMV（元）")
ax.legend()
ax.grid(alpha=0.3)
fig.autofmt_xdate()
fig.tight_layout()
fig.savefig(os.path.join(OUT_DIR, "forecast_2_validation.png"), dpi=130)
plt.close(fig)

# 图 3：尾部 60 天 + 未来 7 天预测
tail = df.tail(60)
fig, ax = plt.subplots(figsize=(11, 4))
ax.plot(tail.stat_date, tail.gmv, lw=1.5, color="#1f3864", label="历史 GMV（最近 60 天）")
fut_dates = pd.to_datetime(fut_df.date)
ax.plot(fut_dates, fut_df.pred_gmv, marker="o", ms=5, lw=2, ls="--", color="#c00000", label="未来 7 天预测")
ax.axvline(last_date, color="gray", ls=":", lw=1)
ax.set_title("未来 7 天 GMV 预测", fontsize=13)
ax.set_ylabel("GMV（元）")
ax.legend()
ax.grid(alpha=0.3)
fig.autofmt_xdate()
fig.tight_layout()
fig.savefig(os.path.join(OUT_DIR, "forecast_3_next7.png"), dpi=130)
plt.close(fig)

# 图 4：月度 GMV
m = df.set_index("stat_date")["gmv"].resample("MS").sum()
fig, ax = plt.subplots(figsize=(9, 3.8))
ax.bar([d.strftime("%m月") for d in m.index], m.values, color="#4472c4")
ax.set_title("月度 GMV（2024）", fontsize=13)
ax.set_ylabel("GMV（元）")
for i, v in enumerate(m.values):
    ax.text(i, v, f"{v/10000:.0f}万", ha="center", va="bottom", fontsize=8)
ax.grid(axis="y", alpha=0.3)
fig.tight_layout()
fig.savefig(os.path.join(OUT_DIR, "forecast_4_monthly.png"), dpi=130)
plt.close(fig)

# ---------- 7. 保存结果 ----------
res_df["基线MAPE(%)"] = round(base_mape, 4)
res_df.to_csv(os.path.join(OUT_DATA, "forecast_metrics.csv"), index=False, encoding="utf-8-sig")
fut_df.to_csv(os.path.join(OUT_DATA, "forecast_next7.csv"), index=False, encoding="utf-8-sig")

summary = {
    "days": len(df),
    "gmv_mean": round(df.gmv.mean(), 2),
    "gmv_std": round(df.gmv.std(), 2),
    "cv": round(df.gmv.std() / df.gmv.mean(), 4),
    "train_days": len(train),
    "test_days": len(test),
    "metrics": results,
    "baseline_mape": round(base_mape, 4),
    "best_model": best_name,
    "next7_total": round(fut_df.pred_gmv.sum(), 2),
    "next7_avg": round(fut_df.pred_gmv.mean(), 2),
}
with open(os.path.join(OUT_DATA, "forecast_summary.json"), "w", encoding="utf-8") as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)

print("\n图片已输出到:", OUT_DIR)
print("未来 7 天合计预测:", f"{summary['next7_total']:,.2f} 元")
