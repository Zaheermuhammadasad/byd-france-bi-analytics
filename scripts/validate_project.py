"""Automated validation for the BYD France BI project.

Re-checks the published data and KPIs from scratch. It needs only pandas, plus
poppler's `pdftotext` for the optional --pdf check. It never modifies any file.

    python scripts/validate_project.py                 # data + KPI checks
    python scripts/validate_project.py --pdf           # + independent re-extraction of every CCFA PDF
    python scripts/validate_project.py --powerbi data/powerbi   # + Power BI package checks

Exit code 0 = every check passed; 1 = at least one failed.
"""
import argparse, glob, hashlib, os, re, subprocess, sys
import numpy as np
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "data", "processed")
results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))


# ------------------------------------------------------------------ load
raw = pd.read_csv(os.path.join(P, "brand_month_raw.csv"))
bm = pd.read_csv(os.path.join(P, "brand_month.csv"))
mm = pd.read_csv(os.path.join(P, "market_month.csv"))
dim = pd.read_csv(os.path.join(P, "dim_brand.csv"))
AUTRES = "Other brands (AUTRES)"

# ------------------------------------------------------------------ 1. structure
expected_periods = [f"{y}-{m:02d}" for y in (2024, 2025, 2026) for m in range(1, 13) if not (y == 2026 and m > 10)]
check("D01 34 consecutive months, Jan 2024 - Oct 2026", sorted(bm.period.unique()) == expected_periods)
check("D02 no duplicate brand-month keys", not bm.duplicated(["period", "brand"]).any())
check("D03 one market row per month", len(mm) == 34 and not mm.period.duplicated().any())

# ------------------------------------------------------------------ 2. extraction consistency
x = (bm[bm.registrations_month.notna() & bm.share_month_pct.notna()]
     .drop(columns=["market_registrations_month", "market_registrations_ytd"])
     .merge(mm[["period", "market_registrations_month"]], on="period"))
d = (x.registrations_month / x.market_registrations_month * 100 - x.share_month_pct).abs()
check("D04 CCFA printed share = registrations / market (all rows, <= 0.001 pp)", d.max() <= 0.001, f"max diff {d.max():.4f} pp")
t = raw[raw.is_total_row].set_index("period")
m = mm.set_index("period")
check("D05 market table = CCFA printed Total (month and YTD)",
      (m.market_registrations_month == t.registrations_month).all() and (m.market_registrations_ytd == t.registrations_ytd).all())

# ------------------------------------------------------------------ 3. traceability
r = raw[~raw.is_total_row]
j = bm[bm.value_type == "actual"].merge(r[["period", "brand_label", "registrations_month"]].rename(
    columns={"registrations_month": "raw_m"}), on=["period", "brand_label"], how="left")
check("D06 every 'actual' monthly value equals its raw PDF row", (j.registrations_month == j.raw_m).all())
fa = bm[bm.brand == "Fiat + Abarth"].set_index("period").registrations_month
comp = r[r.brand_label.isin(["FIAT", "ABARTH", "ABARTH/FIAT"])].groupby("period").registrations_month.sum()
check("D07 'Fiat + Abarth' = sum of its components every month", (fa == comp.reindex(fa.index)).all())
nl = bm[bm.value_type == "not_listed"]
check("D08 not-listed rows are empty, never 0", nl[["registrations_month", "registrations_ytd"]].isna().all().all())
check("D09 only 1 imputed value (Jaguar YTD, Jan 2025)",
      bm[bm.value_type == "imputed"][["brand", "period"]].values.tolist() == [["Jaguar", "2025-01"]])

# ------------------------------------------------------------------ 4. reconciliation
U = bm[bm.in_market_sum]
s = U.groupby("period")[["registrations_month", "registrations_ytd"]].sum()
check("D10 comparison universe = market total every month (month and YTD)",
      (s.registrations_month == m.market_registrations_month).all() and (s.registrations_ytd == m.market_registrations_ytd).all())
b = bm.sort_values(["brand", "year", "month"]).copy()
b["prev"] = b.groupby(["brand", "year"]).registrations_ytd.shift()
b.loc[b.month == 1, "prev"] = 0
b["gap"] = b.registrations_ytd - (b.prev + b.registrations_month)
g = b[b.gap.notna()]
check("D11 every YTD continuity gap is logged in ytd_revision_gap", ((g.gap - g.ytd_revision_gap).abs().fillna(0) == 0).all(),
      f"{int((g.gap != 0).sum())} brand-month revisions")
L = bm[bm.listed_in_source]
expl = True
for per in g[(g.brand == AUTRES) & (g.gap.abs() > 50)].period:
    prev = (pd.Period(per, "M") - 1).strftime("%Y-%m")
    new = set(L[L.period == per].brand) - set(L[L.period == prev].brand)
    gone = set(L[L.period == prev].brand) - set(L[L.period == per].brand) - {"Fiat", "Abarth"}   # these moved into 'Fiat + Abarth'
    t_new = L[(L.period == per) & L.brand.isin(new)]
    moved = (bm[(bm.period == prev) & bm.brand.isin(gone)].registrations_ytd.sum()
             - (t_new.registrations_ytd - t_new.registrations_month).sum())
    expl &= int(moved) == int(g[(g.brand == AUTRES) & (g.period == per)].gap.iloc[0])
check("D12 large AUTRES YTD restatements fully explained by brands entering/leaving the CCFA list", expl)

# growth vs CCFA's own printed year-on-year % (brands; AUTRES excluded: CCFA restates its prior-year base)
rr = r.assign(year=r.period.str[:4].astype(int), month=r.period.str[5:].astype(int))
ly = rr[["brand_label", "year", "month", "registrations_ytd"]].assign(year=lambda q: q.year + 1)
z = rr.merge(ly, on=["brand_label", "year", "month"], suffixes=("", "_ly"))
z = z[z.var_ytd_pct_reported.notna() & (z.registrations_ytd_ly > 0) & (z.brand_label != "AUTRES")]
dz = ((z.registrations_ytd / z.registrations_ytd_ly - 1) * 100).round(1) - z.var_ytd_pct_reported
check("D13 our YTD growth = CCFA printed growth for every brand row (<= 0.1 pp)", dz.abs().max() <= 0.1001,
      f"{len(z)} rows, max diff {dz.abs().max():.2f} pp")

# ------------------------------------------------------------------ 5. KPIs (expected values = docs/kpi_definitions.md)
def ytd(brand, y, mo):
    v = bm[(bm.brand == brand) & (bm.year == y) & (bm.month == mo)].registrations_ytd
    return float(v.iloc[0]) if len(v) and pd.notna(v.iloc[0]) else np.nan


mkt = lambda y, mo: float(mm[(mm.year == y) & (mm.month == mo)].market_registrations_ytd.iloc[0])
growth = lambda br, y, mo: (ytd(br, y, mo) / ytd(br, y - 1, mo) - 1) * 100


def rank(y, mo, brand):
    q = U[(U.year == y) & (U.month == mo) & (U.brand != AUTRES) & U.registrations_ytd.notna()]
    rk = q.registrations_ytd.rank(ascending=False, method="min")
    return int(rk[q.brand == brand].iloc[0]), len(q)


cn = set(dim[dim.is_chinese_owned].brand)
cnr = lambda y, mo: U[(U.year == y) & (U.month == mo) & U.brand.isin(cn)].registrations_ytd.sum()
kpis = {
    "K01 BYD registrations FY24 / FY25 / Jan-Oct 26": ((ytd("BYD", 2024, 12), ytd("BYD", 2025, 12), ytd("BYD", 2026, 10)), (5415, 13533, 28086)),
    "K03 BYD share Jan-Oct 2026 (%)": (round(ytd("BYD", 2026, 10) / mkt(2026, 10) * 100, 2), 2.03),
    "K04 BYD growth Jan-Oct 2026 (%)": (round(growth("BYD", 2026, 10), 1), 185.3),
    "K04 Tesla / MG / Leapmotor / Xpeng growth Jan-Oct 2026 (%)":
        (tuple(round(growth(b_, 2026, 10), 1) for b_ in ["Tesla", "MG", "Leapmotor", "Xpeng"]), (117.1, 23.7, 172.6, 154.1)),
    "K04 Xpeng growth Jan-Oct 2025 is missing (no 2024 figure)": (bool(np.isnan(growth("Xpeng", 2025, 10))), True),
    "K06 BYD rank Jan-Oct 2024 / Jan-Oct 2026": ((rank(2024, 10, "BYD"), rank(2026, 10, "BYD")), ((32, 40), (16, 44))),
    "K10 Chinese-owned share Jan-Oct 2026, lower / upper (%)":
        ((round(cnr(2026, 10) / mkt(2026, 10) * 100, 2), round((cnr(2026, 10) + ytd(AUTRES, 2026, 10)) / mkt(2026, 10) * 100, 2)), (7.07, 7.20)),
    "K11 BYD part of Chinese-owned Jan-Oct 2026 (%)": (round(ytd("BYD", 2026, 10) / cnr(2026, 10) * 100, 1), 28.7),
    "K12 market growth FY25 / Jan-Oct 26 (%)": ((round((mkt(2025, 12) / mkt(2024, 12) - 1) * 100, 2), round((mkt(2026, 10) / mkt(2025, 10) - 1) * 100, 2)), (-5.02, 4.37)),
}
for k, (got, exp) in kpis.items():
    check(k, got == exp, f"got {got}")

# ------------------------------------------------------------------ 6. optional: independent PDF re-extraction
ap = argparse.ArgumentParser()
ap.add_argument("--pdf", action="store_true")
ap.add_argument("--powerbi")
args = ap.parse_args()
if args.pdf:
    num = lambda s: int(s.replace(" ", "").replace("\xa0", "")) if re.fullmatch(r"-?[\d \xa0]+", s) else None
    rows = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "raw", "Immatriculations-VPN*.pdf"))):
        txt = subprocess.run(["pdftotext", "-layout", path, "-"], capture_output=True, text=True).stdout
        for line in txt.split("Energie")[0].splitlines():          # stop before the electric-only page (March 2024)
            parts = [p_ for p_ in re.split(r"\s{2,}", line.strip()) if p_]
            counts = [num(v) for v in parts[1:] if num(v) is not None]
            if len(parts) >= 2 and len(counts) >= 1 and not parts[0].startswith(("Marques", "Source")):
                rows.append((os.path.basename(path), parts[0].upper(), counts[0], counts[1] if len(counts) > 1 else None))
    ind = pd.DataFrame(rows, columns=["source_file", "label", "m", "y"])
    rw = raw.assign(label=raw.brand_label.str.upper())
    mg = rw.merge(ind, on=["source_file", "label"], how="left")
    check("P01 independent pdftotext re-extraction: every raw row found", mg.m.notna().all(), f"{int(mg.m.isna().sum())} missing")
    check("P02 re-extraction: monthly counts identical", (mg.registrations_month == mg.m).all())
    check("P03 re-extraction: YTD counts identical", (mg.registrations_ytd.fillna(-1) == mg.y.fillna(-1)).all())

# ------------------------------------------------------------------ 7. optional: Power BI package
if args.powerbi:
    B = args.powerbi
    man = dict(l.split()[::-1] for l in open(os.path.join(B, "MANIFEST.sha256")) if l.strip())
    check("B01 package files match MANIFEST.sha256",
          all(hashlib.sha256(open(os.path.join(B, f), "rb").read()).hexdigest() == h for f, h in man.items()))
    pd_ = pd.read_csv(os.path.join(B, "dim_date.csv"), parse_dates=["date_key"])
    pb = pd.read_csv(os.path.join(B, "v_brand_month.csv"), parse_dates=["date_key"])
    pm = pd.read_csv(os.path.join(B, "v_market_month.csv"), parse_dates=["date_key"])
    check("B02 package row counts 34 / 1408 / 34", (len(pd_), len(pb), len(pm)) == (34, 1408, 34))
    check("B03 package brand-month universe = market every month",
          (pb.groupby("date_key").registrations_month.sum().values == pm.sort_values("date_key").market_registrations_month.values).all())
    # emulate the DAX prior-year logic (year and month of the LAST date in the filter context)
    def reg_period(dates, brand):
        v = pb[(pb.date_key == max(dates)) & (pb.brand == brand)].registrations_ytd
        return float(v.sum()) if v.notna().any() else np.nan
    def growth_dax(dates, brand):
        last = pd.Timestamp(max(dates))
        ly = pd_[(pd_.year == last.year - 1) & (pd_.month == last.month)].date_key
        return round((reg_period(dates, brand) / reg_period(ly, brand) - 1) * 100, 1)
    ctx = {"year 2026": pd_[pd_.year == 2026].date_key, "no year selected": pd_.date_key,
           "years 2025+2026": pd_[pd_.year >= 2025].date_key}
    check("B04 DAX growth logic gives +185.3% for BYD in every slicer state",
          all(growth_dax(dts, "BYD") == 185.3 for dts in ctx.values()))

# ------------------------------------------------------------------ report
w = max(len(n) for n, _, _ in results)
for n, ok, det in results:
    print(f"{'PASS' if ok else 'FAIL'}  {n:<{w}}  {det}")
failed = sum(not ok for _, ok, _ in results)
print(f"\n{len(results) - failed} / {len(results)} checks passed")
sys.exit(1 if failed else 0)
