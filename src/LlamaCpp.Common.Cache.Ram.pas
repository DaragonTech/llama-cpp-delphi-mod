unit LlamaCpp.Common.Cache.Ram;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  LlamaCpp.Common.Cache.Base,
  LlamaCpp.Common.Types,
  LlamaCpp.Common.State;

type
  TLlamaRAMCache = class(TBaseLlamaCache)
  private
    const
      DEFAULT_CAPACITY =
        {$IFDEF WIN32}
        1073741824
        {$ELSE}
        NativeInt(Int64(2) shl 30)
        {$ENDIF};

  private
    FKeys: TList<TArray<Integer>>;
    FValues: TList<TLlamaState>;

    function KeysEqual(
      const A, B: TArray<Integer>): Boolean;

    function FindExactKeyIndex(
      const AKey: TArray<Integer>): Integer;

    function FindLongestPrefixIndex(
      const AKey: TArray<Integer>): Integer;

  public
    constructor Create(
      ACapacityBytes: NativeInt = DEFAULT_CAPACITY);

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

{ TLlamaRAMCache }

constructor TLlamaRAMCache.Create(ACapacityBytes: NativeInt);
begin
  inherited Create(ACapacityBytes);

  FKeys := TList<TArray<Integer>>.Create;
  FValues := TList<TLlamaState>.Create;
end;

destructor TLlamaRAMCache.Destroy;
var
  I: Integer;
begin
  if Assigned(FValues) then
  begin
    for I := 0 to FValues.Count - 1 do
      FValues[I].Free;
  end;

  FValues.Free;
  FKeys.Free;

  inherited;
end;

function TLlamaRAMCache.KeysEqual(
  const A, B: TArray<Integer>): Boolean;
var
  I: Integer;
begin
  Result := False;

  if Length(A) <> Length(B) then
    Exit;

  for I := 0 to Length(A) - 1 do
  begin
    if A[I] <> B[I] then
      Exit;
  end;

  Result := True;
end;

function TLlamaRAMCache.FindExactKeyIndex(
  const AKey: TArray<Integer>): Integer;
var
  I: Integer;
begin
  Result := -1;

  for I := 0 to FKeys.Count - 1 do
  begin
    if KeysEqual(FKeys[I], AKey) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

function TLlamaRAMCache.FindLongestPrefixIndex(
  const AKey: TArray<Integer>): Integer;
var
  I: Integer;
  LPrefixLen: Integer;
  LMaxPrefixLen: Integer;
begin
  Result := -1;
  LMaxPrefixLen := 0;

  for I := 0 to FKeys.Count - 1 do
  begin
    LPrefixLen := LongestTokenPrefix(
      FKeys[I],
      AKey);

    if LPrefixLen > LMaxPrefixLen then
    begin
      LMaxPrefixLen := LPrefixLen;
      Result := I;
    end;
  end;
end;

function TLlamaRAMCache.GetCacheSize: Int64;
var
  I: Integer;
begin
  Result := 0;

  for I := 0 to FValues.Count - 1 do
    Result := Result + FValues[I].GetSize;
end;

function TLlamaRAMCache.FindLongestPrefixKey(
  const AKey: TArray<Integer>): TArray<Integer>;
var
  LIndex: Integer;
begin
  Result := nil;

  LIndex := FindLongestPrefixIndex(AKey);

  if LIndex >= 0 then
    Result := FKeys[LIndex];
end;

function TLlamaRAMCache.Contains(
  const AKey: TArray<Integer>): Boolean;
begin
  Result := FindLongestPrefixIndex(AKey) >= 0;
end;

function TLlamaRAMCache.GetItem(
  const AKey: TArray<Integer>): TLlamaState;
var
  LIndex: Integer;
begin
  LIndex := FindLongestPrefixIndex(AKey);

  if LIndex < 0 then
    raise Exception.Create('Key not found');

  {
    Return ownership of the state to the caller.

    Do NOT free it when removing it from the cache.
  }
  Result := FValues[LIndex];

  FValues.Delete(LIndex);
  FKeys.Delete(LIndex);
end;

procedure TLlamaRAMCache.SetItem(
  const AKey: TArray<Integer>;
  const AValue: TLlamaState);
var
  LIndex: Integer;
  LNewValue: TLlamaState;
  LKeyCopy: TArray<Integer>;
  I: Integer;
begin
  {
    Make our own copy of the key.

    This prevents changes to the caller's dynamic array from changing
    a key that is already stored in the cache.
  }
  SetLength(LKeyCopy, Length(AKey));

  for I := 0 to Length(AKey) - 1 do
    LKeyCopy[I] := AKey[I];

  LNewValue := AValue.Clone;

  {
    Equivalent to AddOrSetValue.

    If the same token array is already cached, replace its value.
  }
  LIndex := FindExactKeyIndex(AKey);

  if LIndex >= 0 then
  begin
    FValues[LIndex].Free;

    FKeys[LIndex] := LKeyCopy;
    FValues[LIndex] := LNewValue;

    {
      Move the replaced item to the end so it becomes the newest
      cache entry.
    }
    LKeyCopy := FKeys[LIndex];
    LNewValue := FValues[LIndex];

    FKeys.Delete(LIndex);
    FValues.Delete(LIndex);

    FKeys.Add(LKeyCopy);
    FValues.Add(LNewValue);
  end
  else
  begin
    FKeys.Add(LKeyCopy);
    FValues.Add(LNewValue);
  end;

  {
    Remove the oldest items until the cache is within its capacity.
  }
  while (FValues.Count > 0) and
        (GetCacheSize > CapacityBytes) do
  begin
    FValues[0].Free;

    FValues.Delete(0);
    FKeys.Delete(0);
  end;
end;

end.
