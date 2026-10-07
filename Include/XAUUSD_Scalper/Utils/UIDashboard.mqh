//+------------------------------------------------------------------+
//|                                                 UIDashboard.mqh  |
//|                                  Copyright 2026, XAUUSD Scalper  |
//|                    Read-Only Observer Dashboard for Live & Test  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAUUSD Scalper"
#property link      ""
#property version   "1.00"

#include "../Core/Defines.mqh"
#include "../Analysis/SetupAnalyzer.mqh"

//+------------------------------------------------------------------+
//| SAFETY & ARCHITECTURAL BOUNDARY:                                 |
//| CUIDashboard is strictly an observability & audit tooling layer. |
//| It has NO authority over Strategy, Risk, or Execution.          |
//| It does NOT modify strategy state, signals, risk parameters,     |
//| lot sizing, SL/TP, or trade execution.                           |
//| It does NOT act as a trade gate or filter.                       |
//| Single Source of Truth = existing Strategy/Setup implementation. |
//+------------------------------------------------------------------+

class CUIDashboard
{
private:
   string   m_symbol;
   ulong    m_magic;
   int      m_base_x;
   int      m_base_y;
   int      m_corner;
   int      m_width;
   int      m_height;

   // Account / Performance tracking
   double   m_initial_balance;
   double   m_peak_equity;
   double   m_max_dd;
   double   m_max_dd_pct;

   // Throttled history stats
   int      m_total_trades;
   int      m_win_count;
   int      m_loss_count;
   double   m_win_rate;
   double   m_avg_win;
   double   m_avg_loss;
   double   m_today_closed_profit;

   // Performance throttling
   ulong    m_last_stats_ms;
   ulong    m_last_render_ms;
   bool     m_prev_has_pos;
   bool     m_prev_rendered_has_pos;

   // Colors
   color    m_clr_bg;
   color    m_clr_border;
   color    m_clr_header;
   color    m_clr_subtitle;
   color    m_clr_section;
   color    m_clr_label;
   color    m_clr_val_default;
   color    m_clr_val_pos;
   color    m_clr_val_neg;
   color    m_clr_val_warn;
   color    m_clr_val_muted;

   // Convert lifecycle state to string
   string StateToString(ENUM_SWEEP_LIFECYCLE_STATE state) const
   {
      switch(state)
      {
         case SWEEP_STATE_MONITORING:        return "MONITORING";
         case SWEEP_STATE_LEVEL_BREACHED:    return "LEVEL_BREACHED";
         case SWEEP_STATE_RECLAIM_CANDIDATE: return "RECLAIM_CANDIDATE";
         case SWEEP_STATE_STRUCTURE_BREAK:   return "STRUCTURE_BREAK";
         case SWEEP_STATE_EXPIRED:           return "EXPIRED";
         default:                            return "UNKNOWN";
      }
   }

   // Convert direction to string
   string DirectionToString(ENUM_SWEEP_DIRECTION dir) const
   {
      switch(dir)
      {
         case SWEEP_DIR_LONG:  return "LONG";
         case SWEEP_DIR_SHORT: return "SHORT";
         case SWEEP_DIR_NONE:
         default:              return "NONE";
      }
   }

   // Dynamic P/L color determination
   color GetPLColor(double val) const
   {
      if(val > 0.0001)  return m_clr_val_pos;
      if(val < -0.0001) return m_clr_val_neg;
      return m_clr_val_default;
   }

   // Chart Object Helpers
   void SetBox(string name, int x, int y, int w, int h, color bg_clr, color border_clr)
   {
      string obj_name = "GB_UI_" + name;
      if(ObjectFind(0, obj_name) < 0)
      {
         ObjectCreate(0, obj_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, obj_name, OBJPROP_CORNER, m_corner);
         ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(0, obj_name, OBJPROP_XSIZE, w);
         ObjectSetInteger(0, obj_name, OBJPROP_YSIZE, h);
         ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, bg_clr);
         ObjectSetInteger(0, obj_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, border_clr);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, obj_name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
      }
   }

   void SetLabel(string name, string text, color clr, int x, int y, int font_size = 8, string font = "Consolas")
   {
      string obj_name = "GB_UI_" + name;
      if(ObjectFind(0, obj_name) < 0)
      {
         ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, obj_name, OBJPROP_CORNER, m_corner);
         ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, obj_name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
      }
      ObjectSetString(0, obj_name, OBJPROP_FONT, font);
      ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
   }

   // Read active position information (Read-only MT5 query)
   void QueryCurrentPosition(bool &has_pos, string &pos_dir, double &pos_lot, double &pos_entry, double &pos_sl, double &pos_tp, double &pos_rr, double &pos_profit)
   {
      has_pos    = false;
      pos_dir    = "NONE";
      pos_lot    = 0.0;
      pos_entry  = 0.0;
      pos_sl     = 0.0;
      pos_tp     = 0.0;
      pos_rr     = 0.0;
      pos_profit = 0.0;

      int total_positions = PositionsTotal();
      for(int i = total_positions - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;

         if(PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;

         has_pos    = true;
         long type  = PositionGetInteger(POSITION_TYPE);
         pos_dir    = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         pos_lot    = PositionGetDouble(POSITION_VOLUME);
         pos_entry  = PositionGetDouble(POSITION_PRICE_OPEN);
         pos_sl     = PositionGetDouble(POSITION_SL);
         pos_tp     = PositionGetDouble(POSITION_TP);
         pos_profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

         if(type == POSITION_TYPE_BUY)
         {
            if(pos_sl > 0.0 && pos_entry > pos_sl)
            {
               pos_rr = (pos_tp - pos_entry) / (pos_entry - pos_sl);
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            if(pos_sl > 0.0 && pos_sl > pos_entry)
            {
               pos_rr = (pos_entry - pos_tp) / (pos_sl - pos_entry);
            }
         }
         break; // V1 Baseline enforces Max 1 position
      }
   }

   // Throttled history deal scanner for trading statistics
   void UpdateHistoryStats()
   {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      datetime start_of_today = StructToTime(dt);

      if(!HistorySelect(0, now)) return;

      int total_deals = HistoryDealsTotal();
      m_total_trades  = 0;
      m_win_count     = 0;
      m_loss_count    = 0;
      double total_win  = 0.0;
      double total_loss = 0.0;
      m_today_closed_profit = 0.0;

      for(int i = 0; i < total_deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;

         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)m_magic) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_symbol) continue;

         long entry_type = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(entry_type != DEAL_ENTRY_OUT && entry_type != DEAL_ENTRY_INOUT) continue;

         long deal_type = HistoryDealGetInteger(ticket, DEAL_TYPE);
         if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL) continue;

         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                       + HistoryDealGetDouble(ticket, DEAL_SWAP)
                       + HistoryDealGetDouble(ticket, DEAL_COMMISSION);

         m_total_trades++;
         if(profit > 0.0)
         {
            m_win_count++;
            total_win += profit;
         }
         else if(profit < 0.0)
         {
            m_loss_count++;
            total_loss += profit;
         }

         datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         if(deal_time >= start_of_today)
         {
            m_today_closed_profit += profit;
         }
      }

      m_win_rate = (m_total_trades > 0) ? ((double)m_win_count / (double)m_total_trades * 100.0) : 0.0;
      m_avg_win  = (m_win_count > 0)    ? (total_win / (double)m_win_count) : 0.0;
      m_avg_loss = (m_loss_count > 0)   ? (total_loss / (double)m_loss_count) : 0.0;
   }

public:
   CUIDashboard() :
      m_symbol(""),
      m_magic(0),
      m_base_x(15),
      m_base_y(25),
      m_corner(CORNER_LEFT_UPPER),
      m_width(330),
      m_height(490),
      m_initial_balance(0.0),
      m_peak_equity(0.0),
      m_max_dd(0.0),
      m_max_dd_pct(0.0),
      m_total_trades(0),
      m_win_count(0),
      m_loss_count(0),
      m_win_rate(0.0),
      m_avg_win(0.0),
      m_avg_loss(0.0),
      m_today_closed_profit(0.0),
      m_last_stats_ms(0),
      m_last_render_ms(0),
      m_prev_has_pos(false),
      m_prev_rendered_has_pos(false),
      m_clr_bg(C'16,20,28'),
      m_clr_border(C'42,50,66'),
      m_clr_header(C'235,190,60'),
      m_clr_subtitle(C'120,135,155'),
      m_clr_section(C'80,130,190'),
      m_clr_label(C'160,175,195'),
      m_clr_val_default(C'240,245,255'),
      m_clr_val_pos(C'0,225,120'),
      m_clr_val_neg(C'255,85,85'),
      m_clr_val_warn(C'255,185,50'),
      m_clr_val_muted(C'130,140,155')
   {}

   ~CUIDashboard()
   {
      Destroy();
   }

   // Initialize dashboard position and metrics
   bool Init(string symbol, ulong magic, int x = 15, int y = 25, int corner = CORNER_LEFT_UPPER)
   {
      m_symbol          = symbol;
      m_magic           = magic;
      m_base_x          = x;
      m_base_y          = y;
      m_corner          = corner;
      m_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_peak_equity     = AccountInfoDouble(ACCOUNT_EQUITY);
      m_max_dd          = 0.0;
      m_max_dd_pct      = 0.0;
      m_last_stats_ms   = 0;
      m_last_render_ms  = 0;

      // Only draw initial layout if visual environment
      bool is_visual = (MQLInfoInteger(MQL_TESTER) == 0) || (MQLInfoInteger(MQL_VISUAL_MODE) != 0);
      if(is_visual)
      {
         SetBox("BG", m_base_x, m_base_y, m_width, m_height, m_clr_bg, m_clr_border);
      }
      return true;
   }

   // Remove all dashboard UI objects from the chart
   void Destroy()
   {
      ObjectsDeleteAll(0, "GB_UI_");
      ChartRedraw(0);
   }

   // Main read-only observer update
   void Update(const string last_decision, const string last_decision_reason, const CSetupAnalyzer &setup)
   {
      // Optimization: Completely skip UI operations during headless non-visual backtests
      bool is_visual = (MQLInfoInteger(MQL_TESTER) == 0) || (MQLInfoInteger(MQL_VISUAL_MODE) != 0);
      if(!is_visual) return;

      ulong now_ms = GetTickCount64();

      // 1. Account / Performance Queries
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

      if(m_initial_balance <= 0.0)
         m_initial_balance = balance;

      double net_pl     = equity - m_initial_balance;
      double net_pl_pct = (m_initial_balance > 0.0) ? (net_pl / m_initial_balance * 100.0) : 0.0;

      if(equity > m_peak_equity)
         m_peak_equity = equity;

      // Defined purely as Equity Drawdown relative to Peak Equity
      double current_dd     = m_peak_equity - equity;
      double current_dd_pct = (m_peak_equity > 0.0) ? (current_dd / m_peak_equity * 100.0) : 0.0;

      if(current_dd > m_max_dd)
         m_max_dd = current_dd;
      if(current_dd_pct > m_max_dd_pct)
         m_max_dd_pct = current_dd_pct;

      // 2. Query Current Active Position
      bool   has_pos    = false;
      string pos_dir    = "NONE";
      double pos_lot    = 0.0;
      double pos_entry  = 0.0;
      double pos_sl     = 0.0;
      double pos_tp     = 0.0;
      double pos_rr     = 0.0;
      double pos_profit = 0.0;

      QueryCurrentPosition(has_pos, pos_dir, pos_lot, pos_entry, pos_sl, pos_tp, pos_rr, pos_profit);

      bool pos_closed = (m_prev_has_pos && !has_pos);
      bool pos_opened = (!m_prev_has_pos && has_pos);
      m_prev_has_pos  = has_pos;

      // 3. Throttled History Stats (immediately on deal close, or every 2000 ms)
      if(pos_closed || m_last_stats_ms == 0 || (now_ms - m_last_stats_ms >= 2000))
      {
         UpdateHistoryStats();
         m_last_stats_ms = now_ms;
      }

      double today_pl = m_today_closed_profit + (has_pos ? pos_profit : 0.0);

      // 4. Render Throttle (at most every 80 ms unless trade opened/closed)
      if(!pos_closed && !pos_opened && m_last_render_ms > 0 && (now_ms - m_last_render_ms < 80))
      {
         return;
      }
      m_last_render_ms = now_ms;

      // Ensure background panel exists
      SetBox("BG", m_base_x, m_base_y, m_width, m_height, m_clr_bg, m_clr_border);

      int x_label = m_base_x + 12;
      int x_val   = m_base_x + 145;
      int y_cur   = m_base_y + 10;
      int dy      = 14;

      // --- HEADER ---
      SetLabel("TITLE",    "GOLDBERG V1 | OBSERVER",              m_clr_header,   x_label, y_cur, 9, "Consolas");
      y_cur += 14;
      SetLabel("SUBTITLE", "M15 Sweep -> M5 Causal Baseline",     m_clr_subtitle, x_label, y_cur, 8, "Consolas");
      y_cur += 16;

      // --- SECTION A: ACCOUNT / PERFORMANCE ---
      SetLabel("SEC_A",      "--- ACCOUNT & PERFORMANCE ---",     m_clr_section,     x_label, y_cur, 8, "Consolas");
      y_cur += dy;
      SetLabel("L_NET_PL",   "NET P/L:",                          m_clr_label,       x_label, y_cur);
      SetLabel("V_NET_PL",   StringFormat("%s$%.2f (%s%.2f%%)", (net_pl >= 0 ? "+" : "-"), MathAbs(net_pl), (net_pl >= 0 ? "+" : "-"), MathAbs(net_pl_pct)), GetPLColor(net_pl), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_BALANCE",  "BALANCE:",                          m_clr_label,       x_label, y_cur);
      SetLabel("V_BALANCE",  StringFormat("$%.2f", balance),      m_clr_val_default, x_val,   y_cur);
      y_cur += dy;

      SetLabel("L_EQUITY",   "EQUITY:",                           m_clr_label,       x_label, y_cur);
      SetLabel("V_EQUITY",   StringFormat("$%.2f", equity),       m_clr_val_default, x_val,   y_cur);
      y_cur += dy;

      SetLabel("L_PEAK_EQ",  "PEAK EQUITY:",                      m_clr_label,       x_label, y_cur);
      SetLabel("V_PEAK_EQ",  StringFormat("$%.2f", m_peak_equity),m_clr_val_default, x_val,   y_cur);
      y_cur += dy;

      SetLabel("L_CURR_DD",  "CURRENT DD (Eq):",                  m_clr_label,       x_label, y_cur);
      SetLabel("V_CURR_DD",  StringFormat("$%.2f (%.2f%%)", current_dd, current_dd_pct), (current_dd > 0.01 ? m_clr_val_neg : m_clr_val_default), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_MAX_DD",   "MAX DD (Eq):",                      m_clr_label,       x_label, y_cur);
      SetLabel("V_MAX_DD",   StringFormat("$%.2f (%.2f%%)", m_max_dd, m_max_dd_pct),     (m_max_dd > 0.01 ? m_clr_val_neg : m_clr_val_default),    x_val, y_cur);
      y_cur += dy;

      SetLabel("L_TODAY_PL", "TODAY'S P/L:",                      m_clr_label,       x_label, y_cur);
      SetLabel("V_TODAY_PL", StringFormat("%s$%.2f", (today_pl >= 0 ? "+" : "-"), MathAbs(today_pl)), GetPLColor(today_pl), x_val, y_cur);
      y_cur += 16;

      // --- SECTION B: TRADING STATISTICS ---
      SetLabel("SEC_B",      "--- TRADING STATISTICS ---",        m_clr_section,     x_label, y_cur, 8, "Consolas");
      y_cur += dy;

      SetLabel("L_TRADES",   "TOTAL TRADES:",                     m_clr_label,       x_label, y_cur);
      SetLabel("V_TRADES",   StringFormat("%d (%dW / %dL)", m_total_trades, m_win_count, m_loss_count), m_clr_val_default, x_val, y_cur);
      y_cur += dy;

      SetLabel("L_WINRATE",  "WIN RATE:",                         m_clr_label,       x_label, y_cur);
      SetLabel("V_WINRATE",  StringFormat("%.1f%%", m_win_rate),  (m_total_trades == 0 ? m_clr_val_default : (m_win_rate >= 50.0 ? m_clr_val_pos : m_clr_val_neg)), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_AVG_WIN",  "AVG WIN:",                          m_clr_label,       x_label, y_cur);
      SetLabel("V_AVG_WIN",  (m_win_count > 0 ? StringFormat("+$%.2f", m_avg_win) : "---"), (m_win_count > 0 ? m_clr_val_pos : m_clr_val_muted), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_AVG_LOSS", "AVG LOSS:",                         m_clr_label,       x_label, y_cur);
      SetLabel("V_AVG_LOSS", (m_loss_count > 0 ? StringFormat("-$%.2f", MathAbs(m_avg_loss)) : "---"), (m_loss_count > 0 ? m_clr_val_neg : m_clr_val_muted), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_EXPECT_R", "EXPECTANCY (R):",                   m_clr_label,       x_label, y_cur);
      SetLabel("V_EXPECT_R", "N/A",                               m_clr_val_muted,   x_val,   y_cur);
      y_cur += 16;

      // --- SECTION C: CURRENT POSITION ---
      SetLabel("SEC_C",      "--- CURRENT POSITION ---",          m_clr_section,     x_label, y_cur, 8, "Consolas");
      y_cur += dy;

      SetLabel("L_POS_DIR",  "POSITION:",                         m_clr_label,       x_label, y_cur);
      if(has_pos)
         SetLabel("V_POS_DIR", pos_dir, (pos_dir == "BUY" ? m_clr_val_pos : m_clr_val_neg), x_val, y_cur);
      else
         SetLabel("V_POS_DIR", "NONE",  m_clr_val_muted, x_val, y_cur);
      y_cur += dy;

      SetLabel("L_POS_LOT",  "LOT:",                              m_clr_label,       x_label, y_cur);
      SetLabel("V_POS_LOT",  (has_pos ? StringFormat("%.2f", pos_lot) : "---"), (has_pos ? m_clr_val_default : m_clr_val_muted), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_POS_ENTRY","ENTRY:",                            m_clr_label,       x_label, y_cur);
      SetLabel("V_POS_ENTRY",(has_pos ? StringFormat("%.2f", pos_entry) : "---"), (has_pos ? m_clr_val_default : m_clr_val_muted), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_POS_SL",   "SL:",                               m_clr_label,       x_label, y_cur);
      SetLabel("V_POS_SL",   (has_pos && pos_sl > 0.0 ? StringFormat("%.2f", pos_sl) : "---"), (has_pos ? m_clr_val_default : m_clr_val_muted), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_POS_TP",   "TP:",                               m_clr_label,       x_label, y_cur);
      SetLabel("V_POS_TP",   (has_pos && pos_tp > 0.0 ? StringFormat("%.2f", pos_tp) : "---"), (has_pos ? m_clr_val_default : m_clr_val_muted), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_POS_RR",   "RR:",                               m_clr_label,       x_label, y_cur);
      SetLabel("V_POS_RR",   (has_pos && pos_rr > 0.0 ? StringFormat("%.2f", pos_rr) : "---"), (has_pos ? m_clr_val_default : m_clr_val_muted), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_POS_PL",   "CURRENT P/L:",                      m_clr_label,       x_label, y_cur);
      SetLabel("V_POS_PL",   (has_pos ? StringFormat("%s$%.2f", (pos_profit >= 0 ? "+" : "-"), MathAbs(pos_profit)) : "---"), (has_pos ? GetPLColor(pos_profit) : m_clr_val_muted), x_val, y_cur);
      y_cur += 16;

      // --- SECTION D: STRATEGY OBSERVER ---
      SetLabel("SEC_D",      "--- STRATEGY OBSERVER ---",         m_clr_section,     x_label, y_cur, 8, "Consolas");
      y_cur += dy;

      ENUM_SWEEP_LIFECYCLE_STATE st = setup.GetCurrentState();
      ENUM_SWEEP_DIRECTION      dr = setup.GetDirection();
      double ref_p                 = setup.GetReferencePrice();
      double ext_p                 = setup.GetExtremePrice();

      color clr_state = m_clr_val_muted;
      if(st == SWEEP_STATE_LEVEL_BREACHED)    clr_state = m_clr_val_warn;
      else if(st == SWEEP_STATE_RECLAIM_CANDIDATE) clr_state = C'0,215,255';
      else if(st == SWEEP_STATE_STRUCTURE_BREAK)   clr_state = m_clr_val_neg;
      else if(st == SWEEP_STATE_MONITORING)        clr_state = m_clr_label;

      color clr_dir = m_clr_val_muted;
      if(dr == SWEEP_DIR_LONG)       clr_dir = m_clr_val_pos;
      else if(dr == SWEEP_DIR_SHORT) clr_dir = m_clr_val_neg;

      SetLabel("L_STRAT_ST", "STATE:",                            m_clr_label,       x_label, y_cur);
      SetLabel("V_STRAT_ST", StateToString(st),                   clr_state,         x_val,   y_cur);
      y_cur += dy;

      SetLabel("L_STRAT_DIR","DIRECTION:",                        m_clr_label,       x_label, y_cur);
      SetLabel("V_STRAT_DIR",DirectionToString(dr),               clr_dir,           x_val,   y_cur);
      y_cur += dy;

      SetLabel("L_STRAT_REF","REF PRICE:",                        m_clr_label,       x_label, y_cur);
      SetLabel("V_STRAT_REF",(ref_p > 0.0 ? StringFormat("%.2f", ref_p) : "---"), (ref_p > 0.0 ? m_clr_val_default : m_clr_val_muted), x_val, y_cur);
      y_cur += dy;

      SetLabel("L_STRAT_EXT","EXTREME PRICE:",                    m_clr_label,       x_label, y_cur);
      SetLabel("V_STRAT_EXT",(ext_p > 0.0 ? StringFormat("%.2f", ext_p) : "---"), (ext_p > 0.0 ? m_clr_val_default : m_clr_val_muted), x_val, y_cur);
      y_cur += 16;

      // --- SECTION E & F: DIAGNOSTICS & AUDIT ---
      SetLabel("SEC_E",      "--- DIAGNOSTICS & AUDIT ---",       m_clr_section,     x_label, y_cur, 8, "Consolas");
      y_cur += dy;

      string   evt_text = setup.GetLastEvent();
      datetime evt_time = setup.GetLastEventTime();
      if(evt_text == "") evt_text = "AWAITING SWEEP";
      string evt_disp = (evt_time > 0 ? StringFormat("%s [%s]", evt_text, TimeToString(evt_time, TIME_MINUTES)) : evt_text);

      SetLabel("L_LAST_EVT", "LAST EVENT:",                       m_clr_label,       x_label, y_cur);
      SetLabel("V_LAST_EVT", evt_disp,                            m_clr_val_default, x_val,   y_cur);
      y_cur += dy;

      color clr_dec = m_clr_val_default;
      if(last_decision == "BUY_EXECUTED" || last_decision == "SELL_EXECUTED" || StringFind(last_decision, "SIGNAL") >= 0)
         clr_dec = m_clr_val_pos;
      else if(last_decision == "NO_TRADE")
         clr_dec = m_clr_val_warn;
      else if(last_decision == "EXECUTION_FAILED")
         clr_dec = m_clr_val_neg;

      SetLabel("L_LAST_DEC", "LAST DECISION:",                    m_clr_label,       x_label, y_cur);
      SetLabel("V_LAST_DEC", last_decision,                       clr_dec,           x_val,   y_cur);
      y_cur += dy;

      string reason_disp = last_decision_reason;
      if(reason_disp == "") reason_disp = setup.GetLastNoTradeReason();
      if(reason_disp == "") reason_disp = "---";

      SetLabel("L_DEC_RSN",  "REASON:",                           m_clr_label,       x_label, y_cur);
      SetLabel("V_DEC_RSN",  reason_disp,                         m_clr_val_default, x_val,   y_cur);

      ChartRedraw(0);
   }
};
