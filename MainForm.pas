unit MainForm;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Graphics,
  Dialogs, RegularExpressionsCore, INIFiles, shellapi, Thread, StrUtils,
  ComCtrls, Buttons, StdCtrls, IdBaseComponent, IdComponent, IdTCPConnection,
  IdTCPClient, IdHTTP, Vcl.ExtCtrls;

type
  TFormMain = class(TForm)
    mmo1: TMemo;
    pb1: TProgressBar;
    btnStart: TBitBtn;
    btnStop: TBitBtn;
    btnReset: TBitBtn;
    lbl1: TLabel;
    lbl2: TLabel;
    RGCities: TRadioGroup;

    procedure ControlWindow(var Msg: TMessage); message WM_SYSCOMMAND;
    procedure IconMouse(var Msg: TMessage); message WM_USER + 1;
    procedure Ic(n: Integer; Icon: TIcon);
    procedure OnMinimizeProc(Sender: TObject);

    procedure FormCreate(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnResetClick(Sender: TObject);

  private
    Thread: TSyncThread;
    procedure LogFromMain(Str: String);

  public
    years: TStringList;
    runs: TStringList;
    towns: TStringList;
    last: Integer;
    lastpost: string;
    dirname: string;
    delay: Integer;
    finish: string;
    tmpfile: string;
    csvfile: string;
    proxy: string;
    port: Integer;
    sep: string;
    tip: string;
    function explode(const delim, str: string): TStringList;
    procedure State(St:integer);
    procedure GoingErrorState(isDelete:boolean);

  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

{ TForm1 }

procedure TFormMain.FormCreate(Sender: TObject);
var
  cfg: TIniFile;
  i: Integer;
  str: string;
  Regex: TPerlRegEx;
  RegionPrefix:string;
begin
if not FileExists(extractfilepath(paramstr(0)) + 'CONFIG.INI') then
  begin
    LogFromMain('���� config.ini �� ������ � ������� �����. ��������� ���������');
    ShowMessage('���� config.ini �� ������ � ������� �����. ��������� ���������');
    halt;
  end;
cfg := TIniFile.Create(extractfilepath(paramstr(0)) + 'CONFIG.INI');
years := TStringList.Create();
runs := TStringList.Create();
towns := TStringList.Create();
Regex := TPerlRegEx.Create();
cfg.ReadSection('run', years);
for i := 0 to years.Count - 1 do runs.Add(cfg.ReadString('run', years[i], ''));
str := cfg.ReadString('config', 'towns', '');
Regex.Regex := ',';
Regex.Subject := str;
Regex.Split(towns, MAXINT);
for i := 0 to towns.Count - 1 do towns[i] := Trim(towns[i]);
last := StrToInt(cfg.ReadString('config', 'last', ''));
if (last < 1) then last := 1;
if (last > 3) then last := 7;
FormMain.mmo1.Lines.Add('�������� ���������� �� �������� '+IntToStr(last)+' ���');
lastpost := cfg.ReadString('config', 'lastpost', '');
dirname := cfg.ReadString('config', 'dirname', '');
sep := cfg.ReadString('config', 'sep', '');
finish := cfg.ReadString('config', 'finish', '');
delay := StrToInt(cfg.ReadString('http', 'delay', ''));
proxy := cfg.ReadString('http', 'proxy', '');
port := StrToInt(cfg.ReadString('http', 'port', ''));
if FormMain.RGCities.ItemIndex=0 then RegionPrefix:='MOS_';
if FormMain.RGCities.ItemIndex=1 then RegionPrefix:='TV_';

TmpFile := GetCurrentDir() + '\' + FormMain.dirname + '\'+RegionPrefix+ FormatDateTime('yyyy-mm-dd', Now) + IntToStr(last) + '.txt';
CsvFile := GetCurrentDir() + '\' + FormMain.dirname + '\'+RegionPrefix+ FormatDateTime('yyyy-mm-dd', Now) + IntToStr(last) + '.csv';
tip := '';
FreeAndNil(cfg);
FreeAndNil(Regex);
State(1);//��������� � ��������� ������
if FileExists(tmpfile) then
  begin
    FormMain.mmo1.Lines.Add('�������� ��� ����������. ' + #13#10 + '������� ������ [�����] ��� �����������' + #13#10+ '[������] ��� ����� �������.');
    LogFromMain('����������� ����� ����� ������ �� ���������');
    //btnStart.Caption := '�����';
    //btnReset.Enabled := true;
  end;
end;

procedure TFormMain.GoingErrorState(isDelete:boolean);
begin
if isDelete and FileExists(tmpFile) then DeleteFile(tmpFile);
State(4);
end;

procedure TFormMain.btnStartClick(Sender: TObject);
begin
State(2); //��������� � ��������� ������
//  btnStart.Enabled := false;
//  btnStop.Enabled := true;
//  btnReset.Enabled := false;
  lbl2.Caption:='���������� ����� � �������';
  if not Assigned(Thread) then
  begin
    Thread := TSyncThread.Create(false);
    Thread.FreeOnTerminate := True;
    Thread.Priority := tpLower;
  end
  else if Thread.Suspended then
    Thread.Resume;
end;

procedure TFormMain.btnStopClick(Sender: TObject);
begin
State(3);//��������� � ��������� ����
//  btnStart.Caption := '�����';
//  btnStart.Enabled := true;
//  btnStop.Enabled := false;
//  btnReset.Enabled := true;
  try
    if not Thread.Suspended then
      Thread.Suspend;
  except
  LogFromMain('������ �� ����� ������� Suspend ��� ������');
  end;
end;

procedure TFormMain.btnResetClick(Sender: TObject);
begin
State(2);//��������� � ��������� ������
//  btnStart.Caption := '�����';
//  btnStart.Enabled := true;
FormMain.pb1.Position := 0;
//  btnreset.Enabled := False;

if FileExists(tmpfile) then DeleteFile(tmpfile);

if Assigned(Thread) then
  begin
    Thread.Terminate;
    Thread := nil;
    Thread := TSyncThread.Create(false);
    Thread.FreeOnTerminate := True;
    Thread.Priority := tpLower;
  end;
end;

procedure TFormMain.IconMouse(var Msg: TMessage);
var
  p: tpoint;
begin
  GetCursorPos(p);
  case Msg.LParam of
    WM_LBUTTONUP, WM_LBUTTONDBLCLK:
      begin
        Ic(2, Application.Icon);
        ShowWindow(Application.Handle, SW_SHOW);
        ShowWindow(Handle, SW_SHOW);
        Update;
      end;
    WM_RBUTTONUP:
      begin
        SetForegroundWindow(Handle);
        PostMessage(Handle, WM_NULL, 0, 0);
      end;
  end;
end;

procedure TFormMain.OnMinimizeProc(Sender: TObject);
begin
  PostMessage(Handle, WM_SYSCOMMAND, SC_MINIMIZE, 0);
end;

procedure TFormMain.State(St: integer);
begin
//������������ ��������� ������
// 1 ������. ��� ������ ���������
// 2 ������. �� ����� ������ ���������
// 3 ����. ������ ������ ����.
// 4 ������. ������� ������ ������
case St of
1:
  begin
    btnStart.Enabled:=true;
    btnStop.Enabled:=false;
    btnReset.Enabled:=false;
  end;
  2:
  begin
    btnStart.Enabled:=false;
    btnStop.Enabled:=true;
    btnReset.Enabled:=false;
  end;
3:
  begin
    btnStart.Enabled:=true;
    btnStop.Enabled:=false;
    btnReset.Enabled:=true;
  end;
  4:
  begin
    btnStart.Enabled:=false;
    btnStop.Enabled:=false;
    btnReset.Enabled:=true;
  end;
end;

end;

procedure TFormMain.ControlWindow(var Msg: TMessage);
begin
  if Msg.WParam = SC_MINIMIZE then
  begin
    Ic(1, Application.Icon);
    ShowWindow(Handle, SW_HIDE);
    ShowWindow(Application.Handle, SW_HIDE);
  end
  else
    inherited;
end;

procedure TFormMain.Ic(n: Integer; Icon: TIcon);
var
  Nim: TNotifyIconData;
begin
  with Nim do
  begin
    //cbSize := SizeOf(Nim);
    Wnd := Self.Handle;
    uID := 123;
    uFlags := NIF_ICON or NIF_MESSAGE or NIF_TIP;
    hicon := Icon.Handle;
    uCallbackMessage := wm_user + 1;
    if tip <> '' then
      StrLCopy(szTip, PChar(tip), High(szTip))
    else
      szTip := '����� ���������� auto.ru';
  end;
  case n of
    1: Shell_NotifyIcon(Nim_Add, @Nim);
    2: Shell_NotifyIcon(Nim_Delete, @Nim);
    3: Shell_NotifyIcon(Nim_Modify, @Nim);
  end;
end;

function TFormMain.explode(const delim, str: String): TStringList;
var
  offset: integer;
  cur: integer;
  dl: integer;
begin
  Result := TStringList.Create;
  dl := Length(delim);
  offset := 1;
  while True do
  begin
    cur := PosEx(delim, str, offset);
    if cur > 0 then
      Result.Add(Copy(str, offset, cur - offset))
    else
    begin
      Result.Add(Copy(str, offset, Length(str) - offset + 1));
      Break
    end;
    offset := cur + dl;
  end;
end;


procedure TFormMain.LogFromMain(Str: String);
var TStmp:String;
    LogFile:TextFile;
begin
AssignFile(LogFile,ExtractFilePath(ParamStr(0))+'\'+'log.txt');
if not FileExists(ExtractFilePath(ParamStr(0))+'\'+'log.txt') then Rewrite(LogFile) else Append(LogFile);
TStmp:=FormatDateTime('yyyy-mm-dd hh:mi:ss', Now);
Writeln(LogFile,Tstmp+': '+Str);
//Flush(LogFile);
CloseFile(LogFile);
end;

end.

