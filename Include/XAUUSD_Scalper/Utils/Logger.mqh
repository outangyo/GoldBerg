//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| SAFETY DOCUMENTATION:                                            |
//| CLogger is strictly an infrastructure & debugging utility layer. |
//| It contains no strategy decision logic or trade filters.          |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_DEBUG = 0,
   LOG_INFO  = 1,
   LOG_WARN  = 2,
   LOG_ERROR = 3
};

class CLogger
{
private:
   ENUM_LOG_LEVEL m_min_level;

public:
   CLogger() : m_min_level(LOG_INFO) {}
   ~CLogger() {}

   void SetLogLevel(ENUM_LOG_LEVEL level) { m_min_level = level; }

   void Log(ENUM_LOG_LEVEL level, string tag, string message)
   {
      if(level < m_min_level) return;
      string prefix = "[INFO]";
      if(level == LOG_DEBUG) prefix = "[DEBUG]";
      if(level == LOG_WARN)  prefix = "[WARN]";
      if(level == LOG_ERROR) prefix = "[ERROR]";

      PrintFormat("%s [%s] %s", prefix, tag, message);
   }
};
