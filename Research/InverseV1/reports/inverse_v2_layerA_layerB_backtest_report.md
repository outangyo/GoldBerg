# GoldBerg Inverse V2 — Layer A & Layer B Backtest Report

- **Repository:** `outangyo/GoldBerg` (`C:\Project\GoldBerg_V0`)
- **Active Branch:** `experiment/inverse-v2`
- **Evaluated Commit Hash (`HEAD`):** `d451f51938f62868880a8ceaf725f073247d085c`
- **V1 Strategy Baseline Commit:** `7ed6327` (Preserved & Unmodified)
- **Documentation Baseline Commit (`main`):** `e4952d03daa1af0493a3e1cc31409ae3d4dd182d` (Preserved & Unmodified)
- **Broker / Symbol / Model:** `XMGlobal-MT5 9` (`GOLD`, Standard Account, 100 oz contract size, Leverage `1:500`, `Model=4` Every Tick based on Real Ticks, `197,550,686` ticks, `2023.12.01` – `2026.10.07`)

---

## 1. Executive Summary

1. **Signal Stream Preservation (100% Identity Across All 4 Runs):**
   Both `GoldBerg_Scalper_EA.ex5` (V1) and `GoldBerg_InverseV2.ex5` (V2) generated the exact same **2,506** `M5_BREAK_CONFIRMED` signals (`M15_SWEEP: 9,120` → `M15_RECLAIM: 5,041` → `M5_EXTREME_IDENTIFIED: 5,041` → `M5_BREAK_CONFIRMED: 2,506`) with identical timestamps and original entry/SL/TP geometries.
2. **Layer A (Unsuppressed Matched-Signal Diagnostic, `N = 2,493` Executed Pairs):**
   - **V1 Baseline:** Win Rate **`37.18%`** (`927W / 1,566L`), Avg Win **`+1.5367 V1-R`**, Avg Loss **`-1.0342 V1-R`**, Expectancy **`-0.0782 V1-R`**, Cumulative Net R **`-195.04 V1-R`**, Profit Factor (R) **`0.88`**.
   - **Inverse V2:** Win Rate **`54.35%`** (`1,355W / 1,138L`), Avg Win **`+0.6908 V2-R`**, Avg Loss **`-1.0252 V2-R`**, Expectancy **`-0.0925 V2-R`**, Cumulative Net R **`-230.72 V2-R`**, Profit Factor (R) **`0.80`**.
   - **Why Complementation Fails (`8.46%` Both-Loss Penalty):** Across the `2,493` matched pairs, `1,355` (`54.35%`) were `V1 Loss / V2 Win`, `927` (`37.18%`) were `V1 Win / V2 Loss`, `0` (`0.00%`) were `V1 Win / V2 Win`, and **`211` (`8.46%`) were `V1 Loss / V2 Loss`**. Because V2 enters on the opposite executable quote (`Bid` vs `Ask`, mean observed spread `$0.4293/oz`) and exits on the opposite quote stream, plus intrabar two-sided whipsaws (`127` pairs hit V1 SL first then reversed to V2 SL; `84` pairs hit V2 SL first then reversed to V1 SL), V2 loses **`8.46%`** of signals outright alongside V1 while never achieving `V1 Win / V2 Win`.
3. **Layer B (Full Portfolio Backtest, `$10,000`, `1.0%` Equity Risk, `MaxOpenTrades = 1`):**
   - **V1 Baseline (`N = 1,911`):** Win Rate **`38.25%`**, Avg Win **`+1.5308 V1-R`**, Avg Loss **`-1.0323 V1-R`**, Expectancy **`-0.0518 V1-R`**, Net R **`-99.05 V1-R`**, Profit Factor **`0.83`**, Net P&L **`-$6,829.00`** (Final Balance **`$3,171.00`**), Max Closed-Trade Drawdown **`$8,208.83` (`81.41%`)**.
   - **Inverse V2 (`N = 1,828`):** Win Rate **`53.88%`**, Avg Win **`+0.6892 V2-R`**, Avg Loss **`-1.0223 V2-R`**, Expectancy **`-0.1001 V2-R`**, Net R **`-182.94 V2-R`**, Profit Factor **`0.81`**, Net P&L **`-$8,105.61`** (Final Balance **`$1,894.39`**), Max Closed-Trade Drawdown **`$8,575.89` (`82.07%`)**.
4. **Conclusion on Hypothesis:**
   Inverting V1's direction and swapping SL/TP distances (`Reward:Risk = 0.6667:1`, requiring a theoretical zero-cost breakeven win rate of `60.00%`) lifts realized win rate from `38.25%` to `53.88%`, which remains **6.12 percentage points below breakeven**. Consequently, **Inverse V2 underperforms V1 Baseline in both Layer A (`-0.0925 V2-R` vs `-0.0782 V1-R`) and Layer B (`-$8,105.61` vs `-$6,829.00`)**.

---

## 2. Signal Funnel & Risk Rejection Reconciliation (All 4 Runs)

| Funnel Stage / Metric | Layer A: V1 Matched (`MaxOpen=10000`) | Layer A: V2 Matched (`MaxOpen=10000`) | Layer B: V1 Portfolio (`MaxOpen=1`) | Layer B: V2 Portfolio (`MaxOpen=1`) |
| :--- | :---: | :---: | :---: | :---: |
| `M15_SWEEP` | `9,120` | `9,120` | `9,120` | `9,120` |
| `M15_RECLAIM` | `5,041` | `5,041` | `5,041` | `5,041` |
| `M5_EXTREME_IDENTIFIED` | `5,041` | `5,041` | `5,041` | `5,041` |
| **`M5_BREAK_CONFIRMED` (Signals)** | **`2,506`** | **`2,506`** | **`2,506`** | **`2,506`** |
| Rejected: `MAX_OPEN_TRADES` | `0` | `0` | `538` | `567` |
| Rejected: `BELOW_MINIMUM_VOLUME` | `0` | `0` | `51` | `106` |
| Rejected: Invalid Geometry / Other | `0` | `0` | `0` | `0` |
| **Total Risk Rejected** | **`0`** | **`0`** | **`589`** | **`673`** |
| **Order Send Attempts** | **`2,506`** | **`2,506`** | **`1,917`** | **`1,833`** |
| Execution Failed (`Retcode 10018: Market closed`) | `13` | `13` | `6` | `5` |
| **Orders Executed (Closed Trades)** | **`2,493`** | **`2,493`** | **`1,911`** | **`1,828`** |

---

## 3. Layer A — Matched-Signal Diagnostic (`2,506` Signals Paired 1-to-1)

### 3.1 Side-by-Side Matched-Signal Performance (`N = 2,493` Executable Pairs & `$10k` Standalone Filtered Subset)

To evaluate all `2,506` signals independently without `MaxOpenTrades` suppression (`InpMaxOpenTrades = 10000`) or equity-depletion lot truncation (`Deposit = $100,000`, `InpRiskPercent = 0.25%` = `$250` initial risk per signal), every signal was paired 1-to-1 by exact timestamp (`Signal ID #1` to `#2506`).
- Exactly **13 signals** failed `OrderSend` in **both** V1 and V2 at the exact same timestamps due to broker rollover (`Retcode 10018: Market closed` between `00:05` and `00:50` server time).
- Evaluated at a standalone `$10,000` reference equity (`1.0%` risk budget = `$100.00`), **0 / 2,506** V1 signals fall below the `0.01` minimum lot (`max V1 SL distance = $70.10` → `0.0143` raw lot), whereas **2 / 2,506** V2 signals have `D_SL_inverse > $100.00` (`raw_lot < 0.01`):
  1. **Signal `#1936` (`2026.01.30 17:20:00`, Orig `BUY`):** `D_SL_original = $70.10` (`V1 RawLot@10k = 0.0143`, executed in Layer A with `-1.0004 V1-R`) → `D_SL_inverse = $105.15` (`V2 RawLot@10k = 0.0095 < 0.01`, executed in Layer A with `+0.6695 V2-R`).
  2. **Signal `#2054` (`2026.03.23 00:20:00`, Orig `BUY`):** `D_SL_original = $67.74` (`V1 RawLot@10k = 0.0148`) → `D_SL_inverse = $101.61` (`V2 RawLot@10k = 0.0098 < 0.01`). *(Also occurred during `00:20:00` market-closed window, failing with `Retcode 10018`).*

| Cohort / Pairing Subset | Strategy | N | Wins | Losses | Win Rate | Avg Win (R) | Avg Loss (R) | Expectancy (R) | Cumulative Net R | PF (R) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **All Executable Signal Pairs** | **V1 Baseline** | `2,493` | `927` | `1,566` | `37.18%` | `+1.5367 V1-R` | `-1.0342 V1-R` | `-0.0782 V1-R` | `-195.04 V1-R` | `0.88` |
| **All Executable Signal Pairs** | **Inverse V2** | `2,493` | `1,355` | `1,138` | `54.35%` | `+0.6908 V2-R` | `-1.0252 V2-R` | `-0.0925 V2-R` | `-230.72 V2-R` | `0.80` |
| **Pass Standalone `$10k` MinLot (`2,492` pairs)** | **V1 Baseline** | `2,492` | `927` | `1,565` | `37.20%` | `+1.5367 V1-R` | `-1.0342 V1-R` | `-0.0779 V1-R` | `-194.04 V1-R` | `0.88` |
| **Pass Standalone `$10k` MinLot (`2,492` pairs)** | **Inverse V2** | `2,492` | `1,354` | `1,138` | `54.33%` | `+0.6908 V2-R` | `-1.0252 V2-R` | `-0.0929 V2-R` | `-231.39 V2-R` | `0.80` |
| **Original BUY Signals (`1,161` pairs)** | **V1 LONG** | `1,161` | `453` | `708` | `39.02%` | `+1.5487 V1-R` | `-1.0355 V1-R` | `-0.0272 V1-R` | `-31.57 V1-R` | `0.96` |
| **Original BUY Signals (`1,161` pairs)** | **V2 SHORT** | `1,161` | `612` | `549` | `52.71%` | `+0.6915 V2-R` | `-1.0354 V2-R` | `-0.1251 V2-R` | `-145.24 V2-R` | `0.74` |
| **Original SELL Signals (`1,332` pairs)** | **V1 SHORT** | `1,332` | `474` | `858` | `35.59%` | `+1.5252 V1-R` | `-1.0331 V1-R` | `-0.1227 V1-R` | `-163.47 V1-R` | `0.82` |
| **Original SELL Signals (`1,332` pairs)** | **V2 LONG** | `1,332` | `743` | `589` | `55.78%` | `+0.6902 V2-R` | `-1.0158 V2-R` | `-0.0642 V2-R` | `-85.48 V2-R` | `0.86` |

### 3.2 Layer A 2x2 Outcome Cross-Tabulation & Bid/Ask Spread / Tick-Path Asymmetry

| V1 Outcome \ V2 Outcome | V2 WIN (`+0.667 V2-R`) | V2 LOSS (`-1.000 V2-R`) | Row Total (V1) |
| :--- | :---: | :---: | :---: |
| **V1 WIN (`+1.500 V1-R`)** | **`0` (`0.00%`)** | **`927` (`37.18%`)** | `927` (`37.18%`) |
| **V1 LOSS (`-1.000 V1-R`)** | **`1,355` (`54.35%`)** | **`211` (`8.46%`)** | `1,566` (`62.82%`) |
| **Column Total (V2)** | `1,355` (`54.35%`) | `1,138` (`45.65%`) | **`2,493` (`100.00%`)** |

**Why Exact Outcome Complementation Fails (`211` Both-Loss Pairs vs `0` Both-Win Pairs):**
1. **Opposite Entry Quote & Exit Trigger Quote Shift (`2 × Spread` Structural Friction):**
   - For an Original `BUY` signal at `Ask_0` with `SL_1 = Ask_0 - D_SL` and `TP_1 = Ask_0 + D_TP`:
     - **V1 BUY** enters at `Ask_0` and exits on the **Bid** stream (`Bid <= Ask_0 - D_SL` triggers SL; `Bid >= Ask_0 + D_TP` triggers TP). Thus V1 needs Bid to rise by `D_TP + Spread_0` to win, or fall by `D_SL - Spread_0` to lose.
     - **V2 SELL** enters at `Bid_0 = Ask_0 - Spread_0` and exits on the **Ask** stream (`Ask >= Bid_0 + D_TP` triggers SL; `Ask <= Bid_0 - D_SL` triggers TP). Thus V2's TP trigger is `Ask <= Ask_0 - Spread_0 - D_SL = SL_1 - Spread_0` (strictly beyond V1's SL by `Spread_0` plus exit spread!), while V2's SL trigger is `Ask >= Ask_0 - Spread_0 + D_TP = TP_1 - Spread_0`.
   - Because V1 BUY's SL triggers when `Bid <= SL_1`, whereas V2 SELL's TP only triggers when `Ask <= SL_1 - Spread_0` (i.e. `Bid <= SL_1 - Spread_0 - Spread_exit`), there is a **`Spread_0 + Spread_exit` (`~$0.86/oz`) dead-zone** where price triggers V1's Stop Loss (`Bid <= SL_1`) **without** triggering V2's Take Profit (`Ask > SL_1 - Spread_0`), and then reverses to hit V2's Stop Loss!
2. **Intrabar / Multi-Bar Tick-Path Whipsaws (`127` V1-SL-first vs `84` V2-SL-first):**
   - Among the `211` `V1_LOSS × V2_LOSS` pairs, in **`127` pairs** V1 hit its Stop Loss first while V2 failed to clear the `Spread_0 + Spread_exit` dead-zone for TP, after which price reversed across the range to hit V2's Stop Loss (`Sig #11`, `Sig #19`, `Sig #24`). In the remaining **`84` pairs**, V2 hit its Stop Loss first while V1 failed to clear the spread dead-zone for TP, after which price reversed to hit V1's Stop Loss (`Sig #1`, `Sig #30`).
   - Across all `2,493` pairs, V1 and V2 exited at the exact same timestamp in only **`148` pairs (`5.94%`)**; V1 exited first in **`1,385` pairs (`55.56%`)** (because `D_SL_original < D_TP_original`), and V2 exited first in **`960` pairs (`38.51%`)**.

---

## 4. Layer B — Full Portfolio Backtest Comparison (`$10,000`, `1.0%` Equity, `MaxOpenTrades = 1`)

### 4.1 Complete Portfolio Metrics Side-by-Side

| Metric | V1 Baseline (`GoldBerg_Scalper_EA`) | Inverse V2 (`GoldBerg_InverseV2`) | Delta (`V2 - V1`) |
| :--- | :---: | :---: | :---: |
| **Signals Generated (`M5_BREAK_CONFIRMED`)** | `2,506` | `2,506` | `0` |
| **Risk Rejected: `MAX_OPEN_TRADES`** | `538` | `567` | `+29` |
| **Risk Rejected: `BELOW_MINIMUM_VOLUME`** | `51` | `106` | `+55` |
| **Order Send Attempts** | `1,917` | `1,833` | `-84` |
| **Execution Failed (`Retcode 10018`)** | `6` | `5` | `-1` |
| **Trades Executed (Closed Trades)** | **`1,911`** | **`1,828`** | **`-83`** |
| **Wins / Losses** | `731W / 1,180L` | `985W / 843L` | `+254W / -337L` |
| **Win Rate** | **`38.25%`** | **`53.88%`** | **`+15.63%`** |
| **Average Win (in Strategy R)** | `+1.5308 V1-R` | `+0.6892 V2-R` | `-0.8416 R` |
| **Average Loss (in Strategy R)** | `-1.0323 V1-R` | `-1.0223 V2-R` | `+0.0100 R` |
| **Expectancy (in Strategy R)** | **`-0.0518 V1-R`** | **`-0.1001 V2-R`** | **`-0.0483 R`** |
| **Cumulative Net R** | **`-99.05 V1-R`** | **`-182.94 V2-R`** | **`-83.89 R`** |
| **Profit Factor (USD)** | **`0.83`** | **`0.81`** | **`-0.02`** |
| **Profit Factor (R)** | `0.92` | `0.79` | `-0.13` |
| **Gross Profit / Gross Loss (USD)** | `+$32,202.98 / -$39,031.98` | `+$33,616.95 / -$41,722.56` | `+$1,413.97 / -$2,690.58` |
| **Net P&L (USD)** | **`-$6,829.00` (`-68.29%`)** | **`-$8,105.61` (`-81.06%`)** | **`-$1,276.61`** |
| **Final Balance (USD)** | **`$3,171.00`** | **`$1,894.39`** | **`-$1,276.61`** |
| **Peak Closed-Trade Equity (USD)** | `$10,082.82` | `$10,448.89` | `+$366.07` |
| **Maximum Closed-Trade Drawdown** | **`$8,208.83` (`81.41%`)** | **`$8,575.89` (`82.07%`)** | **`+$367.06` (`+0.66%`)** |

### 4.2 Directional Breakdown (Layer B Portfolio)

| Strategy & Direction | Counterpart Origin | Trades | Wins | Losses | Win Rate | Avg Win (R) | Avg Loss (R) | Expectancy (R) | Net R | PF ($) | Net P&L ($) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **V1 LONG** | Original `BUY` | `890` | `359` | `531` | `40.34%` | `+1.5376R` | `-1.0356R` | `+0.0024R` | `+2.10R` | `0.98` | `-$286.11` |
| **V2 SHORT** | Inverted from V1 `BUY` | `834` | `436` | `398` | `52.28%` | `+0.6919R` | `-1.0289R` | `-0.1293R` | `-107.81R` | `0.71` | `-$5,794.48` |
| **V1 SHORT** | Original `SELL` | `1,021` | `372` | `649` | `36.43%` | `+1.5242R` | `-1.0295R` | `-0.0991R` | `-101.15R` | `0.72` | `-$6,542.89` |
| **V2 LONG** | Inverted from V1 `SELL` | `994` | `549` | `445` | `55.23%` | `+0.6870R` | `-1.0164R` | `-0.0756R` | `-75.13R` | `0.89` | `-$2,311.13` |

### 4.3 Year-by-Year Breakdown (Layer A vs Layer B)

| Year | Layer A: V1 Expectancy (`Net R`) | Layer A: V2 Expectancy (`Net R`) | Layer B: V1 Trades / Exp / Net P&L | Layer B: V2 Trades / Exp / Net P&L |
| :---: | :---: | :---: | :---: | :---: |
| **2023 (Dec)** | `-0.3207R` (`-25.65R`, `N=80`) | `-0.0373R` (`-2.98R`, `N=80`) | `N=59` / `-0.2018R` / `-$1,143.86` | `N=58` / `-0.0181R` / `-$127.64` |
| **2024** | `-0.1645R` (`-152.86R`, `N=929`) | `-0.0870R` (`-80.79R`, `N=929`) | `N=685` / `-0.1526R` / `-$5,746.87` | `N=652` / `-0.1009R` / `-$4,769.35` |
| **2025** | `-0.0814R` (`-69.75R`, `N=857`) | `-0.0803R` (`-68.83R`, `N=857`) | `N=676` / `-0.0628R` / `-$1,108.81` | `N=656` / `-0.0677R` / `-$1,685.02` |
| **2026 (Jan–Oct)** | **`+0.0849R` (`+53.22R`, `N=627`)** | **`-0.1246R` (`-78.12R`, `N=627`)** | **`N=491` / `+0.1219R` / `+$1,170.54`** | **`N=462` / `-0.1552R` / `-$1,523.60`** |

> [!IMPORTANT]
> In **2023–2024** (where V1 suffered severe losses in low-ATR conditions), Inverse V2 still posted negative expectancy (`-0.0181R` in 2023, `-0.1009R` in 2024) because Bid/Ask spread and the `0.6667` payoff ratio consumed the inversion gain. Conversely, in **2026** (where V1 achieved positive expectancy `+0.1219 V1-R` and `PF 1.19` in high-ATR conditions), inverting V1 turned 2026 deeply negative (`-0.1552 V2-R`, `PF 0.68`, `-71.69 V2-R`).

---

## 5. Selection-Bias & Portfolio Overlap Reconciliation (Layer B across all `2,506` Signals)

To avoid selection bias when comparing Layer B (`1,911` V1 trades vs `1,828` V2 trades), all `2,506` signals were cross-tabulated by their fate in V1 Layer B vs V2 Layer B:

| V1 Layer B Status | V2 Layer B Status | Signal Count (`% of 2,506`) | V1 Outcome on Subset | V2 Outcome on Subset |
| :--- | :--- | :---: | :---: | :---: |
| **`EXECUTED`** | **`EXECUTED`** | **`1,740` (`69.43%`)** | `WR 37.93%`, `Exp -0.0600R`, `NetR -104.43R` | `WR 53.56%`, `Exp -0.1056R`, `NetR -183.67R` |
| **`EXECUTED`** | `REJ_MAX_OPEN_TRADES` | **`116` (`4.63%`)** | `WR 41.38%`, `Exp +0.0340R`, `NetR +3.94R` | *(Unsuppressed Layer A: `Exp -0.0981R`)* |
| **`EXECUTED`** | `REJ_BELOW_MINIMUM_VOLUME` | **`55` (`2.19%`)** | `WR 41.82%`, `Exp +0.0262R`, `NetR +1.44R` | *(Unsuppressed Layer A: `Exp -0.0268R`)* |
| `REJ_MAX_OPEN_TRADES` | **`EXECUTED`** | **`81` (`3.23%`)** | *(Unsuppressed Layer A: `Exp -0.1558R`)* | `WR 60.49%`, `Exp +0.0121R`, `NetR +0.98R` |
| `REJ_BELOW_MINIMUM_VOLUME` | **`EXECUTED`** | **`7` (`0.28%`)** | *(Unsuppressed Layer A: `Exp -0.0561R`)* | `WR 57.14%`, `Exp -0.0362R`, `NetR -0.25R` |
| `REJ_MAX_OPEN_TRADES` | `REJ_MAX_OPEN_TRADES` | **`450` (`17.96%`)** | Rejected in both | Rejected in both |
| `REJ_BELOW_MINIMUM_VOLUME` | `REJ_BELOW_MINIMUM_VOLUME` | **`43` (`1.72%`)** | Rejected in both | Rejected in both |
| Other (`EXEC_FAILED` / mixed rejections) | Other (`EXEC_FAILED` / mixed rejections) | **`14` (`0.56%`)** | Non-executed in at least one | Non-executed in at least one |

- **Why `BELOW_MINIMUM_VOLUME` is higher in V2 Layer B (`106` vs `51` in V1):**
  1. `D_SL_inverse = 1.5 × D_SL_original`, so every V2 trade has a `50%` wider stop loss and therefore a `33.3%` smaller raw lot size at any given equity level.
  2. V2's deeper cumulative equity drawdown (`$10,000 → $1,894.39` vs V1's `$3,171.00`) shrinks the `1%` risk budget down to `~$18.94`, causing any V2 signal with `D_SL_inverse > $18.94` (`raw_lot < 0.01`) in late 2025/2026 to be rejected by `BELOW_MINIMUM_VOLUME`.
  3. Across all `106` signals rejected by `BELOW_MINIMUM_VOLUME` in V2 Layer B (`102` of which executed in Layer A while `4` fell in market-closed windows), their unsuppressed Layer A performance was **`+0.0404 V1-R` (`+4.12 V1-R`)** in V1 and **`-0.0291 V2-R` (`-2.96 V2-R`)** in V2. Thus `BELOW_MINIMUM_VOLUME` rejections in V2 actually spared V2 from an additional `-2.96 V2-R` of net losses.

---

## 6. Risk-Budget Compliance & Execution-Cost Observations

1. **Risk-Budget Compliance (`1.0%` Equity Cap):**
   - Against the exact unrounded `inv_sl` passed to `CheckInverseRiskAndVolume()` (`OrderCalcProfit`), **0 / 1,828 (`0.00%`)** V2 trades and **0 / 1,911 (`0.00%`)** V1 trades exceeded `1.0%` of account equity at entry.
   - Because `D_TP_original = 1.5 × D_SL_original` produces `.005` half-cent prices whenever `D_SL_original` has an odd cent, `TradeExecutor::NormalizePrice()` rounds `sent_sl` by `$0.005/oz` to 2 decimal places (`_Digits = 2`). In `10 / 1,828` V2 trades where `raw_lot` was just above a `0.01` lot step boundary, that `$0.005/oz` tick-rounding of `sent_sl` created a microscopic post-rounding difference of at most **`+$0.19` (`0.0019%` of equity)**.
2. **Execution-Cost Observations (Real Ticks):**
   - **Directly Observed Bid/Ask Spread at Signal Timestamp:** Across all `2,506` signals, `abs(OriginalEntry - InverseEntry)` measures the exact live XM `GOLD` spread at entry: **Mean = `$0.4293/oz`**, **Median = `$0.4100/oz`**, **Min = `$0.2700/oz`**, **Max = `$2.6200/oz`**.
   - **Entry Slippage:** **`$0.0000/oz`** across all executed trades in both V1 and V2 (market orders filled at current `Ask`/`Bid` tick quote).
   - **Stop-Loss Adverse Exit Slippage:**
     - **V1 Baseline (`1,180` SL exits):** Mean adverse SL slippage = **`+$0.2146/oz`**.
     - **Inverse V2 (`843` SL exits):** Mean adverse SL slippage = **`+$0.1892/oz`** (explaining why V2 Average Loss is `-1.0223 V2-R` instead of `-1.0000 V2-R`).
   - **Take-Profit Favorable Exit Slippage (Price Improvement on Limit/TP Triggers):**
     - **V1 Baseline (`731` TP exits):** Mean TP fill improvement = **`-$0.2046/oz`** (`+$0.2046/oz` favorable fill, explaining why V1 Average Win is `+1.5308 V1-R` instead of `+1.5000 V1-R`).
     - **Inverse V2 (`985` TP exits):** Mean TP fill improvement = **`-$0.2174/oz`** (`+$0.2174/oz` favorable fill, explaining why V2 Average Win is `+0.6892 V2-R` instead of `+0.6667 V2-R`).

---

## 7. Artifacts, Logs & Reproducibility Metadata

All tester `.ini` configurations, raw single-run UTF-16LE MT5 Strategy Tester logs, and analysis scripts are archived in `C:\Users\ACER\.gemini\antigravity\brain\58ab35aa-a701-45db-a18f-d8f6f11fcccc\scratch\`:

- **Commit Hash Evaluated:** `d451f51938f62868880a8ceaf725f073247d085c` (`experiment/inverse-v2`)
- **Layer B — Inverse V2 Portfolio (`MaxOpenTrades=1`, `$10,000`, `1.0%` Risk):**
  - Config: `scratch\tester_inverse_v2_layerB.ini`
  - Raw Log: `scratch\inverse_v2_layerB_portfolio.log`
- **Layer B — V1 Baseline Portfolio (`MaxOpenTrades=1`, `$10,000`, `1.0%` Risk):**
  - Config: `scratch\tester_v1_layerB.ini`
  - Raw Log: `scratch\v1_layerB_portfolio.log`
- **Layer A — V1 Matched-Signal Diagnostic (`MaxOpenTrades=10000`, `$100,000`, `0.25%` Risk):**
  - Config: `scratch\tester_v1_layerA.ini`
  - Raw Log: `scratch\v1_layerA_matched.log`
- **Layer A — Inverse V2 Matched-Signal Diagnostic (`MaxOpenTrades=10000`, `$100,000`, `0.25%` Risk):**
  - Config: `scratch\tester_v2_layerA.ini`
  - Raw Log: `scratch\inverse_v2_layerA_matched.log`
- **Verification & Parsing Script:** `scratch\analyze_layerA_and_compare.py`


---

## 8. V2 Report Audit Addendum (Methodology, Tester Metadata & Post-Normalization Risk)

### 8.A Layer A Methodology — Matched-Signal Diagnostic with Concurrent Positions

- **Explicit Classification:** Layer A (`InpMaxOpenTrades = 10000`, `Deposit = $100,000`, `InpRiskPercent = 0.25%`) is a **matched-signal diagnostic with concurrent open positions**, NOT `2,506` isolated single-trade resets.
- **Concurrency & Margin Statistics (Verified from Deal/Order Timeline at `1:500` Leverage):**
  - **V1 Layer A (`2,493` executed trades):**
    - Maximum Concurrent Open Positions: **`5`** (reached at `2025.08.15 22:50:00`)
    - Peak Gross Open Volume: **`6.85 lots`**
    - Peak Gross Margin Used: **`$2,788.75`** (at `2024.02.07 02:50:07`)
    - Minimum Margin Level: **`3,207.40%`** (at `2024.02.07 02:50:07`)
    - Margin Rejections / Stop-Outs: **`0` margin rejections, `0` stop-outs** (Final Balance: `$60,861.20`).
  - **Inverse V2 Layer A (`2,493` executed trades):**
    - Maximum Concurrent Open Positions: **`6`** (reached at `2025.08.15 22:50:00`)
    - Peak Gross Open Volume: **`6.17 lots`**
    - Peak Gross Margin Used: **`$2,511.73`** (at `2024.02.07 03:05:00`)
    - Minimum Margin Level: **`3,903.54%`** (at `2024.02.07 03:05:00`)
    - Margin Rejections / Stop-Outs: **`0` margin rejections, `0` stop-outs** (Final Balance: `$56,761.87`).
- **R-Normalization & Path-Dependent Equity Sizing Clarification:**
  - Each trade's realized `R` is normalized by its own actual per-unit stop-loss risk distance (`R_i = (ExitPrice_i - EntryPrice_i) / D_SL_i` for LONG, `(EntryPrice_i - ExitPrice_i) / D_SL_i` for SHORT), which is mathematically identical to `Realized_PnL_USD_i / Actual_Planned_Risk_USD_i` (`(pts * 100 * lot) / (D_SL * 100 * lot)`).
  - If normalized instead by the 2-decimal rounded `sent_sl` distance (`|req_entry - sent_sl|`), V1 Layer A expectancy is unchanged (`-0.078235R`, sum `-195.04R`) and V2 Layer A expectancy differs by only `0.000011R` (`-0.092537R`, sum `-230.69R` vs `-0.092548R`, sum `-230.72R`).
  - Because `CRiskManager` sizes each trade at `0.25%` of current `ACCOUNT_EQUITY`, dollar lot sizes vary over the multi-year run as prior trades and open floating P&L change account equity. Therefore, **R-multiples (`Expectancy`, `Net R`, `PF(R)`) are lot-size-invariant per signal**, whereas Layer A `Net P&L ($)` and `PF($)` reflect path-dependent compounding across the `$100,000` trajectory.

### 8.B Tester Metadata Reconciliation (`Leverage 1:500` & `ToDate = 2026.10.08`)

- **Strategy Tester Leverage (`1:500` vs `1:1000`):**
  - The MT5 Strategy Tester run logs record: `Tester: calculate profit in pips, initial deposit 10000, leverage 1:500`.
  - Earlier live-terminal snapshot documentation noted `1:1000` account leverage, whereas the `.ini` harness specified `Leverage=500`.
  - Because `CRiskManager::CalculateLotSize()` computes 1-lot stop-loss risk via `OrderCalcProfit(ORDER_TYPE_BUY/SELL, _Symbol, 1.0, entry, sl, profit)`, which depends solely on contract size (`100 oz`) and price distance (`|entry - sl|`) and is **100% independent of account leverage**, and because no trade ever approached margin limits under `1.0%` equity risk, running at `1:500` vs `1:1000` yields the **exact same 1,911 V1 trades, lot sizes, fill prices, and `-$6,829.00` Net P&L**.
- **`ToDate = 2026.10.08` vs `2026-10-07` Data Horizon:**
  - In MT5 Strategy Tester `.ini` configurations, `ToDate=2026.10.08` defines the **exclusive upper timestamp bound `2026.10.08 00:00:00`** (`testing of Experts\... from 2023.12.01 00:00 to 2026.10.08 00:00 started`), which is required in MT5 to include the entire trading session of `2026-10-07`.
  - The log header confirms `Ticks: GOLD: history ticks synchronized from 2023.11.17 to 2026.10.07`, and the final tick timestamp processed in all runs (`OnDeinit`) is **`2026.10.07 23:58:59`** (`197,550,686 ticks`, `735 D1 bars`).

### 8.C Post-Normalization Risk Audit (`10 / 1,828` V2 Layer B Half-Cent SL Rounding Cases)

In Inverse V2, `D_SL_inverse = D_TP_original = 1.5 × D_SL_original`. When `D_SL_original` has an odd cent (e.g., `$1.57`), `D_SL_inverse` has a half-cent (`.005`, e.g., `$1.575`). `CRiskManager::CalculateLotSize()` evaluates `signal.stop_loss` before `CTradeExecutor::NormalizePrice()` rounds the submitted SL (`sent_sl`) by `+$0.005/oz` to 2 decimal places (`_Digits = 2`). Across all `1,828` executed trades in V2 Layer B:
- **Pre-normalization (`signal.stop_loss`):** **`0 / 1,828`** trades exceeded `1.0000%` of Equity.
- **Post-normalization (`sent_sl` submitted to broker/tester):** **`10 / 1,828`** trades (all `V2 SHORT` where `.005` rounded up by `+$0.005/oz` away from entry) had a post-rounding planned risk slightly above `1.0000%` of Equity, with a **maximum excess of `+$0.3100` (`1.0032%` of Equity vs `1.0000%` budget)**:

| Trade # | Signal # | Timestamp | Dir | Lot | Equity Before | 1.0% Risk Budget | Pre-Norm SL Dist (Risk $) | Submitted `sent_sl` Dist (Risk $) | Dollar Excess | Actual Risk % Equity |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `#55` | `#76` | `2023.12.28 23:05:02` | `SHORT` | `0.63` | `$9,923.00` | `$99.2300` | `$1.575` (`$99.2250`) | `$1.58` (`$99.5400`) | **`+$0.3100`** | `1.0031%` |
| `#150` | `#234` | `2024.02.28 06:35:01` | `SHORT` | `0.52` | `$9,929.80` | `$99.2980` | `$1.905` (`$99.0600`) | `$1.91` (`$99.3200`) | `+$0.0220` | `1.0002%` |
| `#156` | `#241` | `2024.03.04 06:35:25` | `SHORT` | `0.70` | `$9,993.72` | `$99.9372` | `$1.425` (`$99.7500`) | `$1.43` (`$100.1000`) | `+$0.1628` | `1.0016%` |
| `#158` | `#243` | `2024.03.04 12:50:00` | `SHORT` | `0.33` | `$9,955.82` | `$99.5582` | `$3.015` (`$99.4950`) | `$3.02` (`$99.6600`) | `+$0.1018` | `1.0010%` |
| `#193` | `#288` | `2024.03.20 01:50:00` | `SHORT` | `0.67` | `$9,149.31` | `$91.4931` | `$1.365` (`$91.4550`) | `$1.37` (`$91.7900`) | `+$0.2969` | **`1.0032%`** |
| `#320` | `#463` | `2024.05.28 03:05:00` | `SHORT` | `0.35` | `$7,931.35` | `$79.3135` | `$2.265` (`$79.2750`) | `$2.27` (`$79.4500`) | `+$0.1365` | `1.0017%` |
| `#393` | `#560` | `2024.07.05 16:10:00` | `SHORT` | `0.02` | `$7,491.99` | `$74.9199` | `$37.455` (`$74.9100`) | `$37.46` (`$74.9200`) | `+$0.0001` | `1.0000%` |
| `#473` | `#678` | `2024.08.22 07:50:01` | `SHORT` | `0.17` | `$7,063.86` | `$70.6386` | `$4.155` (`$70.6350`) | `$4.16` (`$70.7200`) | `+$0.0814` | `1.0012%` |
| `#494` | `#703` | `2024.08.29 23:05:00` | `SHORT` | `0.32` | `$6,869.37` | `$68.6937` | `$2.145` (`$68.6400`) | `$2.15` (`$68.8000`) | `+$0.1063` | `1.0015%` |
| `#1054` | `#1462` | `2025.07.15 05:20:00` | `SHORT` | `0.06` | `$4,528.38` | `$45.2838` | `$7.545` (`$45.2700`) | `$7.55` (`$45.3000`) | `+$0.0162` | `1.0004%` |
