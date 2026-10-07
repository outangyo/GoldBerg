//+------------------------------------------------------------------+
//|                                                      Defines.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

//--- Trend Context Enum (M15 Market Direction)
enum ENUM_MARKET_CONTEXT
{
   CONTEXT_NEUTRAL = 0,
   CONTEXT_BULLISH = 1,
   CONTEXT_BEARISH = 2
};

//--- Setup Status Enum (M5 Setup Candidate Status)
// IMPORTANT DOCUMENTATION NOTE:
// SETUP_BUY_VALID and SETUP_SELL_VALID indicate that an M5 setup candidate 
// has passed condition checks ONLY. It DOES NOT authorize trade execution.
// Trade execution requires further M1 confirmation, spread verification, 
// and risk validation in the decision pipeline.
enum ENUM_SETUP_STATUS
{
   SETUP_NONE = 0,
   SETUP_BUY_VALID = 1,  // Candidate setup detected on M5 ONLY (Does NOT authorize trade execution)
   SETUP_SELL_VALID = 2  // Candidate setup detected on M5 ONLY (Does NOT authorize trade execution)
};

//--- Signal Execution Action
enum ENUM_SIGNAL_ACTION
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY = 1,
   SIGNAL_SELL = 2
};

//--- Trade Signal Structure
struct TradeSignal
{
   ENUM_SIGNAL_ACTION action;
   double             entry_price;
   double             stop_loss;
   double             take_profit;
   double             risk_reward_ratio;
   string             reason;
};
