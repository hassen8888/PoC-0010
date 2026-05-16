# PoC‑0010 Requirements Specification  
（PoC‑0009 ベースコード準拠版 / Feature‑Enhanced）

## Purpose

PoC‑0010 の目的は、  
PoC‑0009 で取得した first-touch データに加えて、  
**市場状態を表す特徴量（Feature）を StartSession 時点で記録し、  
到達時間（fast / normal / slow）および到達タイプ（straight / reverse / zigzag）を分類し、  
どの特徴量が到達パターンに影響しているかを分析可能にすること。**

PoC‑0010 は PoC‑0009 のコード構造を完全に継承し、  
StartSession 内の「特徴量計算フック」を正式に実装するフェーズである。

---

## Scope

PoC‑0010 では以下を実施する：

1. **StartSession 時点で市場状態の特徴量を計算し、セッションに保存する**
2. **LogSession に特徴量を追加し、CSV に出力する**
3. **Outcome 確定後、特徴量と Outcome を紐付けたデータセットを生成する**
4. **Python 側で到達時間・到達タイプ分類を行い、特徴量の効き具合を分析する**

EA 側では分類は行わず、  
**分類に必要な特徴量を正しく記録することが主目的**。

---

## Feature Set（PoC‑0010 で追加する特徴量）

PoC‑0009 の構造を壊さず、StartSession 内で計算可能な特徴量を追加する。

### A. ボラティリティ系（Volatility）
- vol_1s  
  直近 1 秒間の mid 価格変動幅（max-min）
- vol_5s  
  直近 5 秒間の変動幅
- std_10ticks  
  直近 10 Tick の標準偏差

### B. トレンド系（Trend）
- slope_10ticks  
  直近 10 Tick の線形回帰傾き
- slope_30ticks  
  直近 30 Tick の傾き
- m1_direction  
  M1 足の方向（+1 / -1）
- m5_direction  
  M5 足の方向（+1 / -1）

### C. 流動性系（Liquidity）
- tick_density_1s  
  直近 1 秒の Tick 数
- tick_density_5s  
  直近 5 秒の Tick 数
- spread_points（既存）

### D. レンジ/トレンド判定（Regime）
- bb_width_m1  
  M1 ボリンジャーバンド幅
- adx_m5  
  M5 ADX 値
- direction_agreement_10ticks  
  直近 10 Tick の方向一致率

### E. 反転圧力（Reversal Pressure）
- rsi_m1  
  M1 RSI(14)
- distance_to_prev_high  
  直近高値との距離
- distance_to_prev_low  
  直近安値との距離

---

## Feature Recording Rules

### 1. 特徴量は **StartSession 時点でのみ計算・保存**  
Outcome 判定時には特徴量を再計算しない。

### 2. 特徴量は CSimpleSession にフィールド追加  
PoC‑0009 のコメント位置に追加する。

### 3. LogSession に列を追加  
ヘッダーとデータ行に特徴量を追加する。

### 4. 計算コストは軽量に  
Tick ベースで動作するため、  
重い計算（長期履歴参照）は避ける。

---

## Outcome Classification（分析側で実施）

EA は分類を行わず、  
Python 側で以下の分類を行う。

### A. 到達時間分類（Time Category）
- fast：p25 未満  
- normal：p25〜p75  
- slow：p75 以上  
- timeout：600 秒以上（outcome_type=0）

### B. 到達タイプ分類（Path Type）
Tick データから以下を判定：

- straight  
  ほぼ逆行せずに到達
- reverse  
  entry_direction と逆方向に一度大きく動いてから到達
- zigzag  
  上下に複数回揺れてから到達

※ EA 側では direction_changes を将来利用可能な形で保持（現状 0 のまま）

---

## CSV Output Specification（PoC‑0010 拡張版）

PoC‑0009 の列に加えて、以下を追加：

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

列順は PoC‑0009 の後ろに追加する。

---

## EA Behavior Summary（PoC‑0009 からの変更点）

### 変更点
- StartSession 内で特徴量を計算し、session に保存
- LogSession に特徴量を追加して CSV 出力

### 変更しない点
- StartSession / ProcessActiveSessions の構造
- first-touch 判定ロジック
- セッション管理方式（g_sessions + active_idx）
- タイムアウト処理
- CSV 出力方式（FILE_COMMON）

---

## Evaluation Plan（分析フェーズ）

Python 側で以下を実施：

1. 特徴量と outcome_time_sec の相関分析  
2. fast / normal / slow の特徴量分布比較  
3. straight / reverse / zigzag の特徴量分布比較  
4. 特徴量重要度の算出（ランダムフォレスト等）  
5. 時間帯 × 特徴量 × 到達タイプのヒートマップ

目的は：

**「どの市場状態のときに、どの到達パターンが起きやすいか」を明確化すること。**

---

## Deliverables

1. PoC‑0010 EA（PoC‑0009_base.mq5 に特徴量追加したもの）
2. PoC‑0010 CSV（特徴量付き）
3. Python 分析ノートブック（到達時間/到達タイプ分類＋特徴量分析）
4. PoC‑0010 分析レポート（特徴量の効き具合まとめ）

---

# End of Document
