// ============================================================================
//  PoC-0009 Feature-Ready Version
//  （特徴量追加のためのフックコメント入り整理版）
// ============================================================================

#property strict
#include <Arrays\ArrayObj.mqh>

input bool InpEnableDebugPrint  = false;
input int  InpMaxSessionLifeSec = 1800;
input int  InpEntryTickPeriod   = 0;

// ============================================================================
//  Session Class（★特徴量を追加するならここにフィールドを追加）
// ============================================================================

class CSimpleSession : public CObject
{
public:
   bool active;

   // --- 基本ログ項目 ---
   string date;
   string time;
   int hour;
   double bid;
   double ask;
   int spread_points;
   double entry_mid;
   int entry_direction;

   // --- first-touch 判定用 ---
   double target_up;
   double target_down;
   datetime start_time;

   // --- Outcome ---
   int outcome_type;
   int outcome_time_sec;
   int direction_changes;

   // ========================================================================
   // ★ 特徴量を追加するならここにフィールドを追加
   //    例：
   //    double vol_1s;
   //    double vol_5s;
   //    double slope_10ticks;
   //    double tick_density_1s;
   //    double rsi_14;
   // ========================================================================

   CSimpleSession()
   {
      active = false;
      date = "";
      time = "";
      hour = 0;
      bid = 0.0;
      ask = 0.0;
      spread_points = 0;
      entry_mid = 0.0;
      entry_direction = 0;
      target_up = 0.0;
      target_down = 0.0;
      start_time = 0;
      outcome_type = 0;
      outcome_time_sec = 0;
      direction_changes = 0;

      // ★ 追加した特徴量はここで初期化
   }
};

CArrayObj g_sessions;
int active_idx[];

string g_file_name = "PoC-0009_log.csv";
datetime g_last_entry_second = 0;

int g_file_handle = INVALID_HANDLE;
int g_flush_counter = 0;

// ============================================================================
//  CSV Utility
// ============================================================================

string EscapeCsv(const string value)
{
   bool need_quote = false;
   if(StringFind(value, ",") >= 0 || StringFind(value, "\"") >= 0)
      need_quote = true;

   string escaped = "";
   int len = StringLen(value);

   for(int i = 0; i < len; i++)
   {
      string ch = StringSubstr(value, i, 1);
      if(ch == "\"")
         escaped += "\"\"";
      else
         escaped += ch;
   }

   if(need_quote)
      return "\"" + escaped + "\"";
   return escaped;
}

bool AppendLine(const string line)
{
   if(g_file_handle == INVALID_HANDLE)
      return false;

   FileSeek(g_file_handle, 0, SEEK_END);
   FileWriteString(g_file_handle, line + "\r\n");

   g_flush_counter++;
   if(g_flush_counter >= 100)
   {
      FileFlush(g_file_handle);
      g_flush_counter = 0;
   }
   return true;
}

// ============================================================================
//  Utility
// ============================================================================

string FormatDate(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringFormat("%04d-%02d-%02d", dt.year, dt.mon, dt.day);
}

string FormatTimeOnly(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);
}

bool GetPrevM1BidClose(double &prev_close)
{
   prev_close = iClose(_Symbol, PERIOD_M1, 1);
   return (prev_close != 0.0);
}

// ============================================================================
//  LogSession（★特徴量を CSV に追加するならここに列を追加）
// ============================================================================

bool LogSession(CSimpleSession *session, const string end_time_text)
{
   if(session == NULL)
      return false;

   string line =
      EscapeCsv(session.date) + "," +
      EscapeCsv(session.time) + "," +
      IntegerToString(session.hour) + "," +
      DoubleToString(session.bid, _Digits) + "," +
      DoubleToString(session.ask, _Digits) + "," +
      IntegerToString(session.spread_points) + "," +
      DoubleToString(session.entry_mid, _Digits) + "," +
      IntegerToString(session.entry_direction) + "," +
      IntegerToString(session.outcome_type) + "," +
      IntegerToString(session.outcome_time_sec) + "," +
      IntegerToString(session.direction_changes) + "," +
      EscapeCsv(end_time_text);

   // ========================================================================
   // ★ 特徴量を CSV に追加するならここに追記
   //   line += "," + DoubleToString(session.vol_1s, 5);
   //   line += "," + DoubleToString(session.slope_10ticks, 5);
   // ========================================================================

   return AppendLine(line);
}

// ============================================================================
//  StartSession（★特徴量を計算して session に保存するならここ）
// ============================================================================

void StartSession(const MqlTick &tick, const datetime now_sec, const int entry_direction)
{
   CSimpleSession *session = new CSimpleSession();
   if(session == NULL)
      return;

   session.active = true;
   session.date = FormatDate(now_sec);
   session.time = FormatTimeOnly(now_sec);

   MqlDateTime dt;
   TimeToStruct(now_sec, dt);
   session.hour = dt.hour;

   session.bid = tick.bid;
   session.ask = tick.ask;
   session.spread_points = (int)MathRound((tick.ask - tick.bid) / _Point);
   session.entry_mid = (tick.bid + tick.ask) / 2.0;
   session.entry_direction = entry_direction;

   session.target_up   = session.entry_mid + 0.03;
   session.target_down = session.entry_mid - 0.03;
   session.start_time  = now_sec;

   // ========================================================================
   // ★ 特徴量計算フック
   //   ここで市場状態を計算して session に保存する
   //
   //   例：
   //   session.vol_1s = CalcVolatility(1);
   //   session.slope_10ticks = CalcSlope(10);
   //   session.tick_density_1s = CalcTickDensity(1);
   // ========================================================================

   int idx = g_sessions.Total();
   g_sessions.Add(session);

   ArrayResize(active_idx, ArraySize(active_idx) + 1);
   active_idx[ArraySize(active_idx) - 1] = idx;
}

// ============================================================================
//  ProcessActiveSessions（Outcome 確定時に特徴量と紐付け）
// ============================================================================

void ProcessActiveSessions(const double current_mid, const datetime now_sec)
{
   for(int k = ArraySize(active_idx) - 1; k >= 0; k--)
   {
      int idx = active_idx[k];
      CSimpleSession *session = (CSimpleSession*)g_sessions.At(idx);
      if(session == NULL || !session.active)
      {
         RemoveActiveIndex(k);
         continue;
      }

      // タイムアウト
      if((now_sec - session.start_time) > InpMaxSessionLifeSec)
      {
         session.outcome_type     = 0;
         session.outcome_time_sec = (int)(now_sec - session.start_time);

         // ★ 特徴量は StartSession 時点のものをそのまま使う
         LogSession(session, FormatTimeOnly(now_sec));

         session.active = false;
         RemoveActiveIndex(k);
         continue;
      }

      // first-touch
      int outcome = 0;
      if(current_mid >= session.target_up)
         outcome = 1;
      else if(current_mid <= session.target_down)
         outcome = -1;
      else
         continue;

      session.outcome_type     = outcome;
      session.outcome_time_sec = (int)(now_sec - session.start_time);
      session.active           = false;

      // ★ Outcome 確定時に特徴量を追加するならここで加工も可能
      LogSession(session, FormatTimeOnly(now_sec));

      RemoveActiveIndex(k);
   }
}

// ============================================================================
//  OnTick（StartSession と Outcome 判定の分離構造）
// ============================================================================

void OnTick()
{
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick))
        return;

    datetime now_sec = tick.time;
    double current_mid = (tick.bid + tick.ask) / 2.0;

    // Outcome 判定は毎Tick
    ProcessActiveSessions(current_mid, now_sec);

    // StartSession の間隔制御
    if(InpEntryTickPeriod > 0)
    {
        if((now_sec - g_last_entry_second) < InpEntryTickPeriod)
            return;
    }

    g_last_entry_second = now_sec;

    // 方向判定
    double prev_m1_bid_close = 0.0;
    if(!GetPrevM1BidClose(prev_m1_bid_close))
        return;

    int entry_direction = 0;
    if(current_mid > prev_m1_bid_close)
        entry_direction = 1;
    else if(current_mid < prev_m1_bid_close)
        entry_direction = -1;
    else
        return;

    StartSession(tick, now_sec, entry_direction);
}

// ============================================================
// active_idx 用 削除ヘルパー（Swap + Resize）
// ============================================================

void RemoveActiveIndex(const int k)
{
   int last = ArraySize(active_idx) - 1;
   if(last < 0)
      return;

   if(k != last)
      active_idx[k] = active_idx[last];

   ArrayResize(active_idx, last);
}


// ============================================================
// 終了処理
// ============================================================

void ForceCloseAllSessions(const datetime end_time)
{
   for(int k = ArraySize(active_idx) - 1; k >= 0; k--)
   {
      int idx = active_idx[k];
      CSimpleSession *session = (CSimpleSession*)g_sessions.At(idx);
      if(session != NULL && session.active)
      {
         session.outcome_type     = 0;
         session.outcome_time_sec = (int)(end_time - session.start_time);
         LogSession(session, FormatTimeOnly(end_time));
         session.active = false;
      }
   }

   ArrayResize(active_idx, 0);
}


// ============================================================================
//  OnInit / OnDeinit
// ============================================================================

int OnInit()
{
   g_sessions.Clear();
   g_sessions.FreeMode(true);
   ArrayResize(active_idx, 0);
   g_last_entry_second = 0;

   g_file_handle = FileOpen(g_file_name,
                            FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(g_file_handle == INVALID_HANDLE)
   {
      Print("FileOpen failed: ", GetLastError());
      return INIT_FAILED;
   }

   string header =
      "date,time,hour,bid,ask,spread_points,entry_mid,entry_direction,outcome_type,outcome_time_sec,direction_changes,end_time";

   // ★ 特徴量を CSV に追加するならここに列名を追加
   // header += ",vol_1s,slope_10ticks";

   FileWriteString(g_file_handle, header + "\r\n");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ForceCloseAllSessions(TimeCurrent());

   if(g_file_handle != INVALID_HANDLE)
   {
      FileFlush(g_file_handle);
      FileClose(g_file_handle);
      g_file_handle = INVALID_HANDLE;
   }
}

