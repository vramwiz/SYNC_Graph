# 独自横型トラックバー

- ID: horizontal-trackbar
- 版: 1.0.0 / 登録日: 2026-09-28
- 分類: UI部品（ショートカット管理はUI操作支援）
- 出典: D:\DelphiProg\test\MapRaku\Lib\HorizontalTrackBar
- 動作条件: Delphi 37 / Win64 / VCL・RTL・Windows標準ユニット。外部DLL・別登録ライブラリへの依存なし。

## コピー対象と導入

HorizontalTrackBarControl.pas、HorizontalTrackBarRenderer.pas

上記ファイルだけを利用側へコピーし、ユニット検索パスへ追加する。利用側から保管庫を参照しない。テストは本体と同じ階層に配置しているが、利用側へのテストのコピーは任意。

`THorizontalTrackBarControl.Create(Owner)`で生成してParentを指定する。
`SetRange(Minimum, Maximum)`、`Position`、`SmallChange`、`LargeChange`で値を設定し、`OnChange`で利用側へ反映する。ShowTicks/Frequencyで目盛り、WheelChangesPositionでホイールによる値変更を制御する。
これは数値調整用の横型スライダーであり、横スクロールバーではない。

最小テストは-100～100の値表示、目盛り・ホイール・Enabled切替を備える。ドラッグ、ホイール、矢印・PageUp/Down・Home/End、範囲端、無効状態を確認する。DPIとキャプチャ喪失後の操作も確認する。

## 最小テストとビルド

[HorizontalTrackBarTest.dproj](HorizontalTrackBarTest.dproj) を開く。[HorizontalTrackBarTestForm.pas](HorizontalTrackBarTestForm.pas) が最小使用例。DFMなしのコード生成フォーム。

RAD Studioの環境を読み込み、このフォルダーで実行する。

```bat
msbuild HorizontalTrackBarTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
msbuild HorizontalTrackBarTest.dproj /t:Build /p:Config=Release /p:Platform=Win64 /v:minimal
```

出力は Win64/<構成>/HorizontalTrackBarTest.exe。再利用コードとテストプロジェクト・フォーム・RES・READMEを同階層に置く。

## 確認状況

Win64 Debug/Releaseビルド成功、警告0・エラー0。実行・実UI操作・DPIは未確認で、利用者が確認する。元プロジェクトは変更していない。コピーした本体は色コードのユニット名以外のロジックを変更していない。
