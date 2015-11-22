program AutoSearch;

uses
  Windows,
  Forms,
  Thread in 'Thread.pas' {TSyncThread},
  MainForm in 'MainForm.pas' {FormMain};

{$R *.res}

begin
CreateFileMapping(HWND($FFFFFFFF), nil, PAGE_READWRITE, 0, 1024,
 'AutoSearch');

if GetLastError <> ERROR_ALREADY_EXISTS then
begin
 Application.Initialize;
 //Application.ShowMainForm := False;
 Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end
else
begin
 Application.MessageBox('Программа уже запущена!', 'Внимание!');
 halt;
end;

end.
