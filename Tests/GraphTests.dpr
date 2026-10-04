program GraphTests;
{$APPTYPE CONSOLE}

// 実際のグラフ専用ユニットを使い、値・保存・透過・4種の描画を検証する。
uses System.SysUtils, System.Types, System.Math, System.Skia, System.JSON, GraphModel, GraphValues,
  GraphRadarGeometry, GraphSettings, GraphFonts, GraphAnimation, GraphRenderer, GraphPainter, GraphComposite,
  GraphTextTransform, GraphTextSnap, GraphFloatState;
var Count:Integer;
procedure Check(Condition:Boolean; const Name:string);
begin
  if not Condition then raise Exception.Create('FAIL: '+Name);
  Inc(Count); Writeln('PASS: '+Name);
end;
function ValueLabelTop(const Labels:TArray<TGraphLabel>):Single;
var L:TGraphLabel;
begin
  Result:=-1;
  for L in Labels do
    if L.ID=2+MaxGraphRows then Exit(L.Bounds.Top);
end;

{$WARN SYMBOL_PLATFORM OFF} // Win64の描画前後で、例外マスクだけでなく丸め・状態も検証する。
procedure CheckThreadFloatScope;
var SavedState,SavedDefault,HostState,Previous,Masked,After:Cardinal; I:Integer;
begin
  SavedState:=GetMXCSR; SavedDefault:=DefaultMXCSR;
  try
    for I:=0 to 3 do
    begin
      // 呼出スレッドの状態をRTLの共有既定値と異ならせ、スコープ中も既定値を守る。
      HostState:=$0F80 or $20 or Cardinal(I shl 13);
      RestoreGraphFloatScope(HostState);
      Previous:=BeginGraphFloatScope; Masked:=GetMXCSR;
      Check((Previous=HostState) and ((Masked and $1F80)=$1F80) and
        ((Masked and $3F)=0) and (DefaultMXCSR=SavedDefault),
        'thread scope masks exceptions without changing shared defaults '+IntToStr(I));
      RestoreGraphFloatScope(Previous); After:=GetMXCSR;
      Check((After=HostState) and (DefaultMXCSR=SavedDefault),
        'thread scope restores pending flags and rounding '+IntToStr(I));
    end;
  finally RestoreGraphFloatScope(SavedState); end;
end;

procedure CheckRenderFloatState;
var D:TGraphDocument; Shared:TGraphShared; Animation:TGraphAnimation;
  Labels:TArray<TGraphLabel>; Pixels:TBytes; SavedState,Before,After:Cardinal;
  K:TGraphKind; Failed:Boolean;
begin
  SavedState:=GetMXCSR; D:=TGraphDocument.Create;
  try
    D.ResizeStructure(3,1); D.ResetBounds(320,240);
    Shared:=DefaultShared; Shared.Values:='10'#13#10'20'#13#10'30';
    Animation:=Default(TGraphAnimation); Animation.TransitionMode:=4;
    Animation.GraphMode:=2; Animation.Progress:=0.00001; Animation.ZoomPercent:=150;
    for K:=gkRadar to gkPie do
    begin
      D.Kind:=K;
      SetExceptionMask([exDenormalized,exUnderflow,exPrecision]); SetRoundMode(rmDown);
      SetMXCSRExceptionFlag($20); Before:=GetMXCSR;
      Pixels:=RenderGraph(D,Shared,Animation,320,240,Labels);
      After:=GetMXCSR;
      Check((Length(Pixels)=320*240*4) and (Before=After),
        'render preserves complete host floating point state '+IntToStr(Ord(K)));
    end;
    SetMXCSRExceptionFlag(0);
    Shared.Values:='-1'#13#10'20'#13#10'30'; Before:=GetMXCSR; Failed:=False;
    try Pixels:=RenderGraph(D,Shared,Animation,320,240,Labels);
    except on E:EConvertError do Failed:=True; end;
    After:=GetMXCSR;
    Check(Failed and (Before=After),'render failure preserves host floating point state');
  finally D.Free; SetMXCSR(SavedState); end;
end;
{$WARN SYMBOL_PLATFORM ON}

procedure CheckMissingValues;
var D:TGraphDocument; S:TGraphShared; V,Again,Expanded:TGraphValues;
  A:TGraphAnimation; Labels:TArray<TGraphLabel>; Blank,Zero,RepeatImage:TBytes;
  K:TGraphKind; R,C:Integer; Stable,Visible,Failed:Boolean;
begin
  V:=ParseValues('',3,3); Again:=ParseValues(' , , '#13#10',,'#13#10',,',3,3);
  Expanded:=ParseValues('',4,4); Stable:=True;
  for R:=0 to 2 do
    for C:=0 to 2 do Stable:=Stable and (V[R,C]>0) and
      (V[R,C]=Again[R,C]) and (V[R,C]=Expanded[R,C]);
  Check(Stable,'blank and omitted cells generate stable sample values');
  V:=ParseValues('0,,12'#13#10',0.0,-5',3,3);
  Check((V[0,0]=0) and (V[1,1]=0) and (V[0,2]=12) and (V[1,2]=-5) and
    (V[0,1]>0) and (V[1,0]>0) and (V[2,2]>0),'only missing cells are generated and explicit zero is retained');
  V:=ParseValues(',,'#13#10',,',1,1);
  Check(V[0,0]>0,'extra empty delimiters contain no explicit data');
  Failed:=False; try V:=ParseValues('0,invalid',1,2); except on E:EConvertError do Failed:=True; end;
  Check(Failed,'invalid text is not replaced by sample data');
  Failed:=False; try V:=ParseValues('0'#13#10'1',1,1); except on E:EConvertError do Failed:=True; end;
  Check(Failed,'extra nonempty rows are rejected');
  Check(DefaultShared.Values='','new host values start blank');
  D:=TGraphDocument.Create;
  try
    D.ResetBounds(320,240); S:=Default(TGraphShared); A:=Default(TGraphAnimation);
    for R:=0 to High(D.Lines) do D.Lines[R].Kind:=0;
    for K:=gkRadar to gkPie do
    begin
      D.Kind:=K;
      if K=gkPie then D.ResizeStructure(3,1) else D.ResizeStructure(3,3);
      S.Values:=''; Blank:=RenderGraph(D,S,A,320,240,Labels);
      Visible:=False; for R:=0 to 320*240-1 do Visible:=Visible or (Blank[R*4+3]>0);
      Check(Visible,'blank data renders graph '+IntToStr(Ord(K)));
      RepeatImage:=RenderGraph(D,S,A,320,240,Labels);
      Check(CompareMem(@Blank[0],@RepeatImage[0],Length(Blank)),
        'generated data does not change between frames '+IntToStr(Ord(K)));
      if K=gkPie then S.Values:='0'#13#10'0'#13#10'0'
      else S.Values:='0,0,0'#13#10'0,0,0'#13#10'0,0,0';
      Zero:=RenderGraph(D,S,A,320,240,Labels);
      Check(not CompareMem(@Blank[0],@Zero[0],Length(Blank)),
        'zero data remains distinct from missing data '+IntToStr(Ord(K)));
    end;
    D.Kind:=gkBar; D.Stacked:=True; D.ResizeStructure(3,3); S.Values:='';
    V:=ParseValues(S.Values,3,3);
    Check(CalculateScale(D,V).Maximum>=V[0,0]+V[1,0]+V[2,0],
      'generated values participate in stacked scale');
  finally D.Free; end;
end;

procedure CheckTextOnTop;
var D:TGraphDocument; Shared:TGraphShared; Animation:TGraphAnimation; K:TGraphKind;
  Full,TextOnly:TBytes; Labels:TArray<TGraphLabel>; L:TGraphLabel; I,Opaque:Integer;
begin
  D:=TGraphDocument.Create;
  try
    D.ResizeStructure(3,1); D.ResetBounds(320,240); D.ValueFormat:='';
    D.TextStyles[trName].Color:=$FFFF00FF; D.TextStyles[trName].OutlineWidth:=0;
    D.Lines[3].Kind:=1; D.Lines[3].Width:=12;
    Shared:=DefaultShared; Shared.Title:=''; Shared.Units:='';
    Shared.Names:='TEXT'#13#10'B'#13#10'C'; Shared.Values:='100'#13#10'100'#13#10'100';
    Animation:=Default(TGraphAnimation);
    for K:=gkRadar to gkPie do
    begin
      D.Kind:=K; D.ResetOffsets;
      Full:=RenderGraph(D,Shared,Animation,320,240,Labels);
      for L in Labels do
        if L.ID=2 then D.Offsets[2]:=PointF(D.Bounds.CenterPoint.X-L.Bounds.CenterPoint.X,
          D.Bounds.CenterPoint.Y-L.Bounds.CenterPoint.Y);
      Full:=RenderGraph(D,Shared,Animation,320,240,Labels);
      TextOnly:=RenderGraph(D,Shared,Animation,320,240,Labels,2);
      Opaque:=0;
      for I:=0 to 320*240-1 do
        if (TextOnly[I*4+3]=255) and (TextOnly[I*4]=255) and
          (TextOnly[I*4+1]=0) and (TextOnly[I*4+2]=255) then
        begin
          Inc(Opaque);
          if (Full[I*4]<>255) or (Full[I*4+1]<>0) or (Full[I*4+2]<>255) then
            raise Exception.Create('Text was covered by graph or line');
        end;
      Check(Opaque>0,'element name stays above graph and lines '+IntToStr(Ord(K)));
    end;
  finally D.Free; end;
end;
procedure CheckBaseLinesOnTop;
var D:TGraphDocument; Shared:TGraphShared; Animation:TGraphAnimation;
  Pixels:TBytes; Labels:TArray<TGraphLabel>; I:Integer; Horizontal,Stacked:Boolean;
  Direction:string;
  procedure CheckColor(X,Y:Integer; Color:Cardinal; const Name:string);
  var Offset:Integer;
  begin
    Offset:=(Y*320+X)*4;
    Check((Pixels[Offset]=(Color shr 16 and $FF)) and
      (Pixels[Offset+1]=(Color shr 8 and $FF)) and
      (Pixels[Offset+2]=(Color and $FF)) and (Pixels[Offset+3]=255),Name);
  end;
begin
  D:=TGraphDocument.Create;
  try
    D.Bounds:=RectF(40,30,280,210); D.Minimum:='0'; D.Maximum:='100';
    D.Interval:='50'; D.ValueFormat:='';
    D.TextStyles[trValue].Color:=0; D.TextStyles[trValue].OutlineWidth:=0;
    for I:=0 to High(D.Lines) do D.Lines[I].Kind:=0;
    for I:=0 to 2 do begin D.Lines[I].Kind:=1; D.Lines[I].Width:=4; end;
    D.Lines[0].Color:=$FF00FF00; D.Lines[1].Color:=$FF0000FF;
    D.Lines[2].Color:=$FFFF00FF; D.Lines[4].Kind:=1; D.Lines[4].Width:=8;
    for I:=0 to 1 do
    begin
      D.Series[I].FillColor:=$FFFF0000; D.Series[I].LineColor:=$FFFF0000;
      D.Series[I].LineKind:=1; D.Series[I].Marker:=1;
    end;
    Shared:=Default(TGraphShared); Animation:=Default(TGraphAnimation);
    // 基準線と同じ座標に太いデータ線・マーク・棒を置き、重なりの色で順序を確認する。
    for Horizontal in [False,True] do
    begin
      D.Horizontal:=Horizontal;
      if Horizontal then Direction:='horizontal' else Direction:='vertical';
      D.Kind:=gkLine; D.ResizeStructure(1,2); Shared.Values:='50,50';
      Pixels:=RenderGraph(D,Shared,Animation,320,240,Labels);
      CheckColor(160,120,$FFFF00FF,Direction+' grid stays above data line');
      if Horizontal then CheckColor(160,30,$FF0000FF,Direction+' Y axis stays above marker')
      else CheckColor(40,120,$FF0000FF,Direction+' Y axis stays above marker');
      Shared.Values:='0,0'; Pixels:=RenderGraph(D,Shared,Animation,320,240,Labels);
      if Horizontal then CheckColor(40,120,$FF00FF00,Direction+' X axis stays above zero line')
      else CheckColor(160,210,$FF00FF00,Direction+' X axis stays above zero line');
      D.Kind:=gkBar;
      for Stacked in [False,True] do
      begin
        D.Stacked:=Stacked;
        if Stacked then
        begin D.ResizeStructure(2,1); Shared.Values:='50'#13#10'50'; end
        else begin D.ResizeStructure(1,1); Shared.Values:='100'; end;
        Pixels:=RenderGraph(D,Shared,Animation,320,240,Labels);
        CheckColor(160,120,$FFFF00FF,Direction+' grid stays above bar stacked='+BoolToStr(Stacked,True));
        if Horizontal then CheckColor(40,120,$FF00FF00,Direction+' X axis stays above bar border stacked='+BoolToStr(Stacked,True))
        else CheckColor(160,210,$FF00FF00,Direction+' X axis stays above bar border stacked='+BoolToStr(Stacked,True));
      end;
    end;
    D.Kind:=gkRadar; D.ResizeStructure(4,1);
    Shared.Values:='100'#13#10'100'#13#10'100'#13#10'100';
    Pixels:=RenderGraph(D,Shared,Animation,320,240,Labels);
    CheckColor(220,75,$FFFF00FF,'radar grid stays above data outline');
    CheckColor(160,208,$FF00FF00,'radar axis stays above data outline');
  finally D.Free; end;
end;
procedure CheckSharedValueSize;
var Doc,Restored:TGraphDocument; Shared:TGraphShared; K:TGraphKind;
  Before,After:TArray<TGraphLabel>; L,Original:TGraphLabel; Pixels:TBytes;
  Feedback:TTextSnapFeedback; B:TRectF; I,Count,Ticks:Integer; SameRatio:Boolean;
begin
  Doc:=TGraphDocument.Create;
  try
    Doc.Bounds:=RectF(80,90,560,370); Doc.Minimum:='0'; Doc.Maximum:='100';
    Doc.Interval:='50'; Doc.ValueFormat:='0'; Shared:=Default(TGraphShared);
    Doc.LabelScales[2+MaxGraphRows]:=1.5; Doc.Offsets[2+MaxGraphRows]:=PointF(7,-4);
    for K:=gkRadar to gkPie do
    begin
      Doc.Kind:=K; Doc.TextStyles[trValue].Size:=28;
      if K=gkPie then
      begin Doc.ResizeStructure(3,1); Shared.Values:='20'#13#10'40'#13#10'80'; end
      else begin Doc.ResizeStructure(3,2); Shared.Values:='20,40'#13#10'30,60'#13#10'50,80'; end;
      Pixels:=RenderGraph(Doc,Shared,Default(TGraphAnimation),640,480,Before);
      B:=TRectF.Empty;
      for L in Before do if L.ID=2+MaxGraphRows then B:=L.Bounds;
      Check(not B.IsEmpty,'data value has editable bounds '+IntToStr(Ord(K)));
      B:=ResizeGraphText(Doc,2+MaxGraphRows,trValue,Before,B,Doc.Offsets[2+MaxGraphRows],
        PointF(B.Width*0.5,B.Height*0.5),1.5,28,7,Feedback);
      Check((Abs(Doc.TextStyles[trValue].Size-42)<0.001) and
        (Doc.LabelScales[2+MaxGraphRows]=1.5) and (Doc.Offsets[2+MaxGraphRows].X=7) and
        (Doc.Offsets[2+MaxGraphRows].Y=-4),'value resize changes shared size and preserves individual settings '+IntToStr(Ord(K)));
      Pixels:=RenderGraph(Doc,Shared,Default(TGraphAnimation),640,480,After);
      SameRatio:=True; Count:=0; Ticks:=0;
      for L in After do if L.Role=trValue then
      begin
        Inc(Count); if L.ID>=GraphTickLabelBase then Inc(Ticks);
        for Original in Before do if Original.ID=L.ID then
          SameRatio:=SameRatio and (Abs(L.Bounds.Height/Original.Bounds.Height-1.5)<0.001);
      end;
      Check(SameRatio and (Count>=3),'all values scale together '+IntToStr(Ord(K)));
      if K<>gkPie then Check(Ticks=3,'scale ticks have distinct selectable IDs '+IntToStr(Ord(K)));
      Restored:=LoadGraph(SaveGraph(Doc));
      try Check((Abs(Restored.TextStyles[trValue].Size-42)<0.001) and
        (Restored.LabelScales[2+MaxGraphRows]=1.5),'shared value size survives save and reload '+IntToStr(Ord(K)));
      finally Restored.Free; end;
    end;
    B:=ResizeGraphText(Doc,GraphTickLabelBase,trValue,After,RectF(0,0,40,35),PointF(0,0),
      PointF(10000,10000),1,42,7,Feedback);
    Check(Doc.TextStyles[trValue].Size=500,'shared value size stays in saveable range');
    for I:=0 to High(Doc.LabelScales) do
      if (I<>2+MaxGraphRows) and (Doc.LabelScales[I]<>1) then
        raise Exception.Create('Shared value resize changed an individual scale');
  finally Doc.Free; end;
end;
procedure CheckFonts;
var Runs:TArray<TGraphFontRun>; Run:TGraphFontRun; G:Word; Text:string;
  D,E:TGraphDocument; Role:TTextRole;
begin
  Check(HasGraphGlyphs(ResolveGraphTypeface('ＭＳ ゴシック',TSkFontStyle.Normal),'日本語グラフ'),
    'localized GDI font name resolves Japanese glyphs');
  Text:='ABC日本語123'; Runs:=GraphFontRuns('Arial',Text,TSkFontStyle.Normal,28);
  Check(Length(Runs)>1,'Latin font falls back for Japanese only'); Text:='';
  for Run in Runs do
  begin
    Text:=Text+Run.Text;
    for G in Run.Font.GetGlyphs(Run.Text) do Check(G<>0,'mixed text run has no missing glyph');
  end;
  Check(Text='ABC日本語123','fallback keeps original character order');
  D:=TGraphDocument.Create;
  try
    for Role:=Low(TTextRole) to High(TTextRole) do Check(D.TextStyles[Role].OutlineWidth=1,'new text outline default one');
    D.TextStyles[trTitle].OutlineWidth:=0; E:=LoadGraph(SaveGraph(D));
    try Check(E.TextStyles[trTitle].OutlineWidth=0,'saved disabled outline is preserved'); finally E.Free; end;
  finally D.Free; end;
end;
procedure CheckLegendAttachment;
var Doc,Restored:TGraphDocument; Shared:TGraphShared; Labels:TArray<TGraphLabel>;
  L,Before:TGraphLabel; Pixels:TBytes; Animation:TGraphAnimation; Found:Boolean;
begin
  Doc:=TGraphDocument.Create;
  try
    Doc.Kind:=gkBar; Doc.ResetBounds(640,480); Shared:=DefaultShared;
    Shared.Values:='1,2,3'#13#10'2,3,4'#13#10'3,4,5'; Animation:=Default(TGraphAnimation);
    Pixels:=RenderGraph(Doc,Shared,Animation,640,480,Labels); Found:=False;
    for L in Labels do if L.ID=2 then begin Before:=L; Found:=True; end;
    Check(Found and Before.HasLegend,'legend attached to element name');
    Doc.Offsets[2]:=PointF(60,-40);
    Pixels:=RenderGraph(Doc,Shared,Animation,640,480,Labels);
    for L in Labels do if L.ID=2 then
      Check((Abs(L.LegendBounds.Left-Before.LegendBounds.Left-60)<0.01) and
        (Abs(L.LegendBounds.Top-Before.LegendBounds.Top+40)<0.01),'legend follows text movement');
    Doc.LabelScales[2]:=2;
    Pixels:=RenderGraph(Doc,Shared,Animation,640,480,Labels);
    for L in Labels do if L.ID=2 then
      Check(Abs(L.LegendBounds.Width-2*Before.LegendBounds.Width)<0.01,'legend follows text scale');
    Doc.LegendOffsets[0]:=PointF(2,-1);
    Restored:=LoadGraph(SaveGraph(Doc));
    try Check((Restored.LegendOffsets[0].X=2) and (Restored.LegendOffsets[0].Y=-1),
      'legend relative position survives save and reload'); finally Restored.Free; end;
    Restored:=LoadGraph('{"version":3}');
    try Check(Abs(Restored.LegendOffsets[0].X+0.8)<0.01,'old settings receive default legend position');
    finally Restored.Free; end;
  finally Doc.Free; end;
end;
procedure CheckRadarBounds;
var Geometry:TGraphRadarGeometry; B,Actual:TRectF; P:TPointF;
  Rows,Rotation,I:Integer;
begin
  B:=RectF(20,30,620,270);
  for Rows in [3,4,5,8] do
    for Rotation in [0,17,90] do
    begin
      Geometry:=TGraphRadarGeometry.Fit(B,Rows,Rotation);
      Actual:=RectF(1E9,1E9,-1E9,-1E9);
      for I:=0 to Rows-1 do
      begin
        P:=Geometry.PointAt(-90+Rotation+I*360/Rows,1);
        if P.X<Actual.Left then Actual.Left:=P.X;
        if P.X>Actual.Right then Actual.Right:=P.X;
        if P.Y<Actual.Top then Actual.Top:=P.Y;
        if P.Y>Actual.Bottom then Actual.Bottom:=P.Y;
      end;
      Check((Abs(Actual.Left-B.Left)<0.001) and (Abs(Actual.Right-B.Right)<0.001) and
        (Abs(Actual.Top-B.Top)<0.001) and (Abs(Actual.Bottom-B.Bottom)<0.001),
        Format('radar fills edited bounds rows=%d rotation=%d',[Rows,Rotation]));
    end;
end;
procedure CheckRadarOverlap;
var Doc:TGraphDocument; Shared:TGraphShared; Animation:TGraphAnimation;
  Pixels:TBytes; Labels:TArray<TGraphLabel>; I,Inside,Outside,Edge:Integer;
begin
  Doc:=TGraphDocument.Create;
  try
    Doc.Kind:=gkRadar; Doc.ResizeStructure(4,2); Doc.Bounds:=RectF(40,40,280,200);
    Doc.Minimum:='0'; Doc.Maximum:='100'; Doc.Interval:='100'; Doc.ValueFormat:='';
    for I:=0 to High(Doc.Lines) do Doc.Lines[I].Kind:=0;
    Doc.Series[0].FillColor:=$FFFF0000; Doc.Series[1].FillColor:=$FF0000FF;
    Doc.Series[0].LineColor:=$FFFF0000; Doc.Series[1].LineColor:=$FF0000FF;
    Shared:=DefaultShared; Shared.Title:=''; Shared.Units:='';
    Shared.Names:='A'#13#10'B'#13#10'C'#13#10'D';
    Shared.Values:='50,100'#13#10'50,100'#13#10'50,100'#13#10'50,100';
    Animation:=Default(TGraphAnimation);
    Pixels:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
    Inside:=(140*320+170)*4; Outside:=(125*320+215)*4;
    Check(Abs(Integer(Pixels[Inside+3])-163)<=2,'radar overlapping fills keep transparent background');
    Check((Abs(Integer(Pixels[Inside])-96)<=2) and
      (Abs(Integer(Pixels[Inside+2])-159)<=2),'radar overlapping fills blend at 40 percent');
    Check(Abs(Integer(Pixels[Outside+3])-102)<=2,'radar upper fill alone has 40 percent opacity');
    Doc.Lines[4].Kind:=1; Doc.Lines[4].Width:=6;
    Pixels:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
    Edge:=(135*320+197)*4;
    Check((Pixels[Edge]>240) and (Pixels[Edge+2]<10) and (Pixels[Edge+3]=255),
      'radar lower outline stays visible over upper fill in data color');
    Doc.Lines[0].Kind:=1; Doc.Lines[0].Width:=4; Doc.Lines[0].Color:=$FF00FF00;
    Pixels:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
    Edge:=(145*320+160)*4;
    Check((Pixels[Edge+1]>240) and (Pixels[Edge+3]=255),'radar axes stay clear above overlapping fills');
  finally Doc.Free; end;
end;
procedure CheckDataLines;
var Doc:TGraphDocument; Shared:TGraphShared; Animation:TGraphAnimation;
  K:TGraphKind; Index:Integer; A,B:TBytes; Labels:TArray<TGraphLabel>;
begin
  Doc:=TGraphDocument.Create;
  try
    Doc.ResetBounds(320,240); Shared:=DefaultShared;
    Shared.Values:='30,60,50'#13#10'80,40,90'#13#10'50,70,30';
    Animation:=Default(TGraphAnimation);
    for K:=gkRadar to gkPie do
    begin
      Doc.Kind:=K;
      if K=gkPie then Index:=5 else Index:=4;
      Doc.Lines[Index].Kind:=1; Doc.Lines[Index].Width:=2;
      Doc.Lines[Index].Color:=$FFFF0000; Doc.Series[0].LineColor:=$FFFF0000;
      A:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
      Doc.Lines[Index].Color:=$FF00FF00;
      B:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
      Check(CompareMem(@A[0],@B[0],Length(A)),'line uses independent data color '+IntToStr(Ord(K)));
      Doc.Series[0].LineColor:=$FF00FF00;
      A:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
      Check(not CompareMem(@A[0],@B[0],Length(A)),'data border color renders '+IntToStr(Ord(K)));
      B:=A;
      Doc.Lines[Index].Width:=0;
      with LoadGraph(SaveGraph(Doc)) do
      try Check(Lines[Index].Width=0,'zero line width round trip '+IntToStr(Ord(K))); finally Free; end;
      A:=B;
      Doc.Lines[Index].Width:=12;
      B:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
      Check(not CompareMem(@A[0],@B[0],Length(A)),'data line width renders '+IntToStr(Ord(K)));
      Doc.Lines[Index].Width:=2;
      A:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
      if K=gkLine then Doc.Series[0].LineKind:=3 else Doc.Lines[Index].Kind:=3;
      B:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
      Check(not CompareMem(@A[0],@B[0],Length(A)),'data line kind renders '+IntToStr(Ord(K)));
      if K<>gkLine then
      begin
        Doc.Lines[Index].OutlineWidth:=3; Doc.Lines[Index].Width:=0;
        A:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
        Doc.Lines[Index].Width:=2; Doc.Lines[Index].Kind:=0;
        B:=RenderGraph(Doc,Shared,Animation,320,240,Labels);
        Check(CompareMem(@A[0],@B[0],Length(A)),'zero width hides outline '+IntToStr(Ord(K)));
      end;
    end;
  finally Doc.Free; end;
end;
procedure CheckFillPatterns;
var D,E:TGraphDocument; Surface:ISkSurface; P:TGraphPainter;
  Pixels,Previous:TBytes; I,Pattern,Filled,Solid:Integer; K:TGraphKind; Text:string;
  Json:TJSONObject; Item:TJSONValue;
begin
  D:=TGraphDocument.Create;
  try
    D.Kind:=gkBar; D.Lines[4].Width:=0; D.Lines[4].OutlineWidth:=8;
    Solid:=0; Previous:=nil;
    for Pattern:=0 to 4 do
    begin
      Surface:=TSkSurface.MakeRaster(100,100); Surface.Canvas.Clear(0);
      P:=TGraphPainter.Create(Surface.Canvas,D,1);
      try P.Box(RectF(20,20,80,80),$FFFF0000,$FF00FF00,1,Pattern); finally P.Free; end;
      SetLength(Pixels,100*100*4);
      Surface.ReadPixels(TSkImageInfo.Create(100,100,TSkColorType.RGBA8888,TSkAlphaType.Unpremul),@Pixels[0],400);
      Filled:=0;
      for I:=0 to 9999 do
        if Pixels[I*4+3]>0 then
        begin
          Inc(Filled);
          if (I mod 100<20) or (I mod 100>=80) or (I div 100<20) or (I div 100>=80) then
            raise Exception.Create('Pattern escaped shape bounds');
          if Pixels[I*4+1]<>0 then raise Exception.Create('Width zero still drew border');
        end;
      if Pattern=0 then Check(Filled=0,'no fill and zero border leave transparent shape')
      else if Pattern=1 then begin Solid:=Filled; Check(Solid=3600,'solid fill covers shape'); end
      else
      begin
        Check((Filled>0) and (Filled<Solid),'hatch keeps gaps and stays clipped '+IntToStr(Pattern));
        Check(not CompareMem(@Pixels[0],@Previous[0],Length(Pixels)),'hatch directions differ '+IntToStr(Pattern));
      end;
      Previous:=Copy(Pixels);
    end;
    Surface.Canvas.Clear(0); D.Lines[4].Width:=4; D.Lines[4].OutlineWidth:=0;
    P:=TGraphPainter.Create(Surface.Canvas,D,1);
    try P.Box(RectF(20,20,80,80),$FFFF0000,$FF00FF00,1,0); finally P.Free; end;
    Surface.ReadPixels(TSkImageInfo.Create(100,100,TSkColorType.RGBA8888,TSkAlphaType.Unpremul),@Pixels[0],400);
    Check(Pixels[(50*100+50)*4+3]=0,'no fill keeps shape interior transparent');
    Check((Pixels[(50*100+20)*4+1]=255) and (Pixels[(50*100+20)*4+3]=255),
      'no fill preserves independent border');
    D.Series[0].LineColor:=$FF00FF00; D.Series[0].FillColor:=$FFFF0000;
    D.Series[0].FillPattern:=0; E:=LoadGraph(SaveGraph(D));
    try Check((E.Series[0].FillPattern=0) and (E.Series[0].LineColor=$FF00FF00) and
      (E.Series[0].FillColor=$FFFF0000),'independent colors and no fill round trip'); finally E.Free; end;
    for K:=gkRadar to gkPie do
    begin
      D.Kind:=K; D.Lines[4].Color:=$FF123456; D.Lines[5].Color:=$FF654321;
      Json:=TJSONObject.ParseJSONValue(SaveGraph(D)) as TJSONObject;
      try
        Json.RemovePair('version').Free; Json.AddPair('version',TJSONNumber.Create(2));
        for Item in Json.GetValue<TJSONArray>('series') do
          TJSONObject(Item).RemovePair('fillPattern').Free;
        Text:=Json.ToJSON;
      finally Json.Free; end;
      E:=LoadGraph(Text);
      try
        Check(E.Series[0].FillPattern=1,'old settings default to solid '+IntToStr(Ord(K)));
        case K of
          gkRadar: Check(E.Series[0].LineColor=D.Series[0].FillColor,'old radar border color migration');
          gkBar: Check(E.Series[0].LineColor=D.Lines[4].Color,'old bar border color migration');
          gkPie: Check(E.Series[0].LineColor=D.Lines[5].Color,'old pie border color migration');
          gkLine: Check(E.Series[0].LineColor=D.Series[0].LineColor,'old line color retained');
        end;
      finally E.Free; end;
    end;
  finally D.Free; end;
end;
procedure Run;
var D,E:TGraphDocument; S:TGraphShared; V:TGraphValues; Scale:TGraphScale;
  A:TGraphAnimation; Pixels,Background:TBytes; Labels:TArray<TGraphLabel>;
  K:TGraphKind; I,AlphaCount,ValueLabels:Integer;
  Failed:Boolean; Text:string; Img:ISkImage;
  TitleWidth,PartialLabelTop,FullLabelTop:Single;
  Solo:TGraphShared; PartialAlpha,FullAlpha:Integer;
begin
  CheckThreadFloatScope;
  CheckRenderFloatState;
  CheckMissingValues;
  CheckTextOnTop; CheckBaseLinesOnTop; CheckSharedValueSize; CheckLegendAttachment; CheckFonts; CheckRadarBounds; CheckRadarOverlap; CheckDataLines; CheckFillPatterns;
  D:=TGraphDocument.Create;
  try
    D.ResetBounds(640,480); S:=DefaultShared;
    Check((D.TextStyles[trTitle].OutlineWidth=1) and
      (D.TextStyles[trTitle].OutlineBlur=0) and
      (D.TextStyles[trTitle].ShadowX=0) and
      (D.TextStyles[trTitle].ShadowY=0) and
      (D.TextStyles[trTitle].ShadowBlur=0),'text outline starts at one with shadow and blur disabled');
    S.Title:='Graph'; S.Names:='A'#13#10'B'#13#10'C'; S.Units:='kg';
    S.Values:='10,20,30'#13#10'15,25,35'#13#10'20,30,40';
    V:=ParseValues(S.Values,3,3); Check(V[2,2]=40,'matrix order');
    Failed:=False; try V:=ParseValues('NaN',1,1); except Failed:=True; end;
    Check(Failed,'reject non-finite input');
    Failed:=False; try V:=ParseValues('1,2',1,1); except Failed:=True; end;
    Check(Failed,'reject extra columns');
    Check(FormatGraphValue(1234.5,'約#,##0.0kg')='約1,234.5kg','format literal prefix and suffix');
    Check(FormatGraphValue(1,'')='','empty format hides values');
    D.Kind:=gkBar; D.Stacked:=True; V:=ParseValues(S.Values,3,3);
    Scale:=CalculateScale(D,V); Check(Scale.Maximum>=105,'stacked automatic scale');
    D.Series[0].LineKind:=3; D.Series[0].Transparency:=45; D.Offsets[3]:=PointF(12,18);
    D.LabelScales[0]:=1.5; D.ValueFormat:='0.0kg';
    Text:=SaveGraph(D); E:=LoadGraph(Text);
    try
      Check(E.Series[0].Transparency=45,'style round trip');
      Check(E.Series[0].LineKind=3,'series line kind round trip');
      Check(E.Offsets[3].Y=18,'offset round trip');
      Check(E.LabelScales[0]=1.5,'label scale round trip');
      E.ResizeStructure(1,1); E.ResizeStructure(3,3);
      Check(E.Offsets[3].X=12,'structure preserves offsets');
      Check(Pos('Graph',Text)=0,'host text not duplicated in JSON');
    finally E.Free; end;
    E:=LoadGraph('{"version":1,"zoom":1}');
    try Check(E.Kind=gkNone,'legacy viewport migration'); finally E.Free; end;
    E:=LoadGraph('{"version":2,"kind":3,"rows":3,"columns":3}');
    try
      Check((E.Kind=gkBar) and (E.LabelScales[0]=1) and
        (Length(E.Series)>0),'missing settings use defaults');
    finally E.Free; end;
    A:=Default(TGraphAnimation); A.GraphMode:=2; A.Progress:=0;
    Check(A.CellProgress(2,1,3,2)=1,'no transition shows all cells');
    A.TransitionMode:=1; A.Progress:=300;
    Check((A.CellProgress(0,0,3,2)=1) and
      (A.CellProgress(2,0,3,2)=1) and
      (A.CellProgress(2,1,3,2)=0),'column-group progress');
    A.TransitionMode:=2; A.Progress:=300;
    Check((A.CellProgress(0,0,3,2)=1) and
      (A.CellProgress(1,0,3,2)=0.5) and
      (A.CellProgress(2,0,3,2)=0),'row-group progress');
    A.TransitionMode:=4; A.Progress:=150;
    Check((A.CellProgress(0,0,3,2)=1) and
      (A.CellProgress(0,1,3,2)=0.5) and
      (A.CellProgress(1,0,3,2)=0),'row-major cell progress');
    A.TransitionMode:=3;
    Check((A.CellProgress(0,0,3,2)=1) and
      (A.CellProgress(1,0,3,2)=0.5) and
      (A.CellProgress(0,1,3,2)=0),'column-major cell progress');
    A.Progress:=100;
    Check((A.CellProgress(0,0,3,2)=1) and
      (A.CellProgress(1,0,3,2)=0),'one cell completes at 100');
    A.Progress:=600;
    Check(A.CellProgress(2,1,3,2)=1,'all cells complete at matrix endpoint');
    A.Progress:=150;
    A.GraphMode:=1;
    Check((A.ShapeProgress(1,0,3,2)=1) and
      (A.CellOpacity(1,0,3,2)=0.5),'fade keeps completed shape');
    A.GraphMode:=2;
    Check((A.ShapeProgress(1,0,3,2)=0.5) and
      (A.CellOpacity(1,0,3,2)=1),'growth uses current shape');
    A.Progress:=105;
    Check((A.CellProgress(1,0,3,2)>0) and
      (A.CellOpacity(1,0,3,2)<1),'growth starts with short fade');
    A.ZoomPercent:=150; Check(A.ZoomScale=1.5,'focus zoom scale');
    A:=Default(TGraphAnimation);
    E:=TGraphDocument.Create;
    try
      E.Kind:=gkBar; E.ResizeStructure(1,1); E.ResetBounds(640,480);
      E.ValueFormat:='0';
      for I:=0 to High(E.Lines) do E.Lines[I].Kind:=0;
      Solo:=Default(TGraphShared); Solo.Values:='80';
      A.TransitionMode:=4; A.GraphMode:=2; A.Progress:=0;
      Pixels:=RenderGraph(E,Solo,A,640,480,Labels);
      Check(ValueLabelTop(Labels)<0,'value hidden before animation starts');
      A.Progress:=50;
      Pixels:=RenderGraph(E,Solo,A,640,480,Labels);
      PartialLabelTop:=ValueLabelTop(Labels);
      Check(PartialLabelTop>=0,'value appears during growth');
      Check(Pixels[(160*640+320)*4+3]=0,'growth geometry stops at current value');
      A.Progress:=100;
      Pixels:=RenderGraph(E,Solo,A,640,480,Labels);
      FullLabelTop:=ValueLabelTop(Labels);
      Check((FullLabelTop>=0) and (PartialLabelTop>FullLabelTop+40),
        'value label follows growing bar');
      FullAlpha:=Pixels[(160*640+320)*4+3];
      A.GraphMode:=1; A.Progress:=50;
      Pixels:=RenderGraph(E,Solo,A,640,480,Labels);
      PartialAlpha:=Pixels[(160*640+320)*4+3];
      Check((Abs(ValueLabelTop(Labels)-FullLabelTop)<1) and
        (PartialAlpha>0) and (PartialAlpha<FullAlpha),
        'fade keeps final geometry and reduces opacity');
      A:=Default(TGraphAnimation); A.Progress:=100; A.ZoomPercent:=100;
      Pixels:=RenderGraph(E,Solo,A,640,480,Labels);
      Check(Pixels[(200*640+110)*4+3]=0,'zoom sample starts outside bar');
      A.ZoomPercent:=150;
      Pixels:=RenderGraph(E,Solo,A,640,480,Labels);
      Check(Pixels[(200*640+110)*4+3]>0,'focus zoom expands around active bar');
    finally E.Free; end;
    E:=TGraphDocument.Create;
    try
      E.Kind:=gkRadar; E.ResizeStructure(3,1); E.ResetBounds(640,480);
      for I:=0 to High(E.Lines) do E.Lines[I].Kind:=0;
      Solo:=Default(TGraphShared); Solo.Values:='80'#13#10'80'#13#10'80';
      A:=Default(TGraphAnimation); A.TransitionMode:=4;
      A.GraphMode:=2; A.Progress:=100;
      Pixels:=RenderGraph(E,Solo,A,640,480,Labels);
      PartialAlpha:=Pixels[(205*640+335)*4+3];
      A.Progress:=150;
      Pixels:=RenderGraph(E,Solo,A,640,480,Labels);
      Check(Pixels[(205*640+335)*4+3]>PartialAlpha,
        'radar fills center and first two vertices during second cell');
    finally E.Free; end;
    A:=Default(TGraphAnimation);
    D.Kind:=gkBar; D.LabelScales[0]:=1;
    Pixels:=RenderGraph(D,S,A,640,480,Labels);
    TitleWidth:=0;
    for I:=0 to High(Labels) do if Labels[I].ID=0 then TitleWidth:=Labels[I].Bounds.Width;
    D.LabelScales[0]:=2;
    Pixels:=RenderGraph(D,S,A,640,480,Labels);
    for I:=0 to High(Labels) do if Labels[I].ID=0 then
      Check(Labels[I].Bounds.Width>TitleWidth*1.8,'label scale changes rendering');
    D.LabelScales[0]:=1.5;
    for K:=gkRadar to gkPie do
    begin
      D.Kind:=K; D.Stacked:=False; D.TextStyles[trTitle].OutlineWidth:=2;
      D.TextStyles[trTitle].ShadowBlur:=3; D.TextStyles[trTitle].ShadowX:=4;
      if K=gkPie then begin D.ResizeStructure(3,1); S.Values:='10'#13#10'20'#13#10'30'; end;
      Pixels:=RenderGraph(D,S,A,640,480,Labels); AlphaCount:=0;
      for I:=0 to 640*480-1 do if Pixels[I*4+3]<>0 then Inc(AlphaCount);
      Check((AlphaCount>100) and (AlphaCount<640*480),'graph transparent render '+IntToStr(Ord(K)));
      Check(Length(Labels)>0,'editable labels '+IntToStr(Ord(K)));
      Img:=TSkImage.MakeRasterCopy(TSkImageInfo.Create(640,480,TSkColorType.RGBA8888,TSkAlphaType.Unpremul),@Pixels[0],640*4);
      Img.EncodeToFile('graph-'+IntToStr(Ord(K))+'.png');
      A.TransitionMode:=4; A.GraphMode:=2; A.Progress:=50;
      Pixels:=RenderGraph(D,S,A,640,480,Labels);
      ValueLabels:=0;
      for I:=0 to High(Labels) do
        if (Labels[I].ID>=2+MaxGraphRows) and (Labels[I].ID<GraphTickLabelBase) then Inc(ValueLabels);
      Check(ValueLabels>0,'animated values render '+IntToStr(Ord(K)));
      A.GraphMode:=1;
      Pixels:=RenderGraph(D,S,A,640,480,Labels);
      Check(Length(Pixels)=640*480*4,'animated fade renders '+IntToStr(Ord(K)));
      A:=Default(TGraphAnimation);
    end;
    Background:=TBytes.Create(0,0,255,255); Pixels:=TBytes.Create(255,0,0,128);
    CompositeRgba(Background,Pixels);
    Check((Background[0]=128) and (Background[2]=127) and (Background[3]=255),'source over alpha');
  finally D.Free; end;
end;
begin
  try Run; Writeln('TOTAL ',Count); except on E:Exception do begin Writeln(E.ClassName,': ',E.Message); ExitCode:=1; end; end;
end.
