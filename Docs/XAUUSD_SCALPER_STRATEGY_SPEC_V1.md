# XAUUSD Scalper — Strategy Specification V1 (`XAUUSD_SCALPER_STRATEGY_SPEC_V1`)

> **Status**: DRAFT FOR REVIEW / SPECIFICATION IN PROGRESS  
> **Single Source of Truth**: เอกสารฉบับนี้เมื่อได้รับการ Approve จะเป็น **Single Source of Truth** เพียงหนึ่งเดียวสำหรับการพัฒนาโค้ดของ AGY  
> **Strategy Authority**: AGY ห้ามเปลี่ยน Core Strategy เองโดยไม่มีการขอ Approval จาก GPT (PM) & User (PO)

---

## 1. Governance & Non-Requirements (ข้อห้ามเด็ดขาด)

### 1.1 Fundamental Rules
1. **No Martingale**: ห้ามใช้การเบิ้ล Lot Recovery ใน V1 เด็ดขาด
2. **No Forced Trade**: การไม่มีออเดอร์เลย (**0 trades/day**) ถือเป็น **Valid Outcome** ที่ถูกต้องเมื่อเงื่อนไขไม่ผ่าน ห้ามเพิ่มออเดอร์โดยการบังคับเทรด
3. **No Indicator-Only Entry**: ห้ามใช้ Indicator เป็นตัวตัดสินใจหลักในการเปิดออเดอร์โดยปราศจาก Context & Structure
4. **No Daily Profit Target**: ไม่มีการตั้งเป้ากำไรรายวันอันนำไปสู่การ Overtrade
5. **No Unauthorized Optimization**: ห้ามปรับแก้โค้ดหรือจูน Parameter เองเพื่อทำให้ Backtest ดูดีเกินจริง (Overfitting)

---

## 2. Multi-Timeframe Framework (Conceptual Framework — Quantitative Rules Pending)

> **Important**: โครงสร้าง MTF 3 ระดับด้านล่างยังเป็น **Conceptual Framework** โดยที่ Quantitative Rules ทั้งหมดอยู่ระหว่างการยกร่างโดย Strategy Lead (GPT) & Product Owner (User)

### 2.1 Market Context Engine (M15) — Conceptual
- **Objective**: Define if M15 context is `BULLISH`, `BEARISH`, or `NEUTRAL`.
- **Swing Identification Rules**: [ ] Pending Quantitative Rules
- **Structure Break Criteria**: [ ] Pending Quantitative Rules (BOS / CHOCH definitions)
- **Supporting Indicators**: [ ] Pending Quantitative Rules (EMA Filter / Alignment)

### 2.2 Setup Detection Engine (M5) — Conceptual
- **Objective**: Detect valid pullback setups aligned with M15 Market Context.
- **Pullback Identification**: [ ] Pending Quantitative Rules (Depth / Zones / Order Blocks / S&R)
- **Setup Invalidation**: [ ] Pending Quantitative Rules

### 2.3 Entry Timing & Confirmation Engine (M1) — Conceptual
- **Objective**: Precise timing on M1 to enter the trade.
- **Confirmation Signals**: [ ] Pending Quantitative Rules (Liquidity Sweeps / M1 CHOCH / Momentum)
- **Maximum Entry Distance**: [ ] Pending Quantitative Rules

---

## 3. Market Condition & Execution Filters
### 3.1 Spread Filter
- **Max Spread Threshold**: [ ] Pips / Points (Dynamic check against `SymbolInfoInteger(Symbol(), SYMBOL_SPREAD)`).
### 3.2 Volatility Filter
- **ATR Thresholds**: [ ] Min/Max ATR values on M15/M5.
### 3.3 Session & Time Filter
- **Allowed Hours**: [ ] Broker Server Time ranges.
### 3.4 News Filter (Placeholder)
- [ ] Logic for pausing trade around major news events (No external API dependency without prior proposal).

---

## 4. Risk Management Specification
### 4.1 Position Sizing (Lot Calculation)
- **Account Risk Percentage**: [ ] % per trade.
- **Broker Symbol Property Inspection**: Dynamic check of `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`, `SYMBOL_VOLUME_STEP`, `SYMBOL_TRADE_TICK_SIZE`, `SYMBOL_TRADE_TICK_VALUE`.
### 4.2 Account Limits
- **Max Open Trades**: [ ]
- **Max Daily Drawdown / Loss**: [ ] % or monetary limit.
- **Max Consecutive Losses**: [ ]
- **Cooldown Duration**: [ ] minutes / bars after exit.

---

## 5. Exit Strategy (SL / TP / Management)
### 5.1 Stop Loss Algorithm
- **Structure-Based SL Invalidation**:
  - BUY SL = [ ] (Previous Swing Low - Buffer points)
  - SELL SL = [ ] (Previous Swing High + Buffer points)
### 5.2 Take Profit Algorithm
- **Risk to Reward Ratio (RR)**: Minimum RR = [ ] (e.g., 1:1.5).
### 5.3 Active Trade Management
- **Break-Even Trigger**: [ ]
- **Trailing Stop / Partial Close**: [ ]

---

## 6. Decision Pipeline (NO TRADE Execution Rules)
หากเงื่อนไขใดเงื่อนไขหนึ่งไม่ผ่าน 100% ระบบต้องตอบกลับด้วย **`NO_TRADE`** (0 Trades/Day = Valid Outcome):
1. Session Filter PASS?
2. Spread Filter PASS?
3. Volatility Filter PASS?
4. M15 Context != NEUTRAL PASS?
5. M5 Setup detected PASS?
6. M1 Confirmation PASS?
7. Risk & Min RR PASS?
8. Volume Sizing PASS?
$\rightarrow$ **EXECUTE ORDER** (ถ้าไม่ผ่านแม้แต่ข้อเดียว $\rightarrow$ **NO TRADE**)
