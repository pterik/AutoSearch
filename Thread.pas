unit Thread;

interface

uses
  WinInet, SysUtils, Classes, IdHTTP, IdCookieManager, IdHeaderList,
  RegularExpressionsCore,  Math, Forms,  Windows, Messages,  Controls, Graphics,
  Dialogs,  INIFiles, shellapi, StrUtils,  ComCtrls, Buttons, StdCtrls;

type
  TSyncThread = class(TThread)
  private
    it: integer;
    tmax: integer;
    http: TIdHTTP;
    idckmngr: TIdCookieManager;
    ban: Boolean;
    err: Boolean;
    procedure SetProgress;
    function GetContent(url: String; id: String = ''): String;
    procedure RemoveDuplicates(const StringList: TStringList);
    procedure IdHTTP1HeadersAvailable(Sender: TObject;
  AHeaders: TIdHeaderList; var VContinue: Boolean);
    procedure LogFromThread(Str: String);

  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
  protected
    procedure Execute; override;
  end;

var
  SyncThread: TSyncThread;

implementation

uses MainForm;

function CheckUrl(url: String): boolean;
var
  hSession, hfile: hInternet;
  dwindex, dwcodelen: dword;
  dwcode: array[1..20] of char;
  res: pchar;
begin
  if pos('http://', lowercase(url)) = 0 then
    url := 'http://' + url;
  Result := false;
  hSession := InternetOpen('InetURL:/1.0', INTERNET_OPEN_TYPE_PRECONFIG, nil,
    nil, 0);
  if assigned(hsession) then
  begin
    hfile := InternetOpenUrl(hsession, pchar(url), nil, 0, INTERNET_FLAG_RELOAD,
      0);
    dwIndex := 0;
    dwCodeLen := 10;
    HttpQueryInfo(hfile, HTTP_QUERY_STATUS_CODE, @dwcode, dwcodeLen, dwIndex);
    res := pchar(@dwcode);
    result := (res = '200') or (res = '302');
    if assigned(hfile) then
      InternetCloseHandle(hfile);
    InternetCloseHandle(hsession);
  end;
end;

constructor TSyncThread.Create(CreateSuspended: Boolean);
begin
  it := 0;
  tmax := MAXINT;
  inherited Create(False);
end;

destructor TSyncThread.Destroy;
begin
  //
  inherited Destroy;
end;

procedure TSyncThread.Execute;
var
  Page, tmp, phone: String;
  Regex, Regex2, Regex3: TPerlRegEx;
  p, i, itmp, total: integer;
  id, model, year, run, town, list, temp, temp2, temp3: TStringList;
  ms: TMemoryStream;
  RegionStr, RegionPrefix:string;

begin

  if not (CheckUrl('http://www.yandex.ru/' )) then
  begin
    if MB_ICONERROR=16
    then
      begin
      LogFromThread('������: ' + IntToStr(MB_ICONERROR)+', ��� ����������� � ���������.');
      ShowMessage('������: ' + IntToStr(MB_ICONERROR)+', ��� ����������� � ���������.');
      FormMain.mmo1.Lines.Add('������: ' + IntToStr(MB_ICONERROR)+', ��� ����������� � ���������.');
      FormMain.GoingErrorState(true);
      exit;
      end;
    LogFromThread('������: ' + IntToStr(MB_ICONERROR));
    ShowMessage('������: ' + IntToStr(MB_ICONERROR));
    FormMain.mmo1.Lines.Add('������: ' + IntToStr(MB_ICONERROR));
    Exit;
  end;

  while not (Terminated or Application.Terminated) do
  begin
    try
      ms := TMemoryStream.Create;
      Regex := TPerlRegEx.Create();
      Regex2 := TPerlRegEx.Create();
      Regex3 := TPerlRegEx.Create();

      if not FileExists(FormMain.tmpfile) then
      begin
        p := 0;
        total := 1;
        repeat
          id := TStringList.Create;
          model := TStringList.Create;
          run := TStringList.Create;
          year := TStringList.Create;
          town := TStringList.Create;
          list := TStringList.Create;

          Inc(p);

          if (FormMain.lastpost <> 'ALL') and (p * 50 > StrToInt(FormMain.lastpost))
          then Break;
          if FormMain.RGCities.ItemIndex=0 then RegionStr:='&region[]=38&region_id=87';
          if FormMain.RGCities.ItemIndex=1 then RegionStr:='&region[]=19&region_id=19';

          Page := GetContent('list/'
            + '?category_id=15'
            + '&section_id=1'
            + '&year[1]=' + FormMain.years[FormMain.years.Count - 1]
            + '&currency_key=RUR'
            + '&used_key=5'
            + '&wheel_key=1'
            + '&custom_key=1'
            + '&available_key=1'
            + '&stime=' + IntToStr(FormMain.last)
            + '&country_id=1'
            // ������         region%5B%5D=87&region_id=87&city_id=
            //���������� ���  region%5B%5D=38&region_id=38&city_id=
            //�������� ���    region%5B%5D=19&region_id=19&city_id=
            //  + '&region[]=87' // Moscow
            + RegionStr
            + '&sort_by=1'
            + '&output_format=1'
            + '&client_id=1'
            + '&_p='
            + IntToStr(p));

          if (ban = True) or (err = True) then Exit;

          Regex.RegEx := '<span>([^<]*)</span>';
          Regex.Subject := Page;
          if Regex.Match then
          begin
            tmax := StrToInt(Trim(Regex.Groups[1]));
            //FormMain.mmo1.Lines.Delete(0);
            FormMain.lbl2.Caption:='����� ���������� �������: ' + IntToStr(tmax);
            LogFromThread('����� ���������� �������: ' +IntToStr(tmax))
          end;
          if not Regex.Match then
          begin //Exit
            if FormMain.proxy <> '0.0.0.0' then
              begin
              LogFromThread( '�������� ������� ����� ������ '+FormMain.proxy+ #13#10
              +'�� ������� �� ������ ���������� ��� ������ '+Page);
              FormMain.mmo1.Lines.Insert(0, '�������� ������� ����� ������.')
              end
            else
              begin
              LogFromThread( '�������� ������ �������� ������ ����� ��������� ����� '+ #13#10
              +'�� ������� �� ������ ���������� ��� ������ '+Page);
              FormMain.mmo1.Lines.Insert(0, '����� ���������� �� �������.');
              end;
          Exit;
          end;//Regex.Match

          total := Math.Ceil(tmax / 50);
          //Form1.mmo1.Lines.Delete(1);
          FormMain.lbl2.Caption:='������� ������ ��������: ' + IntToStr(p) +  ' �� ' + IntToStr(total);
          FormMain.pb1.StepIt;
          Regex.RegEx := '/cars/used/sale/([^.]*)\.html';
          if Regex.Match then
          begin
            repeat
              id.Add(Regex.Groups[1]);
             // Form1.mmo1.Lines.Add(Regex.Groups[1]);
            until not Regex.MatchAgain;
          end;

          Regex.RegEx := 'offer-list">([^<]*)<\/a>';
          if Regex.Match then
          begin
            repeat
              model.Add(Trim(Regex.Groups[1]));
            until not Regex.MatchAgain;
          end;

          Regex.RegEx := '12\%><nobr>([^<]*)<\/nobr>';
          if Regex.Match then
          begin
            repeat
              run.Add(Trim(StringReplace(Regex.Groups[1], ' ', '',
                [rfReplaceAll])));
            until not Regex.MatchAgain;
          end;

          Regex.RegEx := '10\%>(\d+)<\/td>';
          if Regex.Match then
          begin
            repeat
              year.Add(Trim(Regex.Groups[1]));
            until not Regex.MatchAgain;
          end;

          Regex.RegEx := 'nowrap>([^<]*)<\/td><td align="center">\&nbsp\;';
          if Regex.Match then
          begin
            repeat
              Regex2.Subject := Regex.Groups[1];
              Regex2.RegEx := '\[\d+\]';
              if Regex2.Match then
                Regex2.Replace;
              town.Add(Trim(Regex2.Subject));
            until not Regex.MatchAgain;
          end;

          i := 0;
          while i < id.Count do
          begin
            tmp := id[i] + FormMain.sep + '"' + model[i] + '"' + FormMain.sep + run[i]
              +  FormMain.sep + year[i]  + FormMain.sep + '"' + town[i] + '"';

            itmp := FormMain.years.IndexOf(year[i]);

            {
            if Form1.towns.IndexOf(Utf8ToAnsi(town[i])) > -1 then
              list.Add(tmp)
            else
             if itmp > -1 then
              if (StrToInt(run[i]))>(StrToInt(Form1.runs[itmp])) then
                list.Add(tmp);
            }

            if (itmp > -1)
              and (FormMain.towns.IndexOf((town[i])) > -1)
              and (StrToInt(run[i]) > StrToInt(FormMain.runs[itmp])) 
            then
              list.Add(tmp);

            Inc(i);
          end;

          list.SaveToStream(ms);

          FreeAndNil(id);
          FreeAndNil(model);
          FreeAndNil(run);
          FreeAndNil(year);
          FreeAndNil(town);
          FreeAndNil(list);

        until p = total;

        ms.SaveToFile(FormMain.tmpfile);
        ms.Free;
      end;
      LogFromThread('��������� ����� �������...');
      FormMain.mmo1.Lines.Add('��������� ����� �������...');
      temp := TStringList.Create;
      temp2 := TStringList.Create;
      it := 0;
      FormMain.pb1.Position := 0;

      temp.LoadFromFile(FormMain.tmpfile);
      tmax := temp.Count;

      for i := 0 to temp.Count - 1 do
      begin
        Regex.Subject := temp[i];
        Regex.RegEx := '^([^' + FormMain.sep + ']*)' + FormMain.sep;
        if Regex.Match then
          temp2.Add(Regex.Groups[1]);
      end;
      LogFromThread('���� ���������� ������� ��� ����� '+FormMain.tmpfile);
      FormMain.mmo1.Lines.Add('���� ���������� �������...');

      for i := 0 to temp2.Count - 1 do
      begin

        Inc(it);
        Synchronize(SetProgress);

        if Pos('-', temp2[i]) > 0 then
        begin
          Page := GetContent('?op=sale&act=getPhones&id=' + temp2[i], temp2[i]);
          if ban = True then
            Exit;
          if err = True then
            Continue;
          Regex2.Subject := Page;
          Regex2.RegEx := '<strong>([^<]*)<\/strong>';

          if Regex2.Match then
          begin
            Regex3.Subject := Regex2.Groups[1];

            Regex3.RegEx := '\s+|\(|\)|-';
            if Regex3.Match then
              Regex3.ReplaceAll;
            Regex3.RegEx := '^\+7';
            if Regex3.Match then
              phone := Trim(Regex3.Subject)
            else
              continue;
          end;

          Regex2.Subject := temp[i];
          Regex2.RegEx := '^([^' + FormMain.sep + ']*)' + FormMain.sep;
          Regex2.Replacement := phone + FormMain.sep;
          if Regex2.Match then
          begin
            Regex2.Replace;
            temp[i] := Regex2.Subject;
          end;

          temp.SaveToFile(FormMain.tmpfile);

        end;
      end;
      LogFromThread('��������� ����������� � ���� '+FormMain.csvfile);

      FormMain.mmo1.Lines.Add('��������� �����������...');

      if FormMain.RGCities.ItemIndex=0 then RegionPrefix:='MOS_';
      if FormMain.RGCities.ItemIndex=1 then RegionPrefix:='TV_';

      if (fileexists(FormMain.csvfile)) then
        RenameFile(FormMain.csvfile, (GetCurrentDir() + '\' + Formmain.dirname + '\' +
          FormatDateTime('yyyy-mm-dd', Now) + RegionPrefix + IntToStr(FormMain.last) + '~'
          +
          FormatDateTime('hhnnss', Now) + '.csv'));
      LogFromThread('���������� CSV ���� '+FormMain.csvfile+' ������������');

      temp3 := TStringList.Create;
      temp3.LoadFromFile(FormMain.tmpfile);
      RemoveDuplicates(temp3);
      try
      temp3.SaveToFile(FormMain.tmpfile);
      LogFromThread('��������� ���������� � '+FormMain.tmpfile);
      except on E:Exception do
      LogFromThread('������ ��� ������ � '+FormMain.tmpfile+#13#10+E.Message);
      end;
      if (FileExists(FormMain.tmpfile)) then
        if RenameFile(FormMain.tmpfile, FormMain.csvfile) then
          Formmain.mmo1.Lines.Add('���������!' + #13#10 +
            '����� ������� ����������: '
            + IntToStr(temp3.Count));

      FormMain.btnStart.Enabled := False;
      FormMain.btnStop.Enabled := False;
      Formmain.btnReset.Enabled := True;

      if FormMain.finish <> 'false' then
      begin
        Application.Terminate;
        FormMain.Ic(2, Application.Icon);
        ExitProcess(0);
      end;

    finally
      FreeAndNil(temp);
      FreeAndNil(temp2);
      FreeAndNil(temp3);
      FreeAndNil(phone);
      FreeAndNil(Page);
      FreeAndNil(tmp);
      FreeAndNil(Regex);
      FreeAndNil(Regex2);
      FreeAndNil(Regex3);
      Terminate;
    end;
  end;

end;

procedure TSyncThread.SetProgress;
var
  PctDone: Extended;
begin
  PctDone := (it / tmax);
  FormMain.pb1.Position := Round(Formmain.pb1.Step * PctDone * 100);
//  Formmain.mmo1.Lines.Delete(2);
//  FormMain.tip := FormatFloat('��������: 0.00 %', PctDone * 100);
  FormMain.tip := FormatFloat('0.00 %', PctDone * 100);
  FormMain.Lbl1.Caption:=FormMain.tip;
//  FormMain.mmo1.Lines.Insert(2, FormMain.tip);
  FormMain.Ic(3, Application.Icon);
end;

procedure TSyncThread.IdHTTP1HeadersAvailable(Sender: TObject;
  AHeaders: TIdHeaderList; var VContinue: Boolean);
var
 i:integer;
 s:string;
 p:pchar;
begin
if not Assigned((Sender as TIdHTTP).CookieManager) then
  begin
  LogFromThread('������� IP '+FormMain.proxy+' �� ����� IdHTTP1HeadersAvailable �� ������������� CookieManager.');
  end;
for i := 0 to AHeaders.Count-1 do
  begin
  LogFromThread('IdHTTP1HeadersAvailable �������� '+IntToStr(i));
  LogFromThread(AHeaders.Strings[i]);
//  if StrLIComp(pchar(AHeaders.Strings[i]),'Set-Cookie:',length('Set-Cookie:'))=0
//    then LogFromThread(AHeaders.Strings[i]+' = Set-Cookie  true')
//    else LogFromThread(AHeaders.Strings[i]+' = Set-Cookie  false');
  end;
try
for i := 0 to AHeaders.Count-1 do
  if 0=StrLIComp(pchar(AHeaders.Strings[i]),'Set-Cookie:',length('Set-Cookie:')) then
  begin
    s:=copy(AHeaders.Strings[i],length('Set-Cookie:')+1);
    p:=pchar(s);
    repeat
    p:=strpos(p,';');
     if p=nil then break;
     repeat p:=p+1 until p^<>' ';
       if 0=StrLIComp(p,'expires',length('expires')) then
        begin
        p^:=#0;
        (Sender as TIdHTTP).CookieManager.AddServerCookie(pchar(s),(sender as tIdHTTP).URL);
        end;
    until p^=#0;
  end;
except on E:Exception do
LogFromThread('������� IP '+FormMain.proxy+' �� ����� IdHTTP1HeadersAvailable ��������� ������.'+E.Message);
end;
LogFromThread(IntToStr((Sender as TIdHTTP).Response.ResponseCode) + ': ' + (Sender as TIdHTTP).URL.GetFullURI());
end;

function TSyncThread.GetContent(url: String; id: String = ''):
  String;

var
  Regex: TPerlRegEx;
begin
try //��� finally
http := TIdHTTP.Create(nil);
idckmngr := TidCookieManager.Create(http);
http.CookieManager := idckmngr;
http.AllowCookies := true;
http.HandleRedirects := true;

http.Request.Host := 'cars.auto.ru';
http.Request.UserAgent := 'Mozilla/5.0 (Windows NT 5.2; WOW64; rv:20.0) Gecko/20100101 Firefox/20.0';
http.Request.Accept := 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5';
http.Request.AcceptLanguage := 'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3';
http.Request.AcceptCharSet := 'windows-1251,utf-8;q=0.7,*;q=0.7';
http.Request.Connection := 'Close';
http.Request.Referer := 'http://cars.auto.ru/';
http.OnHeadersAvailable := IdHTTP1HeadersAvailable;
if FormMain.proxy <> '0.0.0.0' then
  begin
    http.ProxyParams.BasicAuthentication := true;
    http.ProxyParams.ProxyServer := FormMain.proxy;
    if FormMain.port > 0 then http.ProxyParams.ProxyPort := FormMain.port;
    end;
//  try
Regex := TPerlRegEx.Create;
try
http.get('http://www.auto.ru/');
LogFromThread('�������� ������ �������� http://www.auto.ru/ ');
except on E:Exception do
  LogFromThread('Error while getting http://www.auto.ru/: '+E.Message)
end;
try
Regex.Subject := http.get('http://cars.auto.ru/');
LogFromThread('�������� �������� http://cars.auto.ru/');
except on E:Exception do
 LogFromThread('������� IP '+FormMain.proxy+' �� ����� get http://cars.auto.ru ��������� ������.'+E.Message);
end;
try
sleep(FormMain.delay);
LogFromThread('����� �� ��������� ������ ');
except on E:Exception do
 LogFromThread('������� IP '+FormMain.proxy+' �� ����� ����� ��������� ������.'+E.Message);
end;
try
if Pos('Incident Id', Regex.Subject) > 0 then
    begin
          // Form1.mmo1.Lines.Clear;
    LogFromThread('�� ����� get http://cars.auto.ru ������� Incident ID. ������� IP '+FormMain.proxy);
    FormMain.mmo1.Lines.Add('IP �������� �������' + #13#10 +'������� ����� ������ � �������' + #13#10);
    ban := True;
    Exit;
    end;

if (Pos('wikipedia', Regex.Subject) > 0) then
    begin
    //Form1.mmo1.Lines.Clear;
    LogFromThread('�� ����� get http://cars.auto.ru ��������� redirect �� wikipedia. ������� IP '+FormMain.proxy);
    FormMain.mmo1.Lines.Add('�������� ������� ����� ������' + #13#10 + '���������� ������ ������-������');
    ban := True;
    Exit;
    end;
except on E:Exception do
 LogFromThread('������� IP '+FormMain.proxy+' �� ����� ��������� Pos ��������� ������.'+E.Message);
end;
//try
//Regex.RegEx := AnsiToUtf8('">(\d+) ��� 2013');
//if Regex.Match then
//   begin
//      if StrToInt(Trim(Regex.Groups[1])) >= 20 then
//        begin
//          FormMain.mmo1.Lines.Add('����� ������ ����������, ���������� � ������������ � ������ ���������.');
//          LogFromThread('�������� �� ����� ������ ���������� ������ ���������');
//          ShowMessage('����� ������ ����������, ���������� � ������������ � ������ ���������.');
//          Sleep(10000);
//          ExitProcess(0);
//        end;
//      end;
//except on E:Exception do
// LogFromThread('�� ����� �������� �� trial ��������� ������.'+E.Message);
//end;
//
//try
//Regex.Free;
//except on E:Exception do
// LogFromThread('�� ����� Regex.Free ��������� ������.'+E.Message);
//end;

err := False;
//      end;   //get cars.auto.ru
//  except on E:Exception do
//    FormMain.mmo1.Lines.Add('�������� ������� � auto.ru: ' + E.Message + #13#10);
//    err := true;
//    Exit;
//  end;
//  end;
if id <> '' then
    begin
      try
      http.get('http://cars.auto.ru/cars/used/sale/' + id + '.html');
      sleep(FormMain.delay);
      err := False;
      except on E: Exception do
      begin
      LogFromThread('�������� ������� � ��������: http://cars.auto.ru/cars/used/sale/' + id + '.html' + E.Message);
      FormMain.mmo1.Lines.Add('�������� ������� � ����������: ' + E.Message +  #13#10 + ' ');
      err := true;
      Exit;
      end;
      end;
    end;
try
Result := http.get('http://cars.auto.ru/' + url);
sleep(FormMain.delay);
err := False;
LogFromThread('�������� �������� ' + 'http://cars.auto.ru/' + url);
except on E: Exception do 
  begin 
  FormMain.mmo1.Lines.Add('������ ��� ��������� ��������: ''http://cars.auto.ru/' + url+': ' + E.Message +  #13#10 + ' ');
  err := true; 
  Exit; 
  end; end;
finally
http.Request.CustomHeaders.Clear;
idckmngr.Free;
http.Free;
end;//Finally
end;

procedure TSyncThread.RemoveDuplicates(const stringList: TStringList);
var
  buffer: TStringList;
  cnt: Integer;
  i: Integer;
  c: Integer;
  Regex: TPerlRegEx;
  str: TStringList;
begin
  stringList.Sort;
  buffer := TStringList.Create;
  Regex := TPerlRegEx.Create;
  try
    buffer.Sorted := True;
    buffer.Duplicates := dupIgnore;
    buffer.BeginUpdate;
    for cnt := 0 to stringList.Count - 1 do
    begin
      Regex.Subject := stringList[cnt];
      Regex.RegEx := '^([^' + FormMain.sep + ']*)' + FormMain.sep;
      if Regex.Match then
        if Pos('-', Regex.Groups[1]) = 0 then
        begin

          c := 0;
          for i := 0 to stringList.Count - 1 do
          begin
            str := TStringList.Create;
            str := FormMain.explode(FormMain.sep, stringList[i]);

            if Regex.Groups[1] = str[0] then
            begin
            Inc(c);
            if c > 1 then Break
            else buffer.Add(Regex.Subject);
            FreeandNil(str);
            end;
          end;

        end;
    end;
    buffer.EndUpdate;
    stringList.Assign(buffer);
  finally
    FreeandNil(buffer);
    FreeandNil(Regex);
  end;
end;

procedure TSyncThread.LogFromThread(Str: String);
var TStmp:String;
LogFile:TextFile;
begin
AssignFile(LogFile,ExtractFilePath(ParamStr(0))+'\'+'log.txt');
if not FileExists(ExtractFilePath(ParamStr(0))+'\'+'log.txt') then Rewrite(LogFile) else Append(LogFile);
TStmp:=FormatDateTime('yyyy-mm-dd hh:mm:ss', Now);
Writeln(LogFile,Tstmp+': '+Str);
//Flush(LogFile);
CloseFile(LogFile);
end;

end.

