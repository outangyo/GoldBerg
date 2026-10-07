//+------------------------------------------------------------------+
//|                                             StructureTracker.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//|                    M15 Confirmed Swings with Invalidation Memory  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

//--- Swing Point Structure
struct SwingPoint
{
   double   price;       // Confirmed Swing High or Swing Low price
   datetime time;        // Bar open time of the swing bar
   int      bar_index;   // Bar index (shift) at detection
   bool     is_active;   // True if active, false once breached/invalidated
};

//+------------------------------------------------------------------+
//| CStructureTracker: Identifies confirmed M15 Swing Highs/Lows     |
//| using standard fractals on closed bars. Prevents resurrection of |
//| breached/invalidated swings until a strictly newer swing forms.  |
//+------------------------------------------------------------------+
class CStructureTracker
{
private:
   ENUM_TIMEFRAMES m_timeframe;
   int             m_swing_strength;               // Bars on each side (default 2 for 5-bar fractal)
   SwingPoint      m_swing_high;
   SwingPoint      m_swing_low;
   datetime        m_last_invalidated_high_time;   // Timestamp of last breached/invalidated swing high
   datetime        m_last_invalidated_low_time;    // Timestamp of last breached/invalidated swing low
   datetime        m_last_scan_time;

public:
   CStructureTracker() :
      m_timeframe(PERIOD_M15),
      m_swing_strength(2),
      m_last_invalidated_high_time(0),
      m_last_invalidated_low_time(0),
      m_last_scan_time(0)
   {
      m_swing_high.price     = 0.0;
      m_swing_high.time      = 0;
      m_swing_high.bar_index = -1;
      m_swing_high.is_active = false;

      m_swing_low.price      = 0.0;
      m_swing_low.time       = 0;
      m_swing_low.bar_index  = -1;
      m_swing_low.is_active  = false;
   }
   ~CStructureTracker() {}

   bool Init(ENUM_TIMEFRAMES timeframe = PERIOD_M15, int swing_strength = 2)
   {
      m_timeframe                  = timeframe;
      m_swing_strength             = (swing_strength < 1) ? 2 : swing_strength;
      m_last_invalidated_high_time = 0;
      m_last_invalidated_low_time  = 0;
      m_last_scan_time             = 0;
      m_swing_high.is_active       = false;
      m_swing_low.is_active        = false;
      return true;
   }

   // Update confirmed swings from closed M15 bars
   // Critical Rule 1: Never reactivate an invalidated swing; only accept swings with time > last_invalidated_time
   void UpdateSwings(string symbol)
   {
      datetime current_bar_time = iTime(symbol, m_timeframe, 0);
      if(current_bar_time == 0) return;

      // Scan only when a new M15 bar begins or when active swings are missing
      if(current_bar_time == m_last_scan_time && m_swing_high.is_active && m_swing_low.is_active)
         return;

      m_last_scan_time = current_bar_time;

      int total_bars = iBars(symbol, m_timeframe);
      int max_scan   = MathMin(100, total_bars - m_swing_strength - 1);

      // 1. Search for newest confirmed Swing High (strictly newer than last invalidated swing high)
      if(!m_swing_high.is_active)
      {
         for(int i = m_swing_strength + 1; i < max_scan; i++)
         {
            datetime bar_t = iTime(symbol, m_timeframe, i);
            if(bar_t <= m_last_invalidated_high_time)
            {
               // Reached historical invalidated swings - stop searching backwards
               break;
            }

            double high_i = iHigh(symbol, m_timeframe, i);
            bool is_swing_high = true;

            for(int j = 1; j <= m_swing_strength; j++)
            {
               if(high_i <= iHigh(symbol, m_timeframe, i - j) ||
                  high_i <= iHigh(symbol, m_timeframe, i + j))
               {
                  is_swing_high = false;
                  break;
               }
            }

            if(is_swing_high)
            {
               m_swing_high.price     = high_i;
               m_swing_high.time      = bar_t;
               m_swing_high.bar_index = i;
               m_swing_high.is_active = true;
               PrintFormat("[StructureTracker] New confirmed Swing High detected at %s | Price: %f",
                           TimeToString(bar_t), high_i);
               break;
            }
         }
      }

      // 2. Search for newest confirmed Swing Low (strictly newer than last invalidated swing low)
      if(!m_swing_low.is_active)
      {
         for(int i = m_swing_strength + 1; i < max_scan; i++)
         {
            datetime bar_t = iTime(symbol, m_timeframe, i);
            if(bar_t <= m_last_invalidated_low_time)
            {
               // Reached historical invalidated swings - stop searching backwards
               break;
            }

            double low_i = iLow(symbol, m_timeframe, i);
            bool is_swing_low = true;

            for(int j = 1; j <= m_swing_strength; j++)
            {
               if(low_i >= iLow(symbol, m_timeframe, i - j) ||
                  low_i >= iLow(symbol, m_timeframe, i + j))
               {
                  is_swing_low = false;
                  break;
               }
            }

            if(is_swing_low)
            {
               m_swing_low.price     = low_i;
               m_swing_low.time      = bar_t;
               m_swing_low.bar_index = i;
               m_swing_low.is_active = true;
               PrintFormat("[StructureTracker] New confirmed Swing Low detected at %s | Price: %f",
                           TimeToString(bar_t), low_i);
               break;
            }
         }
      }
   }

   // Deactivate and remember invalidated swing (Rule 1)
   void InvalidateSwingHigh(datetime swing_time)
   {
      m_swing_high.is_active = false;
      if(swing_time > m_last_invalidated_high_time)
         m_last_invalidated_high_time = swing_time;
   }

   void InvalidateSwingLow(datetime swing_time)
   {
      m_swing_low.is_active = false;
      if(swing_time > m_last_invalidated_low_time)
         m_last_invalidated_low_time = swing_time;
   }

   // Check if a newer confirmed same-direction Swing High has formed (Rule 6)
   bool CheckNewConfirmedSwingHigh(string symbol, datetime reference_time, SwingPoint &out_new_swing)
   {
      int total_bars = iBars(symbol, m_timeframe);
      int max_scan   = MathMin(100, total_bars - m_swing_strength - 1);

      for(int i = m_swing_strength + 1; i < max_scan; i++)
      {
         datetime bar_t = iTime(symbol, m_timeframe, i);
         if(bar_t <= reference_time) break; // Must be strictly newer than reference swing

         double high_i = iHigh(symbol, m_timeframe, i);
         bool is_swing = true;

         for(int j = 1; j <= m_swing_strength; j++)
         {
            if(high_i <= iHigh(symbol, m_timeframe, i - j) ||
               high_i <= iHigh(symbol, m_timeframe, i + j))
            {
               is_swing = false;
               break;
            }
         }

         if(is_swing)
         {
            out_new_swing.price     = high_i;
            out_new_swing.time      = bar_t;
            out_new_swing.bar_index = i;
            out_new_swing.is_active = true;
            return true;
         }
      }
      return false;
   }

   // Check if a newer confirmed same-direction Swing Low has formed (Rule 6)
   bool CheckNewConfirmedSwingLow(string symbol, datetime reference_time, SwingPoint &out_new_swing)
   {
      int total_bars = iBars(symbol, m_timeframe);
      int max_scan   = MathMin(100, total_bars - m_swing_strength - 1);

      for(int i = m_swing_strength + 1; i < max_scan; i++)
      {
         datetime bar_t = iTime(symbol, m_timeframe, i);
         if(bar_t <= reference_time) break; // Must be strictly newer than reference swing

         double low_i = iLow(symbol, m_timeframe, i);
         bool is_swing = true;

         for(int j = 1; j <= m_swing_strength; j++)
         {
            if(low_i >= iLow(symbol, m_timeframe, i - j) ||
               low_i >= iLow(symbol, m_timeframe, i + j))
            {
               is_swing = false;
               break;
            }
         }

         if(is_swing)
         {
            out_new_swing.price     = low_i;
            out_new_swing.time      = bar_t;
            out_new_swing.bar_index = i;
            out_new_swing.is_active = true;
            return true;
         }
      }
      return false;
   }

   // Adopt new swing directly
   void AdoptNewSwingHigh(const SwingPoint &swing) { m_swing_high = swing; }
   void AdoptNewSwingLow(const SwingPoint &swing)  { m_swing_low  = swing; }

   // Getters
   SwingPoint GetActiveSwingHigh() const { return m_swing_high; }
   SwingPoint GetActiveSwingLow()  const { return m_swing_low; }
   datetime   GetLastInvalidatedHighTime() const { return m_last_invalidated_high_time; }
   datetime   GetLastInvalidatedLowTime()  const { return m_last_invalidated_low_time; }
};
