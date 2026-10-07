# XAUUSD Scalper — Project Brief

## 1. Project Overview
Automated Trading Expert Advisor (EA) สำหรับ MT5 / MQL5 บน XAUUSD (Gold) บัญชี XM
เน้น Strategy-first Scalper, Price Action + Market Structure บน Multi-Timeframe (M15 Context -> M5 Setup -> M1 Entry), Strict Risk Management, Spread & Session Filters, และไม่มี Martingale

---

## 2. Team & Roles Authority
- **User (Product Owner)**: Direction, Strategy Decisions, Testing, Backtest/Forward Test Validation.
- **GPT (PM / Strategy Lead / Tech Lead)**: Strategy Design, Technical Specification, Logic Decomposition, Architectural Review.
- **Antigravity (AGY - Primary Developer)**: MQL5 Implementation, EA Modular Architecture, Code Refactoring, Compilation, Debugging.
  - **Strategy Authority Rule**: AGY ห้ามเปลี่ยน Core Strategy หรือ Trading Logic สำคัญเองโดยเด็ดขาด หากมีข้อเสนอแนะเพิ่มเติมต้องเสนอเป็น Proposal เพื่อขอ approval ก่อนเสมอ

---

## 3. Single Source of Truth
> **Approved Strategy Spec V1 = Single Source of Truth**  
> ทุกการพัฒนา MQL5 Code ของ AGY จะต้องอ้างอิงและอธิบายได้ตามเงื่อนไขที่ถูกระบุและได้รับ approval ใน `XAUUSD_SCALPER_STRATEGY_SPEC_V1` เท่านั้น

---

## 4. Multi-Timeframe Framework (V1 Locked Baseline)
> **Note**: ใน V1 Baseline Pipeline ถูกล็อกไว้ที่ **M15 Sweep $\rightarrow$ M5 Causal Confirmation $\rightarrow$ Risk $\rightarrow$ Execution** (M1 Confirmation ถูกถอดออกจาก V1 Execution Path และ Parked ไว้สำหรับการวิจัยในอนาคต)

- **M15 (Sweep & Structure Lifecycle)**: ค้นหา Confirmed Swings, ตรวจจับ Tick Breach, แทร็ก Extreme Price/Time และยืนยัน Reclaim บนแท่ง M15 ที่ปิดตัว
- **M5 (Causal Confirmation)**: ตรวจสอบแท่ง M5 ปิดทะลุ M5 Extreme Bar High/Low หลัง M15 Reclaim ยืนยันสำเร็จ
- **M1 (Parked / Future Candidate)**: ไม่อยู่ใน V1 Execution Pipeline

---

## 5. Decision Engine & NO TRADE Rule
- **NO TRADE Principle**: การไม่มีออเดอร์เปิดเลยในบางวัน (**0 trades/day**) ถือเป็น **Valid Outcome** ที่ถูกต้องหากสภาวะตลาดไม่ผ่านเงื่อนไข
- **Strict Rule**: **ห้าม Force Trade** หรือหย่อนยานเงื่อนไขเพื่อพยายามให้ออเดอร์เปิดเด็ดขาด

---

## 6. Non-Requirements (ข้อห้ามเด็ดขาด)
1. **No Martingale**: ห้ามเบิ้ล Lot เมื่อแพ้ทุกกรณีใน V1
2. **No Forced Trade**: ห้ามบังคับเปิดออเดอร์เมื่อสภาวะตลาดไม่ตรง Setup
3. **No Indicator-Only Entry**: ห้ามตัดสินใจเปิดออเดอร์จาก Indicator Crossover หรือ Indicator Single Parameter เพียงอย่างเดียว
4. **No Daily Profit Target**: ห้ามตั้งเป้าหมายกำไรรายวันแล้วบังคับเทรดให้ได้ตามเป้า
5. **No Unauthorized Optimization**: ห้ามแอบบิดโค้ดหรือแต่งค่า Parameter เพียงเพื่อให้ผล Backtest อดีตดูดี (Overfitting) โดยไม่ได้รับ approval

---

## 7. Key Technical Principles
1. **Strategy-First**: Market Context -> Setup -> Confirmation -> Risk Validation -> Entry
2. **Explicit Logic**: ทุกเงื่อนไขต้องถูกแปลงเป็นกฎเชิงปริมาณที่ชัดเจน (Measurable / Programmable)
3. **Symbol Spec Aware**: อ่าน Contract size, Tick size/value, Min Volume จาก broker ไม่ hardcode
4. **Structure-Based SL/TP**: SL ตามโครงสร้างราคา ไม่ใช้ fixed pips
