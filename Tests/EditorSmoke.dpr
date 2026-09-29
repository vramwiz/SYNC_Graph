program EditorSmoke;
{$APPTYPE CONSOLE}
// フォーム生成とモデル読み込みのスモークテスト。実ホスト操作とは区別する。
uses System.SysUtils, System.Types, Vcl.Forms, GraphEditorForm, GraphModel,
  GraphSettings, GraphView, GraphPainter, GraphTextToolbar, ToolbarIconButton,
  DarkComboBox, ColorPickerHueBar, ColorPickerSVArea,
  Vcl.StdCtrls, Vcl.Controls, Winapi.Windows,
  Winapi.Messages, GraphHostSettings, AviUtl2FilterTypes, Vcl.Graphics, Vcl.ComCtrls;
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
var F:TGraphEditorForm; D:TGraphDocument; S:TGraphShared; I:Integer;
  Edit:TEDIT_SECTION; K:TGraphKind; View:TGraphView;
  TestLabels:TArray<TGraphLabel>; IconX,IconY:Integer;
  Toolbar:TGraphTextToolbar; Button:TToolbarIconButton; Saved:TGraphDocument;
  FontCombo:TDarkComboBox; ComboCount:Integer;
  Hue:TColorPickerHueBar; SV:TColorPickerSVArea; CodeEdit:TEdit; CodeCount:Integer;
  {$IFDEF GRAPH_SNAPSHOT}Shot:TBitmap; Page:TPageControl; J,Ppi:Integer;{$ENDIF}
begin
  try
    Application.Initialize;
    F:=TGraphEditorForm.Create(nil);
    try
      F.Load(nil,640,480,'',DefaultShared);
      Writeln('PASS editor creation and load');
      Hue:=nil; SV:=nil; CodeEdit:=nil; CodeCount:=0;
      for I:=0 to F.ComponentCount-1 do
      begin
        if F.Components[I] is TColorPickerHueBar then Hue:=TColorPickerHueBar(F.Components[I]);
        if F.Components[I] is TColorPickerSVArea then SV:=TColorPickerSVArea(F.Components[I]);
        if (F.Components[I] is TEdit) and (TEdit(F.Components[I]).Parent<>nil) and
          (TEdit(F.Components[I]).Parent.Align=alBottom) then
        begin
          Inc(CodeCount); CodeEdit:=TEdit(F.Components[I]);
        end;
      end;
      if (Hue=nil) or (SV=nil) or (Hue.Parent<>SV.Parent) or
        (Hue.Parent.Align<>alBottom) or (Hue.Parent.Parent.Align<>alRight) or
        (SV.Width<>SV.Height) or (SV.Width>140) or (Hue.Height<>SV.Height) or
        (Hue.Left<=SV.Left+SV.Width) or (Hue.Width>=Hue.Height) or
        (CodeCount<>1) or (CodeEdit=nil) or (CodeEdit.Top<SV.Top+SV.Height) then
        raise Exception.Create('Color picker layout is wrong');
      CodeEdit.Text:='123456'; CodeEdit.OnExit(CodeEdit);
      if CodeEdit.Text<>'#123456' then
        raise Exception.Create('HEX color entry was not normalized');
      CodeEdit.Text:='255,128,0'; CodeEdit.OnExit(CodeEdit);
      if not SameText(CodeEdit.Text,'#ff8000') then
        raise Exception.Create('Decimal color entry was not normalized: '+CodeEdit.Text);
      Writeln('PASS color picker layout and code entry');
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
    F:=TGraphEditorForm.Create(nil);
    try
      F.Load(nil,640,480,'{broken',DefaultShared);
      PostMessage(F.Handle,WM_SYSCOMMAND,SC_CLOSE,0);
      F.ShowModal;
      Writeln('PASS editor opens damaged settings');
    finally F.Free; end;
    F:=TGraphEditorForm.Create(nil);
    D:=TGraphDocument.Create;
    try
      D.Kind:=gkBar; D.ResetBounds(500,300);
      View:=TGraphView.Create(F); View.Parent:=F; View.SetBounds(0,0,500,300);
      View.SetView(1,0,0);
      SetLength(TestLabels,1);
      TestLabels[0].ID:=0; TestLabels[0].Role:=trTitle;
      TestLabels[0].Bounds:=RectF(100,100,200,130);
      View.Bind(D,TestLabels);
      F.Show;
      View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(150,115));
      View.Perform(WM_LBUTTONUP,0,MakeLParam(150,115));
      IconX:=100+MulDiv(20,View.CurrentPPI,96);
      IconY:=130+MulDiv(28,View.CurrentPPI,96);
      View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(IconX,IconY));
      View.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(IconX+40,IconY));
      View.Perform(WM_LBUTTONUP,0,MakeLParam(IconX+40,IconY));
      if D.TextStyles[trTitle].OutlineWidth<=0 then raise Exception.Create('Outline icon drag did not enable decoration');
      View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(IconX,IconY));
      View.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(IconX-40,IconY));
      View.Perform(WM_LBUTTONUP,0,MakeLParam(IconX-40,IconY));
      if D.TextStyles[trTitle].OutlineWidth<>0 then raise Exception.Create('Outline icon drag did not disable decoration');
      Writeln('PASS decoration icon drag enables and disables outline');
      IconX:=IconX+MulDiv(34,View.CurrentPPI,96);
      View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(IconX,IconY));
      View.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(IconX+12,IconY+8));
      View.Perform(WM_LBUTTONUP,0,MakeLParam(IconX+12,IconY+8));
      if (D.TextStyles[trTitle].ShadowX=0) or (D.TextStyles[trTitle].ShadowY=0) then
        raise Exception.Create('Shadow icon drag did not set position');
      View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(IconX,IconY));
      View.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(IconX-11,IconY-7));
      View.Perform(WM_LBUTTONUP,0,MakeLParam(IconX-11,IconY-7));
      if (D.TextStyles[trTitle].ShadowX<>0) or (D.TextStyles[trTitle].ShadowY<>0) then
        raise Exception.Create('Shadow position did not snap to zero');
      Writeln('PASS shadow position snaps to zero');
      IconX:=IconX+MulDiv(34,View.CurrentPPI,96);
      View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(IconX,IconY));
      View.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(IconX+20,IconY));
      View.Perform(WM_LBUTTONUP,0,MakeLParam(IconX+20,IconY));
      if (D.TextStyles[trTitle].OutlineBlur<=0) or
        (D.TextStyles[trTitle].OutlineWidth<=0) then
        raise Exception.Create('Outline blur icon did not enable outline');
      IconX:=IconX+MulDiv(34,View.CurrentPPI,96);
      View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(IconX,IconY));
      View.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(IconX+20,IconY));
      View.Perform(WM_LBUTTONUP,0,MakeLParam(IconX+20,IconY));
      if D.TextStyles[trTitle].ShadowBlur<=0 then
        raise Exception.Create('Shadow blur icon did not enable shadow');
      Writeln('PASS blur icon drags enable decoration');
      F.Hide;
    finally D.Free; F.Free; end;
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
        View:=nil; Toolbar:=nil;
        for I:=0 to F.ComponentCount-1 do
        begin
          if F.Components[I] is TGraphView then View:=TGraphView(F.Components[I]);
          if F.Components[I] is TGraphTextToolbar then Toolbar:=TGraphTextToolbar(F.Components[I]);
        end;
        if (View=nil) or (Toolbar=nil) or Toolbar.Visible then
          raise Exception.Create('Text toolbar initial visibility is wrong');
        F.Show;
        IconX:=Round(View.PanX+960*View.Zoom);
        IconY:=Round(View.PanY+145*View.Zoom);
        View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(IconX,IconY));
        View.Perform(WM_LBUTTONUP,0,MakeLParam(IconX,IconY));
        if not Toolbar.Visible then raise Exception.Create('Text toolbar did not appear');
        FontCombo:=nil; ComboCount:=0;
        for I:=0 to Toolbar.ControlCount-1 do
          if Toolbar.Controls[I] is TDarkComboBox then
          begin Inc(ComboCount); FontCombo:=TDarkComboBox(Toolbar.Controls[I]); end;
        if (ComboCount<>1) or (FontCombo=nil) or (FontCombo.Items.Count=0) or
          (FontCombo.Font.Color<>$00EEEEEE) then
          raise Exception.Create('Font toolbar contents are wrong');
        Button:=nil;
        for I:=0 to Toolbar.ControlCount-1 do
          if (Toolbar.Controls[I] is TToolbarIconButton) and
            (TToolbarIconButton(Toolbar.Controls[I]).Tag=0) then
            Button:=TToolbarIconButton(Toolbar.Controls[I]);
        if Button=nil then raise Exception.Create('Bold tool is missing');
        Button.Click;
        Saved:=LoadGraph(F.Settings);
        try
          if not Saved.TextStyles[trTitle].Bold then
            raise Exception.Create('Bold tool did not update title style');
        finally Saved.Free; end;
        IconX:=Round(View.PanX+310*View.Zoom);
        IconY:=Round(View.PanY+240*View.Zoom);
        View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(IconX,IconY));
        View.Perform(WM_LBUTTONUP,0,MakeLParam(IconX,IconY));
        if Toolbar.Visible then raise Exception.Create('Text toolbar stayed visible for graph');
        Writeln('PASS text toolbar selection and bold action');
        F.Hide;
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
