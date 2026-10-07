//+------------------------------------------------------------------+
//|                                                SessionFilter.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| SAFETY DOCUMENTATION:                                            |
//| CSessionFilter checks current broker server time (TimeCurrent).  |
//|                                                                  |
//| NOTE ON SESSION HOURS:                                           |
//| Default 08:00 - 22:00 is a TEMPORARY PLACEHOLDER in broker time. |
//| Final session hours are NOT YET APPROVED and await Strategy      |
//| Specification V1 approval.                                       |
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
   // Default 08:00 - 22:00 is a Temporary Placeholder - pending Strategy Spec V1 approval
   CSessionFilter() :
      m_use_session_filter(true),
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
