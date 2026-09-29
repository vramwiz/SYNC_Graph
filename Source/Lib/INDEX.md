# 採用部品

出典は `D:\DelphiProg\test\DelphiVclAppTemplate\Source\Lib`。コピー後は本プロジェクトで管理する。

| 部品 | 状況・用途 | ローカル変更 |
| --- | --- | --- |
| [AviUtl2Canvas](AviUtl2Canvas/README.md) | 背景取得、ABI、項目登録、パン・ズーム | 表示の透明部分を黒へ変更。灰色作業面と外側描画フックを追加。Fitの余白を拡張 |
| [DarkComboBox](UI/DarkComboBox/README.md) | グラフ種類、装飾対象選択 | 本体変更なし |
| [ToolbarIcon](UI/ToolbarIcon/README.md) | 編集アイコン | csCaptureMouseを除外し、MouseUpより前の自動捕捉解除でクリックが失われる問題を修正 |
| [ColorPicker](UI/ColorPicker/README.md) | 色選択 | 本体変更なし |
| [DarkMenu](UI/DarkMenu/README.md) | 値書式プリセット | 本体変更なし |
| [HorizontalTrackBar](UI/HorizontalTrackBar/README.md) | 候補としてコピー済み、未使用 | 本体変更なし |
| [VerticalScrollBar](UI/VerticalScrollBar/README.md) | 候補としてコピー済み、未使用 | 本体変更なし |
| [ShortcutAction](UI/ShortcutAction/README.md) | 候補としてコピー済み、未使用 | 本体変更なし |

各部品のREADMEはコピー元の仕様と当時の確認結果を含む。本プロジェクトでの結果はルートREADMEを参照する。
旧SyncCanvasEditorとSyncCanvasPluginはコピー元の使用例として残しており、現在のDPRからは参照しない。

## DarkEditor 1.0.0
[説明](UI/DarkEditor/README.md)。今回のUI改良をDelphiVclAppTemplateのLibへ登録し、同一内容を採用。フォームの暗色化と日本語表の寸法を担当する。
