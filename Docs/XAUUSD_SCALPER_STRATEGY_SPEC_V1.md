# XAUUSD Scalper — Strategy Specification V1 (`XAUUSD_SCALPER_STRATEGY_SPEC_V1`)

> **Status**: **V1 LOCKED BASELINE SPECIFICATION (AUDIT PASSED)**  
> **Single Source of Truth**: เอกสารฉบับนี้สะท้อนโครงสร้างและลอจิกจริงที่ถูกล็อก (LOCKED) ในโค้ดปัจจุบันสำหรับ Baseline Backtest  
> **Strategy Behavior**: ห้ามเปลี่ยนแปลงแก้ไข Core Strategy Logic หรือพารามิเตอร์โดยไม่ได้รับ Approval

---

## 1. V1 Execution Pipeline (Source of Truth)

ลำดับการตัดสินใจของ V1 Baseline ถูกล็อกไว้ดังนี้:

```text
M15 Confirmed Swing (5-Bar Fractal, Strength 2)
       ↓
M15 Level Breach (Tick Condition: Bid <= SwingLow / Ask >= SwingHigh)
       ↓
M15 Sweep / Real-time Extreme Tracking (Post-breach Tick Extreme & Timestamp)
       ↓
M15 Close Reclaim (Closed M15 Bar: Close >= Ref for Long / Close <= Ref for Short)
       ↓
M5 Causal Confirmation (Closed M5 Bar Breaks M5 Extreme Bar High/Low)
       ↓
Risk Engine (Account Equity × Risk% via OrderCalcProfit)
       ↓
Market Order Execution (Ask for BUY / Bid for SELL)
```

### ขอบเขตที่ถูกปลดออกใน V1 Baseline (Explicit Exclusions):
- **NO M1 Execution Gate**: M1 Confirmation ถูกถอดออกจาก V1 Execution Path อย่างสมบูรณ์ (Parked/Deprecated from V1)
- **NO Hard Spread Filter**: สเปรดใช้สำหรับ Observation / Logging เท่านั้น ไม่ใช้เป็น Hard NO_TRADE Gate ใน Baseline
- **NO Hard Session Filter**: ช่วงเวลาเทรดถูกปิดใช้งาน (Disabled) ใน V1 Baseline
- **NO News Filter**: ไม่มีการเชื่อมต่อข่าวสารภายนอก
- **NO Retest Requirement**: เข้าทันทีเมื่อแท่ง M5 ปิดทะลุ Extreme Bar
- **NO Arbitrary SL Buffer**: SL ผูกกับ `Extreme_Price` ตรงๆ เสมอ (Buffer = 0)

---

## 2. Market Structure & Sweep Lifecycle (M15)

### 2.1 M15 Confirmed Swing Identification
- **Algorithm**: Standard N-bar fractal (`left=2, right=2` หรือ `strength=2`) บนแท่งเทียนที่ปิดแล้ว (`shift >= 3`)
- **No Lookahead**: ยืนยันเฉพาะแท่งที่ปิดแล้วเท่านั้น
- **Swing Invalidation Memory**: เมื่อ Swing ใดถูก Breach หรือ Invalidate แล้ว จะบันทึก Timestamp ไว้ใน Memory (`m_last_invalidated_time`) และระบบจะไม่หยิบ Swing เดิมกลับมา Active อีกเด็ดขาด จนกว่าจะเกิด Confirmed Swing ใหม่ที่เกิดขึ้นหลังเวลาดังกล่าว

### 2.2 M15 Sweep Lifecycle State Machine
1. **`SWEEP_STATE_MONITORING`**:
   - เฝ้าติดตามระดับราคาของ Active Swing Low และ Active Swing High
   - **Breach Operator**:
     - Long: `Bid <= SwingLow`
     - Short: `Ask >= SwingHigh`
   - เมื่อเกิด Breach: Deactivate active swing ทันที, บันทึก `ref_price`, บันทึกเวลาแท่ง M15 ที่เกิด Breach และเปลี่ยนสถานะเป็น `LEVEL_BREACHED`
2. **`SWEEP_STATE_LEVEL_BREACHED`**:
   - ติดตาม Extreme Tick แบบต่อเนื่อง:
     - Long: อัปเดต `m_breach_extreme_price = Bid` และ `m_breach_extreme_time = TimeCurrent()` ทุกครั้งที่ทำ New Lower Extreme
     - Short: อัปเดต `m_breach_extreme_price = Ask` และ `m_breach_extreme_time = TimeCurrent()` ทุกครั้งที่ทำ New Higher Extreme
   - **Same-Direction Swing Expiration**: หากมี Confirmed Same-direction M15 Swing ใหม่เกิดขึ้นระหว่างนี้ จะ Expire Setup เดิมทิ้งทันที และสลับไปติดตาม Swing ตัวใหม่
   - รอจนกระทั่งแท่ง M15 ที่เกิด Breach ปิดตัวลงอย่างสมบูรณ์ (`shift = 1`):
     - **Long**:
       - `Close < ref_price` $\rightarrow$ `STRUCTURE_BREAK` (NO TRADE / Reset)
       - `Close >= ref_price` $\rightarrow$ `RECLAIM_CANDIDATE`
     - **Short**:
       - `Close > ref_price` $\rightarrow$ `STRUCTURE_BREAK` (NO TRADE / Reset)
       - `Close <= ref_price` $\rightarrow$ `RECLAIM_CANDIDATE`
3. **`SWEEP_STATE_RECLAIM_CANDIDATE`**:
   - Freeze `Extreme_Price = m_breach_extreme_price` (ราคา Extreme ที่เกิดจาก Tick หลัง Breach เท่านั้น)
   - Freeze `Extreme_Time = m_breach_extreme_time` (เวลาจริงของ Extreme)
   - บันทึกเวลาที่ M15 Reclaim ยืนยันสำเร็จ (`m_reclaim_confirmed_time`)
   - **M5 Extreme Bar Identification**: ระบุแท่ง M5 โดยตรงผ่าน `iBarShift(symbol, PERIOD_M5, m_extreme_time, false)` เพื่อดึงค่า High และ Low ของแท่งนั้น
   - **Real-time Invalidation Guard**: หากราคาตลาดทำลาย `Extreme_Price` (`Bid < Extreme_Price` สำหรับ Long หรือ `Ask > Extreme_Price` สำหรับ Short) จะ Invalidate และ Expire Setup ทันที

---

## 3. M5 Confirmation Engine

### 3.1 Causal Confirmation Timing
- แท่ง M5 ที่มีสิทธิ์คอนเฟิร์มต้องเป็น **Closed M5 Bar (`shift = 1`)** เท่านั้น
- เวลาเปิดของแท่ง M5 ต้องเปิด **ณ หรือหลัง** จากเวลาที่ M15 Reclaim ยืนยันสำเร็จ (`iTime(..., 1) >= m_reclaim_confirmed_time`)
- ป้องกันการประเมินแท่งซ้ำด้วย `m_last_evaluated_m5_bar`

### 3.2 Confirmation Break Rules
- **Long**: M5 `Close[1] > M5_Extreme_Bar_High` $\rightarrow$ **CONFIRMED BUY**
- **Short**: M5 `Close[1] < M5_Extreme_Bar_Low` $\rightarrow$ **CONFIRMED SELL**

---

## 4. Risk Engine & Trade Sizing

### 4.1 Order Pricing & Stop Loss
- **Executable Entry Price**:
  - BUY: `Ask`
  - SELL: `Bid`
- **Structural Stop Loss**:
  - `signal.stop_loss = Extreme_Price` โดยตรง 100% (ไม่มี Arbitrary SL Buffer)
- **Take Profit (Fixed RR = 1.5)**:
  - BUY: $\text{TP} = \text{Ask} + (\text{Ask} - \text{Extreme\_Price}) \times 1.5$
  - SELL: $\text{TP} = \text{Bid} - (\text{Extreme\_Price} - \text{Bid}) \times 1.5$

### 4.2 Dynamic Lot Calculation
- **Risk Budget**: $\text{Allowed Risk Money} = \text{Account Equity} \times (\text{InpRiskPercent} / 100.0)$
- **Loss per 1.0 Lot**: คำนวณผ่าน API มาตรฐานโบรกเกอร์ `OrderCalcProfit(order_type, symbol, 1.0, entry_price, stop_loss_price, profit_at_sl)`
  - ตรวจสอบทิศทาง: BUY ต้องมี `SL < Entry`, SELL ต้องมี `SL > Entry`
- **Volume Normalization (`NormalizeVolume`)**:
  - ปัดเศษแบบ Step-down floor ตาม `SYMBOL_VOLUME_STEP` ของโบรกเกอร์
  - หาก `raw_lot < SYMBOL_VOLUME_MIN` $\rightarrow$ Return `0.0` (NO TRADE)
  - หาก `raw_lot > SYMBOL_VOLUME_MAX` $\rightarrow$ Return `0.0` (NO TRADE - ไม่ Cap ลงมาเพื่อป้องกัน Risk Breach)

### 4.3 Unimplemented Risk Controls (Explicitly Documented)
- `Max Daily Loss %` และ `Max Consecutive Losses` เป็นพารามิเตอร์ที่ประกาศไว้แต่ **ยังไม่ได้ implement ใน V1 Baseline** เพื่อรอการอนุมัติสเปกในอนาคต

---

## 5. Execution Infrastructure (TradeExecutor)
- **Order Type**: Market Order ผ่าน `CTrade`
- **Filling Mode**: Dynamic Broker Compatible via `SetTypeFillingBySymbol(symbol)`
- **Deviation**: `SetDeviationInPoints(30)` (Temporary Execution Placeholder)
- **Diagnostic Logging**: บันทึก Action, Symbol, Requested Volume, Executed Price, SL, TP, Retcode, Retcode Description, Deal Ticket และ Order Ticket
