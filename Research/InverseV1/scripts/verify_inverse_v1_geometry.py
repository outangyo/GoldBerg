import math

def mql5_normalize_double(val, digits=2):
    # MQL5 NormalizeDouble rounds half away from zero
    factor = 10 ** digits
    return math.floor(val * factor + 0.5) / factor if val >= 0 else math.ceil(val * factor - 0.5) / factor

def transform_inverse_v1(orig_action, orig_entry, orig_sl, orig_tp, current_bid, current_ask):
    orig_sl_dist = abs(orig_entry - orig_sl)
    orig_tp_dist = abs(orig_tp - orig_entry)
    assert orig_entry > 0 and orig_sl_dist > 0 and orig_tp_dist > 0

    inv_action = "SELL" if orig_action == "BUY" else "BUY"
    inv_entry = current_ask if inv_action == "BUY" else current_bid

    if inv_action == "BUY":
        inv_sl = inv_entry - orig_sl_dist
        inv_tp = inv_entry + orig_tp_dist
    else:
        inv_sl = inv_entry + orig_sl_dist
        inv_tp = inv_entry - orig_tp_dist

    rr = orig_tp_dist / orig_sl_dist
    return {
        "orig_action": orig_action,
        "inv_action": inv_action,
        "orig_entry": orig_entry,
        "orig_sl_dist": orig_sl_dist,
        "orig_tp_dist": orig_tp_dist,
        "inv_entry": inv_entry,
        "inv_sl_raw": inv_sl,
        "inv_tp_raw": inv_tp,
        "inv_sl_norm": mql5_normalize_double(inv_sl, 2),
        "inv_tp_norm": mql5_normalize_double(inv_tp, 2),
        "rr": rr,
    }

def calc_lot_size(equity, risk_pct, inv_action, inv_entry, inv_sl_raw, min_lot=0.01, step=0.01):
    # RiskManager passes (executable_entry, stop_loss) to OrderCalcProfit
    # On GOLD (100 oz, _Digits=2), OrderCalcProfit normalizes entry/sl to 2 decimals
    sl_norm = mql5_normalize_double(inv_sl_raw, 2)
    if inv_action == "BUY" and sl_norm >= inv_entry:
        return 0.0, "INVALID_SL"
    if inv_action == "SELL" and sl_norm <= inv_entry:
        return 0.0, "INVALID_SL"
    risk_budget = equity * (risk_pct / 100.0)
    one_lot_loss = abs(inv_entry - sl_norm) * 100.0
    raw_lot = risk_budget / one_lot_loss
    if raw_lot < min_lot - 1e-9:
        return 0.0, f"BELOW_MINIMUM_VOLUME (raw_lot={raw_lot:.6f} < {min_lot})"
    steps = math.floor((raw_lot + 1e-9) / step)
    norm_lot = round(steps * step, 2)
    return norm_lot, f"OK (raw_lot={raw_lot:.6f} -> norm_lot={norm_lot:.2f})"

print("=== TEST 1: Original BUY -> Inverse V1 SELL (Even Cent SL Distance) ===")
t1 = transform_inverse_v1("BUY", orig_entry=4000.00, orig_sl=3990.00, orig_tp=4015.00, current_bid=3999.60, current_ask=4000.00)
lot1, st1 = calc_lot_size(10000.0, 1.0, t1["inv_action"], t1["inv_entry"], t1["inv_sl_raw"])
print(t1, "\nLot:", lot1, st1)
assert t1["inv_action"] == "SELL" and abs(t1["inv_entry"] - 3999.60) < 1e-9
assert abs(t1["inv_sl_raw"] - 4009.60) < 1e-9 and abs(t1["inv_tp_raw"] - 3984.60) < 1e-9 and abs(t1["rr"] - 1.5) < 1e-9

print("\n=== TEST 2: Original SELL -> Inverse V1 BUY (Even Cent SL Distance) ===")
t2 = transform_inverse_v1("SELL", orig_entry=2041.50, orig_sl=2043.30, orig_tp=2038.80, current_bid=2041.50, current_ask=2041.90)
lot2, st2 = calc_lot_size(10000.0, 1.0, t2["inv_action"], t2["inv_entry"], t2["inv_sl_raw"])
print(t2, "\nLot:", lot2, st2)
assert t2["inv_action"] == "BUY" and abs(t2["inv_entry"] - 2041.90) < 1e-9
assert abs(t2["inv_sl_raw"] - 2040.10) < 1e-9 and abs(t2["inv_tp_raw"] - 2044.60) < 1e-9 and abs(t2["rr"] - 1.5) < 1e-9

print("\n=== TEST 3: Odd-Cent Original SL Distance Case (D_SL=1.85 -> D_TP=2.775) ===")
t3 = transform_inverse_v1("BUY", orig_entry=2050.00, orig_sl=2048.15, orig_tp=2052.775, current_bid=2049.60, current_ask=2050.00)
lot3, st3 = calc_lot_size(10000.0, 1.0, t3["inv_action"], t3["inv_entry"], t3["inv_sl_raw"])
print(t3, "\nLot:", lot3, st3)
# Verify that Inverse SL has ZERO half-cent rounding because D_SL_original is an exact 2-decimal tick distance!
assert abs(t3["inv_sl_raw"] - t3["inv_sl_norm"]) < 1e-9
# Verify that only Inverse TP has a 0.005 half-cent normalized to 2 decimals
assert abs(abs(t3["inv_tp_raw"] - t3["inv_tp_norm"]) - 0.005) < 1e-9

print("\n=== TEST 4: Below-Minimum-Volume Rejection Case ===")
t4 = transform_inverse_v1("SELL", orig_entry=3500.00, orig_sl=3525.00, orig_tp=3462.50, current_bid=3500.00, current_ask=3500.40)
lot4, st4 = calc_lot_size(1800.0, 1.0, t4["inv_action"], t4["inv_entry"], t4["inv_sl_raw"])
print(t4, "\nLot:", lot4, st4)
assert lot4 == 0.0 and "BELOW_MINIMUM_VOLUME" in st4

print("\nALL 4 DETERMINISTIC INVERSE V1 GEOMETRY & RISK TESTS PASSED.")
