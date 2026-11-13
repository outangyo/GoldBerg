import re

log_path = r"C:\Users\ACER\.gemini\antigravity\brain\58ab35aa-a701-45db-a18f-d8f6f11fcccc\scratch\inverse_v2_layerB_portfolio.log"
with open(log_path, "r", encoding="utf-16le", errors="ignore") as f:
    lines = f.readlines()

print(f"Total lines in Layer B log: {len(lines)}")

inv_re = re.compile(
    r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+\[INFO\] \[InverseV2\] Transformed (BUY|SELL) -> (BUY|SELL) \| "
    r"OriginalEntry: ([\d\.]+) \| OriginalSLDist: ([\d\.]+) \| OriginalTPDist: ([\d\.]+) \| "
    r"InverseEntry: ([\d\.]+) \| InverseSL: ([\d\.]+) \| InverseTP: ([\d\.]+) \| Reward/Risk: ([\d\.]+)"
)

signals = []
for l in lines:
    m = inv_re.search(l)
    if m:
        signals.append({
            "time": m.group(1),
            "orig_dir": m.group(2),
            "inv_dir": m.group(3),
            "orig_entry": float(m.group(4)),
            "orig_sl_dist": float(m.group(5)),
            "orig_tp_dist": float(m.group(6)),
            "inv_entry": float(m.group(7)),
            "inv_sl": float(m.group(8)),
            "inv_tp": float(m.group(9)),
            "rr": float(m.group(10))
        })

print(f"Total [InverseV2] Transformed signals logged: {len(signals)}")
orig_sls = [s["orig_sl_dist"] for s in signals]
inv_sls = [s["orig_tp_dist"] for s in signals]
spreads = [abs(s["orig_entry"] - s["inv_entry"]) for s in signals]
print(f"Orig SL Dist: min={min(orig_sls):.2f}, max={max(orig_sls):.2f}")
print(f"Inv  SL Dist: min={min(inv_sls):.2f}, max={max(inv_sls):.2f}")
print(f"Spread at signal: min={min(spreads):.2f}, median={sorted(spreads)[len(spreads)//2]:.2f}, mean={sum(spreads)/len(spreads):.4f}, max={max(spreads):.2f}")

# Check at $10,000 fixed reference equity (1% risk = $100) how many of the 2,506 signals have raw_lot < 0.01 (i.e. SL_dist > $100.00):
v1_min_vol_10k = sum(1 for x in orig_sls if (100.0 / (x * 100.0)) < 0.01)
v2_min_vol_10k = sum(1 for x in inv_sls if (100.0 / (x * 100.0)) < 0.01)
print(f"At fixed $10,000 Equity (1% = $100 budget): V1 BELOW_MIN_VOL = {v1_min_vol_10k} / 2506 | V2 BELOW_MIN_VOL = {v2_min_vol_10k} / 2506")
