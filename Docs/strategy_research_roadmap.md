# Strategy Research Roadmap

**Status:** APPROVED RESEARCH SEQUENCE  
**Current V1 strategy baseline:** 7ed6327  
**Documentation baseline before this roadmap:** e4952d03daa1af0493a3e1cc31409ae3d4dd182d  
**Experiment branch:** experiment/inverse-v2

## Purpose

V1's full-period 1% risk backtest did not demonstrate a positive strategy edge. The research sequence below tests whether the observed outcomes contain a usable directional or payoff asymmetry before deciding whether to redesign the strategy.

This roadmap is a research plan, not evidence that any candidate is profitable. No candidate is promoted to LOCKED without review and explicit PO approval.

## Evidence motivating the sequence

V1 full-period baseline (2023-12-01 to 2026-10-07, real ticks, $10,000 initial balance, 1% risk):

- 1,911 trades; 731 wins / 1,180 losses
- Win rate 38.25%; PF 0.83
- Net P&L -$6,829; maximum drawdown 81.41%
- LONG: 890 trades, WR 40.34%, expectancy +0.002R, PF 0.98, net +2.1R
- SHORT: 1,021 trades, WR 36.43%, expectancy -0.099R, PF 0.72, net -101.1R

Interpretation:
- LONG is near breakeven and remains an unproven research candidate, not a validated profitable strategy.
- SHORT accounts for approximately 95.8% of the baseline net dollar loss and deserves separate research if inverse experiments fail.
- No previously explored stop-distance threshold or regime filter is approved for implementation.

## Approved experiment order

### 1. Inverse V2 — first experiment

**Hypothesis:** Reverse the original V1 signal direction and swap the original SL/TP distances. This deliberately changes the payoff ratio as well as direction. The smaller reward distance may be offset by a higher win rate; this is an empirical question, not an assumption.

For each original V1 signal, capture:
- Original signal action and signal entry reference
- Original SL distance: D_SL = abs(OriginalEntry - OriginalSL)
- Original TP distance: D_TP = abs(OriginalTP - OriginalEntry)

At the inverse executable quote:
- Reverse BUY to SELL and SELL to BUY.
- New inverse SL distance = D_TP.
- New inverse TP distance = D_SL.
- For baseline V1 reward/risk 1.5, V2 reward/risk is approximately 1 / 1.5 = 0.6667; equivalently risk:reward is 1.5:1.
- Keep Risk Budget at 1.0% of current Equity, sized from the new inverse SL using broker-aware OrderCalcProfit(). Do not reuse V1 lot size.
- Use the inverse-side executable quote (SELL Bid / BUY Ask) as the sizing reference. Record actual fill and actual realized result.

**Scope control:**
- Preserve V1 signal generation exactly: M15 confirmed swing, sweep/breach, M15 close reclaim, causal M5 extreme-bar break confirmation.
- Do not add filters, alter signal timing, or change the V1 source/baseline.
- Use a separate EA entry point and experiment branch.
- Distinguish the matched-signal diagnostic from the full portfolio backtest. Matched-signal analysis should evaluate each generated signal independently without max-open-position suppression; the portfolio run should retain max open trades = 1.
- Compare LONG and SHORT separately as well as combined.
- Use the same symbol, date range, real-tick model, spread/commission/swap assumptions, starting capital and other tester settings as the V1 baseline.

**Important execution qualification:** The inverse trade uses the opposite executable quote, so its entry will not necessarily equal the original signal entry. V2 preserves the original SL/TP distances, not the old absolute price levels. Bid/Ask, spread, fill movement, slippage and tick-path ordering can prevent exact outcome complementation.

**Decision:** Report trade count, WR, average win/loss in V2-R, expectancy, PF, net P&L, max DD, LONG/SHORT split, costs and risk-budget compliance. Do not declare success from WR alone.

### 2. Inverse V1 — only if V2 does not pass

Reverse direction only, preserve the original V1 stop distance and reward/risk ratio of 1.5:1 (reward/risk). Size from 1% Equity risk using the inverse stop. Keep the same signal-generation and testing controls.

Purpose: isolate whether direction reversal alone helps, without V2's payoff-geometry change.

### 3. SHORT-side research — if both inverse experiments fail

Investigate the SHORT side independently before changing the LONG side. Research candidates include:
- Liquidity/swing-high sweep and reclaim behavior
- M15 structure-break vs reclaim classification
- M5 confirmation and extreme-bar geometry
- Stop-distance and volatility context
- Regime/time-period instability, especially the large differences across 2024, 2025 and 2026

Do not implement a $5 stop threshold, ATR filter, session filter or other candidate merely because it looks favorable in an exploratory slice. Require a pre-defined hypothesis, adequate sample, chronological validation and PO approval.

### 4. New strategy research — if no robust edge is found

Explore a new strategy hypothesis without forcing V1's logic to fit. Preserve V1 and all experiment reports as historical baselines.

## Governance and reproducibility

- PO is final approver.
- GPT/Ray is strategy and technical reviewer; AGY is implementation owner; Gemini may challenge methodology.
- No strategy/source/parameter changes beyond the explicitly approved experiment.
- No commits or pushes to the V1 baseline branch without explicit approval.
- Keep experiment code isolated from the V1 baseline; use a dedicated branch and EA filename.
- One hypothesis / one primary variable per experiment.
- Dashboard remains read-only and must not affect decisions.
- Clearly label LOCKED, CANDIDATE, PARKED and REJECTED conclusions.
- Report exact commit, EA file, inputs, tester configuration, logs and result artifacts for every run.
- A failed experiment is a valid result; do not optimize repeatedly against the same full sample.

## Current status

- V1 baseline: historical reference; not profitable in the tested full-period configuration.
- Inverse V2: approved first experiment; implementation isolated on experiment/inverse-v2.
- Inverse V1: queued, conditional on V2 outcome.
- SHORT-side research: queued, conditional on both inverse experiments.
- New strategy research: queued, conditional on earlier work.
