# ダークコンボボックス

- ID: dark-combobox / 版: 1.0.1 / 登録日: 2026-09-29
- 分類: UI部品。Delphi 37・Win64・VCL/RTL/Windows標準のみ。
- コピー対象: `DarkComboBox.pas`。TDarkComboBoxを生成し、Parentを設定してからItemsを追加する。
- 参照元: MapRakuStrokeStyleComboとSYNC_ScreenLayoutのowner draw方式を参考に新規実装。文書モデル依存なし。

選択専用のcsOwnerDrawFixedを使用する。Styleを別形式へ変更しない。
Colorは背景、Fontは文字書体とサイズ。前景・選択色・枠・矢印は共通の暗色表示を使用する。ParentFont=False、標準Segoe UI 10pt。VCLスタイルへの依存なし。
版1.0.1では参考元と同じくWin32 DrawText前にフォントと文字色をDCへ明示的に設定し、閉じた表示と候補一覧の文字色を修正した。SYNC_Graphでのビルドと自動テストは成功。実AviUtl2画面での確認は未実施。
ItemHeightを個別に固定せず、フォント変更・ハンドル再生成・DPI変更時に実測文字高と余白から調整する。幅と配置は利用側が指定する。
候補はItems、選択はItemIndex、変更通知はOnChange。プログラムによるItemIndex代入ではOnChangeを呼ばない。
入力編集・IMEは対象外。ネイティブコンボのキー操作を使用する。項目は中央揃えの一行表示で、長い文字は省略する。

```pascal
Combo := TDarkComboBox.Create(Self);
Combo.Parent := Panel;
Combo.SetBounds(8, 8, 200, 32);
Combo.Items.Add('項目A');
Combo.Items.Add('項目B');
Combo.ItemIndex := 0;
Combo.OnChange := SelectionChanged;
```

[DarkComboBoxTest.dproj](DarkComboBoxTest.dproj)に標準文字・大きな文字・長い項目・無効状態の例を用意。
本体と同階層にプロジェクト・フォーム・RESを配置。
AviUtl2Canvas編集画面では倍率選択（全体表示/50%/100%/200%）として使用する。

RAD Studio環境でこのフォルダーから実行:

```bat
msbuild DarkComboBoxTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
msbuild DarkComboBoxTest.dproj /t:Build /p:Config=Release /p:Platform=Win64 /v:minimal
```

手動確認: 閉じた状態・開いた候補一覧、日本語と長い文字、選択色、無効状態、Tab/上下/Enter/Esc/ホイール、100%/150%/200%のDPI、編集画面内での操作と倍率変更。
候補ウィンドウの外枠・スクロールバーはWindows標準のため、OS側の外観が残る。全領域を独自描画したポップアップではない。
今回の確認範囲はビルドまで。実ホストでの外観・キー・DPI確認は未完了。文字切れや開閉時の再描画は上記手順で確認する。
