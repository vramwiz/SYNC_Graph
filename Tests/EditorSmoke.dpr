program EditorSmoke;
{$APPTYPE CONSOLE}
// フォーム生成とモデル読み込みのスモークテスト。実ホスト操作とは区別する。
uses System.SysUtils, Vcl.Forms, GraphEditorForm, GraphModel, GraphSettings, Vcl.StdCtrls, Winapi.Windows, Winapi.Messages, GraphHostSettings, AviUtl2FilterTypes, Vcl.Graphics, Vcl.ComCtrls;
// 実ホストと同じエイリアス形式を返し、複数行の初期値で終了できるか確認する。
var StoredValues:UTF8String='0,0,0\n0,0,0\n0,0,0';
function GetItem(Obj:OBJECT_HANDLE; Effect,Item:LPCWSTR):PAnsiChar; cdecl;
begin
  if string(Item)='値' then Result:=PAnsiChar(StoredValues) else Result:=nil;
end;
function SetItem(Obj:OBJECT_HANDLE; Effect,Item:LPCWSTR; Value:PAnsiChar):LongBool; cdecl;
begin
  if string(Item)='値' then StoredValues:=UTF8String(Value);
  Result:=True;
end;
var F:TGraphEditorForm; D:TGraphDocument; S:TGraphShared; I:Integer; Edit:TEDIT_SECTION; K:TGraphKind; {$IFDEF GRAPH_SNAPSHOT}Shot:TBitmap; Page:TPageControl; J,Ppi:Integer;{$ENDIF}
begin
  try
    Application.Initialize;
    F:=TGraphEditorForm.Create(nil);
    try
      F.Load(nil,640,480,'',DefaultShared);
      Writeln('PASS editor creation and load');
      if not F.CloseQuery then
      begin
        for I:=0 to F.ComponentCount-1 do
          if F.Components[I] is TLabel then Writeln(TLabel(F.Components[I]).Caption);
        raise Exception.Create('Editor close rejected');
      end;
      Writeln('PASS editor close validation');
      PostMessage(F.Handle,WM_SYSCOMMAND,SC_CLOSE,0);
      F.ShowModal;
      Writeln('PASS editor modal close');
    finally F.Free; end;
    Edit:=Default(TEDIT_SECTION); Edit.GetObjectItemValue:=GetItem; Edit.SetObjectItemValue:=SetItem;
    S:=GraphHostSettings.ReadShared(@Edit,nil);
    if S.Values<>'0,0,0'#13#10'0,0,0'#13#10'0,0,0' then raise Exception.Create('Alias newline decode failed');
    D:=TGraphDocument.Create;
    try
      for K:=gkRadar to gkPie do
      begin
        D.Kind:=K; D.ResetBounds(640,480);
        F:=TGraphEditorForm.Create(nil);
        try
          F.Load(nil,640,480,SaveGraph(D),S);
          if not F.CloseQuery then raise Exception.Create('Graph close rejected');
          PostMessage(F.Handle,WM_SYSCOMMAND,SC_CLOSE,0); F.ShowModal;
          Writeln('PASS host multiline graph modal close ',Ord(K));
        finally F.Free; end;
      end;
      S.Values:='1,2,3'#13#10'4,5,6'#13#10'7,8,9';
      WriteSettings(@Edit,nil,S,SaveGraph(D));
      if StoredValues<>'1,2,3\n4,5,6\n7,8,9' then raise Exception.Create('Alias newline encode failed');
      Writeln('PASS host multiline write');
    finally D.Free; end;
    D:=TGraphDocument.Create;
    try
      D.Kind:=gkLine; D.ResetBounds(1920,1080); S:=DefaultShared;
      S.Values:='10,20,30'#13#10'15,25,35'#13#10'20,30,40';
      F:=TGraphEditorForm.Create(nil);
      try
        F.Load(nil,1920,1080,SaveGraph(D),S);
        Writeln('PASS editor graph render');
                {$IFDEF GRAPH_SNAPSHOT}
        F.Show;
        for Ppi in [96,144] do
        begin
          F.ScaleForPPI(Ppi);
          for I:=0 to F.ComponentCount-1 do
            if F.Components[I] is TPageControl then
            begin
              Page:=TPageControl(F.Components[I]);
              for J:=0 to Page.PageCount-1 do
              begin
                Page.ActivePageIndex:=J; F.Update; Application.ProcessMessages;
                Shot:=F.GetFormImage;
                try Shot.SaveToFile(ExtractFilePath(ParamStr(0))+Format('editor-%d-%d.bmp',[Ppi,J]));
                finally Shot.Free; end;
              end;
            end;
        end;
        F.Hide;
        {$ENDIF}
        {$IFDEF GRAPH_PREVIEW}F.ShowModal;{$ENDIF}
      finally F.Free; end;
    finally D.Free; end;
  except on E:Exception do begin Writeln(E.ClassName,': ',E.Message); ExitCode:=1; end; end;
end.
