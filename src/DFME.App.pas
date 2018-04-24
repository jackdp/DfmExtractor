unit DFME.App;

{$IFDEF FPC}
  {$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  SysUtils,
  JPL.Strings,
  JPL.Console,
  JPL.ConsoleApp,
  JPL.CmdLineParser,
  DFME.Types,
  DFME.PROCS,
  JclPeImage;

type

  TApp = class(TJPConsoleApp)
  private
    AppParams: TAppParams;
    Pe: TJclPeImage;
  public
    constructor Create;
    //destructor Destroy; override;

    procedure Init;
    procedure Run;
    procedure Done;

    procedure RegisterOptions;
    procedure ProcessOptions;
    procedure ProcessPeFile;

    procedure ListDfms;
    procedure SaveAllDfms;

    function GetDfmTextByIndex(var FormName, ErrStr: string): string;
    procedure SaveOneDfm(const FormIndex: integer); overload;

    function GetDfmTextByName(const FormNameOrClass: string; var ErrStr: string): string; overload;
    procedure SaveOneDfm(const FormNameOrClass: string); overload;

    procedure DisplayHelpAndExit(const ExCode: integer);
    procedure DisplayShortUsageAndExit(const Msg: string; const ExCode: integer);
    procedure DisplayBannerAndExit(const ExCode: integer);
    procedure DisplayMessageAndExit(const Msg: string; const ExCode: integer);
  end;



implementation



constructor TApp.Create;
begin
  inherited Create;
end;

//destructor TApp.Destroy;
//begin
//
//  inherited Destroy;
//end;

{$region '                    Init                              '}
procedure TApp.Init;
begin
  //----------------------------------------------------------------------------

  AppName := 'DfmExtractor';
  MajorVersion := 1;
  MinorVersion := 1;
  Date := EncodeDate(2018, 2, 27);
  FullNameFormat := '%AppName% %MajorVersion%.%MinorVersion% [%OSShort% %Bits%-bit] (%AppDate%)';
  Description := 'Extracts DFM, LFM and FRM forms from executable files compiled by Delphi, Lazarus and CodeTyphon.';
  LicenseName := 'Freeware, OpenSource';
  Author := 'Jacek Pazera';
  HomePage := 'http://www.pazera-software.com/products/dfm-extractor/';
  HelpPage := HomePage;

  //-----------------------------------------------------------------------------

  TryHelpStr := ENDL + 'Try "' + ExeShortName + ' --help for more info.';

  ShortUsageStr :=
    ENDL +
    'Usage: ' + ExeShortName +
    ' -i=FILE [-n=NAME] [-idx=X] [-o=FILE] [-e=EXT] [-p=STR] [-a] [-d=DIR] [-l] [-h] [-V] [--home]' + ENDL +
    ENDL +
    'Mandatory arguments to long options are mandatory for short options too.' + ENDL +
    'Options are case-sensitive. Options in square brackets are optional.';

  ExamplesStr :=
    ENDL +
    'Examples:' + ENDL + ENDL +
    'List all forms in the file program.exe:' + ENDL +
    '  ' + ExeShortName + ' -i program.exe -l' + ENDL +
    ENDL +
    'Save all forms from the program.exe file to files with the LFM extension:' + ENDL +
    '  ' + ExeShortName + ' -i program.exe -a -e lfm' + ENDL +
    ENDL +
    'Save form "Form1" from the program.exe file to "Some Form.dfm" file:' + ENDL +
    '  ' + ExeShortName + ' -i program.exe -n Form1 -o "Some Form.dfm"';


  //------------------------------------------------------------------------------

  AppParams.DefaultExt := '.dfm';
  AppParams.InFile := '';
  AppParams.OutFile := '';
  AppParams.OutDir := '';
  AppParams.ListDfms := False;
  AppParams.SaveAll := False;
  AppParams.OutFilePrefix := '';
  AppParams.FormName := '';
  AppParams.FormIndex := -1;
end;
{$endregion Init}

procedure TApp.Run;
begin
  inherited;

  RegisterOptions;
  Cmd.Parse;
  ProcessOptions;
  if Terminated then Exit;

  ProcessPeFile;

end;

procedure TApp.Done;
begin
  if Assigned(Pe) then FreeAndNil(Pe);
end;

{$region '                    RegisterOptions                   '}
procedure TApp.RegisterOptions;
const
  MAX_LINE_LEN = 102;
var
  Category: string;
begin

  Cmd.CommandLineParsingMode := cpmCustom;
  Cmd.UsageFormat := cufWget;


  // ------------ Registering command-line options -----------------
  Category := 'inout';

  Cmd.RegisterOption('i', 'input-file', cvtRequired, True, False, 'An executable file containing Delphi, Lazarus or CodeTyphon forms (DFM, LFM, FRM).', 'FILE', Category);
  Cmd.RegisterOption('n', 'form-name', cvtRequired, False, False, 'Form name or form class name to extract.', 'NAME', Category);
  Cmd.RegisterOption('idx', 'form-index', cvtRequired, False, False, 'The index of the form to extract. Non-negative integer.', 'X', Category);
  Cmd.RegisterOption('o', 'output-file', cvtRequired, False, False, 'The output file with extracted form.', 'FILE', Category);
  Cmd.RegisterOption('e', 'extension', cvtRequired, False, False, 'The default extension of the output file(s). If not specified, DFM will be used.', 'EXT', Category);
  Cmd.RegisterOption('p', 'prefix', cvtRequired, False, False, 'Output file(s) name prefix (for the -a option).', 'STR', Category);
  Cmd.RegisterOption('a', 'save-all', cvtNone, False, False, 'Saves all forms from the specified executable file to the given (or current) directory.', '', Category);
  Cmd.RegisterOption('d', 'output-dir', cvtRequired, False, False, 'Output directory (for the -a option).', 'DIR', Category);
  Cmd.RegisterOption('l', 'list', cvtNone, False, False, 'Displays a list of all forms in the given input file.', '', Category);

  Category := 'info';
  Cmd.RegisterOption('h', 'help', cvtNone, False, False, 'Show this help.', '', Category);
  Cmd.RegisterShortOption('?', cvtNone, False, True, '', '', '');
  Cmd.RegisterOption('V', 'version', cvtNone, False, False, 'Show application version.', '', Category);
  Cmd.RegisterLongOption('home', cvtNone, False, False, 'Opens program home page in the default browser.', '', Category);

  UsageStr :=
    ENDL +
    'Input/output:' + ENDL + Cmd.OptionsUsageStr('  ', 'inout', MAX_LINE_LEN, '  ', 30) + ENDL + ENDL +
    'Info:' + ENDL + Cmd.OptionsUsageStr('  ', 'info', MAX_LINE_LEN, '  ', 30);

end;
{$endregion RegisterOptions}

{$region '                    ProcessOptions                    '}
procedure TApp.ProcessOptions;
var
  x: integer;
begin

  if Cmd.ErrorCount > 0 then
  begin
    DisplayShortUsageAndExit(Cmd.ErrorsStr, CON_EXIT_CODE_SYNTAX_ERROR);
    Exit;
  end;

  //------------------------------------------------------------------------------

  if (ParamCount = 0) or (Cmd.IsLongOptionExists('help')) or (Cmd.IsOptionExists('?')) then
  begin
    DisplayHelpAndExit(CON_EXIT_CODE_OK);
    Exit;
  end;

  //------------------------------------------------------------------------------

  if Cmd.IsLongOptionExists('home') then GoToHomePage; // and continue

  //------------------------------------------------------------------------------

  if Cmd.IsOptionExists('version') then
  begin
    DisplayBannerAndExit(CON_EXIT_CODE_OK);
    Exit;
  end;

  //------------------------------------------------------------------------------

  if not Cmd.IsOptionExists('i') then
  begin
    DisplayShortUsageAndExit('You must provide an input file.', CON_EXIT_CODE_SYNTAX_ERROR);
    Exit;
  end
  else
  begin
    AppParams.InFile := Trim(Cmd.GetOptionValue('i'));
    if not FileExists(AppParams.InFile) then
    begin
      DisplayShortUsageAndExit('Input file "' + AppParams.InFile + '" does not exists!', CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;
  end;

  //-------------------------------------------------------------------------------

  if ( not Cmd.IsOptionExists('n') ) and ( not Cmd.IsOptionExists('idx') ) and ( not Cmd.IsOptionExists('a') ) and ( not Cmd.IsOptionExists('l') ) then
  begin
    Writeln('Nothing to do!');
    Writeln('You should specify at least one of the options: -n, -idx, -a, -l');
    DisplayTryHelp;
    ExitCode := CON_EXIT_CODE_SYNTAX_ERROR;
    Terminate;
    Exit;
  end;

  //------------------------------------------------------------------------------

  if Cmd.IsOptionExists('o') then AppParams.OutFile := Cmd.GetOptionValue('o');
  if Cmd.IsOptionExists('p') then AppParams.OutFilePrefix := Cmd.GetOptionValue('p');
  if Cmd.IsOptionExists('a') then AppParams.SaveAll := True;
  if Cmd.IsOptionExists('d') then AppParams.OutDir := Cmd.GetOptionValue('d') else AppParams.OutDir := GetCurrentDir;
  if Cmd.IsOptionExists('l') then AppParams.ListDfms := True;
  if Cmd.IsOptionExists('n') then AppParams.FormName := Cmd.GetOptionValue('n');

  //------------------------------------------------------------------------------

  if Cmd.IsOptionExists('idx') then
  begin
    if not TryStrToInt(Cmd.GetOptionValue('idx'), x) then
    begin
      DisplayShortUsageAndExit('The form index should be a non-negative integer.', CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;
    if x < 0 then
    begin
      DisplayShortUsageAndExit('The form index should be a non-negative integer.', CON_EXIT_CODE_SYNTAX_ERROR);
      Exit;
    end;
    AppParams.FormIndex := x;
  end;

  //------------------------------------------------------------------------------

  if Cmd.IsOptionExists('e') then
  begin
    AppParams.DefaultExt := FixFileName(Trim(Cmd.GetOptionValue('e')));
    if AppParams.DefaultExt = '' then AppParams.DefaultExt := '.dfm';
    if Copy(AppParams.DefaultExt, 1, 1) <> '.' then Insert('.', AppParams.DefaultExt, 1);
  end;

end;

{$endregion ProcessOptions}


{$region '                    ProcessPeFile                     '}
procedure TApp.ProcessPeFile;
var
  PackerName, ErrStr: string;
begin

  if not IsValidPeFile(AppParams.InFile) then
  begin
    DisplayMessageAndExit('The input file must be a Windows 32 or 64-bit Portable Executable (PE) file.', CON_EXIT_CODE_INVALID_FILE);
    Exit;
  end;

  Pe := TJclPeImage.Create(True);

  // Po przypisaniu FileName, TJclPeImage automatycznie analizuje plik.
  Pe.FileName := AppParams.InFile;

  // Checking if everything went OK.
  if pe.Status <> TJclPeImageStatus.stOk then
  begin
    case pe.Status of
      TJclPeImageStatus.stNotLoaded: ErrStr := 'NotLoaded: The file could not be loaded.';
      TJclPeImageStatus.stNotPE: ErrStr := 'NotPE: The input file is not a valid Windows 32 or 64-bit Portable Executable (PE) file.';
      TJclPeImageStatus.stNotSupported: ErrStr := 'NotSupported: The given file is not supported.';
      TJclPeImageStatus.stNotFound: ErrStr := 'NotFound: The file can not be found.';
      TJclPeImageStatus.stError: ErrStr := 'An error occurred while parsing the file.';
    else
      ErrStr := 'Unknown error.';
    end;
    DisplayMessageAndExit('PE.STATUS: ' + ErrStr, CON_EXIT_CODE_ERROR);
    Exit;
  end;

  if IsPeFilePacked(Pe, PackerName) then
  begin
    DisplayMessageAndExit('The input file is packed by ' + PackerName + '. You must first unpack the file.', CON_EXIT_CODE_PACKED_FILE);
    Exit;
  end;



  // ----------------- DFM list ---------------------
  if AppParams.ListDfms then
  begin
    ListDfms;
    Exit;
  end;

  // --------------- Save all DFMs -------------------
  if AppParams.SaveAll then
  begin
    SaveAllDfms;
    Exit;
  end;

  // ------------- Save DFM - INDEX -------------------
  if AppParams.FormIndex >= 0 then
  begin
    SaveOneDfm(AppParams.FormIndex);
    Exit;
  end;

  // ------------- Save DFM - NAME --------------------
  if AppParams.FormName <> '' then
  begin
    SaveOneDfm(AppParams.FormName);
    Exit;
  end;
end;

{$endregion ProcessPeFile}

{$region '                    ListDfms                          '}
procedure TApp.ListDfms;
var
  List: TFormList;
  ErrStr, Sep: string;
  i, x, xMaxLen: integer;
  FormItem: TFormItem;
begin

  SetLength(List, 0);
  ErrStr := '';

  if not GetFormListFromPeFile(Pe, List, ErrStr) then
  begin
    DisplayMessageAndExit(ErrStr, CON_EXIT_CODE_ERROR);
    Exit;
  end;

  Writeln('Forms: ' + IntToStrEx(Length(List)));

  xMaxLen := 0;
  for i := 0 to High(List) do
  begin
    x := Length(List[i].FormName);
    if x > xMaxLen then xMaxLen := x;
  end;

  Sep := ' | ';
  Writeln('Index' + Sep + ' Lines' + Sep + PadRight('Form name', xMaxLen, ' ') + Sep + 'Form class');
  Writeln(DASH_LINE);

  for i := 0 to High(List) do
  begin
    FormItem := List[i];
    Writeln(
      Pad(IntToStr(i {FormItem.Index}), 5, ' ') + Sep +
      Pad(IntToStrEx(FormItem.Lines), 6, ' ') + Sep +
      PadRight(FormItem.FormName, xMaxLen, ' ') + Sep +
      FormItem.FormClassName
    );
  end;

end;
{$endregion ListDfms}

{$region '                    SaveAllDfms                       '}
procedure TApp.SaveAllDfms;
var
  List: TFormList;
  FormItem: TFormItem;
  ErrStr, DfmFile, Dir, FilePrefix: string;
  i: integer;
begin

  Dir := IncludeTrailingPathDelimiter(AppParams.OutDir);
  if not DirectoryExists(Dir) then ForceDirectories(Dir);
  if not DirectoryExists(Dir) then
  begin
    DisplayMessageAndExit('Cannot create output directory "' + Dir + '"', CON_EXIT_CODE_ERROR);
    Exit;
  end;

  if AppParams.OutFilePrefix <> '' then FilePrefix := FixFileName(AppParams.OutFilePrefix) else FilePrefix := '';

  ErrStr := '';
  SetLength(List, 0);

  if not GetFormListFromPeFile(Pe, List, ErrStr) then
  begin
    DisplayMessageAndExit(ErrStr, CON_EXIT_CODE_ERROR);
    Exit;
  end;

  for i := 0 to High(List) do
  begin
    FormItem := List[i];
    DfmFile := Dir + FilePrefix + FixFileName(FormItem.FormName) + AppParams.DefaultExt;
    SaveStringToFile(FormItem.DFM, DfmFile);
    Writeln('File saved: ' + DfmFile);
  end;

end;
{$endregion SaveAllDfms}

{$region '                    GetDfmTextByIndex                 '}
function TApp.GetDfmTextByIndex(var FormName, ErrStr: string): string;
var
  List: TFormList;
  FormItem: TFormItem;
begin
  Result := '';
  ErrStr := 'Form with index ' + IntToStr(AppParams.FormIndex) + ' does not exists!';
  SetLength(List, 0);

  if not GetFormListFromPeFile(Pe, List, ErrStr) then
  begin
    DisplayMessageAndExit(ErrStr, CON_EXIT_CODE_ERROR);
    Exit;
  end;

  if not (AppParams.FormIndex in [0..High(List)]) then
  begin
    ErrStr := 'Invalid form index: ' + IntToStr(AppParams.FormIndex) + '. Expected integer in range 0..' + IntToStr(High(List));
    Exit;
  end;

  FormItem := List[AppParams.FormIndex];
  Result := FormItem.DFM;
  FormName := FormItem.FormName;
  ErrStr := '';
end;
{$endregion GetDfmTextByIndex}

{$region '                    GetDfmTextByName                  '}
function TApp.GetDfmTextByName(const FormNameOrClass: string; var ErrStr: string): string;
var
  List: TFormList;
  FormItem: TFormItem;
  UFormNameOrClass: string;
  i: integer;
begin

  Result := '';
  ErrStr := 'Form "' + FormNameOrClass + '" does not exists!';
  UFormNameOrClass := TrimUp(FormNameOrClass);
  SetLength(List, 0);

  if not GetFormListFromPeFile(Pe, List, ErrStr) then
  begin
    DisplayMessageAndExit(ErrStr, CON_EXIT_CODE_ERROR);
    Exit;
  end;

  for i := 0 to High(List) do
  begin
    FormItem := List[i];
    if (UFormNameOrClass = UpperCase(FormItem.FormName)) or (UFormNameOrClass= UpperCase(FormItem.FormClassName)) then
    begin
      Result := FormItem.DFM;
      ErrStr := '';
      Break;
    end;
  end;

end;
{$endregion GetDfmTextByName}

{$region '                    SaveOneDfm - INDEX                '}
procedure TApp.SaveOneDfm(const FormIndex: integer);
var
  DfmStr, FormName, ErrStr, OutFile: string;
begin
  DfmStr := GetDfmTextByIndex(FormName{%H-}, ErrStr{%H-});

  if ErrStr <> '' then
  begin
    DisplayMessageAndExit(ErrStr, CON_EXIT_CODE_ERROR);
    Exit;
  end;

  if DfmStr = '' then
  begin
    DisplayMessageAndExit('An error occurred while processing the file: Empty DFM', CON_EXIT_CODE_ERROR);
    Exit;
  end;

  if Trim(FormName) = '' then FormName := 'Form_' + IntToStr(FormIndex);

  OutFile := AppParams.OutFile;
  if Trim(OutFile) = '' then OutFile := FormName;
  if ExtractFileExt(OutFile) = '' then OutFile := ChangeFileExt(OutFile, AppParams.DefaultExt);
  SaveStringToFile(DfmStr, OutFile);
  Writeln('The form with index ', FormIndex, ' has been saved to file: ' + OutFile);
end;
{$endregion SaveOneDfm - INDEX}

{$region '                    SaveOneDfm - NAME                 '}
procedure TApp.SaveOneDfm(const FormNameOrClass: string);
var
  DfmStr, ErrStr, OutFile: string;
begin
  DfmStr := GetDfmTextByName(FormNameOrClass, ErrStr{%H-});

  if ErrStr <> '' then
  begin
    DisplayMessageAndExit(ErrStr, CON_EXIT_CODE_ERROR);
    Exit;
  end;

  if DfmStr = '' then
  begin
    DisplayMessageAndExit('An error occurred while processing the file: Empty DFM', CON_EXIT_CODE_ERROR);
    Exit;
  end;

  OutFile := AppParams.OutFile;
  if Trim(OutFile) = '' then OutFile := FixFileName(FormNameOrClass);
  if ExtractFileExt(OutFile) = '' then OutFile := ChangeFileExt(OutFile, AppParams.DefaultExt);
  SaveStringToFile(DfmStr, OutFile);
  Writeln('The form with name/class "', FormNameOrClass, '" has been saved to file: ' + OutFile);
end;
{$endregion SaveOneDfm - NAME}


{$region '                    Display... procs                  '}
procedure TApp.DisplayHelpAndExit(const ExCode: integer);
begin
  DisplayBanner;
  DisplayShortUsage;
  DisplayUsage;
  DisplayExamples;
  ExitCode := ExCode;
  Terminate;
end;

procedure TApp.DisplayShortUsageAndExit(const Msg: string; const ExCode: integer);
begin
  if Msg <> '' then Writeln(Msg);
  DisplayShortUsage;
  DisplayTryHelp;
  ExitCode := ExCode;
  Terminate;
end;

procedure TApp.DisplayBannerAndExit(const ExCode: integer);
begin
  DisplayBanner;
  ExitCode := ExCode;
  Terminate;
end;

procedure TApp.DisplayMessageAndExit(const Msg: string; const ExCode: integer);
begin
  Writeln(Msg);
  ExitCode := ExCode;
  Terminate;
end;
{$endregion Display... procs}

end.
