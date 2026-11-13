# GoldBerg Inverse V1 — Implementation Audit, Compile Report & Layer A / Layer B Backtest Results

- **Repository:** `outangyo/GoldBerg` (`C:\Project\GoldBerg_V0`)
- **Active Branch:** `experiment/inverse-v1` (branched from `d451f51938f62868880a8ceaf725f073247d085c`; no commits or pushes created)
- **Preserved Branches:**
  - `main` (`e4952d03daa1af0493a3e1cc31409ae3d4dd182d`) — Unmodified
  - `experiment/inverse-v2` (`d451f51938f62868880a8ceaf725f073247d085c`) — Unmodified
  - V1 Strategy Baseline (`7ed6327`) — Unmodified
- **New EA File:** `Experts/GoldBerg_InverseV1.mq5` (`MagicNumber = 100890`)
- **Compiled Binary:** `Experts/GoldBerg_InverseV1.ex5` (`81,280 bytes`, `0 errors, 0 warnings, 891 ms elapsed`)
- **Broker / Symbol / Model:** `XMGlobal-MT5 9`, `GOLD` (Standard Account, 100 oz contract size, Tester Leverage `1:500`), `Model=4` (Every Tick based on Real Ticks — `197,550,686 ticks`, `735 D1 bars`, `2023.12.01 00:00:00` through last tick `2026.10.07 23:58:59` via `ToDate=2026.10.08`)

---

## Part I — Inverse V1 Implementation Audit & Compile Report

### 1. Ten-Point Implementation Audit Checklist

| # | Audit Requirement | Verification Evidence | Status |
| :---: | :--- | :--- | :---: |
| **1** | **Original V1 signal generator unchanged** | `Include/XAUUSD_Scalper/Analysis/SetupAnalyzer.mqh` and `StructureTracker.mqh` have `0` git diffs against `7ed6327`. `g_setup_analyzer.EvaluateSetup(_Symbol, signal)` is called identically on line 120 of `GoldBerg_InverseV1.mq5`. | **PASS** |
| **2** | **Direction inversion (`BUY -> SELL`, `SELL -> BUY`)** | Lines 146–149 of `GoldBerg_InverseV1.mq5`: `SIGNAL_BUY -> SIGNAL_SELL`, `SIGNAL_SELL -> SIGNAL_BUY`. | **PASS** |
| **3** | **Both original SL and TP distances preserved (`RR = 1.5:1`)** | Lines 134–135 & 167–174: `original_sl_distance = MathAbs(original_entry - signal.stop_loss)` and `original_tp_distance = MathAbs(signal.take_profit - original_entry)`. `D_SL_inverse = original_sl_distance` and `D_TP_inverse = original_tp_distance` (no distance swap). `Reward/Risk` remains `1.5000`. | **PASS** |
| **4** | **Inverse entry uses executable Bid/Ask** | Lines 151–153 & 199: Inverse `BUY` uses `SymbolInfoDouble(_Symbol, SYMBOL_ASK)`; Inverse `SELL` uses `SymbolInfoDouble(_Symbol, SYMBOL_BID)`. | **PASS** |
| **5** | **SL/TP placed on correct sides of inverse entry** | Lines 167–172: For Inverse `SELL` (from Orig `BUY`): `SL = Bid + D_SL_original`, `TP = Bid - D_TP_original`. For Inverse `BUY` (from Orig `SELL`): `SL = Ask - D_SL_original`, `TP = Ask + D_TP_original`. | **PASS** |
| **6** | **RiskManager sizes using inverse SL (`OrderCalcProfit`)** | Line 211: `g_risk_manager.CalculateLotSize(g_symbol_info, signal.action, executable_entry, signal.stop_loss)` passes the transformed `signal.action`, `executable_entry`, and `signal.stop_loss` to `OrderCalcProfit()`. Volume is floored to `0.01` step (`MathFloor((raw_lot + 1e-9) / step) * step`) and rejected with `BELOW_MINIMUM_VOLUME` (`0.0` lot) whenever `raw_lot < 0.01`. | **PASS** |
| **7** | **Distinct Magic Number (`100890`)** | Line 25: `input ulong InpMagicNumber = 100890;` (Verified no collision with V1 `100888` or Inverse V2 `100889`). | **PASS** |
| **8** | **Dashboard & diagnostic observers are read-only** | `g_spread_filter.IsPassed()`, `g_funnel`, and `g_dashboard.Update()` do not gate or alter signals, risk sizing, or order execution. | **PASS** |
| **9** | **V1 baseline and Inverse V2 sources unchanged** | `git status` and `git diff` confirm `0` modifications to any tracked V1 or Inverse V2 file. | **PASS** |
| **10** | **MetaEditor64 compilation** | Compiled with `C:\Program Files\XM Global MT5\MetaEditor64.exe`: **`0 errors, 0 warnings, 891 ms elapsed`**, producing `Experts\GoldBerg_InverseV1.ex5` (`81,280 bytes`). | **PASS** |

### 2. Price Normalization & Quote Handling Notes

- **Zero Half-Cent Rounding on Inverse V1 Stop Loss (`Inverse SL`):**
  In `SetupAnalyzer.mqh`, `original_entry` (`Ask` or `Bid`) and `original_sl` (`M5 extreme_bar.low` or `high`) are both native 2-decimal tick prices on `GOLD` (`_Digits = 2`, `_Point = 0.01`). Consequently, `D_SL_original = |original_entry - original_sl|` is **always an exact 2-decimal number**, and `Inverse SL = inverse_entry ± D_SL_original` is **always an exact 2-decimal price**. Therefore, `CTradeExecutor::NormalizePrice()` never alters `Inverse SL`, resulting in **`0 / 1,883` (`0.00%`) post-normalization risk-budget breaches**.
- **Half-Cent Normalization on Inverse V1 Take Profit (`Inverse TP`):**
  When `D_SL_original` has an odd cent (e.g., `$1.85`), `D_TP_original = 1.5 × D_SL_original` has a `.005` half-cent (`$2.775`). `CTradeExecutor::NormalizePrice()` rounds `Inverse TP` to 2 decimal places (`±$0.005/oz`) upon order submission (`sent_tp`).
- **Sizing Quote vs Dispatch Quote vs Fill Price:**
  Transformation (`inverse_entry`), risk sizing (`executable_entry`), and `TradeExecutor` market dispatch occur synchronously within the same `OnTick()` invocation on the identical tick quote (`Ask` for `BUY`, `Bid` for `SELL`), yielding `$0.0000/oz` quote drift and `$0.0000/oz` entry slippage across all executed trades.

### 3. Deterministic Geometry & Risk Test Cases (`verify_inverse_v1_geometry.py`)

| Test Case | Original Signal (`Action`, `Entry`, `SL`, `TP`, `D_SL`, `D_TP`) | Live Quotes (`Bid / Ask`) | Inverse V1 Output (`Action`, `Entry`, `Raw SL -> Norm SL`, `Raw TP -> Norm TP`, `RR`) | Risk Sizing (`Equity`, `Risk%`, `RawLot -> NormLot / Status`) | Result |
| :--- | :--- | :---: | :--- | :--- | :---: |
| **1. Orig BUY → InvV1 SELL (Even Cent)** | `BUY`, Entry `4000.00`, SL `3990.00`, TP `4015.00` (`D_SL=10.00`, `D_TP=15.00`) | `3999.60 / 4000.00` | `SELL`, Entry `3999.60`, SL `4009.60 -> 4009.60`, TP `3984.60 -> 3984.60`, `RR=1.5000` | `$10,000`, `1.0%` (`$100`): `RawLot=0.100000 -> 0.10 lot` | **PASS** |
| **2. Orig SELL → InvV1 BUY (Even Cent)** | `SELL`, Entry `2041.50`, SL `2043.30`, TP `2038.80` (`D_SL=1.80`, `D_TP=2.70`) | `2041.50 / 2041.90` | `BUY`, Entry `2041.90`, SL `2040.10 -> 2040.10`, TP `2044.60 -> 2044.60`, `RR=1.5000` | `$10,000`, `1.0%` (`$100`): `RawLot=0.555556 -> 0.55 lot` | **PASS** |
| **3. Odd-Cent `D_SL` (`1.85` → `D_TP=2.775`)** | `BUY`, Entry `2050.00`, SL `2048.15`, TP `2052.775` (`D_SL=1.85`, `D_TP=2.775`) | `2049.60 / 2050.00` | `SELL`, Entry `2049.60`, SL `2051.45 -> 2051.45` (`0` diff), TP `2046.825 -> 2046.82`, `RR=1.5000` | `$10,000`, `1.0%` (`$100`): `RawLot=0.540541 -> 0.54 lot` | **PASS** |
| **4. Below-Minimum-Volume Rejection** | `SELL`, Entry `3500.00`, SL `3525.00`, TP `3462.50` (`D_SL=25.00`, `D_TP=37.50`) | `3500.00 / 3500.40` | `BUY`, Entry `3500.40`, SL `3475.40 -> 3475.40`, TP `3537.90 -> 3537.90`, `RR=1.5000` | `$1,800`, `1.0%` (`$18`): `RawLot=0.007200 < 0.01 -> 0.00 lot (REJECTED)` | **PASS** |

---

## Part II — Inverse V1 Layer A & Layer B Backtest Results

### 4. Signal Funnel Reconciliation (V1 vs Inverse V1 vs Inverse V2)

| Funnel Stage / Metric | Layer A: V1 (`MaxOpen=10000`) | Layer A: Inverse V1 (`MaxOpen=10000`) | Layer B: V1 (`MaxOpen=1`) | Layer B: Inverse V1 (`MaxOpen=1`) | Layer B: Inverse V2 (`MaxOpen=1`, Reference) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `M15_SWEEP` | `9,120` | `9,120` | `9,120` | `9,120` | `9,120` |
| `M15_RECLAIM` | `5,041` | `5,041` | `5,041` | `5,041` | `5,041` |
| `M5_EXTREME_IDENTIFIED` | `5,041` | `5,041` | `5,041` | `5,041` | `5,041` |
| **`M5_BREAK_CONFIRMED` (Signals)** | **`2,506`** | **`2,506`** | **`2,506`** | **`2,506`** | **`2,506`** |
| Rejected: `MAX_OPEN_TRADES` | `0` | `0` | `538` | `538` | `567` |
| Rejected: `BELOW_MINIMUM_VOLUME` | `0` | `0` | `51` | `78` | `106` |
| Rejected: Invalid Geometry / Other | `0` | `0` | `0` | `0` | `0` |
| **Total Risk Rejected** | **`0`** | **`0`** | **`589`** | **`616`** | **`673`** |
| **Order Send Attempts** | **`2,506`** | **`2,506`** | **`1,917`** | **`1,890`** | **`1,833`** |
| Execution Failed (`Retcode 10018: Market closed`) | `13` | `13` | `6` | `7` | `5` |
| **Orders Executed (Closed Trades)** | **`2,493`** | **`2,493`** | **`1,911`** | **`1,883`** | **`1,828`** |

---

### 5. Layer A — Matched-Signal Diagnostic with Concurrent Positions (`$100,000`, `0.25%` Equity Risk, `MaxOpenTrades = 10000`)

#### 5.1 Matched-Signal Performance (`N = 2,493` Executed Pairs)

| Cohort / Pairing Subset | Strategy | N | Wins | Losses | Win Rate | Avg Win (R) | Avg Loss (R) | Expectancy (R) | Cumulative Net R | PF (R) | PF ($) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **All Executed Signal Pairs** | **V1 Baseline** | `2,493` | `927` | `1,566` | `37.18%` | `+1.5367 V1-R` | `-1.0342 V1-R` | **`-0.0782 V1-R`** | **`-195.04 V1-R`** | `0.88` | `0.85` |
| **All Executed Signal Pairs** | **Inverse V1** | `2,493` | `904` | `1,589` | `36.26%` | `+1.5383 InvV1-R` | `-1.0296 InvV1-R` | **`-0.0984 InvV1-R`** | **`-245.36 InvV1-R`** | `0.85` | `0.85` |
| **Original BUY (`1,161` pairs)** | **V1 LONG** | `1,161` | `453` | `708` | `39.02%` | `+1.5487 V1-R` | `-1.0355 V1-R` | `-0.0272 V1-R` | `-31.57 V1-R` | `0.96` | `0.95` |
| **Original BUY (`1,161` pairs)** | **InvV1 SHORT** | `1,161` | `422` | `739` | `36.35%` | `+1.5399 InvV1-R` | `-1.0390 InvV1-R` | `-0.1016 InvV1-R` | `-117.97 InvV1-R` | `0.85` | `0.84` |
| **Original SELL (`1,332` pairs)** | **V1 SHORT** | `1,332` | `474` | `858` | `35.59%` | `+1.5252 V1-R` | `-1.0331 V1-R` | `-0.1227 V1-R` | `-163.47 V1-R` | `0.82` | `0.77` |
| **Original SELL (`1,332` pairs)** | **InvV1 LONG** | `1,332` | `482` | `850` | `36.19%` | `+1.5370 InvV1-R` | `-1.0214 InvV1-R` | `-0.0956 InvV1-R` | `-127.38 InvV1-R` | `0.85` | `0.87` |

#### 5.2 Layer A 2x2 Outcome Cross-Tabulation (`N = 2,493` Matched Signal Pairs)

| V1 Outcome \ Inverse V1 Outcome | Inverse V1 WIN (`+1.500 InvV1-R`) | Inverse V1 LOSS (`-1.000 InvV1-R`) | Row Total (V1) |
| :--- | :---: | :---: | :---: |
| **V1 WIN (`+1.500 V1-R`)** | **`0` (`0.00%`)** | **`927` (`37.18%`)** | `927` (`37.18%`) |
| **V1 LOSS (`-1.000 V1-R`)** | **`904` (`36.26%`)** | **`662` (`26.55%`)** | `1,566` (`62.82%`) |
| **Column Total (Inverse V1)** | `904` (`36.26%`) | `1,589` (`63.74%`) | **`2,493` (`100.00%`)** |

> [!IMPORTANT]
> **Structural Mechanism of the `26.55%` Both-Loss Rate (`662 / 2,493` Pairs):**
> Because Inverse V1 preserves the `1.5:1` reward/risk geometry (`D_SL_inverse = 1.0 × D_SL_original` and `D_TP_inverse = 1.5 × D_SL_original`), **both** V1 and Inverse V1 place a tight `1.0 × D_SL` stop loss inside a wider `1.5 × D_SL` target envelope in opposite directions. Whenever post-breakout price action expands or whipsaws by `±1.0 × D_SL` on both sides before trending `1.5 × D_SL` in either direction (plus the `2 × Spread` quote shift), **both V1 and Inverse V1 are stopped out at `-1.0R`** (`662` signals = **`26.55%`** of all executed signals), while **neither can ever win simultaneously (`0.00%`)**. Consequently, **both V1 (`37.18%` WR) and Inverse V1 (`36.26%` WR) lose simultaneously**.

#### 5.3 Layer A Concurrency, Margin & Standalone `$10,000 / 1.0%` Eligibility Diagnostic

- **Layer A Concurrency & Margin Statistics (Inverse V1, `$100,000` Deposit, `0.25%` Risk, `1:500` Leverage):**
  - Maximum Concurrent Open Positions: **`5`** (at `2024.05.07 02:35:03`)
  - Peak Gross Open Volume: **`6.28 lots`**
  - Peak Gross Margin Used: **`$2,622.20`** (at `2024.05.13 22:35:00`)
  - Minimum Margin Level: **`3,431.88%`** (at `2024.05.13 22:35:00`)
  - Margin Rejections / Stop-Outs: **`0` margin rejections, `0` stop-outs** (Final Balance: `$54,154.62`).
  - Exit Timing Comparison (`N = 2,493` pairs): V1 exited first in `1,221` pairs (`48.98%`), Inverse V1 exited first in `1,258` pairs (`50.46%`), and both exited on the exact same timestamp in `14` pairs (`0.56%`).
- **Theoretical Standalone `$10,000 / 1.0%` (`$100` Risk Budget) Minimum-Volume Eligibility Check (Analytical Calculation Across All `2,506` Signals):**
  - Because `D_SL_inverse = D_SL_original` in Inverse V1, the maximum SL distance across all `2,506` signals is `$70.10` (`Signal #1936`), which yields a theoretical standalone `$10,000 / 1.0%` raw lot of `100.0 / (70.10 × 100) = 0.0143 lots >= 0.01`.
  - Therefore, evaluated as a theoretical standalone trade at full `$10,000` initial capital, **`0 / 2,506` (`0.00%`)** signals are rejected by `BELOW_MINIMUM_VOLUME` in both V1 and Inverse V1. All `78` `BELOW_MINIMUM_VOLUME` rejections in Inverse V1 Layer B (and `51` in V1 Layer B) occur **solely due to cumulative portfolio equity drawdown** in late 2025 and 2026.

---

### 6. Layer B — Full Portfolio Backtest (`$10,000`, `1.0%` Equity Risk, `MaxOpenTrades = 1`)

#### 6.1 Three-Way Portfolio Comparison (V1 Baseline vs Inverse V1 vs Inverse V2)

| Metric | V1 Baseline (`GoldBerg_Scalper_EA`) | Inverse V1 (`GoldBerg_InverseV1`) | Inverse V2 (`GoldBerg_InverseV2`, Ref) | Delta (`InvV1 - V1`) |
| :--- | :---: | :---: | :---: | :---: |
| **Signals Generated (`M5_BREAK_CONFIRMED`)** | `2,506` | `2,506` | `2,506` | `0` |
| **Risk Rejected: `MAX_OPEN_TRADES`** | `538` | `538` | `567` | `0` |
| **Risk Rejected: `BELOW_MINIMUM_VOLUME`** | `51` | `78` | `106` | `+27` |
| **Order Send Attempts** | `1,917` | `1,890` | `1,833` | `-27` |
| **Execution Failed (`Retcode 10018`)** | `6` | `7` | `5` | `+1` |
| **Trades Executed (Closed Trades)** | **`1,911`** | **`1,883`** | **`1,828`** | **`-28`** |
| **Wins / Losses** | `731W / 1,180L` | `681W / 1,202L` | `985W / 843L` | `-50W / +22L` |
| **Win Rate** | **`38.25%`** | **`36.17%`** | `53.88%` | **`-2.08%`** |
| **Average Win (in Strategy R)** | `+1.5308 V1-R` | `+1.5305 InvV1-R` | `+0.6892 V2-R` | `-0.0003 R` |
| **Average Loss (in Strategy R)** | `-1.0323 V1-R` | `-1.0293 InvV1-R` | `-1.0223 V2-R` | `+0.0030 R` |
| **Expectancy (in Strategy R)** | **`-0.0518 V1-R`** | **`-0.1035 InvV1-R`** | `-0.1001 V2-R` | **`-0.0517 R`** |
| **Cumulative Net R** | **`-99.05 V1-R`** | **`-194.89 InvV1-R`** | `-182.94 V2-R` | **`-95.84 R`** |
| **Profit Factor (USD)** | **`0.83`** | **`0.83`** | `0.81` | **`0.00`** |
| **Profit Factor (R)** | `0.92` | `0.84` | `0.79` | `-0.08` |
| **Gross Profit / Gross Loss (USD)** | `+$33,641.95 / -$40,470.95` | `+$42,605.34 / -$51,178.07` | `+$33,616.95 / -$41,722.56` | `+$8,963.39 / -$10,707.12` |
| **Net P&L (USD)** | **`-$6,829.00` (`-68.29%`)** | **`-$8,572.73` (`-85.73%`)** | `-$8,105.61` (`-81.06%`) | **`-$1,743.73`** |
| **Final Balance (USD)** | **`$3,171.00`** | **`$1,427.27`** | `$1,894.39` | **`-$1,743.73`** |
| **Peak Closed-Trade Equity (USD)** | `$10,082.82` | `$11,027.21` | `$10,448.89` | `+$944.39` |
| **Maximum Closed-Trade Drawdown** | **`$8,208.83` (`81.41%`)** | **`$9,676.70` (`87.75%`)** | `$8,575.89` (`82.07%`) | **`+$1,467.87` (`+6.34%`)** |

#### 6.2 Directional Breakdown (Layer B Portfolio: V1 vs Inverse V1)

| Strategy & Direction | Counterpart Origin | Trades | Wins | Losses | Win Rate | Avg Win (R) | Avg Loss (R) | Expectancy (R) | Net R | PF (R) | PF ($) | Net P&L ($) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **V1 LONG** | Original `BUY` | `890` | `359` | `531` | `40.34%` | `+1.5376R` | `-1.0356R` | `+0.0024R` | `+2.10R` | `1.00` | `0.98` | `-$286.11` |
| **InvV1 SHORT** | Inverted from V1 `BUY` | `863` | `308` | `555` | `35.69%` | `+1.5331R` | `-1.0374R` | `-0.1200R` | `-103.55R` | `0.82` | `0.75` | `-$5,885.00` |
| **V1 SHORT** | Original `SELL` | `1,021` | `372` | `649` | `36.43%` | `+1.5242R` | `-1.0295R` | `-0.0991R` | `-101.15R` | `0.85` | `0.72` | `-$6,542.89` |
| **InvV1 LONG** | Inverted from V1 `SELL` | `1,020` | `373` | `647` | `36.57%` | `+1.5284R` | `-1.0223R` | `-0.0895R` | `-91.34R` | `0.86` | `0.90` | `-$2,687.73` |

#### 6.3 Year-by-Year Breakdown (V1 vs Inverse V1 across Layer A & Layer B)

| Year | Layer A: V1 Exp (`Net R`) | Layer A: InvV1 Exp (`Net R`) | Layer B: V1 Trades / Exp / Net P&L | Layer B: InvV1 Trades / Exp / Net P&L |
| :---: | :---: | :---: | :---: | :---: |
| **2023 (Dec)** | `-0.3207R` (`-25.65R`, `N=80`) | **`+0.0271R` (`+2.17R`, `N=80`)** | `N=59` / `-0.2018R` / `-$1,143.86` | **`N=63` / `+0.1064R` / `+$618.57`** |
| **2024** | `-0.1645R` (`-152.86R`, `N=929`) | `-0.0877R` (`-81.47R`, `N=929`) | `N=685` / `-0.1526R` / `-$5,746.87` | `N=665` / `-0.1272R` / `-$6,275.50` |
| **2025** | `-0.0814R` (`-69.75R`, `N=857`) | `-0.0893R` (`-76.54R`, `N=857`) | `N=676` / `-0.0628R` / `-$1,108.81` | `N=682` / `-0.0730R` / `-$1,698.21` |
| **2026 (Jan–Oct)** | **`+0.0849R` (`+53.22R`, `N=627`)** | `-0.1428R` (`-89.52R`, `N=627`) | **`N=491` / `+0.1219R` / `+$1,170.54`** | `N=473` / `-0.1421R` / `-$1,217.59` |

#### 6.4 Layer B Selection-Effects & Signal Fate Cross-Tabulation (`2,506` Signals)

| V1 Layer B Status | Inverse V1 Layer B Status | Signal Count (`% of 2,506`) | V1 Outcome on Subset | Inverse V1 Outcome on Subset |
| :--- | :--- | :---: | :---: | :---: |
| **`EXECUTED`** | **`EXECUTED`** | **`1,657` (`66.12%`)** | `WR 37.90%`, `Exp -0.0612R`, `NetR -101.38R`, `NetPnL -$6,630.68` | `WR 35.91%`, `Exp -0.1108R`, `NetR -183.56R`, `NetPnL -$7,521.64` |
| **`EXECUTED`** | `REJ_MAX_OPEN_TRADES` | **`218` (`8.70%`)** | *(Part of `N=254` V1-only exec: `WR 40.55%`, `Exp +0.0092R`, `NetR +2.33R`)* | Rejected (`MaxOpenTrades=1`) |
| **`EXECUTED`** | `REJ_BELOW_MINIMUM_VOLUME` | **`36` (`1.44%`)** | *(Included in `N=254` V1-only exec above)* | Rejected (`Equity drawdown min-lot`) |
| `REJ_MAX_OPEN_TRADES` | **`EXECUTED`** | **`217` (`8.66%`)** | Rejected (`MaxOpenTrades=1`) | *(Part of `N=226` InvV1-only exec: `WR 38.05%`, `Exp -0.0501R`, `NetR -11.33R`)* |
| `REJ_BELOW_MINIMUM_VOLUME` | **`EXECUTED`** | **`9` (`0.36%`)** | Rejected (`Equity drawdown min-lot`) | *(Included in `N=226` InvV1-only exec above)* |
| `REJ_MAX_OPEN_TRADES` | `REJ_MAX_OPEN_TRADES` | **`318` (`12.69%`)** | Rejected in both | Rejected in both |
| `REJ_BELOW_MINIMUM_VOLUME` | `REJ_BELOW_MINIMUM_VOLUME` | **`40` (`1.60%`)** | Rejected in both | Rejected in both |
| Other (`EXEC_FAILED` / mixed rejections) | Other (`EXEC_FAILED` / mixed rejections) | **`11` (`0.44%`)** | Non-executed in at least one | Non-executed in at least one |

#### 6.5 Risk-Budget Compliance & Execution-Cost Observations (Inverse V1 Layer B)

1. **Risk-Budget Compliance (`sent_sl` Submitted to Broker/Tester):**
   - Because `D_SL_inverse = D_SL_original` is always an exact 2-decimal distance on `GOLD`, `sent_sl` equals the unrounded `signal.stop_loss` on every trade.
   - Post-normalization risk-budget breaches (`> 1.0000%` of Equity at entry): **`0 / 1,883` (`0.00%`)**.
2. **Execution-Cost Observations (`N = 1,883` Executed Trades):**
   - **Directly Observed Bid/Ask Spread at Entry:** Mean = **`$0.4285/oz`** across the `1,883` executed trades (`$0.4293/oz` across all `2,506` signals).
   - **Entry Slippage:** **`$0.0000/oz`** across all `1,883` executed trades.
   - **Stop-Loss Adverse Exit Slippage (`N = 1,202` SL exits):** Mean adverse slippage = **`+$0.1766/oz`** (explaining why Average Loss is `-1.0293 InvV1-R` vs `-1.0000 InvV1-R`).
   - **Take-Profit Favorable Exit Slippage (`N = 681` TP exits):** Mean price improvement = **`-$0.1960/oz`** (`+$0.1960/oz` favorable fill, explaining why Average Win is `+1.5305 InvV1-R` vs `+1.5000 InvV1-R`).
   - **Net Exit Slippage (`N = 1,883` trades):** Mean = **`+$0.0418/oz`**, Total = **`+$502.67` (`+14.47 InvV1-R`)**.

---

## 7. Artifacts, Configurations & Log Paths

All files are archived in `C:\Users\ACER\.gemini\antigravity\brain\58ab35aa-a701-45db-a18f-d8f6f11fcccc\scratch\`:
- **Inverse V1 EA Source:** `C:\Project\GoldBerg_V0\Experts\GoldBerg_InverseV1.mq5`
- **Compile Log:** `scratch\compile_inverse_v1.log` (`0 errors, 0 warnings`)
- **Geometry Verification Script:** `scratch\verify_inverse_v1_geometry.py`
- **Layer A Config & Raw Log:** `scratch\tester_inverse_v1_layerA.ini` → `scratch\inverse_v1_layerA_matched.log`
- **Layer B Config & Raw Log:** `scratch\tester_inverse_v1_layerB.ini` → `scratch\inverse_v1_layerB_portfolio.log`
- **Analysis & Audit Scripts:** `scratch\analyze_inverse_v1.py`, `scratch\audit_v2_addendum.py`
