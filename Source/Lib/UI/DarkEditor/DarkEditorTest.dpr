program DarkEditorTest;

// 既定フォームを作らず、フォーム単位のスタイルと日本語の編集表を確認する。
uses Vcl.Forms, Vcl.ValEdit, Vcl.Controls, DarkEditorTheme;
var Form:TForm; Grid:TValueListEditor;
begin
  Application.Initialize;
  Form:=TForm.CreateNew(nil);
  try
    ApplyDarkEditor(Form); Form.Caption:='DarkEditor';
    Form.ClientWidth:=460; Form.ClientHeight:=400;
    Grid:=TValueListEditor.Create(Form); Grid.Parent:=Form;
    Grid.SetBounds(12,12,436,376); Grid.Anchors:=[akLeft,akTop,akRight,akBottom];
    SetupEditorGrid(Grid,220);
    Grid.InsertRow('日本語の項目名','編集できます',True);
    Form.ShowModal;
  finally Form.Free; end;
end.