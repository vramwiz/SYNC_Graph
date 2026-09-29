# ツールバー用アイコンボタン

- ID: `toolbar-icon`
- 版: 1.0.0（2026-09-29）
- 種別・タグ: UI部品、ツールバー、独自アイコン、イベント描画、継承
- 動作条件: Delphi 37 / Win64 / VCL・RTL・Windows標準ユニットのみ。
- 参照元: 同層のSYNC_ScreenLayoutにある `Source/Shell/Toolbars/ScreenLayoutEditActionsUI.pas` と `ScreenLayoutLineStyleControls.pas`。
- 元のボタン配色・描画方式を参考に、文書・Undo・図形の依存を持たない共通部品として新規実装。参照元は変更していない。

## コピーするもの

`ToolbarIconButton.pas` だけを利用アプリにコピーする。
テストのアイコンはサンプルであり、本体に絵柄やアプリの処理は含まない。
配置にはVCLのTFlowPanel/TPanelなどを使う。ボタンのAlign・Anchors・Margins・サイズを利用側で指定する。ツールバー全体の項目管理や折り返しは配置先の責務。

## 共通部品と利用側の責務

共通部品は背景・枠・フォーカス、ホバー、押下、選択、無効状態を描画する。
左ボタンを押して同じボタン内で離した場合にOnClickを発火する。外へドラッグして離した場合は実行しない。
キーボードのSpace/Enterも離した時に実行し、キーリピートによる連続実行を避ける。Esc・フォーカス喪失・キャプチャ喪失で押下を取り消す。Tabによる移動を維持する。
`Selected` は表示状態。`AutoToggle=True` の場合はクリック時にSelectedを反転してからOnClickを呼ぶ。
排他的な選択や文書状態との同期は利用側で行う。通常ボタンはAutoToggle=Falseのまま使用する。
Enabled=FalseではClickを直接呼んでも実行しない。Hintを設定してアイコンの意味を説明する。

## イベントで描く

```pascal
FButton := TToolbarIconButton.Create(Self);
FButton.Parent := ToolbarPanel;
FButton.SetBounds(0, 0, MulDiv(36, CurrentPPI, 96), MulDiv(36, CurrentPPI, 96));
FButton.Hint := '追加';
FButton.OnDrawIcon := DrawAddIcon;
FButton.OnClick := AddClick;
```

OnDrawIconの引数はSender、TCanvas、Bounds、TToolbarIconState。
StateにはEnabled/Hot/Pressed/Selected/Focused、PPI、推奨Foreground色が入る。
Boundsは余白を除いたクライアント座標の実ピクセル矩形であり、再度DPI倍率を掛けない。線幅など96 DPI基準の定数は `MulDiv(Value, State.PPI, 96)` で換算する。
無効色を含む描画色は `State.Foreground` を使うと共通表示に揃う。独自配色の場合は無効状態の表現も利用側で決める。
アイコン描画はBoundsにクリップし、描画後にCanvasのPen/Brush/FontとGDI状態を復元する。
描画コールバックではモデルを書き換えず、Canvasを保持・解放しない。絵柄のデータが変わったらボタンのInvalidateを呼ぶ。

## 継承で描く

```pascal
type
  TMyIconButton = class(TToolbarIconButton)
  protected
    procedure DrawIcon(ACanvas: TCanvas; const Bounds: TRect;
      const State: TToolbarIconState); override;
  end;
```

派生クラスではDrawIconだけを上書きする。Paintを上書きすると共通背景・状態表示も置き換わるため、絵柄の変更には使用しない。
基底DrawIconがOnDrawIconを呼ぶ。派生側でinheritedを呼ばなければ継承側の描画のみ、呼べばイベント描画も実行される。通常はどちらか一方を選ぶ。
描画イベントもオーバーライドもない場合、背景・枠だけを表示する。

## 最小テスト

[ToolbarIconTest.dproj](ToolbarIconTest.dproj) を開く。
[ToolbarIconTestForm.pas](ToolbarIconTestForm.pas)にイベント描画の＋と、継承描画の円の使用例がある。
本体・テストプロジェクト・フォーム・RESはこのフォルダーにまとめてある。

1. ＋、円をクリックし、クリック回数が1回ずつ増えること。
2. 3番目のボタンで選択状態が切り替わること。チェック欄で無効化し、実行されないこと。
3. 最初から無効の4番目は色が変わり、クリックできないこと。
4. ボタン内で押して外で離す、外へ出て戻って離す、Esc、別ウィンドウへの切替を確認する。
5. Tab移動、Space/Enter、キー長押し、ツールチップを確認する。
6. 異なるDPIでサイズ・絵柄・クリック領域が一致することを確認する。

RAD Studio環境を読み込み、このフォルダーでビルドする。

```bat
msbuild ToolbarIconTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
msbuild ToolbarIconTest.dproj /t:Build /p:Config=Release /p:Platform=Win64 /v:minimal
```

出力は `Win64/<構成>/ToolbarIconTest.exe`。
2026-09-29: Debug/Releaseとも警告0・エラー0でビルド成功。実行・実操作・DPI確認は利用者が行うため未確認。
独自描画コントロールであり、標準ボタン相当のスクリーンリーダー対応やTActionとの自動連携は提供しない。
