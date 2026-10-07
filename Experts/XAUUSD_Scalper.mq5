//+------------------------------------------------------------------+
//|                                               XAUUSD_Scalper.mq5 |
//|                                  Copyright 2026, XAUUSD Scalper  |
//|                                             Framework Version 0.0 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "0.01"
#property description "XAUUSD Multi-Timeframe Strategy-First Scalper Framework"

//--- Includes
#include "../Include/XAUUSD_Scalper/Core/Defines.mqh"
#include "../Include/XAUUSD_Scalper/Core/SymbolInfoHelper.mqh"
#include "../Include/XAUUSD_Scalper/Filters/SpreadFilter.mqh"
#include "../Include/XAUUSD_Scalper/Filters/SessionFilter.mqh"
#include "../Include/XAUUSD_Scalper/Analysis/ContextAnalyzer.mqh"
#include "../Include/XAUUSD_Scalper/Analysis/SetupAnalyzer.mqh"
#include "../Include/XAUUSD_Scalper/Analysis/EntryAnalyzer.mqh"
#include "../Include/XAUUSD_Scalper/Risk/RiskManager.mqh"
#include "../Include/XAUUSD_Scalper/Trade/TradeExecutor.mqh"
#include "../Include/XAUUSD_Scalper/Utils/Logger.mqh"

//--- Inputs
input group "=== General Settings ==="
input ulong    InpMagicNumber       = 100888;    // EA Magic Number

input group "=== Risk Management (Temporary Placeholders) ==="
input double   InpRiskPercent       = 1.0;       // Risk % Per Trade [TEMPORARY PLACEHOLDER]
input double   InpMaxDailyLossPct   = 3.0;       // Max Daily Loss % [TEMPORARY PLACEHOLDER]
input int      InpMaxOpenTrades     = 1;         // Max Open Trades [TEMPORARY PLACEHOLDER]
input int      InpMaxLosses         = 3;         // Max Consecutive Losses [TEMPORARY PLACEHOLDER]

input group "=== Filters (Temporary Placeholders) ==="
input double   InpMaxSpreadPoints   = 500.0;     // Max Spread in Points (1 Point = SYMBOL_POINT e.g. 0.01) [TEMPORARY PLACEHOLDER]
input bool     InpUseSessionFilter  = true;      // Enable Session Filter [TEMPORARY PLACEHOLDER]
input int      InpStartHour         = 8;         // Session Start Hour (Broker Server Time) [TEMPORARY PLACEHOLDER]
input int      InpStartMin          = 0;         // Session Start Minute [TEMPORARY PLACEHOLDER]
input int      InpEndHour           = 22;        // Session End Hour (Broker Server Time) [TEMPORARY PLACEHOLDER]
input int      InpEndMin            = 0;         // Session End Minute [TEMPORARY PLACEHOLDER]

//--- Global Engine Objects
CSymbolInfoHelper g_symbol_info;
CSpreadFilter     g_spread_filter;
CSessionFilter     g_session_filter;
CContextAnalyzer  g_context_analyzer;
CSetupAnalyzer    g_setup_analyzer;
CEntryAnalyzer    g_entry_analyzer;
CRiskManager      g_risk_manager;
CTradeExecutor    g_trade_executor;
CLogger           g_logger;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_logger.Log(LOG_INFO, "OnInit", "Initializing XAUUSD Scalper EA Framework V0.0...");

   // 1. Symbol Spec Inspection
   if(!g_symbol_info.Init(_Symbol))
   {
      g_logger.Log(LOG_ERROR, "OnInit", "Failed to initialize SymbolInfo for " + _Symbol);
      return INIT_FAILED;
   }

   // 2. Configure Filters
   g_spread_filter.SetMaxSpreadPoints(InpMaxSpreadPoints);
   g_session_filter.Configure(InpUseSessionFilter, InpStartHour, InpStartMin, InpEndHour, InpEndMin);

   // 3. Configure Analyzers
   if(!g_context_analyzer.Init(PERIOD_M15) ||
      !g_setup_analyzer.Init(PERIOD_M5)    ||
      !g_entry_analyzer.Init(PERIOD_M1))
   {
      g_logger.Log(LOG_ERROR, "OnInit", "Failed to initialize MTF Analyzers.");
      return INIT_FAILED;
   }

   // 4. Configure Risk Manager & Executor
   g_risk_manager.Configure(InpRiskPercent, InpMaxDailyLossPct, InpMaxOpenTrades, InpMaxLosses, InpMagicNumber);
   if(!g_trade_executor.Init(InpMagicNumber))
   {
      g_logger.Log(LOG_ERROR, "OnInit", "Failed to initialize Trade Executor.");
      return INIT_FAILED;
   }

   g_logger.Log(LOG_INFO, "OnInit", "Initialization successful.");
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
   // V1 Target Pipeline: M15 Context -> M5 Setup -> Risk -> Execution
   
   // 1. Observation / Logging (Spread is observation only - NOT a trade blocking gate)
   double current_spread = 0.0;
   g_spread_filter.IsPassed(_Symbol, current_spread);

   // 2. Risk Criteria Check (Active Position Scope)
   if(!g_risk_manager.ValidateGeneralRisk(_Symbol))
   {
      return; // Max open trades or risk limits exceeded -> NO TRADE
   }

   // 3. M15 Sweep Lifecycle & M5 Confirmation (V1 Pipeline: M15 -> M5 -> Risk -> Execution)
   TradeSignal signal;
   if(!g_setup_analyzer.EvaluateSetup(_Symbol, signal))
   {
      return; // No valid Setup -> NO TRADE
   }

   // 5. Calculate Dynamic Lot Size from Executable Entry Price and Directional Structural SL
   double executable_entry = (signal.action == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot_size = g_risk_manager.CalculateLotSize(g_symbol_info, signal.action, executable_entry, signal.stop_loss);
   if(lot_size <= 0.0)
   {
      g_logger.Log(LOG_WARN, "OnTick", "Invalid calculated lot size. Execution skipped.");
      return;
   }

   // 6. Execute Trade Signal
   if(g_trade_executor.ExecuteSignal(g_symbol_info, signal, lot_size))
   {
      g_logger.Log(LOG_INFO, "OnTick", "Trade executed successfully.");
   }
   else
   {
      g_logger.Log(LOG_ERROR, "OnTick", "Trade execution failed.");
   }
}
