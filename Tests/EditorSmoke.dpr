program EditorSmoke;
{$APPTYPE CONSOLE}
// フォーム生成とモデル読み込みのスモークテスト。実ホスト操作とは区別する。
uses System.JSON, System.IOUtils, System.Classes, System.SysUtils, System.Types, Vcl.Forms, GraphEditorForm, GraphModel,
  GraphSettings, GraphView, GraphPainter, GraphRenderer, GraphAnimation, GraphTextToolbar, ToolbarIconButton,
  DarkComboBox, ColorPickerHueBar, ColorPickerSVArea, ColorPickerPanel,
  VerticalScrollBarControl, GraphNumberEdit, GraphLayoutPanel, GraphDataPanel,
  GraphStylePanel, GraphColorStylePanel, GraphSettingsPane, GraphTextSnap,
  HorizontalTrackBarControl,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Controls, Winapi.Windows,
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
procedure CheckCountInputs(Owner:TComponent);
var Panel:TGraphLayoutPanel; Doc:TGraphDocument; I:Integer; Spin:TUpDown;
begin
  Doc:=TGraphDocument.Create; Panel:=TGraphLayoutPanel.Create(Owner);
  try
    Panel.Load(Doc);
    for I:=0 to Panel.ComponentCount-1 do
      if Panel.Components[I] is TUpDown then
      begin
        Spin:=TUpDown(Panel.Components[I]); Spin.OnClick(Spin,btNext);
        Panel.Apply(Doc);
        if ((Spin.Tag=68) and (Doc.Rows<>4)) or ((Spin.Tag=216) and (Doc.Columns<>4)) then
          raise Exception.Create('Count up arrow did not increment');
        Spin.OnClick(Spin,btPrev); Panel.Apply(Doc);
        if (Doc.Rows<>3) or (Doc.Columns<>3) then raise Exception.Create('Count down arrow did not decrement');
      end;
    Writeln('PASS element/data count up/down arrows');
  finally Panel.Free; Doc.Free; end;
end;
procedure CheckInvalidClose;
var Form:TGraphEditorForm; Doc,Accepted:TGraphDocument; Data:TGraphDataPanel;
  Layout:TGraphLayoutPanel; I:Integer; O:TJSONObject; Path,Text:string;
begin
  Doc:=TGraphDocument.Create; Form:=TGraphEditorForm.Create(nil); Path:='';
  try
    Doc.Kind:=gkBar; Doc.ResetBounds(640,480);
    Form.Load(nil,640,480,SaveGraph(Doc),DefaultShared);
    Data:=FindData(Form); Layout:=FindLayout(Form);
    for I:=0 to Data.ComponentCount-1 do
      if (Data.Components[I] is TEdit) and (TEdit(Data.Components[I]).Left=138) then
      begin TEdit(Data.Components[I]).Text:='invalid-value'; Break; end;
    for I:=0 to Layout.ComponentCount-1 do
      if (Layout.Components[I] is TEdit) and (TEdit(Layout.Components[I]).Top=80) then
      begin TEdit(Layout.Components[I]).Text:='invalid-count'; Break; end;
    PostMessage(Form.Handle,WM_SYSCOMMAND,SC_CLOSE,0); Form.ShowModal;
    Path:=Form.RecoveryPath;
    if (Path='') or not TFile.Exists(Path) then raise Exception.Create('Invalid input recovery was not saved');
    Text:=TFile.ReadAllText(Path,TEncoding.UTF8);
    O:=TJSONObject.ParseJSONValue(Text) as TJSONObject;
    try
      if (Pos('invalid-value',O.GetValue<TJSONArray>('inputs').ToJSON)=0) or
        (Pos('invalid-count',O.GetValue<TJSONArray>('inputs').ToJSON)=0) or
        (O.GetValue<string>('error')='') then
        raise Exception.Create('Recovery did not preserve raw inputs and validation error');
    finally O.Free; end;
    Accepted:=LoadGraph(Form.Settings);
    try
      if (Accepted.Kind<>gkBar) or (Accepted.Rows<>3) or
        (Form.Shared.Values<>DefaultShared.Values) then
        raise Exception.Create('Close did not return the last valid settings');
    finally Accepted.Free; end;
    Writeln('PASS invalid inputs saved to recovery and modal close allowed');
  finally Form.Free; Doc.Free; if Path<>'' then TFile.Delete(Path); end;
end;
procedure CheckLineRows(Owner:TComponent);
var Panel:TGraphStylePanel; Doc:TGraphDocument; K:TGraphKind;
  I,Index:Integer; Swatch:TPanel; Slider:THorizontalTrackBarControl; Kind:TComboBox;
begin
  Doc:=TGraphDocument.Create; Panel:=TGraphStylePanel.Create(Owner);
  try
    for K:=gkRadar to gkPie do
    begin
      Doc.Kind:=K; Panel.Load(Doc);
      if K=gkPie then Index:=5 else Index:=4;
      Swatch:=nil; Slider:=nil; Kind:=nil;
      for I:=0 to Panel.ComponentCount-1 do
      begin
        if (Panel.Components[I] is TPanel) and (TPanel(Panel.Components[I]).Tag=Index) then
          Swatch:=TPanel(Panel.Components[I]);
        if (Panel.Components[I] is THorizontalTrackBarControl) and
          (THorizontalTrackBarControl(Panel.Components[I]).Tag=Index) then
          Slider:=THorizontalTrackBarControl(Panel.Components[I]);
        if (Panel.Components[I] is TComboBox) and (TComboBox(Panel.Components[I]).Tag=Index) then
          Kind:=TComboBox(Panel.Components[I]);
      end;
      if (Swatch=nil) or (Slider=nil) or (Kind=nil) then raise Exception.Create('Data line row is missing');
      if not Slider.Visible or (Swatch.Top<>Slider.Top) or (Slider.Top<>Kind.Top) then
        raise Exception.Create('Data line tools are not in one row');
      if Swatch.Visible or (Kind.Visible<>(K<>gkLine)) then
        raise Exception.Create('Line element color/kind was duplicated');
      if K<>gkLine then
      begin
        Kind.ItemIndex:=3; Kind.OnChange(Kind);
        if Doc.Lines[Index].Kind<>3 then
          raise Exception.Create('Data line kind was not applied');
      end;
      Slider.Position:=85;
      if Abs(Doc.Lines[Index].Width-8.5)>0.001 then raise Exception.Create('Data line width was not applied');
    end;
    Writeln('PASS line rows and graph-specific line controls');
  finally Panel.Free; Doc.Free; end;
end;
procedure CheckColorStyles(Owner:TComponent);
var Panel:TGraphColorStylePanel; Doc,Restored:TGraphDocument;
  K:TGraphKind; I,Count,Expected:Integer; Control:TComponent; Swatch:TPanel; Combo:TDarkComboBox; OldColor:Cardinal;
begin
  Doc:=TGraphDocument.Create; Panel:=TGraphColorStylePanel.Create(Owner);
  try
    Doc.ResizeStructure(2,9);
    for K:=gkRadar to gkPie do
    begin
      Doc.Kind:=K; Panel.Load(Doc); Count:=0; Swatch:=nil;
      for I:=0 to Panel.ComponentCount-1 do
      begin
        Control:=Panel.Components[I];
        if Control is TPanel then
        begin Inc(Count); Swatch:=TPanel(Control); end;
        if Control is TDarkComboBox then
          if Control.Name='FillPattern' then
          begin
            if TDarkComboBox(Control).Visible=(K=gkLine) then
              raise Exception.Create('Fill selector visibility is wrong');
          end
          else if TDarkComboBox(Control).Visible<>(K=gkLine) then
            raise Exception.Create('Line-only style selector visibility is wrong');
      end;
      Expected:=Doc.SeriesCount; if K<>gkLine then Expected:=Expected*2;
      if Count<>Expected then raise Exception.Create('Swatch count is wrong');
      OldColor:=Doc.Series[Doc.SeriesCount-1].LineColor;
      Swatch.OnClick(Swatch); Panel.SetSelectedColor($FF123456);
      if (K<>gkLine) and (Doc.Series[Doc.SeriesCount-1].LineColor<>OldColor) then
        raise Exception.Create('Fill editing changed border color');
      if Panel.SelectedColor<>$FF123456 then raise Exception.Create('Selected swatch color is wrong');
      if K=gkLine then
        for I:=0 to Panel.ComponentCount-1 do
          if (Panel.Components[I] is TDarkComboBox) and (Panel.Components[I].Name<>'FillPattern') then
          begin
            Combo:=TDarkComboBox(Panel.Components[I]); Combo.ItemIndex:=2; Combo.OnChange(Combo);
          end;
    end;
    Restored:=LoadGraph(SaveGraph(Doc));
    try
      if (Restored.Series[1].Marker<>2) or (Restored.Series[1].LineKind<>3) then
        raise Exception.Create('Selected series style was not saved');
    finally Restored.Free; end;
    Doc.Kind:=gkRadar; Doc.ResizeStructure(1,1); Panel.Load(Doc);
    Doc.ResizeStructure(2,9); Panel.Load(Doc);
    if Doc.Series[8].FillColor<>$FF123456 then raise Exception.Create('Hidden data color was lost');
    for I:=0 to Panel.ComponentCount-1 do
      if Panel.Components[I].Name='FillPattern' then
      begin
        Combo:=TDarkComboBox(Panel.Components[I]); Combo.ItemIndex:=0; Combo.OnChange(Combo);
      end;
    Restored:=LoadGraph(SaveGraph(Doc));
    try
      if Restored.Series[0].FillPattern<>0 then raise Exception.Create('Fill pattern was not saved');
    finally Restored.Free; end;
    Writeln('PASS independent fill and border colors, fill selector and style persistence');
  finally Panel.Free; Doc.Free; end;
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
procedure CheckLegendInteraction;
var Form:TForm; View:TGraphView; Doc:TGraphDocument; Labels:TArray<TGraphLabel>;
  L:TGraphLabel; Pixels:TBytes; Shared:TGraphShared; X,Y:Integer;
begin
  Form:=TForm.CreateNew(nil); Doc:=TGraphDocument.Create;
  try
    Form.ClientWidth:=640; Form.ClientHeight:=480;
    View:=TGraphView.Create(Form); View.Parent:=Form; View.SetBounds(0,0,640,480);
    Doc.Kind:=gkBar; Doc.Bounds:=RectF(80,100,500,350); Doc.NameLayout:=2;
    Shared:=DefaultShared; Shared.Values:='1,2,3'#13#10'2,3,4'#13#10'3,4,5';
    Pixels:=RenderGraph(Doc,Shared,Default(TGraphAnimation),640,480,Labels);
    View.Bind(Doc,Labels); View.SetView(1,0,0);
    X:=-1; Y:=-1;
    for L in Labels do if (L.ID=2) and L.HasLegend then
    begin X:=Round(L.LegendBounds.CenterPoint.X); Y:=Round(L.LegendBounds.CenterPoint.Y); end;
    if X<0 then raise Exception.Create('Legend drag target missing');
    Form.Show; Application.ProcessMessages;
    View.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
    View.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(X+28,Y+14));
    View.Perform(WM_LBUTTONUP,0,MakeLParam(X+28,Y+14));
    if (Abs(Doc.LegendOffsets[0].X-0.2)>0.01) or
      (Abs(Doc.LegendOffsets[0].Y-0.5)>0.01) then
      raise Exception.Create('Legend drag did not update relative position');
    if (Doc.Offsets[2].X<>0) or (Doc.Offsets[2].Y<>0) or (Doc.LabelScales[2]<>1) then
      raise Exception.Create('Legend drag moved or resized its parent text');
    Writeln('PASS legend mark drag edits relative offset and preserves parent text');
  finally Form.Free; Doc.Free; end;
end;
procedure CheckTextSnapping;
var Doc:TGraphDocument; Labels:TArray<TGraphLabel>; B:TRectF; Scale:Single; Feedback:TTextSnapFeedback;
begin
  Doc:=TGraphDocument.Create;
  try
    SetLength(Labels,2);
    Labels[0].ID:=2; Labels[0].Role:=trName; Labels[0].Bounds:=RectF(20,40,80,60);
    Labels[1].ID:=3; Labels[1].Role:=trName; Labels[1].Bounds:=RectF(100,100,160,120);
    B:=SnapTextBounds(RectF(92,45,152,65),2,Labels,10,@Feedback);
    if not Feedback.HasX or (Abs(Feedback.X-100)>0.01) then
      raise Exception.Create('Position snap guide is wrong');
    if Abs(B.Left-100)>0.01 then raise Exception.Create('Text horizontal snap failed');
    B:=SnapTextBounds(RectF(90,85,150,105),2,Labels,6);
    if (Abs(B.Left-90)>0.01) or (Abs(B.Top-85)>0.01) then
      raise Exception.Create('Text snap did not release outside tolerance');
    Doc.LabelScales[3]:=2;
    Scale:=SnapTextScale(1.9,2,trName,Doc,Labels,@Feedback);
    if Feedback.SizeID<>3 then raise Exception.Create('Size snap target is wrong');
    if Abs(Scale-2)>0.01 then raise Exception.Create('Text size equality snap failed');
    Scale:=SnapTextScale(1.8,2,trName,Doc,Labels);
    if Abs(Scale-1.8)>0.01 then raise Exception.Create('Text size snap did not release');
    Labels[1].Role:=trTitle; Doc.TextStyles[trTitle].Size:=40;
    Doc.TextStyles[trName].Size:=20; Doc.LabelScales[3]:=1;
    Scale:=SnapTextScale(1.9,2,trName,Doc,Labels,@Feedback);
    if Feedback.SizeID<>3 then raise Exception.Create('Size snap target is wrong');
    if Abs(Scale-2)>0.01 then raise Exception.Create('Text snap ignored role font size');
    SetLength(Labels,3);
    Labels[0].ID:=2; Labels[0].Role:=trName; Labels[0].Bounds:=RectF(20,40,80,60);
    Labels[1].ID:=3; Labels[1].Role:=trName; Labels[1].Bounds:=RectF(120,40,180,60);
    Labels[2].ID:=4; Labels[2].Role:=trName; Labels[2].Bounds:=RectF(215,40,275,60);
    B:=SnapTextBounds(Labels[2].Bounds,4,Labels,10,@Feedback);
    if Abs(B.CenterPoint.X-250)>0.01 then raise Exception.Create('Equal spacing extension failed');
    if not Feedback.Spacing or not Feedback.Horizontal then raise Exception.Create('Spacing arrows missing');
    B:=SnapTextBounds(RectF(75,40,135,60),4,Labels,10,@Feedback);
    if Abs(B.CenterPoint.X-100)>0.01 then raise Exception.Create('Equal spacing insertion failed');
    Labels[1].Bounds:=RectF(20,140,80,160);
    B:=SnapTextBounds(RectF(20,235,80,255),4,Labels,10,@Feedback);
    if Abs(B.CenterPoint.Y-250)>0.01 then raise Exception.Create('Vertical equal spacing failed');
    B:=SnapTextBounds(RectF(215,240,275,260),4,Labels,10,@Feedback);
    if Abs(B.CenterPoint.X-245)>0.01 then raise Exception.Create('Unaligned text snapped to spacing');
    Labels[0].HasLegend:=True; Labels[0].LegendBounds:=RectF(20,40,40,60);
    Labels[1].HasLegend:=True; Labels[1].LegendBounds:=RectF(120,40,140,60);
    Labels[2].HasLegend:=True; Labels[2].LegendBounds:=RectF(215,40,235,60);
    B:=SnapLegendBounds(Labels[2].LegendBounds,4,Labels,10,@Feedback);
    if (Abs(B.CenterPoint.X-230)>0.01) or not Feedback.Spacing then
      raise Exception.Create('Legend equal spacing snap failed');
    B:=SnapLegendBounds(RectF(117,100,137,120),4,Labels,10,@Feedback);
    if (Abs(B.Left-120)>0.01) or not Feedback.HasX then
      raise Exception.Create('Legend coordinate snap failed');
    Writeln('PASS legend mark coordinate and equal spacing snap');
    Writeln('PASS equal text spacing horizontal, vertical, insertion and unrelated row');
    Writeln('PASS text position and font size snapping, release and different roles');
  finally Doc.Free; end;
end;
procedure CheckInitialDpi;
var Form:TGraphEditorForm; Layout:TGraphLayoutPanel; Data:TGraphDataPanel;
  Picker:TColorPickerPanel; Ppi,I:Integer;
  {$IFDEF GRAPH_SNAPSHOT}Shot:TBitmap;{$ENDIF}
begin
  for Ppi in [96,144,192] do
  begin
    Form:=TGraphEditorForm.CreateForPPI(nil,Ppi);
    try
      Form.Load(nil,640,480,'',DefaultShared);
      Layout:=FindLayout(Form); Data:=FindData(Form); Picker:=FindPicker(Form);
      if (Form.CurrentPPI<>Ppi) or (Layout.Height<>MulDiv(480,Ppi,96)) or
        (Picker.Parent.Width<>MulDiv(312,Ppi,96)) or
        (Picker.Height<>MulDiv(224,Ppi,96)) then
        raise Exception.CreateFmt('Initial DPI panel dimensions at %d: form=%d layout=%d pane=%d picker=%d',[Ppi,Form.CurrentPPI,Layout.Height,Picker.Parent.Width,Picker.Height]);
      for I:=0 to Layout.ControlCount-1 do
        if Layout.Controls[I] is TDarkComboBox then
          if (Layout.Controls[I].Top=MulDiv(36,Ppi,96)) and
            (Layout.Controls[I].Width<>MulDiv(272,Ppi,96)) then
            raise Exception.CreateFmt('Initial DPI graph selector is wrong at %d',[Ppi]);
      for I:=0 to Data.ControlCount-1 do
        if Data.Controls[I] is TEdit then
          if (Data.Controls[I].Top=MulDiv(66,Ppi,96)) and
            (Data.Controls[I].Width<>MulDiv(272,Ppi,96)) then
            raise Exception.CreateFmt('Initial DPI title width is wrong at %d',[Ppi]);
      {$IFDEF GRAPH_SNAPSHOT}
      Form.Show; Form.Update; Application.ProcessMessages;
      Shot:=Form.GetFormImage;
      try Shot.SaveToFile(ExtractFilePath(ParamStr(0))+Format('editor-initial-%d.bmp',[Ppi]));
      finally Shot.Free; end;
      {$ENDIF}
    finally Form.Free; end;
  end;
  Writeln('PASS initial DPI 100/150/200 percent construction');
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
  Colors:TGraphColorStylePanel; Swatch:TPanel;
  Style:TGraphStylePanel;
  WidthSlider:THorizontalTrackBarControl; LineKind:TComboBox;
  WheelEdit:TGraphNumberEdit; ActiveNumberEdit:TEdit; WheelPoint:TPoint;
  OldPosition:Integer; PreviewTimer:TTimer; OutlineSwatch:TPanel; OutlineSlider:THorizontalTrackBarControl;
  Ppi:Integer;
  {$IFDEF GRAPH_SNAPSHOT}Shot:TBitmap;{$ENDIF}
begin
  try
    Application.Initialize;
    CheckLegendInteraction;
    CheckTextSnapping;
    CheckInitialDpi;
    CheckInvalidClose;
    F:=TGraphEditorForm.Create(nil);
    try
      F.Load(nil,640,480,'',DefaultShared);
      Writeln('PASS editor creation and load');
      CheckColorStyles(F); CheckLineRows(F); CheckCountInputs(F);
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
      Style:=FindStyle(F);
      WidthSlider:=nil; LineKind:=nil;
      if Style=nil then raise Exception.Create('Style panel is missing');
      for I:=0 to Style.ComponentCount-1 do
      begin
        if (Style.Components[I] is THorizontalTrackBarControl) and
          (THorizontalTrackBarControl(Style.Components[I]).Tag=0) then
          WidthSlider:=THorizontalTrackBarControl(Style.Components[I]);
        if (Style.Components[I] is TComboBox) and (TComboBox(Style.Components[I]).Tag=0) then
          LineKind:=TComboBox(Style.Components[I]);
      end;
      if (WidthSlider=nil) or (LineKind=nil) then raise Exception.Create('Line row controls are missing');
      if WidthSlider.Top<>LineKind.Top then raise Exception.Create('Line row controls are not aligned');
      if (LineKind.ItemHeight<26) or (LineKind.DropDownWidth<LineKind.Width) or
        not WidthSlider.WheelChangesPosition then
        raise Exception.Create('Line list or slider wheel setup is wrong');
      OutlineSwatch:=nil; OutlineSlider:=nil; PreviewTimer:=nil;
      for I:=0 to Style.ComponentCount-1 do
      begin
        if (Style.Components[I] is TPanel) and (TPanel(Style.Components[I]).Tag=6) then
          OutlineSwatch:=TPanel(Style.Components[I]);
        if (Style.Components[I] is THorizontalTrackBarControl) and
          (THorizontalTrackBarControl(Style.Components[I]).Tag=6) then
          OutlineSlider:=THorizontalTrackBarControl(Style.Components[I]);
        if (Style.Components[I] is TLabel) and (TLabel(Style.Components[I]).Caption='縁取り') then
          raise Exception.Create('Outline caption remains');
      end;
      for I:=0 to F.ComponentCount-1 do
        if F.Components[I] is TTimer then PreviewTimer:=TTimer(F.Components[I]);
      if (OutlineSwatch=nil) or (OutlineSlider=nil) or (PreviewTimer=nil) then
        raise Exception.Create('Aligned outline tools or preview timer are missing');
      if (OutlineSwatch.Left<>12) or (OutlineSlider.Left<>WidthSlider.Left) or
        (OutlineSlider.Width<>WidthSlider.Width) or (LineKind.Width<110) then
        raise Exception.Create('Color/width columns or line kind width are wrong');
      for I:=20 to 75 do WidthSlider.Position:=I;
      if not PreviewTimer.Enabled or (PreviewTimer.Interval<>60) then
        raise Exception.Create('Continuous slider edits were not queued');
      WidthSlider.OnMouseUp(WidthSlider,mbLeft,[],0,0);
      if PreviewTimer.Enabled then raise Exception.Create('Slider release did not flush final preview');
      Writeln('PASS aligned line controls and coalesced slider preview');
      LineKind.ItemIndex:=2; LineKind.OnChange(LineKind);
      Saved:=LoadGraph(F.Settings);
      try
        if (Abs(Saved.Lines[0].Width-7.5)>0.001) or (Saved.Lines[0].Kind<>2) then
          raise Exception.Create('Dedicated line tools did not update model');
      finally Saved.Free; end;
      Layout:=FindLayout(F);
      for I:=0 to Layout.ComponentCount-1 do
        if (Layout.Components[I] is TDarkComboBox) and
          (TDarkComboBox(Layout.Components[I]).Top=36) then
        begin
          TDarkComboBox(Layout.Components[I]).ItemIndex:=Ord(gkBar);
          TDarkComboBox(Layout.Components[I]).OnChange(Layout.Components[I]);
        end;
      Style.OnChange(Style);
      Saved:=LoadGraph(F.Settings); Saved.Free;
      Colors:=TGraphSettingsPane(FindPicker(F).Owner).ColorPanel;
      Swatch:=nil;
      for I:=0 to Colors.ComponentCount-1 do
        if (Colors.Components[I] is TPanel) and (TPanel(Colors.Components[I]).Tag=1) then
        begin Swatch:=TPanel(Colors.Components[I]); Break; end;
      if Swatch=nil then raise Exception.Create('Series swatches are missing');
      Swatch.OnClick(Swatch);
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
      WheelPoint:=WheelEdit.ClientToScreen(Point(6,WheelEdit.Height div 2));
      WheelHandled:=False;
      F.OnMouseWheel(F,[],120,WheelPoint,WheelHandled);
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
      Scroll.Position:=Style.Top+WidthSlider.Top-100;
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
      D.TextStyles[trTitle].OutlineWidth:=0; // 無効状態からの有効化・解除を検証する。
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
        // DPI変更後の再読込でも、動的な入力行と設定欄の基準寸法を保つ。
        for Ppi in [144,192,96] do
        begin
          F.ScaleForPPI(Ppi);
          F.Load(nil,640,360,SaveGraph(D),S);
          Layout:=FindLayout(F); Data:=FindData(F);
          Picker:=FindPicker(F);
          if (Layout.Height<>MulDiv(480,Ppi,96)) or
            (Picker.Parent.Width<>MulDiv(312,Ppi,96)) then
            raise Exception.CreateFmt('DPI panel dimensions are wrong at %d',[Ppi]);
          for I:=0 to Data.ControlCount-1 do
            if (Data.Controls[I] is TEdit) and (Data.Controls[I].Left=MulDiv(40,Ppi,96)) then
              if Data.Controls[I].Width<>MulDiv(90,Ppi,96) then
                raise Exception.CreateFmt('DPI row width is wrong at %d',[Ppi]);
        end;
        Writeln('PASS DPI 150/200/100 percent and dynamic row reload');
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
