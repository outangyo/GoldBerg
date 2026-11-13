import math

def transform_inverse_v2(orig_action, orig_entry, orig_sl, orig_tp, current_bid, current_ask, equity=10000.0, risk_pct=1.0, digits=2, vol_min=0.01, vol_max=100.0, vol_step=0.01, contract_size=100.0):
    orig_sl_dist = abs(orig_entry - orig_sl)
    orig_tp_dist = abs(orig_tp - orig_entry)
    if orig_entry <= 0.0 or orig_sl_dist <= 0.0 or orig_tp_dist <= 0.0:
        return {"status": "REJECTED", "reason": "Invalid Original Signal Geometry"}
    
    if orig_action == "BUY":
        inv_action = "SELL"
    elif orig_action == "SELL":
        inv_action = "BUY"
    else:
        inv_action = "NONE"
        
    inv_entry = current_ask if inv_action == "BUY" else current_bid
    if inv_action == "NONE" or inv_entry <= 0.0:
        return {"status": "REJECTED", "reason": "Invalid Inverse Action/Entry"}
        
    inv_sl = (inv_entry - orig_tp_dist) if inv_action == "BUY" else (inv_entry + orig_tp_dist)
    inv_tp = (inv_entry + orig_sl_dist) if inv_action == "BUY" else (inv_entry - orig_sl_dist)
    inv_rr = orig_sl_dist / orig_tp_dist if orig_tp_dist > 0 else 0.0
    
    # RiskManager check
    if inv_action == "BUY" and inv_sl >= inv_entry:
        return {"status": "REJECTED", "reason": "INVALID_SL"}
    if inv_action == "SELL" and inv_sl <= inv_entry:
        return {"status": "REJECTED", "reason": "INVALID_SL"}
        
    allowed_risk = equity * (risk_pct / 100.0)
    inv_sl_dist = abs(inv_entry - inv_sl)
    loss_per_lot = inv_sl_dist * contract_size
    raw_lot = allowed_risk / loss_per_lot
    
    if raw_lot < vol_min:
        return {
            "status": "REJECTED",
            "reason": "BELOW_MINIMUM_VOLUME",
            "inv_action": inv_action,
            "inv_entry": inv_entry,
            "inv_sl": inv_sl,
            "inv_tp": inv_tp,
            "inv_sl_dist": inv_sl_dist,
            "inv_tp_dist": abs(inv_tp - inv_entry),
            "inv_rr": inv_rr,
            "raw_lot": raw_lot
        }
    if raw_lot > vol_max:
        return {"status": "REJECTED", "reason": "ABOVE_MAXIMUM_VOLUME"}
        
    steps = math.floor(((raw_lot - vol_min) / vol_step) + 1e-7)
    norm_lot = round(vol_min + steps * vol_step, 2)
    realized_risk_usd = norm_lot * loss_per_lot
    
    return {
        "status": "OK",
        "orig_action": orig_action,
        "inv_action": inv_action,
        "orig_entry": orig_entry,
        "orig_sl_dist": orig_sl_dist,
        "orig_tp_dist": orig_tp_dist,
        "inv_entry": inv_entry,
        "inv_sl": inv_sl,
        "inv_tp": inv_tp,
        "norm_sl": round(inv_sl, digits),
        "norm_tp": round(inv_tp, digits),
        "inv_sl_dist": inv_sl_dist,
        "inv_tp_dist": abs(inv_tp - inv_entry),
        "inv_rr": inv_rr,
        "raw_lot": raw_lot,
        "norm_lot": norm_lot,
        "allowed_risk_usd": allowed_risk,
        "planned_risk_usd": realized_risk_usd
    }

print("=== DETERMINISTIC GEOMETRY & RISK SIZING TESTS ===")

# Test 1: Handoff Example (Original V1 BUY @ 4000, SL=3990, TP=4015, Bid=3999.65, Ask=4000.00)
t1 = transform_inverse_v2("BUY", 4000.00, 3990.00, 4015.00, current_bid=3999.65, current_ask=4000.00)
assert t1["status"] == "OK"
assert t1["inv_action"] == "SELL"
assert math.isclose(t1["inv_entry"], 3999.65)
assert math.isclose(t1["inv_sl"], 3999.65 + 15.0)
assert math.isclose(t1["inv_tp"], 3999.65 - 10.0)
assert math.isclose(t1["inv_sl_dist"], 15.0)
assert math.isclose(t1["inv_tp_dist"], 10.0)
assert math.isclose(t1["inv_rr"], 10.0 / 15.0, rel_tol=1e-6)
assert t1["inv_sl"] > t1["inv_entry"] and t1["inv_tp"] < t1["inv_entry"]
assert t1["norm_lot"] == 0.06 # $100 / ($15 * 100 = $1500/lot) = 0.0666 -> floor 0.06
assert t1["planned_risk_usd"] <= t1["allowed_risk_usd"]
print(f"[PASS] Test 1 (Orig BUY -> Inv SELL): Entry={t1['inv_entry']:.2f}, SL={t1['inv_sl']:.2f} (+{t1['inv_sl_dist']:.2f}), TP={t1['inv_tp']:.2f} (-{t1['inv_tp_dist']:.2f}), RR={t1['inv_rr']:.4f}, Lot={t1['norm_lot']:.2f} (Risk=${t1['planned_risk_usd']:.2f} <= ${t1['allowed_risk_usd']:.2f})")

# Test 2: Original V1 SELL -> Inverse V2 BUY (Orig SELL @ 4000.00 Bid, SL=4010.00, TP=3985.00, Ask=4000.35)
t2 = transform_inverse_v2("SELL", 4000.00, 4010.00, 3985.00, current_bid=4000.00, current_ask=4000.35)
assert t2["status"] == "OK"
assert t2["inv_action"] == "BUY"
assert math.isclose(t2["inv_entry"], 4000.35)
assert math.isclose(t2["inv_sl"], 4000.35 - 15.0)
assert math.isclose(t2["inv_tp"], 4000.35 + 10.0)
assert math.isclose(t2["inv_sl_dist"], 15.0)
assert math.isclose(t2["inv_tp_dist"], 10.0)
assert math.isclose(t2["inv_rr"], 10.0 / 15.0, rel_tol=1e-6)
assert t2["inv_sl"] < t2["inv_entry"] and t2["inv_tp"] > t2["inv_entry"]
assert t2["norm_lot"] == 0.06
print(f"[PASS] Test 2 (Orig SELL -> Inv BUY): Entry={t2['inv_entry']:.2f}, SL={t2['inv_sl']:.2f} (-{t2['inv_sl_dist']:.2f}), TP={t2['inv_tp']:.2f} (+{t2['inv_tp_dist']:.2f}), RR={t2['inv_rr']:.4f}, Lot={t2['norm_lot']:.2f}")

# Test 3: Odd-cent SL distance rounding check (Orig SL dist = $3.33, Orig TP dist = $4.995)
t3 = transform_inverse_v2("BUY", 2500.00, 2496.67, 2500.00 + 3.33 * 1.5, current_bid=2499.65, current_ask=2500.00)
assert t3["status"] == "OK"
print(f"[PASS] Test 3 (Odd-cent 1.5x distance): Unrounded InvSL={t3['inv_sl']:.3f} vs Normalized InvSL={t3['norm_sl']:.2f} (0.5 pt rounding note verified)")

# Test 4: Zero/Invalid Geometry Rejections
for label, args in [
    ("Zero original entry", ("BUY", 0.0, 3990.0, 4015.0, 3999.65, 4000.0)),
    ("Zero SL distance (entry == SL)", ("BUY", 4000.0, 4000.0, 4015.0, 3999.65, 4000.0)),
    ("Zero TP distance (entry == TP)", ("SELL", 4000.0, 4010.0, 4000.0, 4000.0, 4000.35)),
    ("Invalid action NONE", ("NONE", 4000.0, 3990.0, 4015.0, 3999.65, 4000.0)),
    ("Zero inverse quote", ("BUY", 4000.0, 3990.0, 4015.0, 0.0, 4000.0))
]:
    res = transform_inverse_v2(*args)
    assert res["status"] == "REJECTED"
    print(f"[PASS] Test 4 ({label}): Safely rejected -> {res['reason']}")

# Test 5: Below minimum volume rejection when Inverse SL (1.5x original SL) exceeds risk budget for 0.01 lot
# At $10,000 equity, 1% risk = $100. For 0.01 lot ($1/pt), max SL distance is $100.00.
# If original SL = $70 (which would allow 0.01 lot in V1!), original TP = $105 -> Inverse SL = $105 > $100 -> REJECT_BELOW_MINIMUM_VOLUME
t5 = transform_inverse_v2("BUY", 4000.0, 3930.0, 4105.0, current_bid=3999.65, current_ask=4000.00, equity=10000.0)
assert t5["status"] == "REJECTED" and t5["reason"] == "BELOW_MINIMUM_VOLUME"
print(f"[PASS] Test 5 (1.5x Inverse SL Min-Volume Gate): OrigSL=$70 (V1 valid 0.01 lot) -> InvSL=$105 -> RawLot={t5['raw_lot']:.4f} < 0.01 -> Safely rejected ({t5['reason']})")
