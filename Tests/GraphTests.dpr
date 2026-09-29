program GraphTests;
{$APPTYPE CONSOLE}

// 実際のグラフ専用ユニットを使い、値・保存・透過・4種の描画を検証する。
uses System.SysUtils, System.Types, System.Skia, GraphModel, GraphValues,
  GraphSettings, GraphAnimation, GraphRenderer, GraphPainter, GraphComposite;
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
procedure Run;
var D,E:TGraphDocument; S:TGraphShared; V:TGraphValues; Scale:TGraphScale;
  A:TGraphAnimation; Pixels,Background:TBytes; Labels:TArray<TGraphLabel>;
  K:TGraphKind; I,AlphaCount,ValueLabels:Integer;
  Failed:Boolean; Text:string; Img:ISkImage;
  TitleWidth,PartialLabelTop,FullLabelTop:Single;
  Solo:TGraphShared; PartialAlpha,FullAlpha:Integer;
begin
  D:=TGraphDocument.Create;
  try
    D.ResetBounds(640,480); S:=DefaultShared;
    Check((D.TextStyles[trTitle].OutlineWidth=0) and
      (D.TextStyles[trTitle].OutlineBlur=0) and
      (D.TextStyles[trTitle].ShadowX=0) and
      (D.TextStyles[trTitle].ShadowY=0) and
      (D.TextStyles[trTitle].ShadowBlur=0),'text decoration starts disabled');
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
    D.Series[0].Transparency:=45; D.Offsets[3]:=PointF(12,18);
    D.LabelScales[0]:=1.5; D.ValueFormat:='0.0kg';
    Text:=SaveGraph(D); E:=LoadGraph(Text);
    try
      Check(E.Series[0].Transparency=45,'style round trip');
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
