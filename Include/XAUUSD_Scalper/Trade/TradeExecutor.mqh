//+------------------------------------------------------------------+
//|                                                TradeExecutor.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

#include <Trade/Trade.mqh>
#include "../Core/Defines.mqh"
#include "../Core/SymbolInfoHelper.mqh"

//+------------------------------------------------------------------+
//| SAFETY DOCUMENTATION:                                            |
//| TradeExecutor is strictly an execution infrastructure layer.     |
//| No strategy assumptions, Entry Distance, SL/TP/RR calculations,  |
//| or entry filters should be added to this module.                 |
//| Filling mode is dynamically determined based on broker symbol    |
//| capabilities via CTrade::SetTypeFillingBySymbol.                 |
//| Strategy-level Entry/SL/TP/RR validation remains pending        |
//| Strategy Specification V1 approval.                              |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   CTrade   m_trade;
   ulong    m_magic_number;

public:
   CTradeExecutor() : m_magic_number(100888) {}
   ~CTradeExecutor() {}

   bool Init(ulong magic)
   {
      m_magic_number = magic;
      m_trade.SetExpertMagicNumber(m_magic_number);
      
      // Temporary execution parameter / placeholder - NOT an optimized value
      m_trade.SetDeviationInPoints(30);
      return true;
   }

   bool ExecuteSignal(CSymbolInfoHelper &symbol_info, const TradeSignal &signal, double lot_size)
   {
      if(signal.action == SIGNAL_NONE || lot_size <= 0.0) return false;

      string symbol = symbol_info.GetSymbol();
      int digits    = symbol_info.GetDigits();

      // Dynamic broker filling mode configuration without hardcoding
      if(!m_trade.SetTypeFillingBySymbol(symbol))
      {
         PrintFormat("[TradeExecutor][ERROR] Failed to set valid filling mode for symbol %s based on broker specs. Decision: NO_TRADE.", symbol);
         return false;
      }

      double norm_sl = NormalizeDouble(signal.stop_loss, digits);
      double norm_tp = NormalizeDouble(signal.take_profit, digits);

      bool   res = false;
      string action_str = "";

      if(signal.action == SIGNAL_BUY)
      {
         action_str = "BUY";
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         PrintFormat("[TradeExecutor] Sending BUY request | Symbol: %s | Vol: %.2f | Ask: %.*f | SL: %.*f | TP: %.*f",
                     symbol, lot_size, digits, ask, digits, norm_sl, digits, norm_tp);
         res = m_trade.Buy(lot_size, symbol, ask, norm_sl, norm_tp, "XAUUSD Scalper V0");
      }
      else if(signal.action == SIGNAL_SELL)
      {
         action_str = "SELL";
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         PrintFormat("[TradeExecutor] Sending SELL request | Symbol: %s | Vol: %.2f | Bid: %.*f | SL: %.*f | TP: %.*f",
                     symbol, lot_size, digits, bid, digits, norm_sl, digits, norm_tp);
         res = m_trade.Sell(lot_size, symbol, bid, norm_sl, norm_tp, "XAUUSD Scalper V0");
      }
      else
      {
         return false;
      }

      // Comprehensive Trade Result & Retcode Logging
      uint   retcode     = m_trade.ResultRetcode();
      string retdesc     = m_trade.ResultRetcodeDescription();
      double exec_price  = m_trade.ResultPrice();
      ulong  order_ticket = m_trade.ResultOrder();
      ulong  deal_ticket  = m_trade.ResultDeal();

      if(res && (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED))
      {
         PrintFormat("[TradeExecutor][SUCCESS] %s Executed | Symbol: %s | Vol: %.2f | Price: %.*f | SL: %.*f | TP: %.*f | Order: %I64u | Deal: %I64u | Retcode: %u (%s)",
                     action_str, symbol, lot_size, digits, exec_price, digits, norm_sl, digits, norm_tp, order_ticket, deal_ticket, retcode, retdesc);
         return true;
      }
      else
      {
         PrintFormat("[TradeExecutor][REJECTED/FAIL] %s Failed | Symbol: %s | Vol: %.2f | SL: %.*f | TP: %.*f | Retcode: %u (%s)",
                     action_str, symbol, lot_size, digits, norm_sl, digits, norm_tp, retcode, retdesc);
         return false;
      }
   }
};
