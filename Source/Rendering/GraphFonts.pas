unit GraphFonts;

// 一覧と描画の書体解決を共通化し、未収録文字だけを代替書体で補う。
interface
uses System.Skia;
type
  TGraphFontRun=record
    Text:string;
    Font:ISkFont;
    Width:Single;
  end;
function ResolveGraphTypeface(const Name:string; const Style:TSkFontStyle):ISkTypeface;
function HasGraphGlyphs(const Face:ISkTypeface; const Text:string):Boolean;
function GraphFontRuns(const Name,Text:string; const Style:TSkFontStyle; Size:Single):TArray<TGraphFontRun>;
implementation
uses System.SysUtils, System.Classes, System.Generics.Collections, Winapi.Windows;
// 編集UIと映像描画の両スレッドから利用する。参照の取得・登録は同じロックで保護する。
var Faces:TDictionary<string,ISkTypeface>; FontStreams:TObjectList<TMemoryStream>; Lock:TObject;
function WindowsTypeface(const Name:string; const Style:TSkFontStyle):ISkTypeface;
var DC:HDC; Font:HFONT; Old:HGDIOBJ; LF:TLogFont; Bytes:DWORD; Stream:TMemoryStream;
begin
  Result:=nil; FillChar(LF,SizeOf(LF),0); LF.lfHeight:=-28;
  LF.lfWeight:=Style.Weight; LF.lfItalic:=Ord(Style.Slant<>TSkFontSlant.Upright);
  LF.lfCharSet:=DEFAULT_CHARSET; StrPLCopy(LF.lfFaceName,Name,LF_FACESIZE-1);
  DC:=CreateCompatibleDC(0); if DC=0 then Exit;
  // DC・HFONTはこの呼出しが所有し、選択前のオブジェクトを戻してから解放する。
  Font:=CreateFontIndirect(LF);
  try
    if Font=0 then Exit;
    Old:=SelectObject(DC,Font);
    try
      Bytes:=GetFontData(DC,0,0,nil,0);
      if (Bytes=GDI_ERROR) or (Bytes=0) then Exit;
      Stream:=TMemoryStream.Create;
      try
        Stream.SetSize(Bytes);
        if GetFontData(DC,0,0,Stream.Memory,Bytes)<>Bytes then Exit;
        Result:=TSkTypeface.MakeFromStream(Stream);
        // Skiaのストリームアダプターは元のTStreamを参照するため、書体より長く保持する。
        if Result<>nil then begin FontStreams.Add(Stream); Stream:=nil; end;
      finally Stream.Free; end;
    finally SelectObject(DC,Old); end;
  finally if Font<>0 then DeleteObject(Font); DeleteDC(DC); end;
end;
function ResolveGraphTypeface(const Name:string; const Style:TSkFontStyle):ISkTypeface;
var Key:string; WindowsFace:ISkTypeface;
begin
  Key:=Name+'|'+IntToStr(Style.Weight)+'|'+IntToStr(Ord(Style.Slant));
  TMonitor.Enter(Lock);
  try
    if Faces.TryGetValue(Key,Result) then Exit;
    Result:=TSkTypeface.MakeFromName(Name,Style);
    // 言語別の別名やユーザー登録書体は、GDIが開いた実フォントから解決する。
    if (Result=nil) or not SameText(Result.FamilyName,Name) then
    begin
      WindowsFace:=WindowsTypeface(Name,Style);
      if WindowsFace<>nil then Result:=WindowsFace;
    end;
    Faces.Add(Key,Result);
  finally TMonitor.Exit(Lock); end;
end;
function HasGraphGlyphs(const Face:ISkTypeface; const Text:string):Boolean;
var Glyph:Word; Font:ISkFont;
begin
  Result:=False; if Face=nil then Exit;
  Font:=TSkFont.Create(Face,28);
  for Glyph in Font.GetGlyphs(Text) do if Glyph=0 then Exit;
  Result:=True;
end;
function GraphFontRuns(const Name,Text:string; const Style:TSkFontStyle; Size:Single):TArray<TGraphFontRun>;
const Fallbacks:array[0..4] of string=('Yu Gothic UI','Meiryo','Segoe UI','Segoe UI Symbol','Segoe UI Emoji');
var Primary,Face,Previous,Candidate:ISkTypeface; Piece,Fallback:string; I,N,Count:Integer;
begin
  Result:=nil; Primary:=ResolveGraphTypeface(Name,Style);
  if HasGraphGlyphs(Primary,Text) then
  begin
    SetLength(Result,1); Result[0].Text:=Text; Result[0].Font:=TSkFont.Create(Primary,Size);
    Result[0].Width:=Result[0].Font.MeasureText(Text); Exit;
  end;
  Previous:=nil; I:=1;
  while I<=Length(Text) do
  begin
    // UTF-16のサロゲートペアは分割しない。代替は文字単位で、複雑な字形合成は対象外。
    N:=1;
    if (Ord(Text[I])>=$D800) and (Ord(Text[I])<=$DBFF) and (I<Length(Text)) and
      (Ord(Text[I+1])>=$DC00) and (Ord(Text[I+1])<=$DFFF) then N:=2;
    Piece:=Copy(Text,I,N); Inc(I,N); Face:=Primary;
    if not HasGraphGlyphs(Face,Piece) then
      for Fallback in Fallbacks do
      begin
        Candidate:=ResolveGraphTypeface(Fallback,Style);
        if HasGraphGlyphs(Candidate,Piece) then begin Face:=Candidate; Break; end;
      end;
    Count:=Length(Result);
    if (Count=0) or (Face<>Previous) then
    begin
      SetLength(Result,Count+1); Result[Count].Font:=TSkFont.Create(Face,Size);
    end else Dec(Count);
    Result[Count].Text:=Result[Count].Text+Piece; Previous:=Face;
  end;
  for I:=0 to High(Result) do Result[I].Width:=Result[I].Font.MeasureText(Result[I].Text);
end;
initialization
  Lock:=TObject.Create; Faces:=TDictionary<string,ISkTypeface>.Create; FontStreams:=TObjectList<TMemoryStream>.Create(True);
finalization
  // ホスト終了後に書体参照を先に解放し、参照先ストリームを最後に破棄する。
  Faces.Free; FontStreams.Free; Lock.Free;
end.
