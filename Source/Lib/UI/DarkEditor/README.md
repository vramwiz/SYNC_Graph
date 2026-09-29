# DarkEditor 1.0.0

フォーム単位の暗色表示と編集表の余白を共有するVCL用UI補助。SYNC_GraphのUI改良から登録。

- Delphi 37 / Win64。Vcl.Styles、Vcl.Themes、Vcl.Gridsを使用。
- フォームのCreateNew直後にApplyDarkEditor(Self)を呼ぶ。Windows Modern DarkとYu Gothic UI 10ptを適用する。
- 表を親へ接続し寸法を指定した後にSetupEditorGrid(Grid, 項目列の幅)を呼ぶ。幅は96 DPI基準。日本語文字高を実測し、行高に余白を加える。
- グラフのモデル、データ、操作には依存しない。画面固有の配置は利用側が担当する。
- WindowsModernDark.vsfはRAD Studio 37のRedist/styles/vclから採用したEmbarcadero配布物。独自ライセンスは付与しない。
- コピー対象: DarkEditorTheme.pas、DarkEditorStyle.res。リソース再生成にはrcとvsfも必要。同ディレクトリでbrcc32 DarkEditorStyle.rcを実行する。
- 初回にVCLスタイルエンジンを有効化する。元がOSスタイルの場合はUseSystemStyleAsDefault=Trueとして、StyleName未指定のフォームをOS配色に保つ。既にカスタムスタイルが有効なら、その既定スタイルを変更しない。UIスレッドから呼ぶこと。
- SYNC_Graphはランタイムパッケージを使わないDLL。ホストのウィンドウには適用しない。共有VCLランタイムを使う別アプリへの導入時は既定スタイルとの共存を確認すること。

確認: SYNC_Graphの独立フォームで生成・モーダル終了を検証。96/144 DPIで3ページの描画画像を出力し、文字・値と装飾の画像を目視確認。実モニター間移動、実ホストUI操作は未確認。

最小使用例はDarkEditorTest.dpr。次のようにDelphiの環境からビルドできる。

```bat
dcc64 -B DarkEditorTest.dpr
```
選択表示の修正: SetupEditorGridはgoDrawFocusSelectedを有効、goAlwaysShowEditorを無効にする。選択セルを強調し、文字入力・F2・ダブルクリックで編集する。常時編集を前提とする画面では採用時に操作仕様を確認すること。ビルドとフォーム終了テスト成功。実ホストでの選択表示・キャレットの目視確認は利用側で行う。
