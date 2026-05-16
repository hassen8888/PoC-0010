# PoC‑0010 Implementation Specification  
（PoC‑0009 ベースコード準拠版 / Feature‑Enhanced）

## Purpose

PoC‑0010 の目的は、PoC‑0009 の first-touch 観測 EA を拡張し、  
**StartSession 時点の市場状態を特徴量として記録し、  
Outcome（到達方向・到達時間）と紐付けた分析可能なデータセットを生成すること。**

EA 側では分類（fast/normal/slow、straight/reverse/zigzag）は行わず、  
**分析に必要な特徴量を正確にログへ出力することが主目的**。

---

## Implementation

本 PoC は **PoC‑0009_base.mq5 をベースコードとして差分拡張**する。

### 1. ベース構造（変更しない部分）

- StartSession / ProcessActiveSessions の構造はそのまま維持  
- first-touch 判定ロジックは PoC‑0009 と同一  
- active セッション管理は active_idx（int 配列）  
- CArrayObj は append-only（削除しない）  
- CSV 出力は FILE_COMMON、開きっぱなし方式  
- OnInit でヘッダ出力、OnDeinit で Flush & Close  
- MQL4 API は一切使用禁止（TimeHour 等）  
- 時刻は TimeToStruct を使用  
- インジケータは MQL5 ネイティブ（iMACD, iRSI, iBands 等）

---

## 2. 特徴量追加（Feature Set）

StartSession 内の「特徴量計算フック」に以下を追加する。

### A. ボラティリティ系
- vol_1s：直近 1 秒の mid 変動幅（max-min）
- vol_5s：直近 5 秒の変動幅
- std_10ticks：直近 10 Tick の標準偏差

### B. トレンド系
- slope_10ticks：直近 10 Tick の線形回帰傾き
- slope_30ticks：直近 30 Tick の傾き
- m1_direction：M1 足の方向（+1/-1）
- m5_direction：M5 足の方向（+1/-1）

### C. 流動性系
- tick_density_1s：直近 1 秒の Tick 数
- tick_density_5s：直近 5 秒の Tick 数
- spread_points（既存）

### D. レンジ/トレンド判定
- bb_width_m1：M1 ボリンジャーバンド幅
- adx_m5：M5 ADX(14)
- direction_agreement_10ticks：直近 10 Tick の方向一致率（0〜1）

### E. 反転圧力
- rsi_m1：M1 RSI(14)
- distance_to_prev_high：直近高値との距離
- distance_to_prev_low：直近安値との距離

---

## 3. 特徴量の計算ルール

### 3.1 StartSession 時点のみ計算  
- 毎 Tick 計算は禁止（CPU 負荷増大のため）  
- StartSession 内で必要なデータを取得し、session に保存する

### 3.2 CopyBuffer は必要最小限  
- 最新値のみ（count=1〜5）を取得  
- ArraySetAsSeries(true) と CopyBuffer の併用禁止

### 3.3 インジケータハンドル  
- OnInit で作成  
- OnDeinit で IndicatorRelease  
- iMACD は 0=main, 1=signal のみ  
- histogram は main - signal を自前計算

### 3.4 CArrayObj の扱い  
- delete してもメモリ解放されないため、append-only  
- active セッション管理は active_idx のみで行う

---

## 4. CSV 出力仕様（PoC‑0010 拡張版）

### 4.1 列順（csvschema.json に完全一致）

PoC‑0009 の列に加えて以下を追加：

- vol_1s  
- vol_5s  
- std_10ticks  
- slope_10ticks  
- slope_30ticks  
- tick_density_1s  
- tick_density_5s  
- m1_direction  
- m5_direction  
- bb_width_m1  
- adx_m5  
- direction_agreement_10ticks  
- rsi_m1  
- distance_to_prev_high  
- distance_to_prev_low  

### 4.2 出力ルール

- OnInit でヘッダ 1 回のみ  
- AppendLine は FileSeek → FileWriteString  
- 100 行ごとに FileFlush  
- OnDeinit で Flush & Close  
- EscapeCsv はカンマ or ダブルクォート含む場合のみクォート  
- FILE_CSV は使用禁止（タブ区切りになるため）

---

## 5. Outcome 判定（PoC‑0009 と同一）

### 5.1 first-touch  
- current_mid >= target_up → outcome_type = +1  
- current_mid <= target_down → outcome_type = -1  

### 5.2 タイムアウト  
- now_sec - start_time > InpMaxSessionLifeSec → outcome_type = 0  

### 5.3 Outcome 確定時  
- outcome_time_sec = now_sec - start_time  
- 特徴量は StartSession 時点の値をそのまま使用  
- LogSession で CSV 出力  
- active_idx から削除

---

## 6. Execution Conditions

- Tick ベースのストラテジーテスターで実行  
- M1/M5 データが必要（方向判定・インジケータ用）  
- 共通ファイルアクセス（FILE_COMMON）を ON  
- EA は観測専用で注文は行わない

---

## 7. Evaluation Hypotheses

1. 特徴量と outcome_time_sec の間に相関がある  
2. fast/normal/slow で特徴量分布が異なる  
3. straight/reverse/zigzag で特徴量分布が異なる  
4. 時間帯 × 特徴量 × Outcome に偏りがある  
5. 流動性（tick_density）が到達時間に影響する可能性

---

## 8. Evaluation Specification（分析フェーズ）

Python 側で以下を実施：

- outcome_time_sec の分布（四分位）  
- fast/normal/slow の特徴量比較  
- straight/reverse/zigzag の特徴量比較  
- 特徴量重要度（ランダムフォレスト等）  
- 時間帯 × 特徴量 × Outcome のヒートマップ  
- feature_correlations（Pearson）

preprocess_rules.json に従い summary.json を生成する。

---

## 9. Next Step

- 特徴量の有効性を確認し、PoC‑0011 で  
  ShouldStartEntry() の設計に反映する  
- 有効な特徴量のみを残し、不要なものを削除  
- 到達タイプ分類の自動化（EA 側での簡易判定）を検討

---

## 10. Question（不明点）

1. ボリンジャーバンド幅（bb_width_m1）の期間は 20 で確定か？  
2. ADX の期間は 14 で確定か？  
3. distance_to_prev_high/low の参照期間は何秒（または何 Tick）か？  
4. slope_10ticks/30ticks の回帰は「単純線形回帰」で確定か？  
5. m1_direction/m5_direction は「close > open」で +1 としてよいか？

以上の回答後、PoC‑0010_implementation.md を確定版として再生成する。
