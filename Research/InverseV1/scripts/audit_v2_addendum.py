import re
from datetime import datetime

SCRATCH = r"C:\Users\ACER\.gemini\antigravity\brain\58ab35aa-a701-45db-a18f-d8f6f11fcccc\scratch"
import sys
sys.path.insert(0, SCRATCH)
import analyze_layerA_and_compare as a

# 1. Inspect MT5 Strategy Tester header & footer lines across all 4 logs for Section 2B (Leverage, ToDate, Last Timestamp, Ticks, Bars)
for fname in ["v1_layerB_portfolio.log", "inverse_v2_layerB_portfolio.log", "v1_layerA_matched.log", "inverse_v2_layerA_matched.log"]:
    with open(f"{SCRATCH}\\{fname}", "r", encoding="utf-16le", errors="ignore") as f:
        lines = [l.strip() for l in f.readlines()]
    print(f"=== {fname} ===")
    for l in lines[:35]:
        if any(k in l for k in ["1:", "Leverage", "initial deposit", "testing of", "real ticks", "bars"]):
            print("  HEADER:", l)
    for l in lines[-25:]:
        if any(k in l for k in ["final balance", "ticks", "bars", "OnDeinit", "2026.10."]):
            print("  FOOTER:", l)

# 2. Section 2A: Layer A Concurrent Open Positions, Peak Margin Usage, Minimum Margin Level, and R normalization comparison
def layerA_concurrency_and_margin(exec_sigs, label):
    # Build event timeline: (timestamp, +1 for entry, -1 for exit, lot, entry_price, pnl_usd)
    events = []
    for s in exec_sigs:
        events.append((s["time"], +1, s))
        events.append((s["time_out"], -1, s))
    # Sort by timestamp; if exit and entry at exact same second, process exit (-1) before entry (+1)
    events.sort(key=lambda x: (x[0], x[1]))

    open_positions = {}
    max_concurrent = 0
    max_concurrent_ts = None
    max_open_lots = 0.0
    max_margin_usd = 0.0
    max_margin_ts = None
    min_margin_level_pct = float("inf")
    min_margin_level_ts = None
    closed_balance = 100000.0

    for ts, etype, s in events:
        if etype == -1:
            open_positions.pop(s["id"], None)
            closed_balance += s["pnl_usd"]
        else:
            open_positions[s["id"]] = s
            n_open = len(open_positions)
            if n_open > max_concurrent:
                max_concurrent = n_open
                max_concurrent_ts = ts
            # Calculate hedged/net or gross margin on GOLD at 1:500 leverage:
            # In MT5 standard hedging mode, hedged BUY/SELL margin or directional margin:
            # 1 lot GOLD = 100 oz -> Notional = 100 * price -> Margin at 1:500 = 100 * price / 500 = 0.20 * price per lot
            gross_margin = sum(pos["lot"] * pos["entry_price"] * 100.0 / 500.0 for pos in open_positions.values())
            tot_lots = sum(pos["lot"] for pos in open_positions.values())
            if tot_lots > max_open_lots:
                max_open_lots = tot_lots
            if gross_margin > max_margin_usd:
                max_margin_usd = gross_margin
                max_margin_ts = ts
            if gross_margin > 0:
                m_level = (closed_balance / gross_margin) * 100.0
                if m_level < min_margin_level_pct:
                    min_margin_level_pct = m_level
                    min_margin_level_ts = ts

    # Compare Price-Distance R vs Actual-Dollar-Risk R (pnl_usd / (sl_dist * 100 * lot)) vs Equity-Risk-Budget R (pnl_usd / (0.0025 * equity))
    # Notice: pnl_usd = round(pts * 100 * lot, 2), and actual trade initial risk for the executed lot is (sl_dist * 100 * lot),
    # so (pts * 100 * lot) / (sl_dist * 100 * lot) == pts / sl_dist!
    # What if normalized by sent_sl (2-decimal rounded SL)? Let's check both!
    r_unrounded = [s["pts"] / s["sl_dist"] for s in exec_sigs]
    r_sent_sl = [s["pts"] / abs(s["req_entry"] - s["sent_sl"]) for s in exec_sigs]
    print(f"\n[{label} Concurrency & Margin]")
    print(f"  Max Concurrent Open Positions: {max_concurrent} (at {max_concurrent_ts})")
    print(f"  Peak Gross Open Volume: {max_open_lots:.2f} lots")
    print(f"  Peak Gross Margin Used (at 1:500): ${max_margin_usd:.2f} (at {max_margin_ts})")
    print(f"  Minimum Margin Level (at 1:500): {min_margin_level_pct:.2f}% (at {min_margin_level_ts})")
    print(f"  Final Closed Balance (from $100,000): ${closed_balance:.2f}")
    print(f"  Mean R (unrounded D_SL): {sum(r_unrounded)/len(r_unrounded):+.6f}R | Sum: {sum(r_unrounded):+.2f}R")
    print(f"  Mean R (submitted sent_sl): {sum(r_sent_sl)/len(r_sent_sl):+.6f}R | Sum: {sum(r_sent_sl):+.2f}R")

v1_a_exec = [s for s in a.v1_a if s["status"] == "EXECUTED"]
v2_a_exec = [s for s in a.v2_a if s["status"] == "EXECUTED"]
layerA_concurrency_and_margin(v1_a_exec, "Layer A V1")
layerA_concurrency_and_margin(v2_a_exec, "Layer A V2")

# 3. Section 2C: Exact 10 trades in V2 Layer B where post-normalization sent_sl risk exceeded 1.0% Equity
print("\n=== SECTION 2C: V2 LAYER B POST-NORMALIZATION RISK AUDIT ===")
v2_b_exec = [s for s in a.v2_b if s["status"] == "EXECUTED"]
bal = 10000.0
breach_list = []
for idx, s in enumerate(v2_b_exec, 1):
    eq_before = bal
    allowed_usd = eq_before * 0.01
    exact_sl_dist = s["sl_dist"]
    sent_sl_dist = abs(s["req_entry"] - s["sent_sl"])
    pre_norm_risk_usd = exact_sl_dist * 100.0 * s["lot"]
    post_norm_risk_usd = sent_sl_dist * 100.0 * s["lot"]
    if post_norm_risk_usd > allowed_usd + 1e-6:
        excess_usd = post_norm_risk_usd - allowed_usd
        excess_pct_of_budget = (excess_usd / allowed_usd) * 100.0
        actual_risk_pct_equity = (post_norm_risk_usd / eq_before) * 100.0
        breach_list.append({
            "trade_num": idx,
            "sig_id": s["id"],
            "time": s["time"],
            "dir": s["exec_dir"],
            "lot": s["lot"],
            "eq_before": eq_before,
            "allowed_usd": allowed_usd,
            "exact_sl_dist": exact_sl_dist,
            "sent_sl_dist": sent_sl_dist,
            "pre_norm_risk_usd": pre_norm_risk_usd,
            "post_norm_risk_usd": post_norm_risk_usd,
            "excess_usd": excess_usd,
            "actual_risk_pct": actual_risk_pct_equity,
        })
    bal = round(bal + s["pnl_usd"], 2)

print(f"Total post-normalization breaches in V2 Layer B: {len(breach_list)} / {len(v2_b_exec)}")
for b in breach_list:
    print(
        f"  Trade #{b['trade_num']:4d} (Sig #{b['sig_id']:4d}, {b['time']}) | {b['dir']:5s} Lot={b['lot']:.2f} | "
        f"Equity=${b['eq_before']:.2f} | 1% Budget=${b['allowed_usd']:.4f} | "
        f"PreNormSLDist={b['exact_sl_dist']:.3f} (${b['pre_norm_risk_usd']:.4f}) -> "
        f"SentSLDist={b['sent_sl_dist']:.2f} (${b['post_norm_risk_usd']:.4f}) | "
        f"Excess=+${b['excess_usd']:.4f} ({b['actual_risk_pct']:.4f}% Equity)"
    )
max_ex_usd = max(b["excess_usd"] for b in breach_list)
max_ex_pct = max(b["actual_risk_pct"] for b in breach_list)
print(f"Max Post-Normalization Excess: +${max_ex_usd:.4f} (Max Risk % of Equity: {max_ex_pct:.4f}% vs 1.0000% target)")
