unit DFME.Types;

{$IFDEF FPC}
  {$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  JPL.Console;
  //JPL.ConsoleApp;

const

  CON_EXIT_CODE_INVALID_FILE = CON_EXIT_CODE_USER + 1;
  CON_EXIT_CODE_PACKED_FILE = CON_EXIT_CODE_USER + 2;
  CON_EXIT_CODE_NO_DFMS = CON_EXIT_CODE_USER + 3;

  {$IFDEF MSWINDOWS} UNC_PREFIX = '\\?\'; {$ELSE} UNC_PREFIX = ''; {$ENDIF}
  DASH_LINE = '--------------------------------------------------------------------------------';

type

  TAppParams = record
    DefaultExt: string;    // -e
    InFile: string;        // -i
    OutFile: string;       // -o
    OutDir: string;        // -d
    ListDfms: Boolean;     // -l
    SaveAll: Boolean;      // -a
    OutFilePrefix: string; // -p
    FormName: string;      // -n
    FormIndex: integer;    // -idx
  end;


  TFormItem = record
    Index: integer;
    FormName: string;
    FormClassName: string;
    DFM: string;
    Lines: integer;
  end;

  TFormList = array of TFormItem; // TList<TFormItem>;


implementation

end.
