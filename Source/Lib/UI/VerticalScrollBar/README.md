# 独自縦スクロールバー

- ID: `vertical-scrollbar`
- 版: 1.0.0（2026-09-28登録）
- 種別: UI部品
- 用途・タグ: 縦スクロール、暗色UI、独自描画、VCL、一覧・パネル
- 出典: `D:\DelphiProg\test\MapRaku\Lib\VerticalScrollBar\VerticalScrollBarControl.pas` の登録日時点のコピー。初版は本体の変更なし。
- 環境・依存: Delphi 37、Win64、VCL・RTL・Windows標準ユニットのみ。MapRakuモデル、外部DLL、他の登録部品には依存しない。

## コピー対象

`VerticalScrollBarControl.pas` の1ファイルを利用側プロジェクトへコピーする。
クラスは `TVerticalScrollBarControl`。フォーム上でコードから生成する。設計時パッケージのインストールは不要。
表示内容の管理や描画、選択、保存、Undoは含まない。

## 使い方

```pascal
FScrollBar := TVerticalScrollBarControl.Create(Self);
FScrollBar.Parent := ContentPanel;
FScrollBar.Align := alRight;
FScrollBar.Width := MulDiv(14, CurrentPPI, 96);
FScrollBar.SmallChange := RowHeight;
FScrollBar.LargeChange := Max(RowHeight, ViewHeight - RowHeight);
FScrollBar.OnChange := ScrollChanged;
FScrollBar.SetRange(Max(0, ContentHeight - ViewHeight), Max(1, ViewHeight));
```

この例では `System.Math` と `Winapi.Windows` もusesへ追加する。
`ScrollChanged` で `FScrollBar.Position` を表示位置に反映し、内容を再描画する。
描画位置は通常 `内容のY座標 - Position` とする。実装例は [テストフォーム](VerticalScrollBarTestForm.pas) を参照。

| 設定 | 意味 |
| --- | --- |
| Maximum | 最大移動量。全体の高さではなく、通常は内容高−表示高 |
| PageSize | 表示領域の大きさ。つまみの長さ計算に使用 |
| Position | 0～Maximumの現在位置。設定値は範囲内へ補正 |
| SmallChange | ホイール1刻み・上下キーの移動量 |
| LargeChange | トラッククリック・PageUp/Downの移動量 |
| OnChange | Positionが変化した場合の通知。範囲縮小による補正でも発生 |
| BackgroundColor / TrackColor / ThumbColor / ThumbBorderColor | 背景・トラック・つまみ・枠線の色 |

内容サイズや表示サイズが変わったら `SetRange` を呼ぶ。
Maximumが0ではつまみを描かない。必要なら利用側でVisibleも変更する。
通知内から範囲・位置を再更新する場合は、利用側で再入を防ぐ。
内容領域上でのホイール処理も利用側が担当する。バー自身のホイール処理とは二重に適用しない。
つまみの最小高や余白はCurrentPPIに追従する。バー幅と移動量は利用側で適切に設定する。

## 最小テストプロジェクト

このフォルダーの [VerticalScrollBarTest.dproj](VerticalScrollBarTest.dproj) を開く。
DPR・DPROJ・RESとテストフォームはライブラリ本体ユニットと同じフォルダーに置く。
番号付き行の表示は使用例であり、汎用リスト部品として登録したものではない。

RAD Studioの環境を読み込んだコマンドプロンプトで、このライブラリのフォルダーから実行する。

```bat
msbuild VerticalScrollBarTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
msbuild VerticalScrollBarTest.dproj /t:Build /p:Config=Release /p:Platform=Win64 /v:minimal
```

出力: `Win64/<構成>/VerticalScrollBarTest.exe`

手動確認:

1. 100行・1000行でつまみをドラッグし、行表示とPositionが連動すること。
2. バーと内容領域の両方でホイール操作し、先頭・末尾で停止すること。
3. トラッククリックでページ移動すること。バーへフォーカスを置き、上下・PageUp/Down・Home/Endを確認すること。
4. 末尾へ移動してから3行・0行へ変更し、位置が補正され、不要なつまみが消えること。
5. ウィンドウをリサイズし、範囲・つまみの長さが追従すること。
6. 無効状態で操作できないこと。ドラッグ中に別ウィンドウへ切り替え、戻った後の状態を確認すること。
7. 異なるDPIの画面でサイズと当たり判定を確認すること。

## 確認状況・制約

- 2026-09-28: Win64 Debug / Releaseともビルド成功、警告0・エラー0。元ファイルとのSHA-256一致を確認済み。実行・マウス操作・キー操作は未確認で、利用者が確認する。
- 縦方向のみ。トラック長押しの自動リピートは実装されていない。
- キャプチャ喪失時の明示的なドラッグ状態リセット、矢印キーのダイアログキー処理、DPI変更時の実操作は要確認。KeyDown実装があることと実際のキー配送の確認は区別する。
- 整数ピクセル単位の範囲を想定。極端に大きい範囲の整数オーバーフロー対策は未実施。
- ホストアプリへの参照や自動配布は行わず、利用側がコピーして組み込む。
