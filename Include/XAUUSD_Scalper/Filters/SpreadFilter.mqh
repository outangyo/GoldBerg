//+------------------------------------------------------------------+
//|                                                 SpreadFilter.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| SAFETY DOCUMENTATION:                                            |
//| STATUS: OBSERVATION / LOGGING UTILITY ONLY IN V1 BASELINE        |
//| CSpreadFilter inspects realtime spread in points using            |
//| SymbolInfoInteger(symbol, SYMBOL_SPREAD).                        |
//|                                                                  |
//| V1 DECISION:                                                     |
//| Spread is recorded for execution observation and diagnostics      |
//| ONLY. It is NOT a hard strategy gate or NO_TRADE filter in the    |
//| V1 Baseline.                                                     |
//+------------------------------------------------------------------+
class CSpreadFilter
{
private:
   double m_max_spread_points;

public:
   // Default 500.0 points is an observation threshold placeholder
   CSpreadFilter() : m_max_spread_points(500.0) {}
   ~CSpreadFilter() {}

   void SetMaxSpreadPoints(double max_spread)
   {
      m_max_spread_points = max_spread;
   }

   bool IsPassed(string symbol, double &current_spread_points)
   {
      long spread = 0;
      if(!SymbolInfoInteger(symbol, SYMBOL_SPREAD, spread))
      {
         current_spread_points = 999999.0;
         return false;
      }
      current_spread_points = (double)spread;
      return (current_spread_points <= m_max_spread_points);
   }
};
