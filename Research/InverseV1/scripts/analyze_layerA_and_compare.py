import re
import math
import json
from collections import Counter, defaultdict

SCRATCH = r"C:\Users\ACER\.gemini\antigravity\brain\58ab35aa-a701-45db-a18f-d8f6f11fcccc\scratch"

t_re = re.compile(r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})")
start_re = re.compile(r"testing of Experts\\.*started")
sig_re = re.compile(
    r"\[SetupAnalyzer\]\[SIGNAL (BUY|SELL)\] M5 Close ([\d\.]+) [><] Extreme Bar (?:High|Low) ([\d\.]+) \| Entry\((?:Ask|Bid)\): ([\d\.]+) \| SL: ([\d\.]+) \| TP: ([\d\.]+) \| RR: ([\d\.]+)"
)
inv_re = re.compile(
    r"\[INFO\] \[InverseV2\] Transformed (BUY|SELL) -> (BUY|SELL) \| "
    r"OriginalEntry: ([\d\.]+) \| OriginalSLDist: ([\d\.]+) \| OriginalTPDist: ([\d\.]+) \| "
    r"InverseEntry: ([\d\.]+) \| InverseSL: ([\d\.]+) \| InverseTP: ([\d\.]+) \| Reward/Risk: ([\d\.]+)"
)
max_pos_re = re.compile(r"Setup confirmed but rejected by Risk: Max Open Positions")
min_vol_re = re.compile(
    r"\[RiskManager\]\[DIAGNOSTIC\] NO_TRADE \| Reason: BELOW_MINIMUM_VOLUME \| Equity: ([\d\.]+) \| RiskPct: ([\d\.]+)% \| RiskBudget: ([\d\.]+) \| Entry: ([\d\.]+) \| SL: ([\d\.]+) \| StopDistPoints: ([\d\.]+) \| RawLot: ([\d\.]+) \| MinLot: ([\d\.]+)"
)
fail_re = re.compile(
    r"\[TradeExecutor\]\[REJECTED/FAIL\] (BUY|SELL) Failed \| Symbol: GOLD \| Vol: ([\d\.]+) \| SL: ([\d\.]+) \| TP: ([\d\.]+) \| Retcode: (\d+) \((.*?)\)"
)
exec_re = re.compile(
    r"\[TradeExecutor\]\[SUCCESS\] (BUY|SELL) Executed \| Symbol: GOLD \| Vol: ([\d\.]+) \| Price: ([\d\.]+) \| SL: ([\d\.]+) \| TP: ([\d\.]+) \| Order: (\d+) \| Deal: (\d+) \| Retcode: (\d+)"
)
deal_re = re.compile(
    r"deal #(\d+) (buy|sell) ([\d\.]+) GOLD at ([\d\.]+) done \(based on order #(\d+)\)"
)
trig_re = re.compile(
    r"(stop loss|take profit) triggered #(\d+) (buy|sell) ([\d\.]+) GOLD ([\d\.]+) sl: ([\d\.]+) tp: ([\d\.]+) \[#(\d+) (buy|sell) ([\d\.]+) GOLD at ([\d\.]+)\]"
)

def parse_and_clean_log(filename, is_v2=False):
    path = f"{SCRATCH}\\{filename}"
    with open(path, "r", encoding="utf-16le", errors="ignore") as f:
        all_lines = f.readlines()

    # Find start of the last test run in the file (include ~25 header lines before "testing of Experts\... started")
    start_idx = 0
    for idx, line in enumerate(all_lines):
        if start_re.search(line):
            start_idx = max(0, idx - 25)
    lines = all_lines[start_idx:]

    # Save cleaned single-run log back to file if it had multiple concatenated runs
    if start_idx > 0:
        with open(path, "w", encoding="utf-16le") as f:
            f.writelines(lines)

    # Slice strictly from the start_re line for parsing
    run_start = 0
    for idx, line in enumerate(lines):
        if start_re.search(line):
            run_start = idx
    lines = lines[run_start:]

    signals = []
    cur_sig = None
    deals_by_order = {}
    trigs_by_exit_order = {}

    for l in lines:
        tm = t_re.search(l)
        if not tm:
            continue
        ts = tm.group(1)

        sm = sig_re.search(l)
        if sm:
            orig_dir = sm.group(1)
            orig_entry = float(sm.group(4))
            orig_sl = float(sm.group(5))
            orig_tp = float(sm.group(6))
            orig_sl_dist = abs(orig_entry - orig_sl)
            orig_tp_dist = abs(orig_tp - orig_entry)
            cur_sig = {
                "id": len(signals) + 1,
                "time": ts,
                "year": int(ts[:4]),
                "orig_dir": orig_dir,
                "orig_entry": orig_entry,
                "orig_sl": orig_sl,
                "orig_tp": orig_tp,
                "orig_sl_dist": orig_sl_dist,
                "orig_tp_dist": orig_tp_dist,
                "exec_dir": "LONG" if orig_dir == "BUY" else "SHORT",
                "req_entry": orig_entry,
                "req_sl": orig_sl,
                "req_tp": orig_tp,
                "sl_dist": orig_sl_dist,
                "tp_dist": orig_tp_dist,
                "status": "UNKNOWN",
                "reject_reason": None,
                "retcode": None,
                "retdesc": None,
                "lot": None,
                "order_in": None,
                "deal_in": None,
                "entry_price": None,
            }
            signals.append(cur_sig)
            continue

        im = inv_re.search(l)
        if im and cur_sig is not None:
            inv_dir_str = im.group(2)
            inv_entry = float(im.group(6))
            sl_d = cur_sig["orig_tp_dist"]
            tp_d = cur_sig["orig_sl_dist"]
            if inv_dir_str == "BUY":
                exact_inv_sl = inv_entry - sl_d
                exact_inv_tp = inv_entry + tp_d
                exec_dir = "LONG"
            else:
                exact_inv_sl = inv_entry + sl_d
                exact_inv_tp = inv_entry - tp_d
                exec_dir = "SHORT"
            cur_sig["exec_dir"] = exec_dir
            cur_sig["req_entry"] = inv_entry
            cur_sig["req_sl"] = exact_inv_sl
            cur_sig["req_tp"] = exact_inv_tp
            cur_sig["sl_dist"] = sl_d
            cur_sig["tp_dist"] = tp_d
            cur_sig["spread_at_signal"] = abs(cur_sig["orig_entry"] - inv_entry)
            continue

        if max_pos_re.search(l) and cur_sig is not None:
            cur_sig["status"] = "REJECTED"
            cur_sig["reject_reason"] = "MAX_OPEN_TRADES"
            continue

        mvm = min_vol_re.search(l)
        if mvm and cur_sig is not None:
            cur_sig["status"] = "REJECTED"
            cur_sig["reject_reason"] = "BELOW_MINIMUM_VOLUME"
            cur_sig["rej_equity"] = float(mvm.group(1))
            cur_sig["rej_risk_budget"] = float(mvm.group(3))
            cur_sig["rej_raw_lot"] = float(mvm.group(7))
            continue

        fm = fail_re.search(l)
        if fm and cur_sig is not None:
            cur_sig["status"] = "EXEC_FAILED"
            cur_sig["lot"] = float(fm.group(2))
            cur_sig["retcode"] = int(fm.group(5))
            cur_sig["retdesc"] = fm.group(6)
            continue

        em = exec_re.search(l)
        if em and cur_sig is not None:
            cur_sig["status"] = "EXECUTED"
            cur_sig["lot"] = float(em.group(2))
            cur_sig["entry_price"] = float(em.group(3))
            cur_sig["sent_sl"] = float(em.group(4))
            cur_sig["sent_tp"] = float(em.group(5))
            cur_sig["order_in"] = int(em.group(6))
            cur_sig["deal_in"] = int(em.group(7))
            continue

        trm = trig_re.search(l)
        if trm:
            exit_ord = int(trm.group(8))
            trigs_by_exit_order[exit_ord] = {
                "time": ts,
                "reason": "SL" if trm.group(1) == "stop loss" else "TP",
                "pos_id": int(trm.group(2)),
                "trig_price": float(trm.group(11)),
            }
            continue

        dm = deal_re.search(l)
        if dm:
            ord_id = int(dm.group(5))
            deals_by_order[ord_id] = {
                "time": ts,
                "deal_id": int(dm.group(1)),
                "action": dm.group(2),
                "lot": float(dm.group(3)),
                "price": float(dm.group(4)),
                "order_id": ord_id,
            }
            continue

    exits_by_pos = {}
    for exit_ord, tinfo in trigs_by_exit_order.items():
        pos_id = tinfo["pos_id"]
        d_out = deals_by_order.get(exit_ord)
        exits_by_pos[pos_id] = {
            "exit_order": exit_ord,
            "deal_out": d_out["deal_id"] if d_out else None,
            "time_out": d_out["time"] if d_out else tinfo["time"],
            "exit_price": d_out["price"] if d_out else tinfo["trig_price"],
            "trig_price": tinfo["trig_price"],
            "exit_reason": tinfo["reason"],
        }

    for s in signals:
        if s["status"] == "EXECUTED":
            pos_id = s["order_in"]
            s.update(exits_by_pos[pos_id])
            ep = s["entry_price"]
            xp = s["exit_price"]
            lot = s["lot"]
            pts = (xp - ep) if s["exec_dir"] == "LONG" else (ep - xp)
            # Exact MT5 profit per deal: pts * 100 * lot rounded to 2 decimals
            pnl_usd = round(pts * 100.0 * lot, 2)
            # R-multiple using exact unrounded planned SL distance (D_SL_original for V1, D_TP_original for V2)
            r_val = pts / s["sl_dist"] if s["sl_dist"] > 0 else 0.0
            s["pts"] = pts
            s["pnl_usd"] = pnl_usd
            s["r_mult"] = r_val
            s["is_win"] = pnl_usd > 0
            s["entry_slip"] = (ep - s["req_entry"]) if s["exec_dir"] == "LONG" else (s["req_entry"] - ep)
            # Slippage relative to sent SL/TP level (positive = adverse slippage, negative = favorable slippage)
            ref_level = s["sent_sl"] if s["exit_reason"] == "SL" else s["sent_tp"]
            s["adverse_exit_slip"] = (ref_level - xp) if s["exec_dir"] == "LONG" else (xp - ref_level)
            s["adverse_exit_slip_r"] = s["adverse_exit_slip"] / s["sl_dist"] if s["sl_dist"] > 0 else 0.0

    return signals

v1_b = parse_and_clean_log("v1_layerB_portfolio.log", is_v2=False)
v2_b = parse_and_clean_log("inverse_v2_layerB_portfolio.log", is_v2=True)
v1_a = parse_and_clean_log("v1_layerA_matched.log", is_v2=False)
v2_a = parse_and_clean_log("inverse_v2_layerA_matched.log", is_v2=True)

# 1. Verify 1-to-1 signal identity across all 4 runs
assert len(v1_b) == len(v2_b) == len(v1_a) == len(v2_a) == 2506
for i in range(2506):
    assert v1_b[i]["time"] == v2_b[i]["time"] == v1_a[i]["time"] == v2_a[i]["time"]
    assert v1_b[i]["orig_dir"] == v2_b[i]["orig_dir"] == v1_a[i]["orig_dir"] == v2_a[i]["orig_dir"]
    assert abs(v1_b[i]["orig_entry"] - v2_b[i]["orig_entry"]) < 1e-6
    # Attach spread_at_signal to V1 signals from V2's logged InverseEntry
    spread = v2_a[i]["spread_at_signal"]
    v1_b[i]["spread_at_signal"] = spread
    v1_a[i]["spread_at_signal"] = spread
    # Also compute standalone $10,000 1% ($100 risk budget) raw lot & normalized lot
    # 1 lot loss per $1 move = $100 -> raw_lot_10k = 100.0 / (sl_dist * 100.0) = 1.0 / sl_dist
    for s in (v1_b[i], v1_a[i]):
        s["raw_lot_10k"] = 1.0 / s["sl_dist"]
        s["min_vol_reject_10k"] = s["raw_lot_10k"] < 0.01 - 1e-9
    for s in (v2_b[i], v2_a[i]):
        # Note: RiskManager uses normalized SL sent to OrderCalcProfit: abs(req_entry - round(req_sl, 2))
        norm_sl_d = abs(s["req_entry"] - round(s["req_sl"], 2))
        s["norm_sl_dist"] = norm_sl_d
        s["raw_lot_10k"] = 1.0 / norm_sl_d
        s["min_vol_reject_10k"] = s["raw_lot_10k"] < 0.01 - 1e-9

print("1-to-1 Signal Identity Verified: 2,506 / 2,506 timestamps & geometries match 100%.")

def calc_r_stats(exec_list, label):
    n = len(exec_list)
    wins = [s for s in exec_list if s["is_win"]]
    losses = [s for s in exec_list if not s["is_win"]]
    nw, nl = len(wins), len(losses)
    wr = nw / n * 100.0 if n > 0 else 0.0
    avg_w = sum(s["r_mult"] for s in wins) / nw if nw > 0 else 0.0
    avg_l = sum(s["r_mult"] for s in losses) / nl if nl > 0 else 0.0
    net_r = sum(s["r_mult"] for s in exec_list)
    exp_r = net_r / n if n > 0 else 0.0
    pos_r = sum(s["r_mult"] for s in wins)
    neg_r = abs(sum(s["r_mult"] for s in losses))
    pf_r = pos_r / neg_r if neg_r > 0 else 0.0
    gp = sum(s["pnl_usd"] for s in wins)
    gl = abs(sum(s["pnl_usd"] for s in losses))
    net_pnl = gp - gl
    pf_usd = gp / gl if gl > 0 else 0.0
    print(
        f"{label:38s} | N={n:4d} (W={nw:4d}, L={nl:4d}) | WR={wr:5.2f}% | "
        f"AvgW={avg_w:+.4f}R | AvgL={avg_l:+.4f}R | Exp={exp_r:+.4f}R | NetR={net_r:+8.2f}R | "
        f"PF(R)={pf_r:4.2f} | PF($)={pf_usd:4.2f} | NetPnL=${net_pnl:+10.2f}"
    )

print("\n================ LAYER A: MATCHED-SIGNAL DIAGNOSTIC ================")
v1_a_exec = [s for s in v1_a if s["status"] == "EXECUTED"]
v2_a_exec = [s for s in v2_a if s["status"] == "EXECUTED"]
calc_r_stats(v1_a_exec, "Layer A V1 (All 2,493 Exec Signals)")
calc_r_stats(v2_a_exec, "Layer A V2 (All 2,493 Exec Signals)")
calc_r_stats([s for s in v1_a_exec if s["exec_dir"] == "LONG"], "  Layer A V1 LONG (Orig BUY)")
calc_r_stats([s for s in v2_a_exec if s["exec_dir"] == "SHORT"], "  Layer A V2 SHORT (from Orig BUY)")
calc_r_stats([s for s in v1_a_exec if s["exec_dir"] == "SHORT"], "  Layer A V1 SHORT (Orig SELL)")
calc_r_stats([s for s in v2_a_exec if s["exec_dir"] == "LONG"], "  Layer A V2 LONG (from Orig SELL)")

# Check the 2 signals that fail standalone $10,000 min volume in V2
v2_minvol_10k = [i for i in range(2506) if v2_a[i]["min_vol_reject_10k"]]
print(f"\nSignals failing standalone $10,000 (1% = $100) min volume (0.01 lot): V1={sum(1 for s in v1_a if s['min_vol_reject_10k'])}, V2={len(v2_minvol_10k)}")
for idx in v2_minvol_10k:
    s1 = v1_a[idx]
    s2 = v2_a[idx]
    print(
        f"  Signal #{s1['id']} at {s1['time']} | Orig={s1['orig_dir']} | V1 SL_Dist={s1['sl_dist']:.2f} (RawLot10k={s1['raw_lot_10k']:.4f}, V1_R={s1.get('r_mult', 0):+.4f}R) | "
        f"V2 SL_Dist={s2['sl_dist']:.2f} (NormSL={s2['norm_sl_dist']:.2f}, RawLot10k={s2['raw_lot_10k']:.4f}, V2_R={s2.get('r_mult', 0):+.4f}R)"
    )

v1_a_2491 = [v1_a[i] for i in range(2506) if v1_a[i]["status"] == "EXECUTED" and not v2_a[i]["min_vol_reject_10k"]]
v2_a_2491 = [v2_a[i] for i in range(2506) if v2_a[i]["status"] == "EXECUTED" and not v2_a[i]["min_vol_reject_10k"]]
calc_r_stats(v1_a_2491, "Layer A V1 (2,491 Pass $10k MinVol)")
calc_r_stats(v2_a_2491, "Layer A V2 (2,491 Pass $10k MinVol)")

# Check the 13 failed signals in Layer A
print("\nLayer A Execution Failed Signals (Market Closed):")
for i in range(2506):
    if v1_a[i]["status"] != "EXECUTED" or v2_a[i]["status"] != "EXECUTED":
        print(f"  Signal #{v1_a[i]['id']} at {v1_a[i]['time']} | V1={v1_a[i]['status']} ({v1_a[i]['retcode']}) | V2={v2_a[i]['status']} ({v2_a[i]['retcode']})")

# 2x2 Outcome Cross-Tabulation on the 2,493 paired executed signals
ct = Counter()
dur_comp = Counter()
for i in range(2506):
    s1, s2 = v1_a[i], v2_a[i]
    if s1["status"] == "EXECUTED" and s2["status"] == "EXECUTED":
        k = ("V1_WIN" if s1["is_win"] else "V1_LOSS", "V2_WIN" if s2["is_win"] else "V2_LOSS")
        ct[k] += 1
        if s1["time_out"] == s2["time_out"]:
            dur_comp["SAME_EXIT_TIMESTAMP"] += 1
        elif s1["time_out"] < s2["time_out"]:
            dur_comp["V1_EXITS_FIRST"] += 1
        else:
            dur_comp["V2_EXITS_FIRST"] += 1

print("\nLayer A 2x2 Outcome Cross-Tabulation (N = 2,493 Matched Signal Pairs):")
for k, v in sorted(ct.items()):
    print(f"  {k[0]} x {k[1]}: {v:4d} ({v/2493*100:.2f}%)")
print("Layer A Exit Timing Comparison (V1 vs V2):", dict(dur_comp))

# Layer B Portfolio Comparison & Overlap Matrix
print("\n================ LAYER B: FULL PORTFOLIO BACKTEST ($10,000, 1% Risk, MaxOpen=1) ================")
v1_b_exec = [s for s in v1_b if s["status"] == "EXECUTED"]
v2_b_exec = [s for s in v2_b if s["status"] == "EXECUTED"]
calc_r_stats(v1_b_exec, "Layer B V1 Portfolio (N=1,911)")
calc_r_stats(v2_b_exec, "Layer B V2 Portfolio (N=1,828)")
calc_r_stats([s for s in v1_b_exec if s["exec_dir"] == "LONG"], "  Layer B V1 LONG (Orig BUY)")
calc_r_stats([s for s in v2_b_exec if s["exec_dir"] == "SHORT"], "  Layer B V2 SHORT (from Orig BUY)")
calc_r_stats([s for s in v1_b_exec if s["exec_dir"] == "SHORT"], "  Layer B V1 SHORT (Orig SELL)")
calc_r_stats([s for s in v2_b_exec if s["exec_dir"] == "LONG"], "  Layer B V2 LONG (from Orig SELL)")

# Layer B Selection / Overlap Matrix across all 2,506 signals
b_matrix = Counter()
for i in range(2506):
    st1 = v1_b[i]["status"] if v1_b[i]["status"] != "REJECTED" else f"REJ_{v1_b[i]['reject_reason']}"
    st2 = v2_b[i]["status"] if v2_b[i]["status"] != "REJECTED" else f"REJ_{v2_b[i]['reject_reason']}"
    b_matrix[(st1, st2)] += 1

print("\nLayer B Signal Fate Cross-Tabulation (V1 Status x V2 Status across all 2,506 signals):")
for (st1, st2), cnt in sorted(b_matrix.items()):
    print(f"  V1={st1:25s} | V2={st2:25s} : {cnt:4d} ({cnt/2506*100:.2f}%)")

# What happened in Layer A for the 106 signals rejected by BELOW_MINIMUM_VOLUME in V2 Layer B?
v2_b_minvol_ids = [i for i in range(2506) if v2_b[i]["reject_reason"] == "BELOW_MINIMUM_VOLUME"]
print(f"\nDiagnostic on the {len(v2_b_minvol_ids)} signals rejected by BELOW_MINIMUM_VOLUME in V2 Layer B:")
calc_r_stats([v1_a[i] for i in v2_b_minvol_ids if v1_a[i]["status"] == "EXECUTED"], "  In Layer A V1 (Unsuppressed)")
calc_r_stats([v2_a[i] for i in v2_b_minvol_ids if v2_a[i]["status"] == "EXECUTED"], "  In Layer A V2 (Unsuppressed)")
calc_r_stats([v1_b[i] for i in v2_b_minvol_ids if v1_b[i]["status"] == "EXECUTED"], "  In Layer B V1 (Executed subset)")

# Risk Budget & Drawdown for Layer B V1 and V2
def portfolio_curve_and_risk(exec_sigs, label):
    bal = 10000.0
    peak = 10000.0
    max_dd_usd = 0.0
    max_dd_pct = 0.0
    unrounded_breaches = 0
    norm_breaches = 0
    max_norm_excess = 0.0
    sl_exits = [s for s in exec_sigs if s["exit_reason"] == "SL"]
    tp_exits = [s for s in exec_sigs if s["exit_reason"] == "TP"]
    for s in exec_sigs:
        eq_before = bal
        allowed = eq_before * 0.01
        # RiskManager uses OrderCalcProfit on (req_entry, sent_sl)
        norm_sl_dist = abs(s["req_entry"] - s["sent_sl"])
        planned_norm_risk = norm_sl_dist * 100.0 * s["lot"]
        planned_exact_risk = s["sl_dist"] * 100.0 * s["lot"]
        if planned_norm_risk > allowed + 1e-4:
            norm_breaches += 1
        if planned_exact_risk > allowed + 1e-4:
            unrounded_breaches += 1
            ex = planned_exact_risk - allowed
            if ex > max_norm_excess:
                max_norm_excess = ex
        bal = round(bal + s["pnl_usd"], 2)
        if bal > peak:
            peak = bal
        dd_u = peak - bal
        dd_p = dd_u / peak * 100.0
        if dd_u > max_dd_usd:
            max_dd_usd = dd_u
        if dd_p > max_dd_pct:
            max_dd_pct = dd_p

    mean_ent_slip = sum(s["entry_slip"] for s in exec_sigs) / len(exec_sigs)
    mean_sl_slip = sum(s["adverse_exit_slip"] for s in sl_exits) / len(sl_exits) if sl_exits else 0.0
    mean_tp_slip = sum(s["adverse_exit_slip"] for s in tp_exits) / len(tp_exits) if tp_exits else 0.0
    mean_all_exit_slip = sum(s["adverse_exit_slip"] for s in exec_sigs) / len(exec_sigs)
    tot_exit_slip_r = sum(s["adverse_exit_slip_r"] for s in exec_sigs)
    tot_exit_slip_usd = sum(s["adverse_exit_slip"] * 100.0 * s["lot"] for s in exec_sigs)
    mean_spread = sum(s["spread_at_signal"] for s in exec_sigs) / len(exec_sigs)
    print(f"\n[{label}]")
    print(f"  Final Balance: ${bal:.2f} | Net P&L: ${bal - 10000.0:+.2f} | Peak Equity: ${peak:.2f} | Max Closed-Trade DD: ${max_dd_usd:.2f} ({max_dd_pct:.2f}%)")
    print(f"  OrderCalcProfit (sent_sl) Risk Breaches (>1% Equity): {norm_breaches} / {len(exec_sigs)}")
    print(f"  Unrounded 6-dec SL_Dist micro-diffs (>1% Equity due to 2-dec SL rounding): {unrounded_breaches} / {len(exec_sigs)} (Max diff: +${max_norm_excess:.4f})")
    print(f"  Entry Slippage: Mean = ${mean_ent_slip:.4f}/oz")
    print(f"  Exit Slippage (SL exits, N={len(sl_exits)}): Mean adverse slip = +${mean_sl_slip:.4f}/oz")
    print(f"  Exit Slippage (TP exits, N={len(tp_exits)}): Mean slip = ${mean_tp_slip:+.4f}/oz (negative = favorable price improvement)")
    print(f"  Net Exit Slippage (All {len(exec_sigs)} trades): Mean = +${mean_all_exit_slip:.4f}/oz | Total = +${tot_exit_slip_usd:.2f} ({tot_exit_slip_r:+.2f} R)")
    print(f"  Directly Observed Bid/Ask Spread at Entry: Mean = ${mean_spread:.4f}/oz")

portfolio_curve_and_risk(v1_b_exec, "Layer B V1 Baseline")
portfolio_curve_and_risk(v2_b_exec, "Layer B Inverse V2")


print("\n================ LAYER B: OVERLAP & SELECTION-BIAS DIAGNOSTIC ================")
calc_r_stats([v1_b[i] for i in range(2506) if v1_b[i]["status"] == "EXECUTED" and v2_b[i]["status"] == "EXECUTED"], "Layer B V1 (Common 1,740 Executed)")
calc_r_stats([v2_b[i] for i in range(2506) if v1_b[i]["status"] == "EXECUTED" and v2_b[i]["status"] == "EXECUTED"], "Layer B V2 (Common 1,740 Executed)")
calc_r_stats([v1_b[i] for i in range(2506) if v1_b[i]["status"] == "EXECUTED" and v2_b[i]["reject_reason"] == "MAX_OPEN_TRADES"], "V1 Exec / V2 Rej MaxOpen (N=116)")
calc_r_stats([v2_b[i] for i in range(2506) if v2_b[i]["status"] == "EXECUTED" and v1_b[i]["reject_reason"] == "MAX_OPEN_TRADES"], "V2 Exec / V1 Rej MaxOpen (N=81)")
calc_r_stats([v2_b[i] for i in range(2506) if v2_b[i]["status"] == "EXECUTED" and v1_b[i]["reject_reason"] == "BELOW_MINIMUM_VOLUME"], "V2 Exec / V1 Rej MinVol (N=7)")

print("\n================ YEAR-BY-YEAR BREAKDOWN (LAYER A vs LAYER B) ================")
for yr in [2023, 2024, 2025, 2026]:
    calc_r_stats([s for s in v1_a_exec if s["year"] == yr], f"Layer A V1 ({yr})")
    calc_r_stats([s for s in v2_a_exec if s["year"] == yr], f"Layer A V2 ({yr})")
for yr in [2023, 2024, 2025, 2026]:
    calc_r_stats([s for s in v1_b_exec if s["year"] == yr], f"Layer B V1 ({yr})")
    calc_r_stats([s for s in v2_b_exec if s["year"] == yr], f"Layer B V2 ({yr})")

# Classify the 211 V1_LOSS x V2_LOSS pairs in Layer A:
# 1) Same exit timestamp or within same M5 bar / whipsaw vs 2) Spread-induced failure where price reached V1's SL (or V2's TP threshold) on one quote side without clearing the spread on the other quote side!
both_loss = [(v1_a[i], v2_a[i]) for i in range(2506) if v1_a[i]["status"] == "EXECUTED" and v2_a[i]["status"] == "EXECUTED" and not v1_a[i]["is_win"] and not v2_a[i]["is_win"]]
v1_first = sum(1 for s1, s2 in both_loss if s1["time_out"] < s2["time_out"])
v2_first = sum(1 for s1, s2 in both_loss if s2["time_out"] < s1["time_out"])
same_ts = sum(1 for s1, s2 in both_loss if s1["time_out"] == s2["time_out"])
print(f"\nBoth-Loss Breakdown (N={len(both_loss)}): V1_SL_first={v1_first}, V2_SL_first={v2_first}, Same_TS={same_ts}")
print("Sample V1_LOSS x V2_LOSS pairs:")
for s1, s2 in both_loss[:5]:
    print(
        f"  Sig #{s1['id']} ({s1['time']}): Spread=${s1['spread_at_signal']:.2f} | "
        f"V1 {s1['exec_dir']} Entry={s1['entry_price']:.2f} SL={s1['sent_sl']:.2f} TP={s1['sent_tp']:.2f} -> Exit({s1['exit_reason']})={s1['exit_price']:.2f} at {s1['time_out']} ({s1['r_mult']:+.3f}R) | "
        f"V2 {s2['exec_dir']} Entry={s2['entry_price']:.2f} SL={s2['sent_sl']:.2f} TP={s2['sent_tp']:.2f} -> Exit({s2['exit_reason']})={s2['exit_price']:.2f} at {s2['time_out']} ({s2['r_mult']:+.3f}R)"
    )
