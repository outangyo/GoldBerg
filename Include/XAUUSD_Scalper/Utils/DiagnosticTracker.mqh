//+------------------------------------------------------------------+
//|                                            DiagnosticTracker.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//|               Signal Funnel Diagnostic & Dropout Audit Module   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CDiagnosticTracker: Tracks signal funnel and dropout counts      |
//+------------------------------------------------------------------+
class CDiagnosticTracker
{
private:
   // Funnel Stage Counters
   int m_m15_sweep;
   int m_m15_reclaim;
   int m_m5_extreme_identified;
   int m_m5_break_confirmed;

   int m_risk_validation_attempts;
   int m_risk_rejected;
   int m_order_send_attempts;
   int m_orders_executed;

   // Granular Dropouts & Sub-Counters
   int m_m15_structure_break;
   int m_m15_sweep_expired;
   int m_m5_extreme_failed;
   int m_extreme_invalidated;
   int m_reclaim_expired;
   int m_orders_failed;

   // Risk Rejection Breakdown
   int m_reject_below_min_volume;
   int m_reject_invalid_entry;
   int m_reject_invalid_sl;
   int m_reject_order_calc_profit_fail;
   int m_reject_zero_or_invalid_risk;
   int m_reject_max_open_trades;
   int m_reject_other;

public:
   CDiagnosticTracker()
   {
      Reset();
   }
   ~CDiagnosticTracker() {}

   void Reset()
   {
      m_m15_sweep                     = 0;
      m_m15_reclaim                   = 0;
      m_m5_extreme_identified         = 0;
      m_m5_break_confirmed            = 0;

      m_risk_validation_attempts      = 0;
      m_risk_rejected                 = 0;
      m_order_send_attempts           = 0;
      m_orders_executed               = 0;

      m_m15_structure_break           = 0;
      m_m15_sweep_expired             = 0;
      m_m5_extreme_failed             = 0;
      m_extreme_invalidated           = 0;
      m_reclaim_expired               = 0;
      m_orders_failed                 = 0;

      m_reject_below_min_volume       = 0;
      m_reject_invalid_entry          = 0;
      m_reject_invalid_sl             = 0;
      m_reject_order_calc_profit_fail = 0;
      m_reject_zero_or_invalid_risk   = 0;
      m_reject_max_open_trades        = 0;
      m_reject_other                  = 0;
   }

   // Increment methods
   void IncM15Sweep()                 { m_m15_sweep++; }
   void IncM15StructureBreak()        { m_m15_structure_break++; }
   void IncM15SweepExpired()          { m_m15_sweep_expired++; }
   void IncM15Reclaim()               { m_m15_reclaim++; }
   void IncM5ExtremeIdentified()      { m_m5_extreme_identified++; }
   void IncM5ExtremeFailed()          { m_m5_extreme_failed++; }
   void IncExtremeInvalidated()       { m_extreme_invalidated++; }
   void IncReclaimExpired()           { m_reclaim_expired++; }
   void IncM5BreakConfirmed()          { m_m5_break_confirmed++; }

   void IncRiskAttempt()              { m_risk_validation_attempts++; }
   void IncRiskRejected(ENUM_RISK_REJECTION_REASON reason)
   {
      m_risk_rejected++;
      switch(reason)
      {
         case REJECT_BELOW_MINIMUM_VOLUME:    m_reject_below_min_volume++; break;
         case REJECT_INVALID_ENTRY:           m_reject_invalid_entry++; break;
         case REJECT_INVALID_SL:              m_reject_invalid_sl++; break;
         case REJECT_ORDER_CALC_PROFIT_FAIL:  m_reject_order_calc_profit_fail++; break;
         case REJECT_ZERO_OR_INVALID_RISK:    m_reject_zero_or_invalid_risk++; break;
         case REJECT_MAX_OPEN_TRADES:         m_reject_max_open_trades++; break;
         case REJECT_OTHER:
         default:                             m_reject_other++; break;
      }
   }

   void IncOrderSendAttempt()         { m_order_send_attempts++; }
   void IncOrderExecuted()            { m_orders_executed++; }
   void IncOrderFailed()              { m_orders_failed++; }

   // Getters for Dashboard & Diagnostics
   int GetM15Sweep()                  const { return m_m15_sweep; }
   int GetM15Reclaim()                const { return m_m15_reclaim; }
   int GetM5ExtremeIdentified()        const { return m_m5_extreme_identified; }
   int GetM5BreakConfirmed()           const { return m_m5_break_confirmed; }
   int GetRiskValidationAttempts()    const { return m_risk_validation_attempts; }
   int GetRiskRejected()              const { return m_risk_rejected; }
   int GetOrderSendAttempts()         const { return m_order_send_attempts; }
   int GetOrdersExecuted()            const { return m_orders_executed; }

   int GetRejectBelowMinVolume()      const { return m_reject_below_min_volume; }
   int GetRejectInvalidEntry()        const { return m_reject_invalid_entry; }
   int GetRejectInvalidSL()           const { return m_reject_invalid_sl; }
   int GetRejectOrderCalcProfitFail() const { return m_reject_order_calc_profit_fail; }
   int GetRejectZeroOrInvalidRisk()   const { return m_reject_zero_or_invalid_risk; }
   int GetRejectMaxOpenTrades()       const { return m_reject_max_open_trades; }
   int GetRejectOther()               const { return m_reject_other; }

   // Print complete diagnostic report to Journal
   void PrintReport() const
   {
      Print("==================================================");
      Print("=== SIGNAL FUNNEL ===");
      Print("");
      PrintFormat("M15_SWEEP                 : %d", m_m15_sweep);
      PrintFormat("  - Structure Breaks      : %d", m_m15_structure_break);
      PrintFormat("  - Sweeps Expired        : %d", m_m15_sweep_expired);
      PrintFormat("M15_RECLAIM               : %d", m_m15_reclaim);
      PrintFormat("M5_EXTREME_IDENTIFIED     : %d", m_m5_extreme_identified);
      PrintFormat("  - Extreme Invalidated   : %d", m_extreme_invalidated);
      PrintFormat("  - Reclaims Expired      : %d", m_reclaim_expired);
      PrintFormat("M5_BREAK_CONFIRMED        : %d", m_m5_break_confirmed);
      Print("");
      PrintFormat("RISK_VALIDATION_ATTEMPTS  : %d", m_risk_validation_attempts);
      PrintFormat("RISK_REJECTED             : %d", m_risk_rejected);
      PrintFormat("  - BELOW_MINIMUM_VOLUME  : %d", m_reject_below_min_volume);
      PrintFormat("  - INVALID_ENTRY         : %d", m_reject_invalid_entry);
      PrintFormat("  - INVALID_SL            : %d", m_reject_invalid_sl);
      PrintFormat("  - ORDER_CALC_PROFIT_FAIL: %d", m_reject_order_calc_profit_fail);
      PrintFormat("  - ZERO_OR_INVALID_RISK  : %d", m_reject_zero_or_invalid_risk);
      PrintFormat("  - MAX_OPEN_TRADES       : %d", m_reject_max_open_trades);
      PrintFormat("  - OTHER                 : %d", m_reject_other);
      Print("");
      PrintFormat("ORDER_SEND_ATTEMPTS       : %d", m_order_send_attempts);
      PrintFormat("ORDERS_EXECUTED            : %d", m_orders_executed);
      PrintFormat("  - Execution Failed      : %d", m_orders_failed);
      Print("==================================================");
   }
};
