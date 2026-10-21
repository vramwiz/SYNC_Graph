# Delphi製AviUtl2プラグインのSkia DLL初期化方針

作成日: 2026-10-21

## 適用方針

Windows上で `sk4d.dll` を使うDelphi製AviUtl2プラグインは、Skiaの取得・初期化を
**プラグインDLLのロード完了後に呼ばれる `InitializePlugin` へ移す**。
終了処理も `UninitializePlugin` で行い、DLLのアンロード処理へ持ち越さない。
同じDLLを使う別プラグインへ展開する際も、この方針を基本とする。

本書の具体的な生成スクリプトはDelphi 37 / Win64 / System.Skiaを対象とする。
ほかのDelphi・Skiaの版や別のバインディングでは、同じ方針で実際の初期化経路を確認する。
既にロード後の初期化へ対応しているプラグインへ、二重に初期化処理を追加しない。

## 発端と確認結果

SYNC_Graphで、特定環境のAviUtl2起動時に次のエラーが報告された。

```text
Runtime error 216 at 00007FFE2B5B0739
```

- 開発環境では報告された216自体を再現できなかった。
- 配布ZIPには `.auf2`・`sk4d.dll`・READMEが含まれていた。
- カタログからのインストール・アンインストールを繰り返しても、配置は正常だった。
- SYNC_Lyricsとの比較で、GraphにはSkiaのクラス初期化を遅らせる対策がないと分かった。
- 人工ホストでは、旧Graphは `.auf2` のロード中にSkiaをロードし、修正版は
  `InitializePlugin` までロードしないことを確認した。
- **2026-10-21、発生環境の利用者から修正版でエラーが解消したとの報告を受けた。**

この結果から、今回の初期化変更は有効な対策と判断する。ただし、報告されたアドレスの
障害箇所やスタックを直接観測したわけではなく、すべてのRuntime error 216の原因を
Skiaと判断するものではない。アドレスだけを別の実行環境のソース位置へ対応づけることもできない。

## DLLロード中に初期化しない理由

DLLのエントリーポイントはWindowsのローダーロックを保持した状態で呼ばれる。
Microsoftは、この中から直接・間接に `LoadLibrary` / `LoadLibraryEx` を呼ぶと
デッドロックやクラッシュにつながるため、初期化をできるだけ後へ移すよう案内している。
根拠: [Dynamic-Link Library Best Practices](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices)。

今回のDelphi 37では、System.SkiaのクラスコンストラクターがプラグインDLLのロード中に
実行され、`TSkObject` から `SkInitialize` へ進んでSkia DLLを読み込んでいた。
自作ユニットの `initialization` に `LoadLibrary` が見当たらなくても、この経路が残り得る。

別プラグインなどが先にSkiaをロードしている環境では、初回ロードに伴う問題が表面化しない
可能性がある。開発環境で起動できることだけでは、単独導入時の確認にならない。

`.auf2` と同じ場所にDLLを配置することと、適切な時点でDLLを初期化することは、両方必要となる。

## 導入するファイルと役割

| ファイル | 役割 |
| --- | --- |
| [Scripts/PrepareSkiaUnit.ps1](Scripts/PrepareSkiaUnit.ps1) | Delphi同梱System.Skiaから、明示的に初期化・終了する版を生成する |
| `Win64/SkiaOverride/System.Skia.pas` | ビルド時の生成物。クラスコンストラクター／デストラクターを遅延呼出しへ置き換える |
| [TextRendererSkiaBootstrap.pas](Source/Lib/TextRenderer/TextRendererSkiaBootstrap.pas) | プラグインと同じ場所にあるSkia DLLの絶対パスを解決する |
| [TextRendererSkiaRuntime.pas](Source/Lib/TextRenderer/TextRendererSkiaRuntime.pas) | DLLの取得・Skia初期化・参照数・明示的な終了を管理する |

ランタイム管理の2ユニットと生成スクリプトはSYNC_Lyricsの方式を採用した。
Graphの生成スクリプトには、途中の初期化失敗時にSkia APIの参照を戻す処理も含む。
コピー元と差分は [ランタイム管理の説明](Source/Lib/TextRenderer/README.md) を参照する。

他プロジェクトへは必要なファイルをコピーし、そのプロジェクト内で管理する。
GraphやLyricsのフォルダーへの絶対パス参照をビルドへ組み込まない。
各プラグインのランタイム管理ユニットの参照数は、そのモジュール内の取得・解放を管理する。
別プラグインの取得分まで解放してよいという意味ではない。

## プロジェクト設定

1. `.dproj` のビルド前処理で `PrepareSkiaUnit.ps1` を実行する。
2. 生成先をユニット検索パスの先頭へ置く。
3. `SKIA_DEFERRED_INIT` をDebug／Releaseの両方で定義する。
4. `.dpr` の `uses` で生成版System.Skiaを明示する。
5. Delphi本体のインストール先にあるソース・DCUは変更しない。

ビルド前処理の呼出し例（変数はMSBuildが展開する）:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File "$(MSBuildProjectDirectory)\Scripts\PrepareSkiaUnit.ps1" -BdsRoot "$(BDS)" -ProjectRoot "$(MSBuildProjectDirectory)"
```

`.dpr` の指定例:

```pascal
System.Skia in 'Win64\SkiaOverride\System.Skia.pas',
```

**生成版System.Skiaと `SKIA_DEFERRED_INIT` は必ず組で使う。**
Graphは定義なしのプラグインビルドをコンパイルエラーにしている。
通常の `.dproj` 経由でビルドし、生成版を使うのに定義だけ抜けた生成物を作らない。

現在の生成処理は8個のクラス初期化と対象の終了処理など、ソースの構造を検査する。
Delphi更新後に検査が失敗した場合、個数の条件だけを書き換えて通さず、
追加・変更された初期化と終了処理を確認してから生成処理を更新する。

## 初期化と終了の順序

| 呼出し区間 | 実施する処理 |
| --- | --- |
| `.auf2` の `LoadLibrary` 中 | Skiaをロード・初期化しない。軽量な状態や同期オブジェクトの準備に留める |
| `GetFilterPluginTable` | テーブル登録だけでSkiaがロードされないことを確認する |
| `InitializePlugin` | 同梱DLLを取得 → 遅延Skia初期化 → 描画用状態を生成 |
| 描画・設定画面 | 初期化済みランタイムを使い、各コールバックの所有資源を適切に解放 |
| `UninitializePlugin` | 利用中の処理がない状態で、Skia参照・キャッシュ・ストリームを解放 → ランタイムを解放 |
| `.auf2` のアンロード | Skiaのロード・明示的な終了・DLL解放を実行しない |

取得と解放の呼出しは次を使う。

```pascal
TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
// 初期化成功後にだけSkiaを使用する。
// 終了時は、Skiaオブジェクトをすべて破棄してから次を呼ぶ。
TTextRendererSkiaRuntime.Release;
```

実際には、初期化後の状態生成に失敗した場合にも取得済み参照を戻す例外処理を付ける。
重複した `InitializePlugin` で取得数だけが増えないようにし、繰り返しの終了や再初期化も確認する。
公開関数の外へDelphi例外を流さず、初期化失敗は戻り値0としてホストへ返す。

Graphでの接続例は [GraphPlugin.pas](Source/Host/GraphPlugin.pas)、
公開ABIの例外処理は [SYNC_Graph_Filter.dpr](SYNC_Graph_Filter.dpr) を参照する。
既存の委譲先で取得済みなら、公開関数にも同じ取得処理を追加しない。

### フォントや画像の寿命

`ISkTypeface`、`ISkFont`、`ISkImage` などの解放にもSkiaのコードが必要となる。
ランタイムを先に解放し、これらをユニットの `finalization` まで残すと、終了時のアクセス違反につながる。

Graphでは `ClearGraphFontCache` を公開終了から呼び、書体参照 → 参照先のフォントストリーム →
Skiaランタイムの順に解放する。移植先でも、プレビュー画像、描画コンテキスト、
グローバルなインターフェイス参照などを確認し、ランタイムより長く残さない。

## 配布・検証

配布ZIPにはプラグイン本体と、それに対応するWin64版 `sk4d.dll` を同じフォルダーで含める。
生成スクリプトは開発時のビルド処理であり、利用者の環境へDelphiを要求するものではない。
絶対パス指定だけで、複数プラグイン間のSkiaバージョンやAPIの互換性を保証することもできない。

移植後は次を確認する。

1. Win64 Debug／Releaseの両方を警告0・エラー0でビルドする。
2. Skiaをリンクしていない人工ホストの新しいプロセスで、ロード前にSkiaが存在しないことを確認する。
3. `.auf2` のロードとテーブル取得だけではSkiaがロードされず、公開初期化で初めてロードされることを確認する。
4. プラグインだけをコピーしてDLLを欠落させ、ホストを終了させず初期化失敗を返せることを確認する。
5. 描画・設定画面・フォント取得後に終了し、再初期化して再び描画できることを確認する。
6. 重複初期化・重複終了、単独導入、ほかのSkia使用プラグインとの併用を確認する。
7. 発生環境でAviUtl2の起動と通常操作を確認し、人工ホストでの結果と区別して記録する。

Graphの回帰検証は [Tests/run.ps1](Tests/run.ps1)、
単独ロード・DLL欠落の検証は [Tests/plugin_startup.ps1](Tests/plugin_startup.ps1) を参照する。

再発時は `%LOCALAPPDATA%\SYNC_Graph\Diagnostics\startup-*.log` にある
実際に結合したDLLのパス、失敗段階、例外アドレス、モジュール内の相対位置（RVA）を調べる。
MAPは同じバイナリのビルドで生成したものを使う。
first-chanceのアクセス違反記録には処理済み例外も含むため、それだけでクラッシュと判断しない。
