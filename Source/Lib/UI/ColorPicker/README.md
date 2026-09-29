# カラーピッカーと色コード解析

- ID: color-picker
- 基礎4ユニット: 1.0.0 / 共通パネル: 1.1.1（2026-09-29に参考元からコピー・同期）
- 分類: UI部品（ショートカット管理はUI操作支援）
- 出典: D:\DelphiProg\test\MapRaku\Lib\ColorPicker
- 動作条件: Delphi 37 / Win64 / VCL・RTL・Windows標準ユニット。外部DLL・別登録ライブラリへの依存なし。

## コピー対象と導入

ColorPickerPanel.pas、ColorPickerHueBar.pas、ColorPickerSVArea.pas、ColorPickerColorMath.pas、ColorCode.pas

基礎4ユニットは従来のコピーを維持し、共通パネルだけ参考元の1.1.0から追加した。ユニット検索パスは本プロジェクト内のディレクトリを参照する。

共通パネルは子Editのハンドル生成に備え、Ownerがウィンドウの場合は生成の初めにParentを確定する。また親画面の初期配置後に`RefreshLayout`で寸法を再計算する。この2点は参考元へ反映済みで、パネル本体は同一内容。基礎4ユニットも変更していない。パネルの`SelectedColor`を装飾対象と同期し、OnChangeでモデルへ反映する。アルファ値はモデル側に保持する。

色相バーは`TColorPickerHueBar`、彩度・明度領域は`TColorPickerSVArea`。いずれもParentとBoundsを設定する。
色相のOnChangeでは現在色をColorToHsvで分解し、彩度・明度を保持したまま新しい色相でHsvToColorを呼び、SV領域のBaseColorとColorを更新する。実装例はテストフォームを参照。
SVのOnChangeでColorを読み、適用は利用側で行う。プロパティへの代入はOnChangeを発火しないため、外部からの色設定後は利用側で表示・適用を同期する。
`TryParseColorCode(Text, Color)`は`#RRGGBB`、`RRGGBB`、`rgb(255,0,0)`、`255,0,0`に対応する。失敗時のColorは使用しない。

テストは色相・SV・色プレビュー・色コード入力を接続している。色相とSVをドラッグし、赤・緑・青・白・黒、不正コード、RGBの範囲外、HEX入力を確認する。アルファ選択、色履歴、文書への反映は含まない。
色コード解析はMapRakuのSource/ObjectProperties/Color/MapRakuColorCode.pasからコピーし、ユニット名だけColorCodeへ変更。他の3ユニットはロジック変更なし。

## 検証

参考元の`D:\DelphiProg\test\DelphiVclAppTemplate\Source\Lib\UI\ColorPicker`には単体テストがある。本プロジェクトへはコピーしていない。本プロジェクトでは`Tests/EditorSmoke.dpr`で配置、HEX・RGB十進入力、選択中の線色への反映を確認する。

## 確認状況

参考元の単体サンプルはWin64 Debug/Releaseビルド成功。こちらの編集フォームのビルドとスモークテストも通過。実AviUtl2でのUI操作と複数DPIはユーザー確認待ち。参考元は変更していない。
