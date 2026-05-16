# analyze 用注意点（分析フェーズ・正式版）

:::rule id="analysis_input"
## 1. 入力データ
- CSV は schema に完全準拠すること
- 欠損値は 0 または NaN として扱う
- outcome_type=0 は「未到達」として別扱い
:::endrule

---

:::rule id="analysis_labels"
## 2. ラベル定義
- 到達時間分類：fast / normal / slow（outcome_time_sec の四分位で分割）
- 到達タイプ分類：straight / reverse / zigzag（Tick パス解析）
:::endrule

---

:::rule id="analysis_features"
## 3. 特徴量
- feature_columns をそのまま使用
- 必要に応じて正規化・標準化
- 相関分析は Pearson / Spearman を使用
:::endrule

---

:::rule id="analysis_outputs"
## 4. 出力
- summary.json（基本統計）
- 特徴量重要度（ランダムフォレスト等）
- 到達時間/到達タイプ別の特徴量分布
- 時間帯 × 特徴量 × Outcome のヒートマップ
:::endrule

---

:::rule id="analysis_rules"
## 5. 注意点
- 分析側で EA ロジックを推測しない（データのみで判断）
- 特徴量の多重共線性に注意
- outcome_time_sec の外れ値は winsorize 可能
- 特徴量の欠損は 0 または NaN のまま扱い、補完しない
:::endrule
