//+------------------------------------------------------------------+
//|                                                GoldBerg_InverseV1.mq5 |
//|                                  Copyright 2026, GoldBerg        |
//|                                                     Version 1.00 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldBerg"
#property link      ""
#property version   "1.00"
#property description "GoldBerg_InverseV1: M15 Sweep -> M5 Causal Confirmation -> Direction Inversion (Preserved SL/TP Distances) -> Risk -> Execution"

//--- Includes (Active V1 Build Path)
#include "../Include/XAUUSD_Scalper/Core/Defines.mqh"
#include "../Include/XAUUSD_Scalper/Core/SymbolInfoHelper.mqh"
#include "../Include/XAUUSD_Scalper/Filters/SpreadFilter.mqh"
#include "../Include/XAUUSD_Scalper/Filters/SessionFilter.mqh"
#include "../Include/XAUUSD_Scalper/Analysis/SetupAnalyzer.mqh"
#include "../Include/XAUUSD_Scalper/Risk/RiskManager.mqh"
#include "../Include/XAUUSD_Scalper/Trade/TradeExecutor.mqh"
#include "../Include/XAUUSD_Scalper/Utils/Logger.mqh"
#include "../Include/XAUUSD_Scalper/Utils/UIDashboard.mqh"
#include "../Include/XAUUSD_Scalper/Utils/DiagnosticTracker.mqh"

//--- Inputs
input group "=== General Settings ==="
input ulong    InpMagicNumber       = 100890;    // EA Magic Number (Distinct from V1=100888, V2=100889)

input group "=== Risk Management ==="
input double   InpRiskPercent       = 1.0;       // Risk % Per Trade (Baseline: 1.0%)
input int      InpMaxOpenTrades     = 1;         // Max Open Trades (V1 Baseline = 1)
input double   InpMaxDailyLossPct   = 3.0;       // Max Daily Loss % [UNIMPLEMENTED / FUTURE CANDIDATE]
input int      InpMaxLosses         = 3;         // Max Consecutive Losses [UNIMPLEMENTED / FUTURE CANDIDATE]

input group "=== Observation & Diagnostics (Non-Blocking in V1 Baseline) ==="
input double   InpMaxSpreadPoints   = 500.0;     // [OBSERVATION ONLY] Diagnostic Spread Threshold (Points)
input bool     InpUseSessionFilter  = false;     // [DISABLED IN V1 BASELINE] Session filter is not a strategy gate
input int      InpStartHour         = 8;         // [DISABLED / UNUSED IN V1]
input int      InpStartMin          = 0;         // [DISABLED / UNUSED IN V1]
input int      InpEndHour           = 22;        // [DISABLED / UNUSED IN V1]
input int      InpEndMin            = 0;         // [DISABLED / UNUSED IN V1]

//--- Global Engine Objects (Active V1 Baseline)
CSymbolInfoHelper  g_symbol_info;
CSpreadFilter      g_spread_filter;
CSessionFilter     g_session_filter;
CSetupAnalyzer     g_setup_analyzer;
CRiskManager       g_risk_manager;
CTradeExecutor     g_trade_executor;
CLogger            g_logger;
CUIDashboard       g_dashboard;
CDiagnosticTracker g_funnel;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_logger.Log(LOG_INFO, "OnInit", "Initializing GoldBerg_InverseV1 EA Inverse V1 experiment...");

   // 1. Symbol Spec Inspection
   if(!g_symbol_info.Init(_Symbol))
   {
      g_logger.Log(LOG_ERROR, "OnInit", "Failed to initialize SymbolInfo for " + _Symbol);
      return INIT_FAILED;
   }

   // 2. Configure Filters (Observation/Diagnostic)
   g_spread_filter.SetMaxSpreadPoints(InpMaxSpreadPoints);
   g_session_filter.Configure(InpUseSessionFilter, InpStartHour, InpStartMin, InpEndHour, InpEndMin);

   // 3. Configure Setup Analyzer (M15 Sweep Lifecycle & M5 Causal Confirmation)
   if(!g_setup_analyzer.Init(PERIOD_M15, PERIOD_M5))
   {
      g_logger.Log(LOG_ERROR, "OnInit", "Failed to initialize Setup Analyzer.");
      return INIT_FAILED;
   }
   g_setup_analyzer.SetDiagnosticTracker(&g_funnel);

   // 4. Configure Risk Manager & Executor
   g_risk_manager.Configure(InpRiskPercent, InpMaxDailyLossPct, InpMaxOpenTrades, InpMaxLosses, InpMagicNumber);
   if(!g_trade_executor.Init(InpMagicNumber))
   {
      g_logger.Log(LOG_ERROR, "OnInit", "Failed to initialize Trade Executor.");
      return INIT_FAILED;
   }

   // 5. Initialize Read-Only Observer Dashboard
   g_dashboard.Init(_Symbol, InpMagicNumber);

   g_logger.Log(LOG_INFO, "OnInit", "Initialization successful. Ready for Inverse V1 execution.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_dashboard.Destroy();
   g_logger.Log(LOG_INFO, "OnDeinit", StringFormat("EA Deinitialized. Reason code: %d", reason));

   // Print Signal Funnel Diagnostic Report (Visible in Strategy Tester Journal / Logs)
   g_funnel.PrintReport();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Inverse V1 pipeline: unchanged V1 signal generation -> inverse direction ONLY (preserving original SL and TP distances) -> Risk -> Execution
   string last_decision = "HOLD / EVALUATING";
   string last_reason   = "Scanning";

   // 1. Observation / Diagnostics (Spread is observation only - NOT a trade blocking gate)
   double current_spread = 0.0;
   g_spread_filter.IsPassed(_Symbol, current_spread);

   // 2. M15 Sweep Lifecycle & M5 Causal Confirmation
   TradeSignal signal;
   if(!g_setup_analyzer.EvaluateSetup(_Symbol, signal))
   {
      last_decision = "NO_TRADE";
      last_reason   = g_setup_analyzer.GetLastNoTradeReason();
      if(last_reason == "") last_reason = "No Confirmed Setup";
      g_dashboard.Update(last_decision, last_reason, g_setup_analyzer, &g_funnel);
      return;
   }

   // 2b. INVERSE V1 transformation (signal generation above remains exactly V1).
   // Reverse direction only and preserve BOTH original SL and TP distances (Reward/Risk remains 1.5:1):
   // D_SL_inverse = D_SL_original; D_TP_inverse = D_TP_original.
   // Uses the opposite executable quote (Bid for SELL, Ask for BUY).
   double original_entry = signal.entry_price;
   double original_sl_distance = MathAbs(original_entry - signal.stop_loss);
   double original_tp_distance = MathAbs(signal.take_profit - original_entry);

   if(original_entry <= 0.0 || original_sl_distance <= 0.0 || original_tp_distance <= 0.0)
   {
      last_decision = "NO_TRADE";
      last_reason   = "Invalid Original Signal Geometry";
      g_logger.Log(LOG_WARN, "OnTick", "Inverse V1 rejected signal: invalid original entry/SL/TP geometry.");
      g_dashboard.Update(last_decision, last_reason, g_setup_analyzer, &g_funnel);
      return;
   }

   ENUM_SIGNAL_ACTION original_action = signal.action;
   ENUM_SIGNAL_ACTION inverse_action =
      (original_action == SIGNAL_BUY) ? SIGNAL_SELL :
      (original_action == SIGNAL_SELL) ? SIGNAL_BUY : SIGNAL_NONE;

   double inverse_entry = (inverse_action == SIGNAL_BUY)
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(inverse_action == SIGNAL_NONE || inverse_entry <= 0.0)
   {
      last_decision = "NO_TRADE";
      last_reason   = "Invalid Inverse Action/Entry";
      g_dashboard.Update(last_decision, last_reason, g_setup_analyzer, &g_funnel);
      return;
   }

   // Original BUY -> inverse SELL: SL = Bid + D_SL_original; TP = Bid - D_TP_original.
   // Original SELL -> inverse BUY: SL = Ask - D_SL_original; TP = Ask + D_TP_original.
   signal.action            = inverse_action;
   signal.entry_price       = inverse_entry;
   signal.stop_loss         = (inverse_action == SIGNAL_BUY)
      ? inverse_entry - original_sl_distance
      : inverse_entry + original_sl_distance;
   signal.take_profit       = (inverse_action == SIGNAL_BUY)
      ? inverse_entry + original_tp_distance
      : inverse_entry - original_tp_distance;
   signal.risk_reward_ratio = (original_sl_distance > 0.0)
      ? original_tp_distance / original_sl_distance : 0.0;
   signal.reason            = "INVERSE_V1_FROM_" + string(original_action == SIGNAL_BUY ? "BUY" : "SELL");

   g_logger.Log(LOG_INFO, "InverseV1",
      StringFormat("Transformed %s -> %s | OriginalEntry: %.2f | OriginalSLDist: %.2f | OriginalTPDist: %.2f | InverseEntry: %.2f | InverseSL: %.2f | InverseTP: %.2f | Reward/Risk: %.4f",
         original_action == SIGNAL_BUY ? "BUY" : "SELL",
         inverse_action == SIGNAL_BUY ? "BUY" : "SELL",
         original_entry, original_sl_distance, original_tp_distance,
         inverse_entry, signal.stop_loss, signal.take_profit, signal.risk_reward_ratio));

   // 3. Risk Engine Phase: 1% Equity budget is recalculated using the NEW inverse SL.
   g_funnel.IncRiskAttempt();

   // 3a. Position Count Gate (Max Open Trades)
   if(!g_risk_manager.ValidateGeneralRisk(_Symbol))
   {
      g_funnel.IncRiskRejected(REJECT_MAX_OPEN_TRADES);
      last_decision = "NO_TRADE";
      last_reason   = "Max Open Positions";
      g_logger.Log(LOG_WARN, "OnTick", "Setup confirmed but rejected by Risk: Max Open Positions.");
      g_dashboard.Update(last_decision, last_reason, g_setup_analyzer, &g_funnel);
      return;
   }

   // 3b. Directional Executable Entry Price
   double executable_entry = (signal.action == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(executable_entry <= 0.0)
   {
      g_funnel.IncRiskRejected(REJECT_INVALID_ENTRY);
      last_decision = "NO_TRADE";
      last_reason   = "Invalid Entry Price";
      g_logger.Log(LOG_WARN, "OnTick", "Setup confirmed but rejected by Risk: Invalid Entry Price.");
      g_dashboard.Update(last_decision, last_reason, g_setup_analyzer, &g_funnel);
      return;
   }

   // 3c. Dynamic Lot Size Calculation and Directional Structural SL
   double lot_size = g_risk_manager.CalculateLotSize(g_symbol_info, signal.action, executable_entry, signal.stop_loss);
   if(lot_size <= 0.0)
   {
      ENUM_RISK_REJECTION_REASON rej_code = g_risk_manager.GetLastRejectionCode();
      g_funnel.IncRiskRejected(rej_code);
      last_decision = "NO_TRADE";
      last_reason   = g_risk_manager.GetLastRejectionReason();
      if(last_reason == "") last_reason = "Invalid Lot Size";
      g_logger.Log(LOG_WARN, "OnTick", StringFormat("Lot calculation rejected (%s). Execution skipped.", last_reason));
      g_dashboard.Update(last_decision, last_reason, g_setup_analyzer, &g_funnel);
      return;
   }

   // 4. Execute Trade Signal
   g_funnel.IncOrderSendAttempt();
   if(g_trade_executor.ExecuteSignal(g_symbol_info, signal, lot_size))
   {
      g_funnel.IncOrderExecuted();
      last_decision = (signal.action == SIGNAL_BUY) ? "BUY_EXECUTED" : "SELL_EXECUTED";
      last_reason   = signal.reason;
      g_logger.Log(LOG_INFO, "OnTick", "Trade executed successfully.");
   }
   else
   {
      g_funnel.IncOrderFailed();
      last_decision = "EXECUTION_FAILED";
      last_reason   = "OrderSend Error";
      g_logger.Log(LOG_ERROR, "OnTick", "Trade execution failed.");
   }

   g_dashboard.Update(last_decision, last_reason, g_setup_analyzer, &g_funnel);
}
