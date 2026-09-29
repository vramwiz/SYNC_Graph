program EditorSmoke;
{$APPTYPE CONSOLE}
// フォーム生成とモデル読み込みのスモークテスト。実ホスト操作とは区別する。
uses System.Classes, System.SysUtils, System.Types, Vcl.Forms, GraphEditorForm, GraphModel,
  GraphSettings, GraphView, GraphPainter, GraphTextToolbar, ToolbarIconButton,
  DarkComboBox, ColorPickerHueBar, ColorPickerSVArea, ColorPickerPanel,
  VerticalScrollBarControl, GraphNumberEdit, GraphLayoutPanel, GraphDataPanel,
  GraphStylePanel,
  HorizontalTrackBarControl,
  Vcl.StdCtrls, Vcl.Controls, Winapi.Windows,
  Winapi.Messages, GraphHostSettings, AviUtl2FilterTypes, Vcl.Graphics, Vcl.ComCtrls;
// 実ホストと同じエイリアス形式を返し、複数行の初期値で終了できるか確認する。
type TNumberProbe=class(TGraphNumberEdit)
  function WheelOnDigit(Index,Delta:Integer):Boolean;
end;
function TNumberProbe.WheelOnDigit(Index,Delta:Integer):Boolean;
var Location:TPoint;
begin
  Canvas.Font.Assign(Font);
  Location:=ClientToScreen(Point(4+Canvas.TextWidth(Copy(Text,1,Index))+2,Height div 2));
  Result:=DoMouseWheel([],Delta,Location);
end;
function FindLayout(Root:TComponent):TGraphLayoutPanel;
var I:Integer;
begin
  Result:=nil;
  for I:=0 to Root.ComponentCount-1 do
  begin
    if Root.Components[I] is TGraphLayoutPanel then
      Exit(TGraphLayoutPanel(Root.Components[I]));
    Result:=FindLayout(Root.Components[I]);
    if Result<>nil then Exit;
  end;
end;
function FindData(Root:TComponent):TGraphDataPanel;
var I:Integer;
begin
  Result:=nil;
  for I:=0 to Root.ComponentCount-1 do
  begin
    if Root.Components[I] is TGraphDataPanel then
      Exit(TGraphDataPanel(Root.Components[I]));
    Result:=FindData(Root.Components[I]);
    if Result<>nil then Exit;
  end;
end;
function FindStyle(Root:TComponent):TGraphStylePanel;
var I:Integer;
begin
  Result:=nil;
  for I:=0 to Root.ComponentCount-1 do
  begin
    if Root.Components[I] is TGraphStylePanel then
      Exit(TGraphStylePanel(Root.Components[I]));
    Result:=FindStyle(Root.Components[I]);
    if Result<>nil then Exit;
  end;
end;
function FindPicker(Root:TComponent):TColorPickerPanel;
var I:Integer;
begin
  Result:=nil;
  for I:=0 to Root.ComponentCount-1 do
  begin
    if Root.Components[I] is TColorPickerPanel then
      Exit(TColorPickerPanel(Root.Components[I]));
    Result:=FindPicker(Root.Components[I]);
    if Result<>nil then Exit;
  end;
end;
function FindScroll(Root:TComponent):TVerticalScrollBarControl;
var I:Integer;
begin
  Result:=nil;
  for I:=0 to Root.ComponentCount-1 do
  begin
    if Root.Components[I] is TVerticalScrollBarControl then
      Exit(TVerticalScrollBarControl(Root.Components[I]));
    Result:=FindScroll(Root.Components[I]);
    if Result<>nil then Exit;
  end;
end;
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
  Picker:TColorPickerPanel; Scroll:TVerticalScrollBarControl;
  Number:TNumberProbe; Layout:TGraphLayoutPanel; Preset:TDarkComboBox;
  Data:TGraphDataPanel; NameFirst,NameSecond:TEdit; Key:Word;
  WheelHandled:Boolean;
  Style:TGraphStylePanel; Mode,Target:TDarkComboBox;
  WidthSlider:THorizontalTrackBarControl; LineKind:TComboBox;
  WheelEdit:TGraphNumberEdit; ActiveNumberEdit:TEdit; WheelPoint:TPoint;
  OldPosition:Integer;
  {$IFDEF GRAPH_SNAPSHOT}Shot:TBitmap; Ppi:Integer;{$ENDIF}
begin
  try
    Application.Initialize;
    F:=TGraphEditorForm.Create(nil);
    try
      F.Load(nil,640,480,'',DefaultShared);
      Writeln('PASS editor creation and load');
      Hue:=nil; SV:=nil; CodeEdit:=nil; CodeCount:=0;
      Picker:=FindPicker(F); Scroll:=FindScroll(F);
      for I:=0 to F.ComponentCount-1 do
      begin
        if F.Components[I] is TPageControl then
          raise Exception.Create('PageControl remains in editor');
      end;
      if Picker=nil then raise Exception.Create('Common color picker is missing');
      if (Picker.Parent.Width<300) or (Picker.Parent.Width>320) then
        raise Exception.Create('Settings panel width was not reduced');
      for I:=0 to Picker.ComponentCount-1 do
      begin
        if Picker.Components[I] is TColorPickerHueBar then Hue:=TColorPickerHueBar(Picker.Components[I]);
        if Picker.Components[I] is TColorPickerSVArea then SV:=TColorPickerSVArea(Picker.Components[I]);
        if Picker.Components[I] is TEdit then
        begin
          Inc(CodeCount); CodeEdit:=TEdit(Picker.Components[I]);
        end;
      end;
      if (Hue=nil) or (SV=nil) or (Hue.Parent<>SV.Parent) or
        (Picker.Align<>alBottom) or (Picker.Parent.Align<>alRight) or
        (SV.Width<>SV.Height) or (SV.Width>140) or (Hue.Height<>SV.Height) or
        (Hue.Left<=SV.Left+SV.Width) or (Hue.Width>=Hue.Height) or
        (CodeCount<>1) or (CodeEdit=nil) or (CodeEdit.Top<SV.Top+SV.Height) or
        (Scroll=nil) or (Scroll.Maximum<=0) then
        raise Exception.Create(Format('Color picker layout is wrong: picker=%d,%d SV=%d,%d hue=%d,%d code=%d count=%d scroll=%d',
          [Picker.Width,Picker.Height,SV.Width,SV.Height,Hue.Width,Hue.Height,CodeEdit.Top,CodeCount,Scroll.Maximum]));
      CodeEdit.Text:='123456'; CodeEdit.OnExit(CodeEdit);
      if CodeEdit.Text<>'#123456' then
        raise Exception.Create('HEX color entry was not normalized');
      CodeEdit.Text:='255,128,0'; CodeEdit.OnExit(CodeEdit);
      if not SameText(CodeEdit.Text,'#ff8000') then
        raise Exception.Create('Decimal color entry was not normalized: '+CodeEdit.Text);
      Saved:=LoadGraph(F.Settings);
      try
        if Saved.Lines[0].Color<>$FFFF8000 then
          raise Exception.Create('Shared picker did not update the selected line color');
      finally Saved.Free; end;
      Style:=FindStyle(F); Mode:=nil; Target:=nil;
      WidthSlider:=nil; LineKind:=nil;
      if Style=nil then raise Exception.Create('Style panel is missing');
      for I:=0 to Style.ComponentCount-1 do
      begin
        if (Style.Components[I] is THorizontalTrackBarControl) and
          (THorizontalTrackBarControl(Style.Components[I]).Top=180) then
          WidthSlider:=THorizontalTrackBarControl(Style.Components[I]);
        if (Style.Components[I] is TComboBox) and
          (TComboBox(Style.Components[I]).Top=112) then
          LineKind:=TComboBox(Style.Components[I]);
        if Style.Components[I] is TDarkComboBox then
        begin
          if (TDarkComboBox(Style.Components[I]).Top=36) and
            (TDarkComboBox(Style.Components[I]).Left=12) then
            Mode:=TDarkComboBox(Style.Components[I]);
          if TDarkComboBox(Style.Components[I]).Top=326 then
            Target:=TDarkComboBox(Style.Components[I]);
        end;
      end;
      if (Mode=nil) or (Target=nil) or (WidthSlider=nil) or (LineKind=nil) then
        raise Exception.Create('Color target selectors are missing');
      if (LineKind.ItemHeight<26) or (LineKind.DropDownWidth<LineKind.Width) or
        not WidthSlider.WheelChangesPosition then
        raise Exception.Create('Line list or slider wheel setup is wrong');
      WidthSlider.Position:=75;
      LineKind.ItemIndex:=2; LineKind.OnChange(LineKind);
      Saved:=LoadGraph(F.Settings);
      try
        if (Abs(Saved.Lines[0].Width-7.5)>0.001) or (Saved.Lines[0].Kind<>2) then
          raise Exception.Create('Dedicated line tools did not update model');
      finally Saved.Free; end;
      Mode.ItemIndex:=1; Mode.OnChange(Mode);
      Target.ItemIndex:=1; Target.OnChange(Target);
      CodeEdit.Text:='#abcdef'; CodeEdit.OnExit(CodeEdit);
      Saved:=LoadGraph(F.Settings);
      try
        if Saved.Series[0].FillColor<>$FFABCDEF then
          raise Exception.Create('Shared picker did not update series fill');
      finally Saved.Free; end;
      Writeln('PASS color picker layout and code entry');
      Number:=TNumberProbe.Create(F);
      try
        Number.Parent:=F; Number.SetBounds(240,8,180,28);
        Number.Text:='1234.56';
        if not Number.WheelOnDigit(0,120) or (Number.Text<>'2234.56') then
          raise Exception.Create('Number wheel did not increase the thousands digit: '+Number.Text);
        if not Number.WheelOnDigit(6,120) or (Number.Text<>'2234.57') then
          raise Exception.Create('Number wheel did not increase the hundredths digit: '+Number.Text);
      finally Number.Free; end;
      Writeln('PASS number digit wheel');
      Scroll.Position:=100; WheelHandled:=False;
      F.OnMouseWheel(F,[],120,F.ClientToScreen(Point(1000,200)),WheelHandled);
      if not WheelHandled or (Scroll.Position>=100) then
        raise Exception.Create('Settings wheel did not scroll vertically');
      Scroll.Position:=0;
      Writeln('PASS settings wheel scroll');
      Data:=FindData(F); NameFirst:=nil; NameSecond:=nil;
      if Data=nil then raise Exception.Create('Data panel is missing');
      for I:=0 to Data.ComponentCount-1 do
        if Data.Components[I] is TEdit then
        begin
          if (TEdit(Data.Components[I]).Left=40) and
            (TEdit(Data.Components[I]).Top=200) then
            NameFirst:=TEdit(Data.Components[I]);
          if (TEdit(Data.Components[I]).Left=40) and
            (TEdit(Data.Components[I]).Top=240) then
            NameSecond:=TEdit(Data.Components[I]);
        end;
      if (NameFirst=nil) or (NameSecond=nil) then
        raise Exception.Create('Row editors are missing');
      F.Show;
      Layout:=FindLayout(F); WheelEdit:=nil;
      D:=LoadGraph(F.Settings);
      try
        D.Bounds:=RectF(12,34,567,890);
        Layout.Apply(D);
        if (D.Bounds.Left<>12) or (D.Bounds.Top<>34) or
          (D.Bounds.Right<>567) or (D.Bounds.Bottom<>890) then
          raise Exception.Create('Settings panel overwrote canvas bounds');
      finally D.Free; end;
      for I:=0 to Layout.ComponentCount-1 do
        if (Layout.Components[I] is TGraphNumberEdit) and
          (TGraphNumberEdit(Layout.Components[I]).Top=228) then
          WheelEdit:=TGraphNumberEdit(Layout.Components[I]);
      if WheelEdit=nil then raise Exception.Create('Rotation number edit is missing');
      WheelEdit.Text:='10';
      WheelHandled:=False;
      F.OnMouseWheel(F,[],120,WheelEdit.ClientToScreen(
        Point(6,WheelEdit.Height div 2)),WheelHandled);
      if not WheelHandled or (WheelEdit.Text<>'20') then
        raise Exception.Create('Form wheel did not reach number edit');
      WheelPoint:=WheelEdit.ClientToScreen(Point(6,WheelEdit.Height div 2));
      SendMessage(WheelEdit.Handle,WM_MOUSEWHEEL,MakeWParam(0,120),
        MakeLParam(WheelPoint.X,WheelPoint.Y));
      if WheelEdit.Text<>'30' then
        raise Exception.Create('Window wheel message did not reach displayed number');
      Scroll.Position:=100; WheelHandled:=False;
      F.OnMouseWheel(F,[],120,WheelEdit.ClientToScreen(
        Point(80,WheelEdit.Height div 2)),WheelHandled);
      if not WheelHandled or (Scroll.Position>=100) then
        raise Exception.Create('Wheel outside a digit did not scroll settings');
      Scroll.Position:=0;
      SendMessage(WheelEdit.Handle,WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(6,WheelEdit.Height div 2));
      ActiveNumberEdit:=nil;
      for I:=0 to WheelEdit.ControlCount-1 do
        if WheelEdit.Controls[I] is TEdit then
          ActiveNumberEdit:=TEdit(WheelEdit.Controls[I]);
      if (ActiveNumberEdit=nil) or not ActiveNumberEdit.Visible or
        (ActiveNumberEdit.SelLength<>Length(WheelEdit.Text)) then
        raise Exception.Create('Number edit did not select all text on entry');
      ActiveNumberEdit.Text:='37'; Key:=VK_RETURN;
      ActiveNumberEdit.OnKeyDown(ActiveNumberEdit,Key,[]);
      if WheelEdit.Editing or (WheelEdit.Text<>'37') then
        raise Exception.Create('Enter did not commit number edit');
      WheelEdit.BeginEdit; ActiveNumberEdit.Text:='99'; Key:=VK_ESCAPE;
      ActiveNumberEdit.OnKeyDown(ActiveNumberEdit,Key,[]);
      if WheelEdit.Editing or (WheelEdit.Text<>'37') then
        raise Exception.Create('Escape did not restore number edit');
      WheelEdit.BeginEdit; ActiveNumberEdit.Text:='41'; NameFirst.SetFocus;
      if WheelEdit.Editing or (WheelEdit.Text<>'41') then
        raise Exception.Create('Focus loss did not commit number edit');
      Mode.ItemIndex:=0; Mode.OnChange(Mode);
      Scroll.Position:=Scroll.Maximum;
      OldPosition:=WidthSlider.Position; WheelHandled:=False;
      F.OnMouseWheel(F,[],120,WidthSlider.ClientToScreen(Point(20,16)),WheelHandled);
      if not WheelHandled or (WidthSlider.Position<=OldPosition) then
        raise Exception.Create('Form wheel did not reach line width slider');
      Scroll.Position:=0;
      NameFirst.SetFocus; Key:=VK_DOWN;
      NameFirst.OnKeyDown(NameFirst,Key,[]);
      if (Key<>0) or (F.ActiveControl<>NameSecond) then
        raise Exception.Create('Down key did not focus next row');
      F.Hide;
      Writeln('PASS row edit keyboard navigation');
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
    D:=TGraphDocument.Create;
    try
      D.Kind:=gkLine; D.ResetBounds(640,480); D.Offsets[2].X:=13;
      F:=TGraphEditorForm.Create(nil);
      try
        F.Load(nil,640,480,SaveGraph(D),DefaultShared);
        Layout:=FindLayout(F); Preset:=nil; Button:=nil;
        if Layout=nil then raise Exception.Create('Layout panel is missing');
        for I:=0 to Layout.ComponentCount-1 do
          if (Layout.Components[I] is TDarkComboBox) and
            (TDarkComboBox(Layout.Components[I]).Items.Count=3) then
            Preset:=TDarkComboBox(Layout.Components[I]);
        for I:=0 to F.ComponentCount-1 do
          if (F.Components[I] is TToolbarIconButton) and
            (TToolbarIconButton(F.Components[I]).Tag=4) then
            Button:=TToolbarIconButton(F.Components[I]);
        if (Preset=nil) or (Button=nil) then
          raise Exception.Create('Preset or undo tool is missing');
        Preset.ItemIndex:=1; Preset.OnChange(Preset);
        if not F.CloseQuery then raise Exception.Create('Preset change rejected');
        Saved:=LoadGraph(F.Settings);
        try
          if (Saved.NameLayout<>1) or (Saved.Offsets[2].X<>0) then
            raise Exception.Create('Preset did not reset manual name position');
        finally Saved.Free; end;
        Button.Click;
        Saved:=LoadGraph(F.Settings);
        try
          if (Saved.NameLayout<>0) or (Saved.Offsets[2].X<>13) then
            raise Exception.Create(Format('Preset undo did not restore name position: %d, %.2f',
              [Saved.NameLayout,Saved.Offsets[2].X]));
        finally Saved.Free; end;
        Writeln('PASS name layout preset undo');
      finally F.Free; end;
    finally D.Free; end;
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
        Button:=nil; CodeEdit:=nil;
        for I:=0 to Toolbar.ControlCount-1 do
          if (Toolbar.Controls[I] is TToolbarIconButton) and
            (TToolbarIconButton(Toolbar.Controls[I]).Tag=2) then
            Button:=TToolbarIconButton(Toolbar.Controls[I]);
        Picker:=FindPicker(F);
        if (Button=nil) or (Picker=nil) then
          raise Exception.Create('Shared text color picker is missing');
        for I:=0 to Picker.ComponentCount-1 do
          if Picker.Components[I] is TEdit then CodeEdit:=TEdit(Picker.Components[I]);
        if CodeEdit=nil then raise Exception.Create('Color code edit is missing');
        Button.Click;
        CodeEdit.Text:='#224466'; CodeEdit.OnExit(CodeEdit);
        Saved:=LoadGraph(F.Settings);
        try
          if Saved.TextStyles[trTitle].Color<>$FF224466 then
            raise Exception.Create('Shared picker did not update title color');
        finally Saved.Free; end;
        Writeln('PASS shared picker updates selected text color');
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
          F.Update; Application.ProcessMessages;
          Shot:=F.GetFormImage;
          try Shot.SaveToFile(ExtractFilePath(ParamStr(0))+Format('editor-%d.bmp',[Ppi]));
          finally Shot.Free; end;
          Scroll:=FindScroll(F);
          if Scroll<>nil then
          begin
              Scroll.Position:=Scroll.Maximum; F.Update; Application.ProcessMessages;
              Shot:=F.GetFormImage;
              try Shot.SaveToFile(ExtractFilePath(ParamStr(0))+Format('editor-scroll-%d.bmp',[Ppi]));
              finally Shot.Free; end;
              Scroll.Position:=0;
            end;
        end;
        F.Hide;
        {$ENDIF}
        {$IFDEF GRAPH_PREVIEW}F.ShowModal;{$ENDIF}
      finally F.Free; end;
    finally D.Free; end;
  except on E:Exception do begin Writeln(E.ClassName,': ',E.Message); ExitCode:=1; end; end;
end.
