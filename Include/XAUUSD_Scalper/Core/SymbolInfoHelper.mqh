//+------------------------------------------------------------------+
//|                                             SymbolInfoHelper.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

class CSymbolInfoHelper
{
private:
   string   m_symbol;
   double   m_point;
   int      m_digits;
   double   m_tick_size;
   double   m_tick_value;
   double   m_contract_size;
   double   m_vol_min;
   double   m_vol_max;
   double   m_vol_step;
   int      m_stops_level;

public:
   CSymbolInfoHelper() : m_symbol("") {}
   ~CSymbolInfoHelper() {}

   bool Init(string symbol)
   {
      m_symbol = symbol;
      ResetLastError();
      
      if(!SymbolInfoDouble(m_symbol, SYMBOL_POINT, m_point)) return false;
      m_digits        = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_tick_size     = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      m_tick_value    = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      m_contract_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      m_vol_min       = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      m_vol_max       = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      m_vol_step      = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      m_stops_level   = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);

      PrintFormat("[SymbolInfo] %s | Digits: %d | Point: %f | TickSize: %f | TickVal: %f | MinVol: %.2f | VolStep: %.2f",
                  m_symbol, m_digits, m_point, m_tick_size, m_tick_value, m_vol_min, m_vol_step);
      return true;
   }

   // Getters
   string GetSymbol()       const { return m_symbol; }
   double GetPoint()        const { return m_point; }
   int    GetDigits()       const { return m_digits; }
   double GetTickSize()     const { return m_tick_size; }
   double GetTickValue()    const { return m_tick_value; }
   double GetContractSize() const { return m_contract_size; }
   double GetVolMin()       const { return m_vol_min; }
   double GetVolMax()       const { return m_vol_max; }
   double GetVolStep()      const { return m_vol_step; }
   int    GetStopsLevel()   const { return m_stops_level; }

   // Safe Volume Normalization
   // GUARANTEE: Volume normalization will NEVER silently increase risk above the approved risk budget.
   // 1. If raw_lot < m_vol_min -> return 0.0 (NO_TRADE).
   // 2. If raw_lot > m_vol_max -> return 0.0 (NO_TRADE) (do NOT cap down).
   // 3. Step-down floor according to broker runtime m_vol_step to prevent rounding up risk.
   // 4. Dynamic volume precision based on m_vol_step (no hardcoding).
   double NormalizeVolume(double raw_lot)
   {
      if(raw_lot <= 0.0) return 0.0;
      if(m_vol_min <= 0.0 || m_vol_max <= 0.0) return 0.0;

      // If calculated lot based on risk budget is strictly below broker minimum volume,
      // executing m_vol_min would breach maximum risk budget -> NO_TRADE (return 0.0)
      if(raw_lot < m_vol_min)
      {
         PrintFormat("[SymbolInfo] Calculated raw lot (%.4f) < Min Volume (%.2f). Decision: NO_TRADE.",
                     raw_lot, m_vol_min);
         return 0.0;
      }

      // If calculated lot exceeds broker maximum volume, do NOT cap down to m_vol_max; return 0.0 -> NO_TRADE
      if(raw_lot > m_vol_max)
      {
         PrintFormat("[SymbolInfo] Calculated raw lot (%.4f) > Max Volume (%.2f). Decision: NO_TRADE.",
                     raw_lot, m_vol_max);
         return 0.0;
      }

      if(m_vol_step <= 0.0) return 0.0;

      // Step-down rounding with IEEE-754 epsilon to ensure we never exceed risk budget by rounding up
      double steps = MathFloor(((raw_lot - m_vol_min) / m_vol_step) + 0.0000001);
      double normalized = m_vol_min + steps * m_vol_step;

      // Final bounds check: must be strictly within [m_vol_min, m_vol_max]
      if(normalized < m_vol_min || normalized > m_vol_max) return 0.0;

      // Dynamic decimal precision derived from broker runtime m_vol_step
      int vol_digits = (m_vol_step > 0.0) ? (int)MathMax(0, MathRound(-MathLog10(m_vol_step))) : 2;
      return NormalizeDouble(normalized, vol_digits);
   }
};
