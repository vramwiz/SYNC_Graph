# Skiaランタイム管理

`D:\DelphiProg\SYNC_Lyrics\Source\Lib\TextRenderer` から、2026-10-21に次の2ユニットをコピーした。

- `TextRendererSkiaBootstrap.pas`: プラグインと同じフォルダーの `sk4d.dll` の絶対パス解決。
- `TextRendererSkiaRuntime.pas`: 明示的な取得・解放、参照数、Skiaの遅延初期化。

描画本体はGraph固有の既存実装を使う。コピー元へのビルド時参照はない。
2ユニットの処理内容はコピー元と同じ。日本語Pascalソースの保存規則に合わせUTF-8 BOMを付けた。

プラグインは `SKIA_DEFERRED_INIT` を定義し、`Scripts/PrepareSkiaUnit.ps1` が生成する
`Win64/SkiaOverride/System.Skia.pas` と組み合わせる。生成スクリプトもLyricsから採用し、
途中の初期化失敗時にSkia APIの参照を戻す処理を追加した。Delphiのインストール元は変更しない。
Delphi側のクラス初期化の構造が変わると生成を停止するため、再確認してから更新する。

取得・解放はDLLの `initialization` / `finalization` から呼ばず、ホストの公開ライフサイクルから呼ぶ。
解放前にすべてのSkiaインターフェイス参照を破棄する。Graphのフォントキャッシュもこの対象となる。
単独EXEの既存テストは通常のDelphi同梱System.Skiaを使用する。
