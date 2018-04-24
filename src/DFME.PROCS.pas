unit DFME.PROCS;

{$IFDEF FPC}
  {$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  Windows,
  SysUtils, Classes,
  JclPeImage, //<-- https://github.com/project-jedi/jcl/
  DFME.Types
  ;


function IsPeFilePacked(Pe: TJclPeImage; out PackerName: string): Boolean;
function IsValidPeFile(const ExeFile: string): Boolean;
function GetFormListFromPeFile(Pe: TJclPeImage; var List: TFormList; var ErrStr: string): Boolean;
procedure SaveStringToFile(const s: string; const FileName: string);


implementation


function AddUncPrefix(const FileName: string): string;
begin
  if Copy(FileName, 1, 2) <> '\\' then Result := UNC_PREFIX + FileName
  else Result := FileName;
end;


{$region '                          GetFormListFromPeFile                          '}
// TJclPeBorImage ma problemy z plikami EXE skompilowanymi przez Lazarusa/CodeTyphon,
// więc trzeba to zrobić po swojemu.
function GetFormListFromPeFile(Pe: TJclPeImage; var List: TFormList; var ErrStr: string): Boolean;
var
  riRcdataList, riRcdataItem, riRawDfm: TJclPeResourceItem;
  i, x, y: integer;
  FormItem: TFormItem;
  RawData: PAnsiChar;
  msBinDfm, msTextDfm: TMemoryStream;
  slDfm: TStringList;
  FormName, FormClass: string;

  function GetFormNameAndClass: Boolean;
  var
    s: string;
    xp: integer;
  begin
    Result := False;
    FormName := '';
    FormClass := '';
    if slDfm.Count = 0 then Exit;
    s := Trim(slDfm[0]);

    // first line: "object FormName: TFormClass" OR "inherited FrameName: TFrameClass" OR maybe something else...

    xp := Pos(' ', s);
    if xp < 0 then Exit;
    s := Copy(s, xp + 1, Length(s));
    xp := Pos(':', s);
    if xp < 0 then Exit;
    FormName := Trim(Copy(s, 1, xp - 1));
    FormClass := Trim(Copy(s, xp + 1, Length(s)));
    Result := (FormName <> '') and (FormClass <> '');
  end;

begin
  SetLength(List, 0);
  ErrStr := '';
  Result := False;
  if Pe.Status <> TJclPeImageStatus.stOk then Exit;


  // Formularze są zapisywane w zasobach. Jeśli w pliku nie ma zasobów, to nie ma też formularzy.
  if Pe.ResourceList.Count = 0 then
  begin
    ErrStr := 'The file does not contain any resources.';
    Exit;
  end;


  {                                                       }
  {  Resources          // Pe.ResourceList                }
  {   |                                                   }
  {   RCData            // riRcdataList                   }     // TYPE
  {     |                                                 }
  {     TSOMEFORM       // riRcdataItem                   }     // NAME
  {       |                                               }
  {       0             // riRawDfm                       }     // LANG ID
  {                                                       }
  // PEInfo (run as admin) - http://www.pazera-software.pl/products/peinfo/
  // PE Format: https://msdn.microsoft.com/library/windows/desktop/ms680547#the_.rsrc_section



  // Wyszukiwanie zasobów z formularzami
  for i := 0 to Pe.ResourceList.Count - 1 do
  begin

    // Formularze Delphi/Lazarusa są zapisywane w zasobach typu RCData. Inne zasoby ignorujemy.
    if Pe.ResourceList.Items[i].ResourceType <> TJclPeResourceKind.rtRCData then Continue;

    riRcdataList := Pe.ResourceList.Items[i];


    for x := 0 to riRcdataList.List.Count - 1 do
    begin

      riRcdataItem := riRcdataList.List.Items[x];


      for y := 0 to riRcdataItem.List.Count - 1 do
      begin
        riRawDfm := riRcdataItem.List.Items[y];


        // Pierwsze 4 bajty w binarnym DFMie: $54 $50 $46 $30 ('TPF0')
        if riRawDfm.RawEntryDataSize < 4 then Continue;
        RawData := riRawDfm.RawEntryData;
        if (RawData[0] <> 'T') or (RawData[1] <> 'P') or (RawData[2] <> 'F') or (RawData[3] <> '0') then Continue;


        //Writeln('Cool! We (probably) have a form: ' + riRcdataItem.Name);

        msBinDfm := TMemoryStream.Create;
        msTextDfm := TMemoryStream.Create;
        slDfm := TStringList.Create;
        try

          msBinDfm.WriteBuffer(riRawDfm.RawEntryData^, riRawDfm.RawEntryDataSize);
          msBinDfm.Position := 0;
          try
            ObjectBinaryToText(msBinDfm, msTextDfm);
          except
            on EReadError do
            begin
              // Invalid stream format
              Continue;
            end;
          end;
          msTextDfm.Position := 0;
          slDfm.LoadFromStream(msTextDfm);
          if not GetFormNameAndClass then Continue;

          FormItem.Index := Length(List);
          FormItem.FormName := FormName;
          FormItem.FormClassName := FormClass;
          FormItem.DFM := slDfm.Text;
          FormItem.Lines := slDfm.Count;

          SetLength(List, Length(List) + 1);
          List[High(List)] := FormItem;

        finally
          slDfm.Free;
          msTextDfm.Free;
          msBinDfm.Free;
        end;


      end; // for y

    end; // for x

  end; // for i


  if Length(List) = 0 then
  begin
    ErrStr := 'The input file does not contain any Delphi/Lazarus forms.';
    Exit;
  end;

  Result := True;

end;
{$endregion GetFormListFromPeFile}


{$region '               IsPeFilePacked                '}
function IsPeFilePacked(Pe: TJclPeImage; out PackerName: string): Boolean;
var
  i: integer;
  USection: string;
begin
  Result := False;
  PackerName := '';

  if not Pe.StatusOK then Exit(False);

  for i := 0 to Pe.ImageSectionCount - 1 do
  begin

    USection := UpperCase(Pe.ImageSectionNames[i]);

    if USection = 'UPX0' then
    begin
      Result := True;
      PackerName := 'UPX';
      Break;
    end;

    if USection = '.MPRESS1' then
    begin
      Result := True;
      PackerName := 'MPRESS';
      Break;
    end;

    { TODO : Dodać wykrywanie ASPACKA i innych pakerów EXE }

  end; // for i

end;
{$endregion IsPeFilePacked}

function IsValidPeFile(const ExeFile: string): Boolean;
const
  // https://msdn.microsoft.com/en-us/library/windows/desktop/aa364819
  BIN_WIN32 = 0; //SCS_32BIT_BINARY
  BIN_WIN64 = 6; //SCS_64BIT_BINARY
var
  bt: Cardinal;
begin
  bt := 0;
  GetBinaryType(PChar(AddUncPrefix(ExeFile)), bt);
  Result := (bt = BIN_WIN32) or (bt = BIN_WIN64);
end;

procedure SaveStringToFile(const s: string; const FileName: string);
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Text := s;
    sl.SaveToFile(FileName);
  finally
    sl.Free;
  end;
end;


end.
