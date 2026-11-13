import re
import datetime
import math
from collections import defaultdict

log_path = r"C:\Users\ACER\.gemini\antigravity\brain\58ab35aa-a701-45db-a18f-d8f6f11fcccc\scratch\inverse_v2_layerB_portfolio.log"
with open(log_path, "r", encoding="utf-16le", errors="ignore") as f:
    lines = f.readlines()

t_re = re.compile(r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})")
sig_re = re.compile(r"\[SetupAnalyzer\]\[SIGNAL (BUY|SELL)\] M5 Close ([\d\.]+) [><] Extreme Bar (?:High|Low) ([\d\.]+) \| Entry\((?:Ask|Bid)\): ([\d\.]+) \| SL: ([\d\.]+) \| TP: ([\d\.]+) \| RR: ([\d\.]+)")
inv_re = re.compile(
    r"\[INFO\] \[InverseV2\] Transformed (BUY|SELL) -> (BUY|SELL) \| "
    r"OriginalEntry: ([\d\.]+) \| OriginalSLDist: ([\d\.]+) \| OriginalTPDist: ([\d\.]+) \| "
    r"InverseEntry: ([\d\.]+) \| InverseSL: ([\d\.]+) \| InverseTP: ([\d\.]+) \| Reward/Risk: ([\d\.]+)"
)
max_pos_re = re.compile(r"Setup confirmed but rejected by Risk: Max Open Positions")
min_vol_re = re.compile(r"\[RiskManager\]\[DIAGNOSTIC\] NO_TRADE \| Reason: BELOW_MINIMUM_VOLUME \| Equity: ([\d\.]+) \| RiskPct: ([\d\.]+)% \| RiskBudget: ([\d\.]+) \| Entry: ([\d\.]+) \| SL: ([\d\.]+) \| StopDistPoints: ([\d\.]+) \| RawLot: ([\d\.]+) \| MinLot: ([\d\.]+)")
send_re = re.compile(r"\[TradeExecutor\] Sending (BUY|SELL) request \| Symbol: GOLD \| Vol: ([\d\.]+) \| (?:Ask|Bid): ([\d\.]+) \| SL: ([\d\.]+) \| TP: ([\d\.]+)")
fail_re = re.compile(r"\[TradeExecutor\]\[REJECTED/FAIL\] (BUY|SELL) Failed \| Symbol: GOLD \| Vol: ([\d\.]+) \| SL: ([\d\.]+) \| TP: ([\d\.]+) \| Retcode: (\d+) \((.*?)\)")
exec_re = re.compile(r"\[TradeExecutor\]\[SUCCESS\] (BUY|SELL) Executed \| Symbol: GOLD \| Vol: ([\d\.]+) \| Price: ([\d\.]+) \| SL: ([\d\.]+) \| TP: ([\d\.]+) \| Order: (\d+) \| Deal: (\d+) \| Retcode: (\d+)")
deal_re = re.compile(r"deal #(\d+) (buy|sell) ([\d\.]+) GOLD at ([\d\.]+) done \(based on order #(\d+)\)")
op_re = re.compile(r"order performed (buy|sell) ([\d\.]+) at ([\d\.]+) \[#(\d+) (buy|sell) ([\d\.]+) GOLD at ([\d\.]+)\]")
trig_re = re.compile(r"(stop loss|take profit) triggered #(\d+) (buy|sell) ([\d\.]+) GOLD ([\d\.]+) sl: ([\d\.]+) tp: ([\d\.]+) \[#(\d+) (buy|sell) ([\d\.]+) GOLD at ([\d\.]+)\]")

signals_by_time = {}
ops = {}
trigs = {}
deals = []
min_vol_events = []
exec_fail_events = []

for l in lines:
    tm = t_re.search(l)
    if not tm:
        continue
    ts = tm.group(1)
    im = inv_re.search(l)
    if im:
        signals_by_time[ts] = {
            "time": ts,
            "orig_dir": im.group(1),
            "inv_dir": im.group(2),
            "orig_entry": float(im.group(3)),
            "orig_sl_dist": float(im.group(4)),
            "orig_tp_dist": float(im.group(5)),
            "inv_entry": float(im.group(6)),
            "inv_sl": float(im.group(7)),
            "inv_tp": float(im.group(8)),
            "rr": float(im.group(9))
        }
    mvm = min_vol_re.search(l)
    if mvm:
        min_vol_events.append({
            "time": ts,
            "equity": float(mvm.group(1)),
            "risk_budget": float(mvm.group(3)),
            "entry": float(mvm.group(4)),
            "sl": float(mvm.group(5)),
            "stop_pts": float(mvm.group(6)),
            "raw_lot": float(mvm.group(7))
        })
    fm = fail_re.search(l)
    if fm:
        exec_fail_events.append({
            "time": ts,
            "dir": fm.group(1),
            "vol": float(fm.group(2)),
            "retcode": int(fm.group(5)),
            "retdesc": fm.group(6)
        })
    trm = trig_re.search(l)
    if trm:
        trigs[int(trm.group(8))] = {
            "reason": trm.group(1), # 'stop loss' or 'take profit'
            "pos_id": int(trm.group(2)),
            "trig_price": float(trm.group(11))
        }
    om = op_re.search(l)
    if om:
        ops[int(om.group(4))] = {
            "action": om.group(1),
            "lot": float(om.group(2)),
            "exec_price": float(om.group(3)),
            "req_price": float(om.group(7))
        }
    dm = deal_re.search(l)
    if dm:
        deals.append({
            "time": ts,
            "deal_id": int(dm.group(1)),
            "action": dm.group(2),
            "lot": float(dm.group(3)),
            "price": float(dm.group(4)),
            "order_id": int(dm.group(5))
        })

print(f"Total deals: {len(deals)} ({len(deals)//2} closed trades)")
print(f"Min volume rejections: {len(min_vol_events)}")
print(f"Execution failures: {len(exec_fail_events)} -> {exec_fail_events}")

trades = []
balance = 10000.0
peak_balance = 10000.0
max_dd_usd = 0.0
max_dd_pct = 0.0

for i in range(0, len(deals), 2):
    d_in = deals[i]
    d_out = deals[i+1]
    sig = signals_by_time.get(d_in["time"])
    op_in = ops.get(d_in["order_id"])
    op_out = ops.get(d_out["order_id"])
    trig = trigs.get(d_out["order_id"])
    
    # Direction in V2: 'buy' -> V2 LONG (from V1 SHORT), 'sell' -> V2 SHORT (from V1 LONG)
    v2_dir = "LONG" if d_in["action"] == "buy" else "SHORT"
    entry_price = d_in["price"]
    exit_price = d_out["price"]
    lot = d_in["lot"]
    
    inv_sl = sig["inv_sl"]
    inv_tp = sig["inv_tp"]
    v2_sl_dist = sig["orig_tp_dist"] # Planned V2 SL distance = D_TP_original
    v2_tp_dist = sig["orig_sl_dist"] # Planned V2 TP distance = D_SL_original
    
    pts = (exit_price - entry_price) if v2_dir == "LONG" else (entry_price - exit_price)
    pnl_usd = pts * 100.0 * lot
    
    # V2-R is defined with denominator = V2 Planned SL distance (D_SL_inverse = D_TP_original)
    v2_net_r = pts / v2_sl_dist if v2_sl_dist > 0 else 0.0
    
    # Entry & exit slippage
    entry_slip = (entry_price - sig["inv_entry"]) if v2_dir == "LONG" else (sig["inv_entry"] - entry_price)
    trig_price = trig["trig_price"] if trig else (op_out["req_price"] if op_out else exit_price)
    exit_slip = (trig_price - exit_price) if v2_dir == "LONG" else (exit_price - trig_price)
    
    # Check risk budget compliance at entry
    equity_before = balance # since MaxOpenTrades = 1, closed balance == equity before trade
    allowed_risk_usd = equity_before * 0.01
    planned_risk_usd = v2_sl_dist * 100.0 * lot
    norm_sl_dist = abs(entry_price - round(inv_sl, 2))
    norm_planned_risk_usd = norm_sl_dist * 100.0 * lot
    
    balance += pnl_usd
    if balance > peak_balance:
        peak_balance = balance
    dd_usd = peak_balance - balance
    dd_pct = (dd_usd / peak_balance * 100.0) if peak_balance > 0 else 0.0
    if dd_usd > max_dd_usd:
        max_dd_usd = dd_usd
    if dd_pct > max_dd_pct:
        max_dd_pct = dd_pct
        
    trades.append({
        "id": len(trades) + 1,
        "time_in": d_in["time"],
        "time_out": d_out["time"],
        "year": int(d_in["time"][:4]),
        "v2_dir": v2_dir,
        "orig_dir": sig["orig_dir"],
        "lot": lot,
        "entry_price": entry_price,
        "exit_price": exit_price,
        "inv_sl": inv_sl,
        "inv_tp": inv_tp,
        "v2_sl_dist": v2_sl_dist,
        "v2_tp_dist": v2_tp_dist,
        "pts": pts,
        "pnl_usd": pnl_usd,
        "v2_net_r": v2_net_r,
        "is_win": pnl_usd > 0,
        "exit_reason": trig["reason"] if trig else "other",
        "entry_slip": entry_slip,
        "exit_slip": exit_slip,
        "exit_slip_r": exit_slip / v2_sl_dist if v2_sl_dist > 0 else 0.0,
        "spread_at_entry": abs(sig["orig_entry"] - sig["inv_entry"]),
        "equity_before": equity_before,
        "allowed_risk_usd": allowed_risk_usd,
        "planned_risk_usd": planned_risk_usd,
        "norm_planned_risk_usd": norm_planned_risk_usd,
        "realized_risk_pct": ( abs(pnl_usd) / equity_before * 100.0 ) if pnl_usd < 0 else 0.0
    })

def summarize(sub, label):
    n = len(sub)
    wins = [t for t in sub if t["is_win"]]
    losses = [t for t in sub if not t["is_win"]]
    nw, nl = len(wins), len(losses)
    wr = nw / n * 100.0 if n > 0 else 0.0
    avg_win_r = sum(t["v2_net_r"] for t in wins) / nw if nw > 0 else 0.0
    avg_loss_r = sum(t["v2_net_r"] for t in losses) / nl if nl > 0 else 0.0
    net_r = sum(t["v2_net_r"] for t in sub)
    exp_r = net_r / n if n > 0 else 0.0
    gp = sum(t["pnl_usd"] for t in wins)
    gl = abs(sum(t["pnl_usd"] for t in losses))
    net_pnl = gp - gl
    pf = gp / gl if gl > 0 else 999.0
    print(f"{label:28s} | N={n:4d} (W={nw:4d}, L={nl:3d}) | WR={wr:5.2f}% | AvgW={avg_win_r:+.4f}R | AvgL={avg_loss_r:+.4f}R | Exp={exp_r:+.4f}R | NetR={net_r:+8.2f}R | PF={pf:5.2f} | NetPnL=${net_pnl:+9.2f} (GP=${gp:.2f}, GL=-${gl:.2f})")

print("\n=== LAYER B: INVERSE V2 PORTFOLIO BACKTEST SUMMARY ===")
summarize(trades, "ALL TRADES (Combined)")
summarize([t for t in trades if t["v2_dir"] == "LONG"], "V2 LONG (from V1 SHORT)")
summarize([t for t in trades if t["v2_dir"] == "SHORT"], "V2 SHORT (from V1 LONG)")

print(f"\nFinal Balance: ${balance:.2f} | Net P&L: ${balance - 10000.0:+.2f}")
print(f"Peak Balance/Equity: ${peak_balance:.2f} | Max Closed-Trade Drawdown: ${max_dd_usd:.2f} ({max_dd_pct:.2f}%)")

# Risk budget compliance check
breaches_unrounded = [t for t in trades if t["planned_risk_usd"] > t["allowed_risk_usd"] + 1e-4]
breaches_norm = [t for t in trades if t["norm_planned_risk_usd"] > t["allowed_risk_usd"] + 1e-4]
print(f"Risk Budget Compliance: Unrounded breaches = {len(breaches_unrounded)} / {len(trades)} | Normalized SL (0.5pt rounding) breaches = {len(breaches_norm)} / {len(trades)}")
if breaches_norm:
    max_excess = max(t["norm_planned_risk_usd"] - t["allowed_risk_usd"] for t in breaches_norm)
    print(f"  Max normalized SL excess over 1% budget: +${max_excess:.4f}")

# Slippage & Spread stats
tot_entry_slip = sum(t["entry_slip"] for t in trades)
mean_exit_slip = sum(t["exit_slip"] for t in trades) / len(trades)
tot_exit_slip_usd = sum(t["exit_slip"] * 100.0 * t["lot"] for t in trades)
tot_exit_slip_r = sum(t["exit_slip_r"] for t in trades)
mean_spread = sum(t["spread_at_entry"] for t in trades) / len(trades)
print(f"Execution Costs: Entry Slippage = {tot_entry_slip:.4f} | Mean Exit Slip = +${mean_exit_slip:.4f}/oz | Total Exit Slip = +${tot_exit_slip_usd:.2f} (+{tot_exit_slip_r:.2f} V2-R) | Mean Observed Entry Spread = ${mean_spread:.4f}/oz")

print("\n=== YEAR-BY-YEAR BREAKDOWN (V2 PORTFOLIO) ===")
for y in [2023, 2024, 2025, 2026]:
    summarize([t for t in trades if t["year"] == y], f"Year {y}")
