# Language Specification

## 1. 言語設計の基本方針

* **目的**：Cのような黒魔術的高速処理を **ユーザーが安全に扱える** 言語
* **基本思想**

  1. 式中心・関数型寄せ
  2. パイプライン中心
  3. Result 型による自動エラー伝播
  4. unsafe / asm を式として自然に統合
  5. 型は原則推論、必要に応じて注釈可能
  6. インデントでブロックを表現（コロン不要）
* Python・Elixir 風の美しい記述を重視

## 2. 安全性と unsafe の扱い

* **unsafe 契約**

  * ユーザーが明示的に unsafe ブロックを使用
  * その中でポインタ操作・メモリレイアウト制御・アセンブリを使用可能
  * 型推論で式として結果を返す
* **Err 自動スキップ演算子 `?|>`**

  * Result 型専用のパイプライン演算子
  * 最初の Err でパイプラインをショートサーキット
  * 通常フローは簡潔に、必要に応じて `match` でエラー処理

## 3. パイプラインと式中心設計

| 構文       | 説明                            |                                              |
| -------- | ----------------------------- | -------------------------------------------- |
| `        | >`                            | 通常値を次に渡す                                     |
| `?       | >`                            | Result 型専用。Err が出たら右側をスキップ、パイプライン全体が Err を返す |
| `match`  | パターンマッチ。式として値を返す              |                                              |
| `unsafe` | 式として扱う。副作用は明示                 |                                              |
| `asm!`   | 式として扱う。LLVM inline asm に変換可能  |                                              |
| 関数呼び出し   | パイプラインに自然に接続。引数の最初に左の値を自動バインド |                                              |

### 3.1 Result 型フロー例

```py
data
    |> parse()        # Result[T,E]
    ?|> process()     # 成功値は右に流れる、Err ならスキップ
    ?|> save()
```

* `?|>` は **ショートサーキット型**
* match で明示的に Err を処理可能

### 3.2 unsafe / asm 組み込み例

```py
val = unsafe
    ptr = raw_cast(data)
    *ptr = 42
    return ptr

x |> unsafe
    asm!("mulss {0}, {1}", inout(x), in(y))
```

## 4. 型推論設計

| 項目                 | 推論ルール                     |                                               |
| ------------------ | ------------------------- | --------------------------------------------- |
| PipeExpr (`        | >`)                       | 左の型 → 右に自動バインド                                |
| PipeResultExpr (`? | >`)                       | 左が Ok(T) → 右に T を渡す。Err(E) → パイプライン全体が Err(E) |
| unsafe / asm       | 内部の式の型をそのまま返す。副作用は Unit 型 |                                               |
| match              | 式として値を返す                  |                                               |
| 関数呼び出し             | 引数・返り値を型推論                |                                               |

* 結果として、ユーザーはほぼ Python 風に書けるが、内部は Rust の安全性・型チェック


## 5. LLVM ネイティブコンパイラ設計

### 5.1 コンパイラ全体フロー

```
ソースコード
   │
字句解析（Lexer） → トークン列
   │
構文解析（Parser） → AST
   │
型推論（Type Inference） → 型付き AST
   │
AST → LLVM IR 生成
   │
LLVM 最適化 → ネイティブバイナリ
```

### 5.2 AST ノード例

```
Expr
 ├─ Literal(value, type)
 ├─ Variable(name, type)
 ├─ FunctionCall(name, args, return_type)
 ├─ PipeExpr(left, right)
 ├─ PipeResultExpr(left, right)
 ├─ MatchExpr(expr, cases)
 ├─ UnsafeExpr(body)
 ├─ AsmExpr(template, operands)
```

### 5.3 LLVM IR 生成ルール（簡易版）

* **PipeExpr**: 左値を右関数に渡す
* **PipeResultExpr**: 条件分岐で Ok/Err を管理（ショートサーキット）
* **MatchExpr**: LLVM 条件分岐で各ケース評価
* **UnsafeExpr**: ポインタ・メモリ操作を LLVM 命令に変換
* **AsmExpr**: LLVM inline asm に変換

### 5.4 LLVM IR 変換例

```llvm
; val |> double() ?|> unsafe_store()
%res = call {i1,i32} @double(i32 %val)
%is_ok = extractvalue %res, 0
br i1 %is_ok, label %ok, label %err

ok:
  %v = extractvalue %res, 1
  %res2 = call {i1,void} @unsafe_store(i32 %v)
  br label %cont

err:
  %res2 = %res
  br label %cont

cont:
  ; %res2 がパイプライン最終結果
```

## 6. 標準ライブラリ（拡張用）

* 高階関数: `map`, `filter`, `reduce`, `flat_map`
* unsafe / asm のラッパー関数
* Result 型対応関数は自動ショートサーキット可能

## 7. 今後のステップ

1. **簡易 LLVM IR 生成プロトタイプ作成**

   * PipeExpr / PipeResultExpr / UnsafeExpr / MatchExpr の最小動作確認
2. **型推論と Result 型伝播の完全統合**
3. **標準ライブラリ関数を LLVM に展開**
4. **並列処理や unsafe 最適化の追加**
5. **LLVM 最適化 & ネイティブバイナリ生成**
