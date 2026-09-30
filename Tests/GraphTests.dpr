program GraphTests;
{$APPTYPE CONSOLE}

// 実際のグラフ専用ユニットを使い、値・保存・透過・4種の描画を検証する。
uses System.SysUtils, System.Types, System.Skia, System.JSON, GraphModel, GraphValues,
  GraphRadarGeometry, GraphSettings, GraphFonts, GraphAnimation, GraphRenderer, GraphPainter, GraphComposite;
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
  CheckTextOnTop; CheckLegendAttachment; CheckFonts; CheckRadarBounds; CheckRadarOverlap; CheckDataLines; CheckFillPatterns;
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
        if Labels[I].ID>=2+MaxGraphRows then Inc(ValueLabels);
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
