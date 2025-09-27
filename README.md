# lilium

## 1. 言語設計の基本方針

### 1.1 コア思想

* **式中心・関数型寄せ**
  → if/match/unsafe/asm も式として値を返す
* **パイプライン中心**

  * 通常パイプライン: `|>`
  * Result型専用パイプライン: `?|>`（自動ショートサーキット）
* **Result 型 + 自動ショートサーキット**

  * 一度 Err が出たらパイプライン全体をスキップ
* **unsafe / asm**

  * ユーザーが明示的に低レベル操作を行える
* **Python風のシンプル記述**

  * インデントでブロック表現、コロン不要
  * 型や所有権注釈は最小限

### 1.2 文法の特徴

* 式中心：すべての構文は値を返す
* インデント構文：波括弧・コロンなし
* パターンマッチ: `match` 式
* 高階関数 / パイプライン用関数と自然に接続
* unsafe / asm も式として扱える

## 2. 型と型推論

### 2.1 型推論方針

* 原則型注釈不要、推論により型を決定
* パイプラインで左の値が右に自動バインド
* unsafe / asm / match も型推論可能
* Result[T,E] 型は自動でショートサーキット

### 2.2 Result パイプラインルール

* `?|>`: 左が `Ok(T)` → 右に T を流す
* 左が `Err(E)` → 右はスキップ、パイプライン全体が `Err(E)` を返す
* match で明示的に Err を処理可能

## 3. パイプライン設計

| 演算子 | 用途 | 挙動       |                               |
| --- | -- | -------- | ----------------------------- |
| `   | >` | 通常パイプライン | 左の値を右に渡す                      |
| `?  | >` | Result専用 | 左が Ok → 右に流す / 左が Err → 右スキップ |

* 並列処理もサポート、タスク単位でショートサーキット
* unsafe / asm 内も自然に統合

## 4. AST ノード設計（プロトタイプ）

```
Expr
 ├─ Literal(value, type)
 ├─ Variable(name, type)
 ├─ FunctionCall(name, args, return_type)
 ├─ PipeExpr(left, right)           ; |>
 ├─ PipeResultExpr(left, right)     ; ?|>
 ├─ MatchExpr(expr, cases)
 ├─ UnsafeExpr(body)
 ├─ AsmExpr(template, operands)
```

* 型情報を保持
* Result 型は `{OkFlag: i1, Value: T}` と仮定

## 5. 標準ライブラリ（構想）

* 高階関数：`map`, `filter`, `reduce`, `flat_map`
* Result 専用：`try_map`, `try_filter`
* unsafe / asm 用：`unsafe_block`, `asm!`
* 式として返す、パイプラインに自然に組み込める

## 6. コンパイラ作成手順（LLVM向け）

### 6.1 ステップ 1: Lexer

* 入力コード → トークン列
* インデントをトークン化
* 識別子・キーワード・演算子・リテラルを抽出

### 6.2 ステップ 2: Parser

* トークン列 → AST
* 式中心・パイプライン中心を反映
* AST ノードに型情報プレースホルダーを持たせる

### 6.3 ステップ 3: 型推論

* 各 AST ノードの型を推論
* パイプライン (`|>` / `?|>`) と Result 型のルール適用
* unsafe / asm / match も式として型推論

### 6.4 ステップ 4: LLVM IR 生成

* AST → LLVM IR に変換
* PipeExpr → 通常関数呼び出し
* PipeResultExpr → 条件分岐 (`Ok` / `Err`) に変換
* UnsafeExpr → メモリ操作 / 低レベル命令
* AsmExpr → inline asm

### 6.5 ステップ 5: LLVM 最適化

* `-O2/-O3` を使用
* 不要な Result チェックやコピーを削除
* unsafe / asm も最適化対象

### 6.6 ステップ 6: ネイティブバイナリ生成

* LLVM モジュールをネイティブコードにコンパイル
* テストケースでパイプライン + Result のショートサーキットを確認

## 7. 注意点 / 設計上のポイント

1. **ショートサーキット型 Result** に統一
2. **式中心・パイプライン中心を崩さない**
3. **unsafe / asm は式として自然に組み込む**
4. **型推論で LLVM 型に正確にマッピング**
5. **同じ処理は必ず一通りの書き方**

## 8. 拡張可能性

* map/filter/reduce → LLVM ループに展開
* 並列処理 → LLVM vectorization / threading
* 高度な unsafe / asm 最適化
* 標準ライブラリの Result 型関数の追加

💡 **まとめ**

* **式中心 + パイプライン + Result型 + 自動ショートサーキット + unsafe/asm** が言語のコア
* 型推論と LLVM IR 生成ルールにより **安全かつ高速なネイティブコード** が生成可能
* インタプリタ不要で直接 LLVM にコンパイルする構造を前提
