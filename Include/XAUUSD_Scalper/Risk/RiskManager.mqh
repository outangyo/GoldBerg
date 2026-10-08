//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

#include "../Core/SymbolInfoHelper.mqh"
#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| SAFETY DOCUMENTATION:                                            |
//| Max Daily Loss and Max Consecutive Losses are declared risk      |
//| controls but are intentionally not implemented in this version.  |
//| No implementation should be added until the corresponding Risk  |
//| Specification section of XAUUSD_SCALPER_STRATEGY_SPEC_V1 is     |
//| defined and approved.                                            |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double m_risk_percent_per_trade;
   double m_max_daily_loss_percent;
   int    m_max_open_positions;
   int    m_max_consecutive_losses;
   ulong  m_magic_number;
   ENUM_RISK_REJECTION_REASON m_last_rejection_code;
   string m_last_rejection_reason;

public:
   CRiskManager() :
      m_risk_percent_per_trade(5.0),
      m_max_daily_loss_percent(3.0),
      m_max_open_positions(1),
      m_max_consecutive_losses(3),
      m_magic_number(0),
      m_last_rejection_code(REJECT_NONE),
      m_last_rejection_reason("")
   {}
   ~CRiskManager() {}

   void Configure(double risk_pct, double max_daily_loss_pct, int max_positions, int max_losses, ulong magic_number = 0)
   {
      m_risk_percent_per_trade = risk_pct;
      m_max_daily_loss_percent = max_daily_loss_pct;
      m_max_open_positions     = max_positions;
      m_max_consecutive_losses = max_losses;
      m_magic_number           = magic_number;
   }

   void SetMagicNumber(ulong magic_number)
   {
      m_magic_number = magic_number;
   }

   // Validate general risk criteria (e.g. current active positions count for THIS EA instance)
   bool ValidateGeneralRisk(string symbol)
   {
      int current_open = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            ulong  pos_magic  = PositionGetInteger(POSITION_MAGIC);

            // Filter positions strictly by BOTH Symbol and Magic Number
            if(pos_symbol == symbol && pos_magic == m_magic_number)
            {
               current_open++;
            }
         }
      }
      if(current_open >= m_max_open_positions)
      {
         m_last_rejection_code   = REJECT_MAX_OPEN_TRADES;
         m_last_rejection_reason = "MAX_OPEN_TRADES";
         return false; // Reached max open positions limit for this EA
      }
      return true;
   }

   // Calculate dynamic lot size based on Account Equity, Risk %, Directional SL Validation, and broker-aware OrderCalcProfit()
   double CalculateLotSize(CSymbolInfoHelper &symbol_info, ENUM_ORDER_TYPE order_type, double entry_price, double stop_loss_price)
   {
      // 1. Basic price validation
      if(entry_price <= 0.0)
      {
         m_last_rejection_code   = REJECT_INVALID_ENTRY;
         m_last_rejection_reason = "INVALID_ENTRY";
         return 0.0;
      }
      if(stop_loss_price <= 0.0)
      {
         m_last_rejection_code   = REJECT_INVALID_SL;
         m_last_rejection_reason = "INVALID_SL";
         return 0.0;
      }

      // 2. Strict Entry / SL Direction Validation (No MathAbs direction assumption)
      if(order_type == ORDER_TYPE_BUY)
      {
         // BUY: Structural SL must be strictly below executable entry price
         if(stop_loss_price >= entry_price)
         {
            PrintFormat("[RiskManager] Invalid BUY SL direction (SL: %f >= Entry: %f). Decision: NO_TRADE.",
                        stop_loss_price, entry_price);
            m_last_rejection_code   = REJECT_INVALID_SL;
            m_last_rejection_reason = "INVALID_SL";
            return 0.0;
         }
      }
      else if(order_type == ORDER_TYPE_SELL)
      {
         // SELL: Structural SL must be strictly above executable entry price
         if(stop_loss_price <= entry_price)
         {
            PrintFormat("[RiskManager] Invalid SELL SL direction (SL: %f <= Entry: %f). Decision: NO_TRADE.",
                        stop_loss_price, entry_price);
            m_last_rejection_code   = REJECT_INVALID_SL;
            m_last_rejection_reason = "INVALID_SL";
            return 0.0;
         }
      }
      else
      {
         // Non-executable order type
         m_last_rejection_code   = REJECT_INVALID_ENTRY;
         m_last_rejection_reason = "INVALID_ENTRY";
         return 0.0;
      }

      // 3. Risk budget based on Account Equity
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= 0.0)
      {
         m_last_rejection_code   = REJECT_ZERO_OR_INVALID_RISK;
         m_last_rejection_reason = "ZERO_OR_INVALID_RISK";
         return 0.0;
      }

      double allowed_risk_money = equity * (m_risk_percent_per_trade / 100.0);
      if(allowed_risk_money <= 0.0)
      {
         m_last_rejection_code   = REJECT_ZERO_OR_INVALID_RISK;
         m_last_rejection_reason = "ZERO_OR_INVALID_RISK";
         return 0.0;
      }

      // 4. Broker-aware monetary loss calculation for 1.0 lot via OrderCalcProfit()
      string symbol = symbol_info.GetSymbol();
      double profit_at_sl = 0.0;
      ResetLastError();
      if(!OrderCalcProfit(order_type, symbol, 1.0, entry_price, stop_loss_price, profit_at_sl))
      {
         PrintFormat("[RiskManager] OrderCalcProfit failed for %s (Error: %d). Decision: NO_TRADE.",
                     symbol, GetLastError());
         m_last_rejection_code   = REJECT_ORDER_CALC_PROFIT_FAIL;
         m_last_rejection_reason = "ORDER_CALC_PROFIT_FAIL";
         return 0.0;
      }

      // When hitting SL, profit_at_sl must be negative (a monetary loss)
      if(profit_at_sl >= 0.0)
      {
         PrintFormat("[RiskManager] Calculated profit at SL is non-negative (%f). Decision: NO_TRADE.", profit_at_sl);
         m_last_rejection_code   = REJECT_ORDER_CALC_PROFIT_FAIL;
         m_last_rejection_reason = "ORDER_CALC_PROFIT_FAIL";
         return 0.0;
      }

      double monetary_loss_per_lot = -profit_at_sl;
      if(monetary_loss_per_lot <= 0.0)
      {
         m_last_rejection_code   = REJECT_ORDER_CALC_PROFIT_FAIL;
         m_last_rejection_reason = "ORDER_CALC_PROFIT_FAIL";
         return 0.0;
      }

      // 5. Raw lot calculation and broker volume normalization
      double raw_lot = allowed_risk_money / monetary_loss_per_lot;

      // Diagnostic logging when raw calculated lot is strictly below broker minimum volume
      if(raw_lot < symbol_info.GetVolMin())
      {
         double stop_dist_points = (symbol_info.GetPoint() > 0.0) ? (MathAbs(entry_price - stop_loss_price) / symbol_info.GetPoint()) : 0.0;
         PrintFormat("[RiskManager][DIAGNOSTIC] NO_TRADE | Reason: BELOW_MINIMUM_VOLUME | Equity: %.2f | RiskPct: %.1f%% | RiskBudget: %.2f | Entry: %.2f | SL: %.2f | StopDistPoints: %.1f | RawLot: %.4f | MinLot: %.2f",
                     equity, m_risk_percent_per_trade, allowed_risk_money, entry_price, stop_loss_price, stop_dist_points, raw_lot, symbol_info.GetVolMin());
         m_last_rejection_code   = REJECT_BELOW_MINIMUM_VOLUME;
         m_last_rejection_reason = "BELOW_MINIMUM_VOLUME";
         return 0.0;
      }

      double final_lot = symbol_info.NormalizeVolume(raw_lot);
      if(final_lot <= 0.0)
      {
         m_last_rejection_code   = REJECT_OTHER;
         m_last_rejection_reason = "OTHER";
         return 0.0;
      }

      m_last_rejection_code   = REJECT_NONE;
      m_last_rejection_reason = "";
      return final_lot;
   }

   // Overload accepting ENUM_SIGNAL_ACTION for seamless integration with TradeSignal
   double CalculateLotSize(CSymbolInfoHelper &symbol_info, ENUM_SIGNAL_ACTION action, double entry_price, double stop_loss_price)
   {
      if(action == SIGNAL_BUY)
         return CalculateLotSize(symbol_info, ORDER_TYPE_BUY, entry_price, stop_loss_price);
      else if(action == SIGNAL_SELL)
         return CalculateLotSize(symbol_info, ORDER_TYPE_SELL, entry_price, stop_loss_price);

      m_last_rejection_code   = REJECT_INVALID_ENTRY;
      m_last_rejection_reason = "INVALID_ENTRY";
      return 0.0;
   }

   // Read-only diagnostic getters for rejection code and reason
   ENUM_RISK_REJECTION_REASON GetLastRejectionCode()   const { return m_last_rejection_code; }
   string                     GetLastRejectionReason() const { return m_last_rejection_reason; }
};
