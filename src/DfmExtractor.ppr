program DfmExtractor;

{$IFDEF FPC}
  {$mode objfpc}{$H+}
{$ENDIF}

{$SetPEFlags $20} // IMAGE_FILE_LARGE_ADDRESS_AWARE

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  DFME.App in 'DFME.App.pas',
  DFME.Types in 'DFME.Types.pas'
  ;

var
  App: TApp;

procedure MyExitProcedure;
begin
  if Assigned(App) then
  begin
    App.Done;
    FreeAndNil(App);
  end;
end;


begin

  App := TApp.Create;
  try

    try

      App.ExitProcedure := @MyExitProcedure;
      App.Init;
      App.Run;
      if Assigned(App) then App.Done;

    except
      on E: Exception do Writeln(E.ClassName, ': ', E.Message);
    end;

  finally
    if Assigned(App) then App.Free;
  end;

end.
