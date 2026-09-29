unit DarkEditorTheme;

// フォーム単位の暗色スタイルと、文字が欠けない編集表の寸法を共有する。
interface
uses Vcl.Forms, Vcl.Grids;
procedure ApplyDarkEditor(Form:TForm);
procedure SetupEditorGrid(Grid:TCustomDrawGrid; KeyWidth:Integer);
implementation
uses System.Classes, System.SysUtils, System.Math, Winapi.Windows,
  Vcl.Themes, Vcl.Styles, Vcl.Graphics;
{$R DarkEditorStyle.res}
type TGridAccess=class(TCustomDrawGrid);

procedure ApplyDarkEditor(Form:TForm);
begin
  // スタイル未指定のフォームはOS配色を維持し、明示指定したフォームだけを暗色にする。
  if TStyleManager.Style['Windows Modern Dark']=nil then
    TStyleManager.LoadFromResource(HInstance,'SYNC_DARK_EDITOR');
  if not TStyleManager.IsCustomStyleActive then
  begin
    TStyleManager.UseSystemStyleAsDefault:=True;
    TStyleManager.SetStyle('Windows Modern Dark');
  end;
  Form.StyleName:='Windows Modern Dark';
  Form.Font.Name:='Yu Gothic UI'; Form.Font.Size:=10;
  Form.Font.Color:=$00EEEEEE; Form.Color:=$00282828;
end;

procedure SetupEditorGrid(Grid:TCustomDrawGrid; KeyWidth:Integer);
begin
  // VCL既定の行高は日本語フォントより低い場合がある。実測文字高に余白を加える。
  TGridAccess(Grid).Canvas.Font.Assign(TGridAccess(Grid).Font);
  TGridAccess(Grid).DefaultRowHeight:=Max(MulDiv(30,Grid.CurrentPPI,96),
    TGridAccess(Grid).Canvas.TextHeight('国Ag')+MulDiv(10,Grid.CurrentPPI,96));
  TGridAccess(Grid).Color:=$00303030; TGridAccess(Grid).FixedColor:=$00383838;
  TGridAccess(Grid).Font.Color:=$00EEEEEE;
  // 常時表示のインプレース編集欄が選択色を覆うため、選択と文字編集を分ける。
  // 通常時は選択セルを強調し、入力開始・F2・ダブルクリックで編集欄を表示する。
  TGridAccess(Grid).Options:=(TGridAccess(Grid).Options+[goDrawFocusSelected])-[goAlwaysShowEditor];
  TGridAccess(Grid).ColWidths[0]:=MulDiv(KeyWidth,Grid.CurrentPPI,96);
  TGridAccess(Grid).ColWidths[1]:=Max(MulDiv(100,Grid.CurrentPPI,96),
    Grid.ClientWidth-TGridAccess(Grid).ColWidths[0]-MulDiv(24,Grid.CurrentPPI,96));
end;
end.