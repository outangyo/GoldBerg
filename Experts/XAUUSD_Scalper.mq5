//+------------------------------------------------------------------+
//|                                               XAUUSD_Scalper.mq5 |
//|                                  Copyright 2026, XAUUSD Scalper  |
//|                                             Baseline Version 1.0 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"
#property description "XAUUSD V1 Locked Baseline: M15 Sweep -> M5 Causal Confirmation -> Risk -> Execution"

//--- Includes (Active V1 Build Path)
#include "../Include/XAUUSD_Scalper/Core/Defines.mqh"
#include "../Include/XAUUSD_Scalper/Core/SymbolInfoHelper.mqh"
#include "../Include/XAUUSD_Scalper/Filters/SpreadFilter.mqh"
#include "../Include/XAUUSD_Scalper/Filters/SessionFilter.mqh"
#include "../Include/XAUUSD_Scalper/Analysis/SetupAnalyzer.mqh"
#include "../Include/XAUUSD_Scalper/Risk/RiskManager.mqh"
#include "../Include/XAUUSD_Scalper/Trade/TradeExecutor.mqh"
#include "../Include/XAUUSD_Scalper/Utils/Logger.mqh"

//--- Inputs
input group "=== General Settings ==="
input ulong    InpMagicNumber       = 100888;    // EA Magic Number

input group "=== Risk Management ==="
input double   InpRiskPercent       = 1.0;       // Risk % Per Trade
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
CSymbolInfoHelper g_symbol_info;
CSpreadFilter     g_spread_filter;
CSessionFilter     g_session_filter;
CSetupAnalyzer    g_setup_analyzer;
CRiskManager      g_risk_manager;
CTradeExecutor    g_trade_executor;
CLogger           g_logger;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_logger.Log(LOG_INFO, "OnInit", "Initializing XAUUSD Scalper EA Baseline V1.0...");

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

   // 4. Configure Risk Manager & Executor
   g_risk_manager.Configure(InpRiskPercent, InpMaxDailyLossPct, InpMaxOpenTrades, InpMaxLosses, InpMagicNumber);
   if(!g_trade_executor.Init(InpMagicNumber))
   {
      g_logger.Log(LOG_ERROR, "OnInit", "Failed to initialize Trade Executor.");
      return INIT_FAILED;
   }

   g_logger.Log(LOG_INFO, "OnInit", "Initialization successful. Ready for V1 Baseline execution.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_logger.Log(LOG_INFO, "OnDeinit", StringFormat("EA Deinitialized. Reason code: %d", reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // V1 Locked Pipeline: M15 Sweep -> M5 Causal Confirmation -> Risk -> Execution
   
   // 1. Observation / Diagnostics (Spread is observation only - NOT a trade blocking gate)
   double current_spread = 0.0;
   g_spread_filter.IsPassed(_Symbol, current_spread);

   // 2. Risk Criteria Check (Active Position Scope)
   if(!g_risk_manager.ValidateGeneralRisk(_Symbol))
   {
      return; // Max open trades reached -> NO TRADE
   }

   // 3. M15 Sweep Lifecycle & M5 Causal Confirmation
   TradeSignal signal;
   if(!g_setup_analyzer.EvaluateSetup(_Symbol, signal))
   {
      return; // No confirmed Setup -> NO TRADE
   }

   // 4. Calculate Dynamic Lot Size from Executable Entry Price and Directional Structural SL
   double executable_entry = (signal.action == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot_size = g_risk_manager.CalculateLotSize(g_symbol_info, signal.action, executable_entry, signal.stop_loss);
   if(lot_size <= 0.0)
   {
      g_logger.Log(LOG_WARN, "OnTick", "Invalid calculated lot size. Execution skipped.");
      return;
   }

   // 5. Execute Trade Signal
   if(g_trade_executor.ExecuteSignal(g_symbol_info, signal, lot_size))
   {
      g_logger.Log(LOG_INFO, "OnTick", "Trade executed successfully.");
   }
   else
   {
      g_logger.Log(LOG_ERROR, "OnTick", "Trade execution failed.");
   }
}
