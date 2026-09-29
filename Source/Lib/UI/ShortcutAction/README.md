# ショートカット管理

- ID: shortcut-action
- 版: 1.0.0 / 登録日: 2026-09-28
- 分類: UI部品（ショートカット管理はUI操作支援）
- 出典: D:\DelphiProg\test\MapRaku\Lib\ShortcutAction
- 動作条件: Delphi 37 / Win64 / VCL・RTL・Windows標準ユニット。外部DLL・別登録ライブラリへの依存なし。

## コピー対象と導入

ShortcutAction.pas

上記ファイルだけを利用側へコピーし、ユニット検索パスへ追加する。利用側から保管庫を参照しない。テストは本体と同じ階層に配置しているが、利用側へのテストのコピーは任意。

`TShortcutAction.Create`で生成し、`Add(Key, Shift, Proc, CanExecute)`でKeyDown用の処理を登録する。文字操作はCharのAddオーバーロードを使用する。
フォームのKeyPreviewをTrueにし、OnKeyDownからKeyDown、OnKeyPressからProcessKeyPressへ渡す。処理済みキーは0または#0になり、戻り値はTrueになる。
フォーム終了時にFreeする。登録した匿名メソッドが参照するオブジェクトは、登録が有効な間は生存させる。重複キー登録は例外になる。
Enabledと全体・項目別の実行条件を使用できる。入力欄編集中の扱いは利用側が決める。

テストではCtrl+Kでカウント、xで文字操作、チェック欄で条件切替を確認する。入力欄内ではxは通常入力を維持する。OSのグローバルホットキー登録機能は含まない。

## 最小テストとビルド

[ShortcutActionTest.dproj](ShortcutActionTest.dproj) を開く。[ShortcutActionTestForm.pas](ShortcutActionTestForm.pas) が最小使用例。DFMなしのコード生成フォーム。

RAD Studioの環境を読み込み、このフォルダーで実行する。

```bat
msbuild ShortcutActionTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
msbuild ShortcutActionTest.dproj /t:Build /p:Config=Release /p:Platform=Win64 /v:minimal
```

出力は Win64/<構成>/ShortcutActionTest.exe。再利用コードとテストプロジェクト・フォーム・RES・READMEを同階層に置く。

## 確認状況

Win64 Debug/Releaseビルド成功、警告0・エラー0。実行・実UI操作・DPIは未確認で、利用者が確認する。元プロジェクトは変更していない。コピーした本体は色コードのユニット名以外のロジックを変更していない。
