# カラーピッカーと色コード解析

- ID: color-picker
- 版: 1.0.0 / 登録日: 2026-09-28
- 分類: UI部品（ショートカット管理はUI操作支援）
- 出典: D:\DelphiProg\test\MapRaku\Lib\ColorPicker
- 動作条件: Delphi 37 / Win64 / VCL・RTL・Windows標準ユニット。外部DLL・別登録ライブラリへの依存なし。

## コピー対象と導入

ColorPickerHueBar.pas、ColorPickerSVArea.pas、ColorPickerColorMath.pas、ColorCode.pas

上記ファイルだけを利用側へコピーし、ユニット検索パスへ追加する。利用側から保管庫を参照しない。テストは本体と同じ階層に配置しているが、利用側へのテストのコピーは任意。

色相バーは`TColorPickerHueBar`、彩度・明度領域は`TColorPickerSVArea`。いずれもParentとBoundsを設定する。
色相のOnChangeでは現在色をColorToHsvで分解し、彩度・明度を保持したまま新しい色相でHsvToColorを呼び、SV領域のBaseColorとColorを更新する。実装例はテストフォームを参照。
SVのOnChangeでColorを読み、適用は利用側で行う。プロパティへの代入はOnChangeを発火しないため、外部からの色設定後は利用側で表示・適用を同期する。
`TryParseColorCode(Text, Color)`は`#RRGGBB`、`RRGGBB`、`rgb(255,0,0)`、`255,0,0`に対応する。失敗時のColorは使用しない。

テストは色相・SV・色プレビュー・色コード入力を接続している。色相とSVをドラッグし、赤・緑・青・白・黒、不正コード、RGBの範囲外、HEX入力を確認する。アルファ選択、色履歴、文書への反映は含まない。
色コード解析はMapRakuのSource/ObjectProperties/Color/MapRakuColorCode.pasからコピーし、ユニット名だけColorCodeへ変更。他の3ユニットはロジック変更なし。

## 最小テストとビルド

[ColorPickerTest.dproj](ColorPickerTest.dproj) を開く。[ColorPickerTestForm.pas](ColorPickerTestForm.pas) が最小使用例。DFMなしのコード生成フォーム。

RAD Studioの環境を読み込み、このフォルダーで実行する。

```bat
msbuild ColorPickerTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
msbuild ColorPickerTest.dproj /t:Build /p:Config=Release /p:Platform=Win64 /v:minimal
```

出力は Win64/<構成>/ColorPickerTest.exe。再利用コードとテストプロジェクト・フォーム・RES・READMEを同階層に置く。

## 確認状況

Win64 Debug/Releaseビルド成功、警告0・エラー0。実行・実UI操作・DPIは未確認で、利用者が確認する。元プロジェクトは変更していない。コピーした本体は色コードのユニット名以外のロジックを変更していない。
