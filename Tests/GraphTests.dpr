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
procedure Run;
var D,E:TGraphDocument; S:TGraphShared; V:TGraphValues; Scale:TGraphScale;
  A:TGraphAnimation; Pixels,Background:TBytes; Labels:TArray<TGraphLabel>;
  K:TGraphKind; I,AlphaCount:Integer; Failed:Boolean; Text:string; Img:ISkImage;
  TitleWidth:Single;
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
    A:=Default(TGraphAnimation); A.ElementMode:=1; A.Progress:=150;
    Check((A.Element(0)=1) and (A.Element(1)=0.5) and (A.Element(2)=0),'element progress');
    A.Progress:=50; Check(A.Element(0)=0.5,'reverse progress');
    A.EnterMode:=1; A.EnterSeconds:=2; A.Time:=1;
    Check(A.Opacity=0.5,'fade timing'); A:=Default(TGraphAnimation);
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
    end;
    Background:=TBytes.Create(0,0,255,255); Pixels:=TBytes.Create(255,0,0,128);
    CompositeRgba(Background,Pixels);
    Check((Background[0]=128) and (Background[2]=127) and (Background[3]=255),'source over alpha');
  finally D.Free; end;
end;
begin
  try Run; Writeln('TOTAL ',Count); except on E:Exception do begin Writeln(E.ClassName,': ',E.Message); ExitCode:=1; end; end;
end.
