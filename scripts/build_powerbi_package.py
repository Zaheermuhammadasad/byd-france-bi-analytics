"""Rebuild the four Power BI CSVs in data/powerbi/ from data/processed/ (no MySQL needed).

Implements exactly the logic of sql/04_views.sql + sql/07_powerbi_extract.sql:
  dim_date        34 months, is_complete_year = 12 months of data in that year
  dim_brand       ownership flags + is_residual (AUTRES)
  v_brand_month   comparison universe only (in_market_sum = True)
  v_market_month  market totals, same-month YoY (LAG 12), seasonality index (complete years)
Then checks every output against data/powerbi/MANIFEST.sha256: identical bytes =
identical to the package validated on MySQL 8.0.46.

    python scripts/build_powerbi_package.py
"""
import hashlib, os, sys
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P, OUT = os.path.join(ROOT, "data", "processed"), os.path.join(ROOT, "data", "powerbi")

bm = pd.read_csv(os.path.join(P, "brand_month.csv"))
mm = pd.read_csv(os.path.join(P, "market_month.csv"))
dim = pd.read_csv(os.path.join(P, "dim_brand.csv"))

# dim_date
d = pd.DataFrame({"date_key": pd.date_range("2024-01-01", mm.date.max(), freq="MS")})
d["period"] = d.date_key.dt.strftime("%Y-%m")
d["year"], d["month"] = d.date_key.dt.year, d.date_key.dt.month
d["month_name"], d["quarter"] = d.date_key.dt.strftime("%b"), d.date_key.dt.quarter
d["months_in_data"] = d.groupby("year").month.transform("count")
d["is_complete_year"] = (d.months_in_data == 12).astype(int)
d["date_key"] = d.date_key.dt.strftime("%Y-%m-%d")

# dim_brand
flags = ["is_chinese_owned", "is_chinese_origin", "is_joint_venture", "is_byd"]
b = dim[["brand", "brand_origin_country", "controlling_owner", "controlling_owner_country", "ownership_structure"] + flags].copy()
b[flags] = b[flags].astype(int)
b["is_residual"] = (b.brand == "Other brands (AUTRES)").astype(int)
b = b.sort_values("brand", key=lambda s: s.map(lambda x: x.encode("utf-8")))   # byte order, like the SQL ORDER BY used for export

# v_brand_month (universe only)
u = bm[bm.in_market_sum].rename(columns={"date": "date_key"})
u = u[["date_key", "brand", "registrations_month", "registrations_ytd", "value_type", "source_id"]].copy()
u = u.sort_values(["date_key", "brand"], key=lambda s: s.map(lambda x: x.encode("utf-8")) if s.name == "brand" else s)

# v_market_month
m = mm.rename(columns={"date": "date_key"}).sort_values("date_key")[["date_key", "year", "market_registrations_month", "market_registrations_ytd"]].copy()
m["market_same_month_prev_year"] = m.market_registrations_month.shift(12)
m["market_yoy_pct"] = m.market_registrations_month * 100.0 / m.market_same_month_prev_year - 100
complete = m.year.map(m.groupby("year").size()) == 12
m["seasonality_index"] = (m.market_registrations_month * 100.0 / m.groupby("year").market_registrations_month.transform("mean")).where(complete)
m = m.drop(columns="year")

ints = ["registrations_month", "registrations_ytd", "market_registrations_month", "market_registrations_ytd", "market_same_month_prev_year"]
for name, df in {"dim_date": d, "dim_brand": b, "v_brand_month": u, "v_market_month": m}.items():
    df = df.copy()
    for c in ints:
        if c in df:
            df[c] = df[c].astype("Int64")            # whole numbers; missing stays empty, never 0
    df.to_csv(os.path.join(OUT, name + ".csv"), index=False, float_format="%.6f", lineterminator="\n")

# compare with the manifest of the validated package
bad = 0
for line in open(os.path.join(OUT, "MANIFEST.sha256")):
    if line.strip():
        digest, fname = line.split()
        got = hashlib.sha256(open(os.path.join(OUT, fname), "rb").read()).hexdigest()
        print(f"{'OK      ' if got == digest else 'MISMATCH'} {fname}")
        bad += got != digest
sys.exit(1 if bad else 0)
