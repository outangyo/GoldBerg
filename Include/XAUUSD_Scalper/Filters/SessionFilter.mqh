//+------------------------------------------------------------------+
//|                                                SessionFilter.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| SAFETY DOCUMENTATION:                                            |
//| STATUS: DISABLED / PLACEHOLDER IN V1 BASELINE                    |
//| CSessionFilter checks current broker server time (TimeCurrent).  |
//|                                                                  |
//| V1 DECISION:                                                     |
//| Session Filter is NOT a strategy gate in the V1 Baseline. It is  |
//| decoupled from the trade execution path to allow 24-hour baseline|
//| evaluation of pure price action without hidden session rules.    |
//+------------------------------------------------------------------+
class CSessionFilter
{
private:
   bool m_use_session_filter;
   int  m_start_hour;
   int  m_start_minute;
   int  m_end_hour;
   int  m_end_minute;

public:
   // Default 08:00 - 22:00 is a placeholder for future session research
   CSessionFilter() :
      m_use_session_filter(false),
      m_start_hour(8),
      m_start_minute(0),
      m_end_hour(22),
      m_end_minute(0)
   {}
   ~CSessionFilter() {}

   void Configure(bool enable, int start_h, int start_m, int end_h, int end_m)
   {
      m_use_session_filter = enable;
      m_start_hour         = start_h;
      m_start_minute       = start_m;
      m_end_hour           = end_h;
      m_end_minute         = end_m;
   }

   bool IsPassed()
   {
      if(!m_use_session_filter) return true;

      MqlDateTime dt;
      TimeCurrent(dt);
      
      int current_mins = dt.hour * 60 + dt.min;
      int start_mins   = m_start_hour * 60 + m_start_minute;
      int end_mins     = m_end_hour * 60 + m_end_minute;

      if(start_mins <= end_mins)
      {
         return (current_mins >= start_mins && current_mins <= end_mins);
      }
      else
      {
         // Overnight session
         return (current_mins >= start_mins || current_mins <= end_mins);
      }
   }
};
