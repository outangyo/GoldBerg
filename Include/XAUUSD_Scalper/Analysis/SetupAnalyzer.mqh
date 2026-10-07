//+------------------------------------------------------------------+
//|                                                SetupAnalyzer.mqh |
//|                                  Copyright 2026, XAUUSD Scalper  |
//|                         V1 Locked Strategy: M15 Sweep -> M5 Conf |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

#include "../Core/Defines.mqh"
#include "StructureTracker.mqh"

//--- M15 Sweep Lifecycle State Machine
enum ENUM_SWEEP_LIFECYCLE_STATE
{
   SWEEP_STATE_MONITORING        = 0, // Monitoring active M15 swings
   SWEEP_STATE_LEVEL_BREACHED    = 1, // Tick breached level; tracking extreme, waiting for M15 bar to close
   SWEEP_STATE_RECLAIM_CANDIDATE = 2, // M15 closed reclaimed; Extreme frozen, awaiting M5 confirmation
   SWEEP_STATE_STRUCTURE_BREAK   = 3, // M15 closed beyond reference; invalid -> NO TRADE
   SWEEP_STATE_EXPIRED           = 4  // Setup expired/completed -> reset to MONITORING
};

//--- Sweep Direction
enum ENUM_SWEEP_DIRECTION
{
   SWEEP_DIR_NONE  = 0,
   SWEEP_DIR_LONG  = 1, // Low sweep candidate -> Long trade
   SWEEP_DIR_SHORT = 2  // High sweep candidate -> Short trade
};

//+------------------------------------------------------------------+
//| CSetupAnalyzer: Stateful M15 Sweep Lifecycle & M5 Confirmation   |
//+------------------------------------------------------------------+
class CSetupAnalyzer
{
private:
   ENUM_TIMEFRAMES              m_context_tf;            // M15
   ENUM_TIMEFRAMES              m_confirm_tf;            // M5
   CStructureTracker            m_structure_tracker;     // M15 confirmed swings
   ENUM_SWEEP_LIFECYCLE_STATE   m_state;                 // Current lifecycle state
   ENUM_SWEEP_DIRECTION         m_direction;             // Active sweep direction
   double                       m_ref_price;             // Retained reference swing price
   datetime                     m_ref_swing_time;        // Bar time of reference swing
   datetime                     m_breach_m15_bar_time;   // Open time of M15 bar during which breach occurred
   double                       m_breach_extreme_price;  // Tick-tracked extreme price occurred after breach
   datetime                     m_breach_extreme_time;   // Exact timestamp when breach extreme was recorded
   double                       m_extreme_price;         // Frozen Extreme_Price (Structural SL)
   datetime                     m_extreme_time;          // Frozen actual timestamp of extreme
   datetime                     m_reclaim_confirmed_time;// Timestamp when M15 reclaim was confirmed
   double                       m_m5_extreme_bar_high;   // M5 Extreme Bar High
   double                       m_m5_extreme_bar_low;    // M5 Extreme Bar Low
   datetime                     m_m5_extreme_bar_time;   // M5 Extreme Bar open time
   datetime                     m_last_evaluated_m5_bar; // Last closed M5 bar time evaluated

   // Reset state machine back to MONITORING (Does NOT resurrect invalidated swings)
   void ResetToMonitoring()
   {
      m_state                  = SWEEP_STATE_MONITORING;
      m_direction              = SWEEP_DIR_NONE;
      m_ref_price              = 0.0;
      m_ref_swing_time         = 0;
      m_breach_m15_bar_time    = 0;
      m_breach_extreme_price   = 0.0;
      m_breach_extreme_time    = 0;
      m_extreme_price          = 0.0;
      m_extreme_time           = 0;
      m_reclaim_confirmed_time = 0;
      m_m5_extreme_bar_high    = 0.0;
      m_m5_extreme_bar_low     = 0.0;
      m_m5_extreme_bar_time    = 0;
      m_last_evaluated_m5_bar  = 0;
   }

   // Identify M5 Extreme Bar using actual frozen Extreme_Time (Rule 4)
   bool IdentifyM5ExtremeBar(string symbol)
   {
      if(m_extreme_time == 0) return false;

      // Deterministic mapping: find the M5 bar containing the actual extreme timestamp
      int m5_shift = iBarShift(symbol, m_confirm_tf, m_extreme_time, false);
      if(m5_shift < 0)
      {
         PrintFormat("[SetupAnalyzer][ERROR] Could not find M5 bar shift for Extreme_Time: %s",
                     TimeToString(m_extreme_time));
         return false;
      }

      m_m5_extreme_bar_high = iHigh(symbol, m_confirm_tf, m5_shift);
      m_m5_extreme_bar_low  = iLow(symbol, m_confirm_tf, m5_shift);
      m_m5_extreme_bar_time = iTime(symbol, m_confirm_tf, m5_shift);

      PrintFormat("[SetupAnalyzer] M5 Extreme Bar identified | Shift: %d | Time: %s | High: %f | Low: %f | Frozen SL: %f",
                  m5_shift, TimeToString(m_m5_extreme_bar_time), m_m5_extreme_bar_high, m_m5_extreme_bar_low, m_extreme_price);
      return true;
   }

public:
   CSetupAnalyzer() :
      m_context_tf(PERIOD_M15),
      m_confirm_tf(PERIOD_M5),
      m_state(SWEEP_STATE_MONITORING),
      m_direction(SWEEP_DIR_NONE),
      m_ref_price(0.0),
      m_ref_swing_time(0),
      m_breach_m15_bar_time(0),
      m_breach_extreme_price(0.0),
      m_breach_extreme_time(0),
      m_extreme_price(0.0),
      m_extreme_time(0),
      m_reclaim_confirmed_time(0),
      m_m5_extreme_bar_high(0.0),
      m_m5_extreme_bar_low(0.0),
      m_m5_extreme_bar_time(0),
      m_last_evaluated_m5_bar(0)
   {}
   ~CSetupAnalyzer() {}

   bool Init(ENUM_TIMEFRAMES context_tf = PERIOD_M15, ENUM_TIMEFRAMES confirm_tf = PERIOD_M5)
   {
      m_context_tf = context_tf;
      m_confirm_tf = confirm_tf;
      m_structure_tracker.Init(m_context_tf, 2); // Standard 5-bar fractal on M15
      ResetToMonitoring();
      return true;
   }

   // Main V1 Strategy Evaluation: M15 Sweep Lifecycle -> M5 Confirmation
   bool EvaluateSetup(string symbol, TradeSignal &out_signal)
   {
      out_signal.action            = SIGNAL_NONE;
      out_signal.entry_price       = 0.0;
      out_signal.stop_loss         = 0.0;
      out_signal.take_profit       = 0.0;
      out_signal.risk_reward_ratio = 1.5;
      out_signal.reason            = "NO_SIGNAL";

      // 1. Update M15 confirmed Swings (respecting invalidation history)
      m_structure_tracker.UpdateSwings(symbol);
      SwingPoint active_high = m_structure_tracker.GetActiveSwingHigh();
      SwingPoint active_low  = m_structure_tracker.GetActiveSwingLow();

      // =====================================================================
      // STATE 1: MONITORING
      // =====================================================================
      if(m_state == SWEEP_STATE_MONITORING)
      {
         double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

         // Long candidate: Current Bid breaches active M15 Swing Low (Rule 5: Bid <= SwingLow)
         if(active_low.is_active && active_low.price > 0.0 && current_bid <= active_low.price)
         {
            m_direction            = SWEEP_DIR_LONG;
            m_ref_price            = active_low.price; // Retain reference
            m_ref_swing_time       = active_low.time;
            m_breach_m15_bar_time  = iTime(symbol, m_context_tf, 0);
            m_breach_extreme_price = current_bid;      // Initial breach extreme
            m_breach_extreme_time  = TimeCurrent();    // Actual extreme timestamp (Rule 3)
            m_state                = SWEEP_STATE_LEVEL_BREACHED;

            // Invalidate swing low so it cannot be resurrected (Rule 1)
            m_structure_tracker.InvalidateSwingLow(active_low.time);

            PrintFormat("[SetupAnalyzer] LEVEL_BREACHED (Long) | Ref Low: %f (Bar: %s) | Tick Bid: %f | ExtremeTime: %s",
                        m_ref_price, TimeToString(m_ref_swing_time), current_bid, TimeToString(m_breach_extreme_time));
            return false;
         }

         // Short candidate: Current Ask breaches active M15 Swing High (Rule 5: Ask >= SwingHigh)
         if(active_high.is_active && active_high.price > 0.0 && current_ask >= active_high.price)
         {
            m_direction            = SWEEP_DIR_SHORT;
            m_ref_price            = active_high.price; // Retain reference
            m_ref_swing_time       = active_high.time;
            m_breach_m15_bar_time  = iTime(symbol, m_context_tf, 0);
            m_breach_extreme_price = current_ask;       // Initial breach extreme
            m_breach_extreme_time  = TimeCurrent();     // Actual extreme timestamp (Rule 3)
            m_state                = SWEEP_STATE_LEVEL_BREACHED;

            // Invalidate swing high so it cannot be resurrected (Rule 1)
            m_structure_tracker.InvalidateSwingHigh(active_high.time);

            PrintFormat("[SetupAnalyzer] LEVEL_BREACHED (Short) | Ref High: %f (Bar: %s) | Tick Ask: %f | ExtremeTime: %s",
                        m_ref_price, TimeToString(m_ref_swing_time), current_ask, TimeToString(m_breach_extreme_time));
            return false;
         }

         return false; // Still monitoring
      }

      // =====================================================================
      // STATE 2: LEVEL_BREACHED (Tracking extreme, waiting for M15 bar to close)
      // =====================================================================
      if(m_state == SWEEP_STATE_LEVEL_BREACHED)
      {
         // Rule 6: Same-direction swing expiration
         // If a newer confirmed same-direction M15 swing forms, expire current event
         SwingPoint new_swing;
         if(m_direction == SWEEP_DIR_LONG && m_structure_tracker.CheckNewConfirmedSwingLow(symbol, m_ref_swing_time, new_swing))
         {
            PrintFormat("[SetupAnalyzer] Same-direction new Swing Low confirmed at %s (%f). Expiring active sweep.",
                        TimeToString(new_swing.time), new_swing.price);
            m_structure_tracker.AdoptNewSwingLow(new_swing);
            ResetToMonitoring();
            return false;
         }
         else if(m_direction == SWEEP_DIR_SHORT && m_structure_tracker.CheckNewConfirmedSwingHigh(symbol, m_ref_swing_time, new_swing))
         {
            PrintFormat("[SetupAnalyzer] Same-direction new Swing High confirmed at %s (%f). Expiring active sweep.",
                        TimeToString(new_swing.time), new_swing.price);
            m_structure_tracker.AdoptNewSwingHigh(new_swing);
            ResetToMonitoring();
            return false;
         }

         // Rule 2 & 3: Continuously track extreme price and actual extreme timestamp AFTER breach
         double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

         if(m_direction == SWEEP_DIR_LONG)
         {
            if(current_bid < m_breach_extreme_price)
            {
               m_breach_extreme_price = current_bid;
               m_breach_extreme_time  = TimeCurrent(); // Actual timestamp (Rule 3)
            }
         }
         else if(m_direction == SWEEP_DIR_SHORT)
         {
            if(current_ask > m_breach_extreme_price)
            {
               m_breach_extreme_price = current_ask;
               m_breach_extreme_time  = TimeCurrent(); // Actual timestamp (Rule 3)
            }
         }

         datetime current_m15_time = iTime(symbol, m_context_tf, 0);
         // If breaching M15 bar hasn't closed yet, wait (Rule 4)
         if(current_m15_time <= m_breach_m15_bar_time)
         {
            return false;
         }

         // Breaching M15 bar has closed (shift = 1)
         double m15_close = iClose(symbol, m_context_tf, 1);

         // Rule 5: Swing Low evaluation
         if(m_direction == SWEEP_DIR_LONG)
         {
            if(m15_close < m_ref_price)
            {
               // STRUCTURE_BREAK -> NO TRADE (Rule 5)
               PrintFormat("[SetupAnalyzer] STRUCTURE_BREAK (Long) | Close: %f < Ref: %f. Resetting.",
                           m15_close, m_ref_price);
               ResetToMonitoring();
               return false;
            }
            else // m15_close >= m_ref_price
            {
               // RECLAIM_CANDIDATE: Freeze tick-tracked Extreme_Price and Extreme_Time (Rule 2 & 3)
               m_state                  = SWEEP_STATE_RECLAIM_CANDIDATE;
               m_extreme_price          = m_breach_extreme_price; // Rule 2: strictly tick-tracked extreme
               m_extreme_time           = m_breach_extreme_time;  // Rule 3: actual extreme timestamp
               m_reclaim_confirmed_time = current_m15_time;       // Rule 7: reclaim confirmed at new M15 bar open

               PrintFormat("[SetupAnalyzer] RECLAIM_CANDIDATE (Long) | Close: %f >= Ref: %f | Frozen Extreme_Price: %f | Extreme_Time: %s",
                           m15_close, m_ref_price, m_extreme_price, TimeToString(m_extreme_time));

               // Identify M5 Extreme Bar (Rule 4)
               if(!IdentifyM5ExtremeBar(symbol))
               {
                  ResetToMonitoring();
                  return false;
               }
            }
         }
         // Rule 6: Swing High evaluation
         else if(m_direction == SWEEP_DIR_SHORT)
         {
            if(m15_close > m_ref_price)
            {
               // STRUCTURE_BREAK -> NO TRADE (Rule 6)
               PrintFormat("[SetupAnalyzer] STRUCTURE_BREAK (Short) | Close: %f > Ref: %f. Resetting.",
                           m15_close, m_ref_price);
               ResetToMonitoring();
               return false;
            }
            else // m15_close <= m_ref_price
            {
               // RECLAIM_CANDIDATE: Freeze tick-tracked Extreme_Price and Extreme_Time (Rule 2 & 3)
               m_state                  = SWEEP_STATE_RECLAIM_CANDIDATE;
               m_extreme_price          = m_breach_extreme_price; // Rule 2: strictly tick-tracked extreme
               m_extreme_time           = m_breach_extreme_time;  // Rule 3: actual extreme timestamp
               m_reclaim_confirmed_time = current_m15_time;       // Rule 7: reclaim confirmed at new M15 bar open

               PrintFormat("[SetupAnalyzer] RECLAIM_CANDIDATE (Short) | Close: %f <= Ref: %f | Frozen Extreme_Price: %f | Extreme_Time: %s",
                           m15_close, m_ref_price, m_extreme_price, TimeToString(m_extreme_time));

               // Identify M5 Extreme Bar (Rule 4)
               if(!IdentifyM5ExtremeBar(symbol))
               {
                  ResetToMonitoring();
                  return false;
               }
            }
         }
      }

      // =====================================================================
      // STATE 3: RECLAIM_CANDIDATE -> M5 Confirmation Phase
      // =====================================================================
      if(m_state == SWEEP_STATE_RECLAIM_CANDIDATE)
      {
         // Rule 6: Same-direction swing expiration check
         SwingPoint new_swing;
         if(m_direction == SWEEP_DIR_LONG && m_structure_tracker.CheckNewConfirmedSwingLow(symbol, m_ref_swing_time, new_swing))
         {
            PrintFormat("[SetupAnalyzer] Same-direction new Swing Low confirmed at %s (%f). Expiring reclaim candidate.",
                        TimeToString(new_swing.time), new_swing.price);
            m_structure_tracker.AdoptNewSwingLow(new_swing);
            ResetToMonitoring();
            return false;
         }
         else if(m_direction == SWEEP_DIR_SHORT && m_structure_tracker.CheckNewConfirmedSwingHigh(symbol, m_ref_swing_time, new_swing))
         {
            PrintFormat("[SetupAnalyzer] Same-direction new Swing High confirmed at %s (%f). Expiring reclaim candidate.",
                        TimeToString(new_swing.time), new_swing.price);
            m_structure_tracker.AdoptNewSwingHigh(new_swing);
            ResetToMonitoring();
            return false;
         }

         // Realtime extreme invalidation guard
         double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

         if(m_direction == SWEEP_DIR_LONG && current_bid < m_extreme_price)
         {
            PrintFormat("[SetupAnalyzer] Long setup invalidated: Current Bid (%f) broke below frozen Extreme_Price (%f).",
                        current_bid, m_extreme_price);
            ResetToMonitoring();
            return false;
         }
         else if(m_direction == SWEEP_DIR_SHORT && current_ask > m_extreme_price)
         {
            PrintFormat("[SetupAnalyzer] Short setup invalidated: Current Ask (%f) broke above frozen Extreme_Price (%f).",
                        current_ask, m_extreme_price);
            ResetToMonitoring();
            return false;
         }

         // Rule 7: Causal order M5 confirmation timing
         // Only evaluate closed M5 bars (shift = 1) that closed AT OR AFTER M15 reclaim confirmation
         datetime m5_closed_time = iTime(symbol, m_confirm_tf, 1);
         if(m5_closed_time == 0) return false;

         // If the closed M5 bar opened prior to M15 reclaim confirmation, it cannot confirm
         if(m5_closed_time < m_reclaim_confirmed_time)
         {
            return false;
         }

         // Ensure each eligible closed M5 bar is evaluated only once
         if(m5_closed_time <= m_last_evaluated_m5_bar)
         {
            return false;
         }
         m_last_evaluated_m5_bar = m5_closed_time;

         double m5_close = iClose(symbol, m_confirm_tf, 1);
         double m5_low   = iLow(symbol, m_confirm_tf, 1);
         double m5_high  = iHigh(symbol, m_confirm_tf, 1);

         // Invalidation check on closed M5 bar
         if(m_direction == SWEEP_DIR_LONG && m5_low < m_extreme_price)
         {
            PrintFormat("[SetupAnalyzer] Long setup invalidated: Closed M5 low (%f) broke below Extreme_Price (%f).",
                        m5_low, m_extreme_price);
            ResetToMonitoring();
            return false;
         }
         else if(m_direction == SWEEP_DIR_SHORT && m5_high > m_extreme_price)
         {
            PrintFormat("[SetupAnalyzer] Short setup invalidated: Closed M5 high (%f) broke above Extreme_Price (%f).",
                        m5_high, m_extreme_price);
            ResetToMonitoring();
            return false;
         }

         // Confirmation check (Rule 9)
         // Long: M5 Close breaks Extreme Bar High
         if(m_direction == SWEEP_DIR_LONG)
         {
            if(m5_close > m_m5_extreme_bar_high)
            {
               double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
               if(ask <= m_extreme_price)
               {
                  ResetToMonitoring();
                  return false;
               }

               double sl_dist = ask - m_extreme_price;
               if(sl_dist <= 0.0)
               {
                  ResetToMonitoring();
                  return false;
               }

               out_signal.action            = SIGNAL_BUY;
               out_signal.entry_price       = ask;
               out_signal.stop_loss         = m_extreme_price; // Rule 10: strictly Extreme_Price
               out_signal.take_profit       = ask + (sl_dist * 1.5); // Rule 11: RR_Target = 1.5
               out_signal.risk_reward_ratio = 1.5;
               out_signal.reason            = "M15_SWEEP_M5_CONFIRMED_BUY";

               PrintFormat("[SetupAnalyzer][SIGNAL BUY] M5 Close %f > Extreme Bar High %f | Entry(Ask): %f | SL: %f | TP: %f | RR: 1.5",
                           m5_close, m_m5_extreme_bar_high, ask, out_signal.stop_loss, out_signal.take_profit);

               ResetToMonitoring();
               return true;
            }
         }
         // Short: M5 Close breaks Extreme Bar Low
         else if(m_direction == SWEEP_DIR_SHORT)
         {
            if(m5_close < m_m5_extreme_bar_low)
            {
               double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
               if(bid >= m_extreme_price)
               {
                  ResetToMonitoring();
                  return false;
               }

               double sl_dist = m_extreme_price - bid;
               if(sl_dist <= 0.0)
               {
                  ResetToMonitoring();
                  return false;
               }

               out_signal.action            = SIGNAL_SELL;
               out_signal.entry_price       = bid;
               out_signal.stop_loss         = m_extreme_price; // Rule 10: strictly Extreme_Price
               out_signal.take_profit       = bid - (sl_dist * 1.5); // Rule 11: RR_Target = 1.5
               out_signal.risk_reward_ratio = 1.5;
               out_signal.reason            = "M15_SWEEP_M5_CONFIRMED_SELL";

               PrintFormat("[SetupAnalyzer][SIGNAL SELL] M5 Close %f < Extreme Bar Low %f | Entry(Bid): %f | SL: %f | TP: %f | RR: 1.5",
                           m5_close, m_m5_extreme_bar_low, bid, out_signal.stop_loss, out_signal.take_profit);

               ResetToMonitoring();
               return true;
            }
         }
      }

      return false;
   }

   // Compatibility overload
   bool EvaluateSetup(string symbol, ENUM_MARKET_CONTEXT context, TradeSignal &out_signal)
   {
      return EvaluateSetup(symbol, out_signal);
   }

   // Status getters
   ENUM_SWEEP_LIFECYCLE_STATE GetCurrentState() const { return m_state; }
   ENUM_SWEEP_DIRECTION      GetDirection()    const { return m_direction; }
};
