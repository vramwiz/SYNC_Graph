unit GraphHostLog;

// 公式SDK logger2.hの最小ABI。失敗した映像処理をホストのログへ記録する。
interface
uses System.SysUtils, AviUtl2FilterTypes;
type
  PGraphLogHandle=^TGraphLogHandle;
  TGraphLogProc=procedure(Handle:PGraphLogHandle; Message:PWideChar); cdecl;
  TGraphLogHandle=record
    Log,Info,Warn,Error,Verbose:TGraphLogProc;
  end;
procedure InitializeGraphLogger(Handle:PGraphLogHandle);
procedure ReportGraphVideoError(Video:PFILTER_PROC_VIDEO; const Stage:string;
  Error:Exception);
implementation
uses Winapi.Windows;
// ホスト所有で、初期化後からDLL終了まで借用する。映像スレッドからログだけを呼ぶ。
var Logger:PGraphLogHandle;
procedure InitializeGraphLogger(Handle:PGraphLogHandle);
begin Logger:=Handle; end;
procedure ReportGraphVideoError(Video:PFILTER_PROC_VIDEO; const Stage:string;
  Error:Exception);
var Message:string;
begin
  // ログの失敗で元の描画例外を隠したり、ホスト境界へ例外を流したりしない。
  try
    Message:='SYNC グラフ ['+Stage+'] '+Error.ClassName+': '+Error.Message;
    if (Video<>nil) and (Video^.Object_<>nil) then
      Message:=Message+Format(' (object=%d effect=%d frame=%d size=%dx%d)',
        [Video^.Object_^.ID,Video^.Object_^.EffectID,Video^.Object_^.Frame,
         Video^.Object_^.Width,Video^.Object_^.Height]);
    OutputDebugString(PChar(Message));
    if (Logger<>nil) and Assigned(Logger^.Error) then Logger^.Error(Logger,PChar(Message));
  except
    // ログなしの旧ホストでも、元の映像処理の失敗を呼出側へ返す。
  end;
end;
end.
