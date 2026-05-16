# **PoC管理ルール（OpenAI向け最小版）**

この文書は、OpenAI が PoC の実装仕様（makespec）および EA コード生成（generate）を行う際に従うべき **最低限の運用ルール** を定義する。

## **1. PoC の基本原則**

### **1.1 PoC は「要求仕様 → 実装仕様 → 実装 → 分析」の順で進む**

OpenAI は以下の順序を厳守する：

1. **PoC-XXXX_request.md（要求仕様）を読み、実装仕様を作成する（makespec）**
    
2. **実装仕様に質問があれば列挙し、回答後に再生成する**
    
3. **質問がなくなったら、実装仕様に従って EA を生成する（generate）**
    
4. **分析（analyze）では、summary.json と implementation.md のみを参照する**
    

## **2. PoC要求仕様（request.md）について**

- 人間（順司＋Copilot）が作成する
    
- OpenAI は **request.md の内容を最優先で解釈する**
    
- 曖昧な点があれば **必ず質問として列挙する**
    
- 質問が解消されるまで実装仕様を確定してはならない
    

## **3. PoC実装仕様（implementation.md）について**

OpenAI（makespec）が生成する文書であり、以下を必ず含める：

- Purpose
    
- Implementation
    
- Execution Conditions
    
- Evaluation Hypotheses
    
- Evaluation Specification
    
- Next Step
    
- Question（不明点）
    

### **3.1 質問が残っている状態では generate に進んではならない**

- 質問が 0 件になるまで **implementation.md を再生成する**
    
- generate は **implementation.md が確定した後のみ** 実行される
    

## **4. EA生成（generate）について**

OpenAI は以下を厳守する：

### **4.1 ベースコードを必ず参照する**

- generate では **ベース mq5 を必ず読み込み、構造を維持したまま差分修正する**
    
- request.md や implementation.md に明記されていない変更を勝手に行ってはならない
    
- 全面書き換えは禁止
    

### **4.2 csvschema.json をログ仕様として厳守する**

- ログ列名・型・意味は **csvschema.json の定義に完全一致** させる
    
- request.md に書かれていない列を追加してはならない
    
- schema にない列を出力してはならない
    

## **5. analyze（評価レポート生成）について**

OpenAI（analyze）は以下のみを参照する：

- summary.json（preprocess の結果）
    
- PoC-XXXX_implementation.md（実装仕様）
    

以下は **OpenAI に渡さない**：

- csvschema.json
    
- preprocess_rules.json
    
- request.md
    
- ベースコード
    

分析レポートには以下を含める：

- Purpose
    
- Evaluation Specification
    
- Results
    
- Analysis
    
- Improvement Plan
    
- Next Step
    

## **6. OpenAI が守るべき禁止事項**

OpenAI は以下を行ってはならない：

- ベースコードの構造を勝手に変更する
    
- request.md に書かれていない仕様を勝手に追加する
    
- ログ列を勝手に追加・削除する
    
- 実装仕様に質問が残っている状態で generate を進める
    
- analyze で request.md や schema を参照する
    
- 行間補完による仕様の改変
    

# 🟦 **この最小版が満たすもの**

- OpenAI が理解すべき “PoC改善ループのルール” だけを抽出
    
- makespec / generate / analyze の動作に必要な部分だけ
    
- OpenAI が暴走しないためのガードレールを維持
    
- request.md → implementation.md → generate の流れを強制
    
- ベースコード尊重・差分修正の原則を明確化