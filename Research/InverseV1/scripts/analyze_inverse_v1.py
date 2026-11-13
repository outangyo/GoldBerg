import re
import math
from collections import Counter

SCRATCH = r"C:\Users\ACER\.gemini\antigravity\brain\58ab35aa-a701-45db-a18f-d8f6f11fcccc\scratch"

t_re = re.compile(r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})")
start_re = re.compile(r"testing of Experts\\.*started")
sig_re = re.compile(
    r"\[SetupAnalyzer\]\[SIGNAL (BUY|SELL)\] M5 Close ([\d\.]+) [><] Extreme Bar (?:High|Low) ([\d\.]+) \| Entry\((?:Ask|Bid)\): ([\d\.]+) \| SL: ([\d\.]+) \| TP: ([\d\.]+) \| RR: ([\d\.]+)"
)
inv1_re = re.compile(
    r"\[INFO\] \[InverseV1\] Transformed (BUY|SELL) -> (BUY|SELL) \| "
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
eot_re = re.compile(
    r"position closed due end of test at ([\d\.]+) \[#(\d+) (buy|sell) ([\d\.]+) GOLD ([\d\.]+)"
)

def parse_log(filename, is_inv_v1=False):
    path = f"{SCRATCH}\\{filename}"
    with open(path, "r", encoding="utf-16le", errors="ignore") as f:
        all_lines = f.readlines()

    run_start = 0
    for idx, line in enumerate(all_lines):
        if start_re.search(line):
            run_start = idx
    lines = all_lines[run_start:]

    signals = []
    cur_sig = None
    deals_by_order = {}
    trigs_by_exit_order = {}
    eot_by_pos_order = {}

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

        im = inv1_re.search(l)
        if im and cur_sig is not None:
            inv_dir_str = im.group(2)
            inv_entry = float(im.group(6))
            sl_d = cur_sig["orig_sl_dist"]
            tp_d = cur_sig["orig_tp_dist"]
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

        eotm = eot_re.search(l)
        if eotm:
            pos_id = int(eotm.group(2))
            eot_by_pos_order[pos_id] = {
                "time": ts,
                "reason": "END_OF_TEST",
                "close_price": float(eotm.group(1)),
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
            if pos_id in exits_by_pos:
                s.update(exits_by_pos[pos_id])
            elif pos_id in eot_by_pos_order:
                einfo = eot_by_pos_order[pos_id]
                s["exit_order"] = None
                s["deal_out"] = None
                s["time_out"] = einfo["time"]
                s["exit_price"] = einfo["close_price"]
                s["trig_price"] = einfo["close_price"]
                s["exit_reason"] = "END_OF_TEST"
            else:
                s["exit_reason"] = "OPEN_OR_MISSING"

            ep = s["entry_price"]
            xp = s["exit_price"]
            lot = s["lot"]
            pts = (xp - ep) if s["exec_dir"] == "LONG" else (ep - xp)
            pnl_usd = round(pts * 100.0 * lot, 2)
            sent_sl_dist = abs(s["req_entry"] - s["sent_sl"])
            r_val = pts / s["sl_dist"] if s["sl_dist"] > 0 else 0.0
            r_val_sent = pts / sent_sl_dist if sent_sl_dist > 0 else 0.0
            s["pts"] = pts
            s["pnl_usd"] = pnl_usd
            s["r_mult"] = r_val
            s["r_mult_sent"] = r_val_sent
            s["is_win"] = pnl_usd > 0
            s["entry_slip"] = (ep - s["req_entry"]) if s["exec_dir"] == "LONG" else (s["req_entry"] - ep)
            ref_level = s["sent_sl"] if s["exit_reason"] == "SL" else (s["sent_tp"] if s["exit_reason"] == "TP" else s["trig_price"])
            s["adverse_exit_slip"] = (ref_level - xp) if s["exec_dir"] == "LONG" else (xp - ref_level)
            s["adverse_exit_slip_r"] = s["adverse_exit_slip"] / s["sl_dist"] if s["sl_dist"] > 0 else 0.0

    return signals, all_lines[:35], all_lines[-30:], len(deals_by_order)

v1_b, _, _, v1_b_deals = parse_log("v1_layerB_portfolio.log", is_inv_v1=False)
iv1_b, iv1_b_hdr, iv1_b_ftr, iv1_b_deals = parse_log("inverse_v1_layerB_portfolio.log", is_inv_v1=True)
v1_a, _, _, v1_a_deals = parse_log("v1_layerA_matched.log", is_inv_v1=False)
iv1_a, iv1_a_hdr, iv1_a_ftr, iv1_a_deals = parse_log("inverse_v1_layerA_matched.log", is_inv_v1=True)

print("=== INVERSE V1 TESTER HEADER / FOOTER VERIFICATION ===")
for l in iv1_b_hdr:
    if any(k in l for k in ["leverage", "testing of", "real ticks"]):
        print("  LayerB HDR:", l.strip())
for l in iv1_b_ftr:
    if any(k in l for k in ["M15_SWEEP", "M5_BREAK_CONFIRMED", "RISK_", "BELOW_MINIMUM", "MAX_OPEN", "ORDER", "Execution Failed", "ticks"]):
        print("  LayerB FTR:", l.strip())
for l in iv1_a_ftr:
    if any(k in l for k in ["M5_BREAK_CONFIRMED", "RISK_REJECTED", "ORDERS_EXECUTED", "Execution Failed", "ticks"]):
        print("  LayerA FTR:", l.strip())

# Verify 1-to-1 signal identity
assert len(v1_b) == len(iv1_b) == len(v1_a) == len(iv1_a) == 2506
for i in range(2506):
    assert v1_b[i]["time"] == iv1_b[i]["time"] == v1_a[i]["time"] == iv1_a[i]["time"]
    assert v1_b[i]["orig_dir"] == iv1_b[i]["orig_dir"]
    assert abs(v1_b[i]["orig_entry"] - iv1_b[i]["orig_entry"]) < 1e-6
    spread = iv1_a[i]["spread_at_signal"]
    v1_b[i]["spread_at_signal"] = spread
    v1_a[i]["spread_at_signal"] = spread
    # Standalone $10,000 / 1.0% ($100 risk budget) theoretical min-volume eligibility check:
    for s in (v1_b[i], v1_a[i], iv1_b[i], iv1_a[i]):
        s["raw_lot_10k"] = 1.0 / s["sl_dist"]
        s["min_vol_reject_10k"] = s["raw_lot_10k"] < 0.01 - 1e-9

print(f"\n1-to-1 Signal Identity Verified: 2,506 / 2,506 signals match.")
print(f"Deals count: V1_B={v1_b_deals}, InvV1_B={iv1_b_deals}, V1_A={v1_a_deals}, InvV1_A={iv1_a_deals}")
print(f"EOT open positions in InvV1_B={sum(1 for s in iv1_b if s.get('exit_reason')=='END_OF_TEST')}, InvV1_A={sum(1 for s in iv1_a if s.get('exit_reason')=='END_OF_TEST')}")
print(f"Missing exits in InvV1_B={sum(1 for s in iv1_b if s.get('exit_reason')=='OPEN_OR_MISSING')}, InvV1_A={sum(1 for s in iv1_a if s.get('exit_reason')=='OPEN_OR_MISSING')}")

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
        f"PF(R)={pf_r:4.2f} | PF($)={pf_usd:4.2f} | NetPnL=${net_pnl:+10.2f} (GP=${gp:.2f}, GL=-${gl:.2f})"
    )

print("\n================ LAYER A: MATCHED-SIGNAL DIAGNOSTIC (V1 vs INVERSE V1) ================")
v1_a_exec = [s for s in v1_a if s["status"] == "EXECUTED"]
iv1_a_exec = [s for s in iv1_a if s["status"] == "EXECUTED"]
calc_r_stats(v1_a_exec, "Layer A V1 (All 2,493 Exec Signals)")
calc_r_stats(iv1_a_exec, "Layer A InvV1 (All 2,493 Exec Signals)")
calc_r_stats([s for s in v1_a_exec if s["exec_dir"] == "LONG"], "  Layer A V1 LONG (Orig BUY)")
calc_r_stats([s for s in iv1_a_exec if s["exec_dir"] == "SHORT"], "  Layer A InvV1 SHORT (from Orig BUY)")
calc_r_stats([s for s in v1_a_exec if s["exec_dir"] == "SHORT"], "  Layer A V1 SHORT (Orig SELL)")
calc_r_stats([s for s in iv1_a_exec if s["exec_dir"] == "LONG"], "  Layer A InvV1 LONG (from Orig SELL)")

print(f"\nTheoretical Standalone $10,000 / 1.0% ($100 Risk) Min-Volume Rejections across 2,506 signals:")
print(f"  V1: {sum(1 for s in v1_a if s['min_vol_reject_10k'])} / 2506 (Max D_SL = ${max(s['sl_dist'] for s in v1_a):.2f}, Min RawLot@10k = {min(s['raw_lot_10k'] for s in v1_a):.4f})")
print(f"  Inverse V1: {sum(1 for s in iv1_a if s['min_vol_reject_10k'])} / 2506 (Max D_SL = ${max(s['sl_dist'] for s in iv1_a):.2f}, Min RawLot@10k = {min(s['raw_lot_10k'] for s in iv1_a):.4f})")

# 2x2 Outcome Cross-Tabulation on the 2,493 paired executed signals
ct = Counter()
dur_comp = Counter()
for i in range(2506):
    s1, s2 = v1_a[i], iv1_a[i]
    if s1["status"] == "EXECUTED" and s2["status"] == "EXECUTED":
        k = ("V1_WIN" if s1["is_win"] else "V1_LOSS", "InvV1_WIN" if s2["is_win"] else "InvV1_LOSS")
        ct[k] += 1
        if s1["time_out"] == s2["time_out"]:
            dur_comp["SAME_EXIT_TIMESTAMP"] += 1
        elif s1["time_out"] < s2["time_out"]:
            dur_comp["V1_EXITS_FIRST"] += 1
        else:
            dur_comp["INVV1_EXITS_FIRST"] += 1

print("\nLayer A 2x2 Outcome Cross-Tabulation (N = 2,493 Matched Signal Pairs):")
for k, v in sorted(ct.items()):
    print(f"  {k[0]:10s} x {k[1]:10s}: {v:4d} ({v/2493*100:.2f}%)")
print("Layer A Exit Timing Comparison (V1 vs InvV1):", dict(dur_comp))

# Layer A Concurrency & Margin for Inverse V1
events = []
for s in iv1_a_exec:
    events.append((s["time"], +1, s))
    events.append((s["time_out"], -1, s))
events.sort(key=lambda x: (x[0], x[1]))
open_pos = {}
max_conc = 0
max_conc_ts = None
max_lots = 0.0
max_marg = 0.0
max_marg_ts = None
min_mlevel = float("inf")
min_mlevel_ts = None
c_bal = 100000.0
for ts, etype, s in events:
    if etype == -1:
        open_pos.pop(s["id"], None)
        c_bal += s["pnl_usd"]
    else:
        open_pos[s["id"]] = s
        if len(open_pos) > max_conc:
            max_conc = len(open_pos)
            max_conc_ts = ts
        gm = sum(p["lot"] * p["entry_price"] * 100.0 / 500.0 for p in open_pos.values())
        tl = sum(p["lot"] for p in open_pos.values())
        if tl > max_lots:
            max_lots = tl
        if gm > max_marg:
            max_marg = gm
            max_marg_ts = ts
        if gm > 0:
            ml = (c_bal / gm) * 100.0
            if ml < min_mlevel:
                min_mlevel = ml
                min_mlevel_ts = ts

print(f"\n[Layer A Inverse V1 Concurrency & Margin]")
print(f"  Max Concurrent Open Positions: {max_conc} (at {max_conc_ts})")
print(f"  Peak Gross Open Volume: {max_lots:.2f} lots")
print(f"  Peak Gross Margin Used (at 1:500): ${max_marg:.2f} (at {max_marg_ts})")
print(f"  Minimum Margin Level (at 1:500): {min_mlevel:.2f}% (at {min_mlevel_ts})")
print(f"  Final Closed Balance (from $100,000): ${c_bal:.2f}")

print("\n================ LAYER B: FULL PORTFOLIO BACKTEST (V1 vs INVERSE V1) ================")
v1_b_exec = [s for s in v1_b if s["status"] == "EXECUTED"]
iv1_b_exec = [s for s in iv1_b if s["status"] == "EXECUTED"]
calc_r_stats(v1_b_exec, "Layer B V1 Portfolio (N=1,911)")
calc_r_stats(iv1_b_exec, f"Layer B InvV1 Portfolio (N={len(iv1_b_exec)})")
calc_r_stats([s for s in v1_b_exec if s["exec_dir"] == "LONG"], "  Layer B V1 LONG (Orig BUY)")
calc_r_stats([s for s in iv1_b_exec if s["exec_dir"] == "SHORT"], "  Layer B InvV1 SHORT (from Orig BUY)")
calc_r_stats([s for s in v1_b_exec if s["exec_dir"] == "SHORT"], "  Layer B V1 SHORT (Orig SELL)")
calc_r_stats([s for s in iv1_b_exec if s["exec_dir"] == "LONG"], "  Layer B InvV1 LONG (from Orig SELL)")

# Layer B Selection / Overlap Matrix across all 2,506 signals
b_matrix = Counter()
for i in range(2506):
    st1 = v1_b[i]["status"] if v1_b[i]["status"] != "REJECTED" else f"REJ_{v1_b[i]['reject_reason']}"
    st2 = iv1_b[i]["status"] if iv1_b[i]["status"] != "REJECTED" else f"REJ_{iv1_b[i]['reject_reason']}"
    b_matrix[(st1, st2)] += 1

print("\nLayer B Signal Fate Cross-Tabulation (V1 Status x InvV1 Status across all 2,506 signals):")
for (st1, st2), cnt in sorted(b_matrix.items()):
    print(f"  V1={st1:25s} | InvV1={st2:25s} : {cnt:4d} ({cnt/2506*100:.2f}%)")

print("\nLayer B Overlap & Non-Overlapping Subsets:")
calc_r_stats([v1_b[i] for i in range(2506) if v1_b[i]["status"] == "EXECUTED" and iv1_b[i]["status"] == "EXECUTED"], "Layer B V1 (Common Executed)")
calc_r_stats([iv1_b[i] for i in range(2506) if v1_b[i]["status"] == "EXECUTED" and iv1_b[i]["status"] == "EXECUTED"], "Layer B InvV1 (Common Executed)")
calc_r_stats([v1_b[i] for i in range(2506) if v1_b[i]["status"] == "EXECUTED" and iv1_b[i]["status"] != "EXECUTED"], "V1 Exec / InvV1 Not Exec")
calc_r_stats([iv1_b[i] for i in range(2506) if iv1_b[i]["status"] == "EXECUTED" and v1_b[i]["status"] != "EXECUTED"], "InvV1 Exec / V1 Not Exec")

# Portfolio curve, drawdown, risk compliance, and execution costs for Inverse V1 Layer B
bal = 10000.0
peak = 10000.0
max_dd_usd = 0.0
max_dd_pct = 0.0
sent_sl_breaches = 0
exact_sl_breaches = 0
for s in iv1_b_exec:
    eq_before = bal
    allowed = eq_before * 0.01
    sent_sl_dist = abs(s["req_entry"] - s["sent_sl"])
    if sent_sl_dist * 100.0 * s["lot"] > allowed + 1e-6:
        sent_sl_breaches += 1
    if s["sl_dist"] * 100.0 * s["lot"] > allowed + 1e-6:
        exact_sl_breaches += 1
    bal = round(bal + s["pnl_usd"], 2)
    if bal > peak:
        peak = bal
    dd_u = peak - bal
    dd_p = dd_u / peak * 100.0
    if dd_u > max_dd_usd:
        max_dd_usd = dd_u
    if dd_p > max_dd_pct:
        max_dd_pct = dd_p

sl_exits = [s for s in iv1_b_exec if s["exit_reason"] == "SL"]
tp_exits = [s for s in iv1_b_exec if s["exit_reason"] == "TP"]
eot_exits = [s for s in iv1_b_exec if s["exit_reason"] == "END_OF_TEST"]
mean_ent_slip = sum(s["entry_slip"] for s in iv1_b_exec) / len(iv1_b_exec)
mean_sl_slip = sum(s["adverse_exit_slip"] for s in sl_exits) / len(sl_exits) if sl_exits else 0.0
mean_tp_slip = sum(s["adverse_exit_slip"] for s in tp_exits) / len(tp_exits) if tp_exits else 0.0
mean_all_exit_slip = sum(s["adverse_exit_slip"] for s in iv1_b_exec) / len(iv1_b_exec)
tot_exit_slip_r = sum(s["adverse_exit_slip_r"] for s in iv1_b_exec)
tot_exit_slip_usd = sum(s["adverse_exit_slip"] * 100.0 * s["lot"] for s in iv1_b_exec)
mean_spread = sum(s["spread_at_signal"] for s in iv1_b_exec) / len(iv1_b_exec)

print(f"\n[Layer B Inverse V1 Portfolio Risk & Execution Costs]")
print(f"  Final Balance: ${bal:.2f} | Net P&L: ${bal - 10000.0:+.2f} | Peak Equity: ${peak:.2f} | Max Closed-Trade DD: ${max_dd_usd:.2f} ({max_dd_pct:.2f}%)")
print(f"  Submitted SL (sent_sl) Risk Breaches (>1% Equity): {sent_sl_breaches} / {len(iv1_b_exec)}")
print(f"  Unrounded SL_Dist Risk Breaches (>1% Equity): {exact_sl_breaches} / {len(iv1_b_exec)}")
print(f"  Exit counts: SL={len(sl_exits)}, TP={len(tp_exits)}, EOT={len(eot_exits)}")
print(f"  Entry Slippage: Mean = ${mean_ent_slip:.4f}/oz")
print(f"  Exit Slippage (SL exits, N={len(sl_exits)}): Mean adverse slip = +${mean_sl_slip:.4f}/oz")
print(f"  Exit Slippage (TP exits, N={len(tp_exits)}): Mean slip = ${mean_tp_slip:+.4f}/oz (negative = favorable price improvement)")
print(f"  Net Exit Slippage (All {len(iv1_b_exec)} trades): Mean = +${mean_all_exit_slip:.4f}/oz | Total = +${tot_exit_slip_usd:.2f} ({tot_exit_slip_r:+.2f} R)")
print(f"  Directly Observed Bid/Ask Spread at Entry: Mean = ${mean_spread:.4f}/oz")

print("\n================ YEAR-BY-YEAR BREAKDOWN (INVERSE V1 LAYER A & LAYER B) ================")
for yr in [2023, 2024, 2025, 2026]:
    calc_r_stats([s for s in iv1_a_exec if s["year"] == yr], f"Layer A InvV1 ({yr})")
for yr in [2023, 2024, 2025, 2026]:
    calc_r_stats([s for s in iv1_b_exec if s["year"] == yr], f"Layer B InvV1 ({yr})")
