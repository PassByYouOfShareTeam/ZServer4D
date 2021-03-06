unit CommunicationTest;

interface

{$I zDefine.inc}


uses SysUtils, CommunicationFramework, DataFrameEngine,
  UnicodeMixedLib, CoreClasses, DoStatusIO, MemoryStream64, PascalStrings,
  CommunicationFrameworkIO;

type
  TCommunicationTestIntf = class(TCoreClassObject)
  private
    PrepareSendConsole, PrepareResultConsole    : string;
    PrepareSendDataFrame, PrepareResultDataFrame: TDataFrameEngine;
    TempStream                                  : TMemoryStream64;
  public
    constructor Create;
    destructor Destroy; override;

    // client test command
    procedure Cmd_TestStream(Sender: TPeerClient; InData, OutData: TDataFrameEngine);
    procedure Cmd_TestConsole(Sender: TPeerClient; InData: string; var OutData: string);
    procedure Cmd_TestDirectStream(Sender: TPeerClient; InData: TDataFrameEngine);
    procedure Cmd_TestDirectConsole(Sender: TPeerClient; InData: string);
    procedure Cmd_TestBigStream(Sender: TPeerClient; InData: TCoreClassStream; BigStreamTotal, BigStreamCompleteSize: Int64);
    procedure Cmd_BigStreamPostInfo(Sender: TPeerClient; InData: string);
    procedure Cmd_RemoteInfo(Sender: TPeerClient; InData: string);

    // server test command result
    procedure CmdResult_TestConsole(Sender: TPeerClient; ResultData: string);
    procedure CmdResult_TestStream(Sender: TPeerClient; ResultData: TDataFrameEngine);

    procedure RegCmd(intf: TCommunicationFramework);
    procedure ExecuteTest(intf: TPeerClient);
    procedure ExecuteAsyncTest(intf: TPeerClient);
  end;

implementation

var
  TestStreamData: TMemoryStream64 = nil;

constructor TCommunicationTestIntf.Create;
var
  i: Integer;
begin
  inherited;
  PrepareSendConsole := 'console test';
  PrepareResultConsole := 'console result';
  PrepareSendDataFrame := TDataFrameEngine.Create;
  PrepareResultDataFrame := TDataFrameEngine.Create;
  for i := 1 to 10 do
    begin
      PrepareSendDataFrame.WriteInteger(i);
      PrepareResultDataFrame.WriteInteger(i);
    end;

  TempStream := TMemoryStream64.Create;

end;

destructor TCommunicationTestIntf.Destroy;
begin
  DisposeObject(PrepareSendDataFrame);
  DisposeObject(PrepareResultDataFrame);
  DisposeObject(TempStream);
  inherited;
end;

procedure TCommunicationTestIntf.Cmd_TestStream(Sender: TPeerClient; InData, OutData: TDataFrameEngine);
begin
  if not InData.Compare(PrepareSendDataFrame) then
      DoStatus('TestStream in Data failed!');
  OutData.Assign(PrepareResultDataFrame);
end;

procedure TCommunicationTestIntf.Cmd_TestConsole(Sender: TPeerClient; InData: string; var OutData: string);
begin
  if InData <> PrepareSendConsole then
      DoStatus('TestConsole in Data failed!');
  OutData := PrepareResultConsole;
end;

procedure TCommunicationTestIntf.Cmd_TestDirectStream(Sender: TPeerClient; InData: TDataFrameEngine);
begin
  if not InData.Compare(PrepareSendDataFrame) then
      DoStatus('TestDirectStream in Data failed!');
end;

procedure TCommunicationTestIntf.Cmd_TestDirectConsole(Sender: TPeerClient; InData: string);
begin
  if InData <> PrepareSendConsole then
      DoStatus('TestDirectConsole in Data failed!');
  TempStream.Clear;
end;

procedure TCommunicationTestIntf.Cmd_TestBigStream(Sender: TPeerClient; InData: TCoreClassStream; BigStreamTotal, BigStreamCompleteSize: Int64);
begin
  TempStream.CopyFrom(InData, InData.Size);
end;

procedure TCommunicationTestIntf.Cmd_BigStreamPostInfo(Sender: TPeerClient; InData: string);
begin
  if InData <> umlStreamMD5Char(TempStream).Text then
      DoStatus('TestBigStream failed!');
  TempStream.Clear;
end;

procedure TCommunicationTestIntf.Cmd_RemoteInfo(Sender: TPeerClient; InData: string);
begin
  DoStatus('remote:' + InData);
end;

procedure TCommunicationTestIntf.CmdResult_TestConsole(Sender: TPeerClient; ResultData: string);
begin
  if ResultData <> PrepareResultConsole then
      DoStatus('TestResultConsole Data failed!');
end;

procedure TCommunicationTestIntf.CmdResult_TestStream(Sender: TPeerClient; ResultData: TDataFrameEngine);
begin
  if not ResultData.Compare(PrepareResultDataFrame) then
      DoStatus('TestResultStream Data failed!');
end;

procedure TCommunicationTestIntf.RegCmd(intf: TCommunicationFramework);
begin
  {$IFDEF FPC}
  intf.RegisterStream('TestStream').OnExecute := @Cmd_TestStream;
  intf.RegisterConsole('TestConsole').OnExecute := @Cmd_TestConsole;
  intf.RegisterDirectStream('TestDirectStream').OnExecute := @Cmd_TestDirectStream;
  intf.RegisterDirectConsole('TestDirectConsole').OnExecute := @Cmd_TestDirectConsole;
  intf.RegisterBigStream('TestBigStream').OnExecute := @Cmd_TestBigStream;
  intf.RegisterDirectConsole('BigStreamPostInfo').OnExecute := @Cmd_BigStreamPostInfo;
  intf.RegisterDirectConsole('RemoteInfo').OnExecute := @Cmd_RemoteInfo;
  {$ELSE}
  intf.RegisterStream('TestStream').OnExecute := Cmd_TestStream;
  intf.RegisterConsole('TestConsole').OnExecute := Cmd_TestConsole;
  intf.RegisterDirectStream('TestDirectStream').OnExecute := Cmd_TestDirectStream;
  intf.RegisterDirectConsole('TestDirectConsole').OnExecute := Cmd_TestDirectConsole;
  intf.RegisterBigStream('TestBigStream').OnExecute := Cmd_TestBigStream;
  intf.RegisterDirectConsole('BigStreamPostInfo').OnExecute := Cmd_BigStreamPostInfo;
  intf.RegisterDirectConsole('RemoteInfo').OnExecute := Cmd_RemoteInfo;
  {$ENDIF}
end;

procedure TCommunicationTestIntf.ExecuteTest(intf: TPeerClient);
var
  tmpdf: TDataFrameEngine;
begin
  {$IFDEF FPC}
  intf.SendConsoleCmd('TestConsole', PrepareSendConsole, @CmdResult_TestConsole);
  intf.SendStreamCmd('TestStream', PrepareSendDataFrame, @CmdResult_TestStream);
  {$ELSE}
  intf.SendConsoleCmd('TestConsole', PrepareSendConsole, CmdResult_TestConsole);
  intf.SendStreamCmd('TestStream', PrepareSendDataFrame, CmdResult_TestStream);
  {$ENDIF}
  intf.SendDirectConsoleCmd('TestDirectConsole', PrepareSendConsole);
  intf.SendDirectStreamCmd('TestDirectStream', PrepareSendDataFrame);
  intf.SendBigStream('TestBigStream', TestStreamData, False);
  intf.SendDirectConsoleCmd('BigStreamPostInfo', umlStreamMD5Char(TestStreamData).Text);

  if intf.OwnerFramework is TCommunicationFrameworkClient then
    begin
      if intf.WaitSendConsoleCmd('TestConsole', PrepareSendConsole, 0) <> PrepareResultConsole then
          DoStatus('wait Mode:TestResultConsole Data failed!');

      tmpdf := TDataFrameEngine.Create;
      intf.WaitSendStreamCmd('TestStream', PrepareSendDataFrame, tmpdf, 0);
      if not tmpdf.Compare(PrepareResultDataFrame) then
          DoStatus('wait Mode:TestResultStream Data failed!');
      DisposeObject(tmpdf);
    end;

  intf.SendDirectConsoleCmd('RemoteInfo', 'client id[' + IntToStr(intf.ID) + '] test over!');
end;

procedure TCommunicationTestIntf.ExecuteAsyncTest(intf: TPeerClient);
var
  tmpdf: TDataFrameEngine;
begin
  {$IFDEF FPC}
  intf.SendConsoleCmd('TestConsole', PrepareSendConsole, @CmdResult_TestConsole);
  intf.SendStreamCmd('TestStream', PrepareSendDataFrame, @CmdResult_TestStream);
  {$ELSE}
  intf.SendConsoleCmd('TestConsole', PrepareSendConsole, CmdResult_TestConsole);
  intf.SendStreamCmd('TestStream', PrepareSendDataFrame, CmdResult_TestStream);
  {$ENDIF}
  intf.SendDirectConsoleCmd('TestDirectConsole', PrepareSendConsole);
  intf.SendDirectStreamCmd('TestDirectStream', PrepareSendDataFrame);

  intf.SendDirectConsoleCmd('RemoteInfo', 'client id[' + IntToStr(intf.ID) + '] test over!');
end;

initialization

TestStreamData := TMemoryStream64.Create;
TestStreamData.SetSize(1024 * 1024);
FillByte(TestStreamData.Memory^, TestStreamData.Size, $99);

finalization

DisposeObject(TestStreamData);
TestStreamData := nil;

end.
