unit LlamaCpp.Common.Cache.Disk;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.Generics.Collections,
  System.IOUtils,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  LlamaCpp.Common.Types,
  LlamaCpp.Common.State,
  LlamaCpp.Common.Cache.Base;

type
  TLlamaDiskCache = class(TBaseLlamaCache)
  private const
  {$IFDEF MSWINDOWS}
    DEFAULT_CACHE_DIR = '.\cache\llama_cache';
  {$ELSE}
    DEFAULT_CACHE_DIR = './cache/llama_cache';
  {$ENDIF}

  private
    FCacheFileName: string;
    FConnection: TFDConnection;
    FDatS: TFDQuery;
    FTask: ITask;

  private
    procedure CreateCacheConnectionDefs;
    procedure CreateCacheTable;

    function Load(
      const AKey: TArray<Integer>): TLlamaState;

    procedure Save(
      const AKey: TArray<Integer>;
      const AState: TLlamaState);

    procedure Delete(
      const AKey: TArray<Integer>);

  public
    constructor Create(
      const ACacheDir: string = DEFAULT_CACHE_DIR;
      ACapacityBytes: Int64 = Int64(2) shl 30);

    destructor Destroy; override;

    function GetCacheSize: Int64; override;

    function FindLongestPrefixKey(
      const AKey: TArray<Integer>): TArray<Integer>; override;

    function GetItem(
      const AKey: TArray<Integer>): TLlamaState; override;

    function Contains(
      const AKey: TArray<Integer>): Boolean; override;

    procedure SetItem(
      const AKey: TArray<Integer>;
      const AValue: TLlamaState); override;
  end;

implementation

uses
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.Param,
  FireDAC.DatS,
  FireDAC.DApt.Intf,
  FireDAC.DApt,
  Data.DB,
  FireDAC.Comp.DataSet,
  {$IFDEF MSWINDOWS}
  Windows
  {$ELSE}
  Posix.Unistd
  {$ENDIF}
  ;

type
  TCachePair = TPair<TArray<Integer>, TLlamaState>;
  TCachePairs = TArray<TCachePair>;

{ TLlamaDiskCache }

constructor TLlamaDiskCache.Create(
  const ACacheDir: string;
  ACapacityBytes: Int64);
var
  LStr: string;
begin
  inherited Create(ACapacityBytes);

  if TDirectory.Exists(ACacheDir) then
  begin
    for LStr in TDirectory.GetFiles(
      ACacheDir,
      '*',
      TSearchOption.soAllDirectories) do
    begin
      try
        TFile.Delete(LStr);
      except
        // Ignore files currently in use
      end;
    end;

    for LStr in TDirectory.GetDirectories(ACacheDir) do
    begin
      try
        TDirectory.Delete(LStr, True);
      except
        // Ignore directories currently in use
      end;
    end;
  end;

  {$IFDEF MSWINDOWS}
  FCacheFileName := TPath.Combine(
    TPath.GetFullPath(ACacheDir),
    IntToStr(GetCurrentProcessId));
  {$ELSE}
  FCacheFileName := TPath.Combine(
    TPath.GetFullPath(ACacheDir),
    IntToStr(GetPID));
  {$ENDIF}

  FCacheFileName := TPath.Combine(
    FCacheFileName,
    IntToStr(TThread.CurrentThread.ThreadID));

  FCacheFileName := TPath.Combine(
    FCacheFileName,
    'cache.db');

  if not TDirectory.Exists(
    TPath.GetDirectoryName(FCacheFileName)) then
  begin
    TDirectory.CreateDirectory(
      TPath.GetDirectoryName(FCacheFileName));
  end;

  FConnection := TFDConnection.Create(nil);

  FDatS := TFDQuery.Create(FConnection);
  FDatS.Connection := FConnection;

  CreateCacheConnectionDefs;
  CreateCacheTable;
end;

destructor TLlamaDiskCache.Destroy;
begin
  if Assigned(FTask) then
    FTask.Wait;

  FConnection.Free;

  inherited;
end;

procedure TLlamaDiskCache.CreateCacheConnectionDefs;
begin
  FConnection.Params.Values['Database'] := FCacheFileName;
  FConnection.LoginPrompt := False;
  FConnection.DriverName := 'SQLite';
  FConnection.Connected := True;
end;

procedure TLlamaDiskCache.CreateCacheTable;
begin
  FDatS.SQL.Text :=
    'CREATE TABLE IF NOT EXISTS CACHE (' +
    'ID INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    'KEY BLOB, ' +
    'DATA BLOB' +
    ')';

  FDatS.ExecSQL;
end;

function TLlamaDiskCache.Load(
  const AKey: TArray<Integer>): TLlamaState;
var
  LStream: TMemoryStream;
begin
  Result := nil;

  FDatS.Close;

  FDatS.SQL.Text :=
    'SELECT KEY, DATA FROM CACHE WHERE KEY = :KEY';

  LStream := TMemoryStream.Create;
  try
    if Length(AKey) > 0 then
      LStream.WriteBuffer(
        AKey[0],
        Length(AKey) * SizeOf(Integer));

    LStream.Position := 0;

    FDatS.ParamByName('KEY').LoadFromStream(
      LStream,
      ftBlob);

    LStream.Clear;

    FDatS.Open;

    if FDatS.IsEmpty then
    begin
      FDatS.Close;
      Exit;
    end;

    try
      LStream.Size := 0;

      TBlobField(
        FDatS.FieldByName('DATA')).SaveToStream(LStream);

      Result := TLlamaState.Create;

      try
        LStream.Position := 0;
        Result.Deserialize(LStream);
      except
        FreeAndNil(Result);
        raise;
      end;

    finally
      FDatS.Close;
    end;

  finally
    LStream.Free;
  end;
end;

procedure TLlamaDiskCache.Save(
  const AKey: TArray<Integer>;
  const AState: TLlamaState);
var
  LStream: TMemoryStream;
begin
  Delete(AKey);

  FDatS.Close;

  FDatS.SQL.Text :=
    'INSERT INTO CACHE (KEY, DATA) ' +
    'VALUES (:KEY, :DATA)';

  LStream := TMemoryStream.Create;
  try
    if Length(AKey) > 0 then
      LStream.WriteBuffer(
        AKey[0],
        Length(AKey) * SizeOf(Integer));

    LStream.Position := 0;

    FDatS.ParamByName('KEY').LoadFromStream(
      LStream,
      ftBlob);

    LStream.Clear;
    LStream.Size := 0;

    AState.Serialize(LStream);

    LStream.Position := 0;

    FDatS.ParamByName('DATA').LoadFromStream(
      LStream,
      ftBlob);

    LStream.Clear;

    FDatS.ExecSQL;

    FConnection.Commit;

  finally
    LStream.Free;
  end;
end;

procedure TLlamaDiskCache.Delete(
  const AKey: TArray<Integer>);
var
  LStream: TMemoryStream;
begin
  FDatS.Close;

  FDatS.SQL.Text :=
    'DELETE FROM CACHE WHERE KEY = :KEY';

  LStream := TMemoryStream.Create;
  try
    if Length(AKey) > 0 then
      LStream.WriteBuffer(
        AKey[0],
        Length(AKey) * SizeOf(Integer));

    LStream.Position := 0;

    FDatS.ParamByName('KEY').LoadFromStream(
      LStream,
      ftBlob);

    LStream.Clear;

    FDatS.ExecSQL;

    FConnection.Commit;

  finally
    LStream.Free;
  end;
end;

function TLlamaDiskCache.GetCacheSize: Int64;
const
  SQL_SIZES =
    'SELECT SUM(LENGTH(KEY)) + SUM(LENGTH(DATA)) FROM CACHE';
begin
  Result := 0;

  FDatS.Close;
  FDatS.Open(SQL_SIZES);

  try
    if not FDatS.Fields[0].IsNull then
      Result := FDatS.Fields[0].AsLargeInt
    else
      Result := 0;

  finally
    FDatS.Close;
  end;
end;

function TLlamaDiskCache.FindLongestPrefixKey(
  const AKey: TArray<Integer>): TArray<Integer>;
var
  LPrefixLen: Integer;
  LMaxPrefixLen: Integer;
  LKey: TArray<Integer>;
  LStream: TMemoryStream;
begin
  Result := nil;
  LMaxPrefixLen := 0;

  FDatS.Close;
  FDatS.Open(
    'SELECT KEY FROM CACHE');

  try
    if FDatS.IsEmpty then
      Exit;

    FDatS.First;

    LStream := TMemoryStream.Create;
    try
      while not FDatS.Eof do
      begin
        LStream.Clear;

        TBlobField(
          FDatS.FieldByName('KEY')).SaveToStream(LStream);

        LStream.Position := 0;

        SetLength(
          LKey,
          LStream.Size div SizeOf(Integer));

        if Length(LKey) > 0 then
        begin
          LStream.ReadBuffer(
            LKey[0],
            Length(LKey) * SizeOf(Integer));
        end;

        LPrefixLen := LongestTokenPrefix(
          LKey,
          AKey);

        if LPrefixLen > LMaxPrefixLen then
        begin
          LMaxPrefixLen := LPrefixLen;

          {
            Make a real copy of the dynamic array.
          }
          SetLength(Result, Length(LKey));

          if Length(LKey) > 0 then
            Move(
              LKey[0],
              Result[0],
              Length(LKey) * SizeOf(Integer));
        end;

        FDatS.Next;
      end;

    finally
      LStream.Free;
    end;

  finally
    FDatS.Close;
  end;
end;

function TLlamaDiskCache.Contains(
  const AKey: TArray<Integer>): Boolean;
var
  LKey: TArray<Integer>;
begin
  if Assigned(FTask) then
    FTask.Wait;

  LKey := FindLongestPrefixKey(AKey);

  Result := Length(LKey) > 0;
end;

function TLlamaDiskCache.GetItem(
  const AKey: TArray<Integer>): TLlamaState;
var
  LFoundKey: TArray<Integer>;
begin
  if Assigned(FTask) then
    FTask.Wait;

  LFoundKey := FindLongestPrefixKey(AKey);

  if Length(LFoundKey) = 0 then
    raise Exception.Create('Key not found');

  Result := Load(LFoundKey);

  Delete(LFoundKey);
end;

procedure TLlamaDiskCache.SetItem(
  const AKey: TArray<Integer>;
  const AValue: TLlamaState);
var
  LValue: TLlamaState;
  LKey: TArray<Integer>;
  I: Integer;
begin
  {
    Clone both the state and key before starting the background task.

    AKey is a dynamic array and is reference-counted, so making a
    separate copy avoids depending on the caller keeping it unchanged.
  }
  LValue := AValue.Clone;

  SetLength(LKey, Length(AKey));

  for I := 0 to Length(AKey) - 1 do
    LKey[I] := AKey[I];

  FTask := TTask.Run(
    procedure
    begin
      try
        Save(LKey, LValue);
      finally
        LValue.Free;
      end;

      while GetCacheSize > CapacityBytes do
      begin
        FDatS.ExecSQL(
          'DELETE FROM CACHE ' +
          'WHERE ID = (' +
          'SELECT MIN(ID) FROM CACHE' +
          ')');
      end;

      FConnection.Commit;
    end);
end;

end.
