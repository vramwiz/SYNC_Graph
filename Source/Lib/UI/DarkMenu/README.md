# ダークメニュー

- ID: dark-menu
- 版: 1.0.0 / 登録日: 2026-09-28
- 分類: UI部品（ショートカット管理はUI操作支援）
- 出典: D:\DelphiProg\test\MapRaku\Lib\DarkMenu
- 動作条件: Delphi 37 / Win64 / VCL・RTL・Windows標準ユニット。外部DLL・別登録ライブラリへの依存なし。

## コピー対象と導入

VectArtDarkPopupMenu.pas、VectArtDarkMenuGroup.pas

上記ファイルだけを利用側へコピーし、ユニット検索パスへ追加する。利用側から保管庫を参照しない。テストは本体と同じ階層に配置しているが、利用側へのテストのコピーは任意。

`TVectArtDarkPopupMenu.CreateForHosts`でメニューバー型、CreatePopupで任意位置表示用のメニューを生成する。AddItem/AddSubMenuで内容を設定する。Topは利用側で指定する。
ルートメニューを`TVectArtDarkMenuGroup.RegisterMenu`へ登録すると、排他的な開閉、ホバー切替、外側クリック、Esc、アプリ非アクティブ時の閉鎖を管理する。
グループはメニューを所有しない。子メニューも別Ownerによる所有のため、生存期間を揃える。テスト例のようにグループを先に解放し、登録済みメニューが破棄された後に入力監視が残らないようにする。
RegisterMenuはOnHover/OnOpeningへ接続するので、利用側で上書きしない。メニュー項目の処理は利用側へ委譲する。VectArtの名前はコピー時の互換性のため維持しているが、VectArt/MapRaku本体への依存はない。

テストは2つのルートメニュー、子メニュー、無効項目、右クリックメニューを備える。排他切替、外側クリック、Esc、項目実行、フォーム端での位置補正を確認する。VCLのPanelを利用したメニューであり、Windows標準メニューと同じキーボード操作・アクセシビリティを保証するものではない。

## 最小テストとビルド

[DarkMenuTest.dproj](DarkMenuTest.dproj) を開く。[DarkMenuTestForm.pas](DarkMenuTestForm.pas) が最小使用例。DFMなしのコード生成フォーム。

RAD Studioの環境を読み込み、このフォルダーで実行する。

```bat
msbuild DarkMenuTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
msbuild DarkMenuTest.dproj /t:Build /p:Config=Release /p:Platform=Win64 /v:minimal
```

出力は Win64/<構成>/DarkMenuTest.exe。再利用コードとテストプロジェクト・フォーム・RES・READMEを同階層に置く。

## 確認状況

Win64 Debug/Releaseビルド成功、警告0・エラー0。実行・実UI操作・DPIは未確認で、利用者が確認する。元プロジェクトは変更していない。コピーした本体は色コードのユニット名以外のロジックを変更していない。
