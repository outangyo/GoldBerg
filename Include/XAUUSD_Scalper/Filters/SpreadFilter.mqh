//+------------------------------------------------------------------+
//|                                                 SpreadFilter.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| SAFETY DOCUMENTATION:                                            |
//| CSpreadFilter checks realtime spread in Points using              |
//| SymbolInfoInteger(symbol, SYMBOL_SPREAD).                        |
//|                                                                  |
//| NOTE ON THRESHOLD:                                               |
//| The default 500.0 points value is a TEMPORARY PLACEHOLDER.       |
//| The final spread threshold is NOT YET APPROVED and must be       |
//| determined based on actual XM XAUUSD symbol specifications and   |
//| Strategy Specification V1 approval.                              |
//+------------------------------------------------------------------+
class CSpreadFilter
{
private:
   double m_max_spread_points;

public:
   // Default 500.0 points is a Temporary Placeholder - pending Strategy Spec V1 approval
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
