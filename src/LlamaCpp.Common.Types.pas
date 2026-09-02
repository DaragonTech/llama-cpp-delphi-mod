unit LlamaCpp.Common.Types;

interface

uses
  System.Rtti,
  System.TypInfo,
  System.SysUtils,
  System.Generics.Collections,
  LlamaCpp.Common.State,
  LlamaCpp.Common.TokenArray,
  LlamaCpp.Common.Settings,
  LlamaCpp.Common.Sampling.Params,
  LlamaCpp.Common.Sampling.CustomSampler,
  LlamaCpp.Common.Chat.Types;

type
  TCompletionCallback = reference to procedure(
    const AResponse: TCreateCompletionResponse; var AContinue: Boolean);

  TChatCompletionCallback = reference to procedure(
    const AResponse: TChatCompletionStreamResponse; var AContinue: Boolean);

  TStoppingCriteria = reference to function(
    const ATokens: TArray<Integer>;
    const ALogits: TArray<Single>): Boolean;

  IStoppingCriteriaList = interface
    ['{1DFC697E-E47B-4FC9-A2AD-64F8B332B27B}']
    procedure Add(const AProcessor: TStoppingCriteria);
    function Execute(
      const AInputIds: TArray<Integer>;
      const ALogits: TArray<Single>): Boolean;
  end;

  TLogitsProcessor = reference to procedure(
    const InputIds: TArray<Integer>;
    [ref] const Scores: TArray<Single>
  );

  ILogitsProcessorList = interface
    ['{90061F97-DC6B-4FAA-B2B7-399509B21FB8}']
    procedure Add(const AProcessor: TLogitsProcessor);
    procedure Execute(
      const InputIds: TArray<Integer>;
      [ref] const Scores: TArray<Single>);
  end;

  ILlamaCache = interface
    ['{F28B509B-443F-4F8F-B8EB-B9FF32D83A5D}']

    function GetCacheSize: Int64;
    function LongestTokenPrefix(
      const A, B: TArray<Integer>): Integer;

    function FindLongestPrefixKey(
      const AKey: TArray<Integer>): TArray<Integer>;

    function GetItem(
      const AKey: TArray<Integer>): TLlamaState;

    function Contains(
      const AKey: TArray<Integer>): Boolean;

    procedure SetItem(
      const AKey: TArray<Integer>;
      const AValue: TLlamaState);

    property CacheSize: Int64 read GetCacheSize;

    property Items[const AKey: TArray<Integer>]: TLlamaState
      read GetItem write SetItem; default;
  end;

  ILlamaGrammar = interface
    ['{9E2B2065-9ADA-4A7A-B145-D5CE44712D20}']

    function GetGrammar: string;
    procedure SetGrammar(const AGrammar: string);

    function GetRoot: string;
    procedure SetRoot(const ARoot: string);

    procedure Reset;

    property Grammar: string read GetGrammar write SetGrammar;
    property Root: string read GetRoot write SetRoot;
  end;

  ILlamaTokenizer = interface
    ['{B7AF62EE-53C6-4DAF-84E3-7C46A1791232}']

    function Tokenize(
      const AText: TBytes;
      const AAddSpecial: Boolean = True;
      const AParseSpecial: Boolean = True): TArray<Integer>;

    function Detokenize(
      const ATokens: TArray<Integer>;
      const APrevTokens: TArray<Integer> = nil;
      const ASpecial: Boolean = False): TBytes;

    function Encode(
      const AText: string;
      const AAddSpecial: Boolean = True;
      const AParseSpecial: Boolean = False): TArray<Integer>;

    function Decode(
      const ATokens: TArray<Integer>;
      const APrevTokens: TArray<Integer> = nil;
      const ASpecial: Boolean = False): string;
  end;

  // Speculative decoding
  ILlamaDraftModel = interface
    ['{D28A39AB-EEC0-4DBC-AFD6-5188CDD0644E}']
    function Execute(
      const AInputIds: TArray<Integer>): TArray<Integer>;
  end;

  TokenizationTask = reference to function(
    const AText: string;
    const AAddSpecial: Boolean = True;
    const AParseSpecial: Boolean = False): TArray<Integer>;

  TCreateCompletionTask = reference to function(
    const ATokens: TArray<Integer>;
    ASettings: TLlamaCompletionSettings;
    const AStoppingCriteria: IStoppingCriteriaList = nil;
    const ALogitsProcessor: ILogitsProcessorList = nil;
    const AGrammar: ILlamaGrammar = nil): TCreateCompletionResponse;

  TCreateCompletionTaskAsync = reference to procedure(
    const ATokens: TArray<Integer>;
    ASettings: TLlamaCompletionSettings;
    const ACallback: TCompletionCallback;
    const AStoppingCriteria: IStoppingCriteriaList = nil;
    const ALogitsProcessor: ILogitsProcessorList = nil;
    const AGrammar: ILlamaGrammar = nil);

  ILlamaChatCompletionHandler = interface
    ['{B4354AD2-9F0F-46B2-A30C-17BB2849D348}']

    function Handle(
      ASettings: TLlamaChatCompletionSettings;
      const ATokenizationTask: TokenizationTask;
      const ACreateCompletionTask: TCreateCompletionTask;
      const AStoppingCriteria: IStoppingCriteriaList = nil;
      const ALogitsProcessor: ILogitsProcessorList = nil;
      const AGrammar: ILlamaGrammar = nil):
      TCreateChatCompletionResponse; overload;

    procedure Handle(
      ASettings: TLlamaChatCompletionSettings;
      const ATokenizationTask: TokenizationTask;
      const ACreateCompletionTask: TCreateCompletionTaskAsync;
      const ACallback: TChatCompletionCallback;
      const AStoppingCriteria: IStoppingCriteriaList = nil;
      const ALogitsProcessor: ILogitsProcessorList = nil;
      const AGrammar: ILlamaGrammar = nil); overload;
  end;

  ILlamaChatFormater = interface
    ['{D4EA01ED-E8FB-4BC0-A850-6B3AF367784D}']

    function Format(
      const ASettings: TLlamaChatCompletionSettings):
      TChatFormatterResponse;
  end;

  TNullable<T> = record
  private
    FValue: T;

    // Delphi 10.2 compatibility:
    // Default record memory is zeroed, so False means NULL.
    FHasValue: Boolean;

    function GetValue: T;
    procedure SetValue(const AValue: T);
    function GetIsNull: Boolean;

  public
    constructor Create(const AValue: T);

    procedure Clear;

    // Implicit conversions
    class operator Implicit(const A: TNullable<T>): T;
    class operator Implicit(const A: T): TNullable<T>;

    // Arithmetic operators
    class operator Add(
      const A, B: TNullable<T>): TNullable<T>;

    class operator Subtract(
      const A, B: TNullable<T>): TNullable<T>;

    class operator Multiply(
      const A, B: TNullable<T>): TNullable<T>;

    class operator Divide(
      const A, B: TNullable<T>): TNullable<T>;

    class operator IntDivide(
      const A, B: TNullable<T>): TNullable<T>;

    class operator Modulus(
      const A, B: TNullable<T>): TNullable<T>;

    // Comparison operators
    class operator Equal(
      const A, B: TNullable<T>): Boolean;

    class operator NotEqual(
      const A, B: TNullable<T>): Boolean;

    class operator GreaterThan(
      const A, B: TNullable<T>): Boolean;

    class operator GreaterThanOrEqual(
      const A, B: TNullable<T>): Boolean;

    class operator LessThan(
      const A, B: TNullable<T>): Boolean;

    class operator LessThanOrEqual(
      const A, B: TNullable<T>): Boolean;

    class function Null: TNullable<T>; static;

    function CanCast<C>: Boolean;
    function Cast<C>: C;

    property Value: T read GetValue write SetValue;
    property IsNull: Boolean read GetIsNull;
  end;

  TInteger = TNullable<Integer>;
  TString = TNullable<string>;

implementation

{ TNullable<T> }

constructor TNullable<T>.Create(const AValue: T);
begin
  FValue := AValue;
  FHasValue := True;
end;

function TNullable<T>.GetValue: T;
begin
  if not FHasValue then
    raise Exception.Create('Attempt to access a null value');

  Result := FValue;
end;

procedure TNullable<T>.SetValue(const AValue: T);
begin
  FValue := AValue;
  FHasValue := True;
end;

function TNullable<T>.GetIsNull: Boolean;
begin
  Result := not FHasValue;
end;

procedure TNullable<T>.Clear;
begin
  FValue := Default(T);
  FHasValue := False;
end;

function TNullable<T>.CanCast<C>: Boolean;
begin
  {
    The original version used TValue.TryCast(), which is problematic
    with older Delphi RTL versions.

    The nullable class currently uses casts primarily for determining
    whether T is Integer, so exact RTTI type matching is sufficient.
  }
  Result := TypeInfo(T) = TypeInfo(C);
end;

function TNullable<T>.Cast<C>: C;
var
  LSource: TValue;
begin
  if IsNull then
    raise Exception.Create('Cannot cast a null value');

  if not CanCast<C> then
    raise EInvalidCast.Create('Invalid nullable type cast');

  LSource := TValue.From<T>(FValue);
  Result := LSource.AsType<C>;
end;

class operator TNullable<T>.Add(
  const A, B: TNullable<T>): TNullable<T>;
var
  LValue: Integer;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := TNullable<T>.Null;
    Exit;
  end;

  if A.CanCast<Integer> and B.CanCast<Integer> then
  begin
    LValue := A.Cast<Integer> + B.Cast<Integer>;
    Result := TNullable<T>.Create(
      TValue.From<Integer>(LValue).AsType<T>);
  end
  else
    raise ENotImplemented.Create('Add is not implemented for this type.');
end;

class operator TNullable<T>.Subtract(
  const A, B: TNullable<T>): TNullable<T>;
var
  LValue: Integer;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := TNullable<T>.Null;
    Exit;
  end;

  if A.CanCast<Integer> and B.CanCast<Integer> then
  begin
    LValue := A.Cast<Integer> - B.Cast<Integer>;
    Result := TNullable<T>.Create(
      TValue.From<Integer>(LValue).AsType<T>);
  end
  else
    raise ENotImplemented.Create(
      'Subtract is not implemented for this type.');
end;

class operator TNullable<T>.Multiply(
  const A, B: TNullable<T>): TNullable<T>;
var
  LValue: Integer;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := TNullable<T>.Null;
    Exit;
  end;

  if A.CanCast<Integer> and B.CanCast<Integer> then
  begin
    LValue := A.Cast<Integer> * B.Cast<Integer>;
    Result := TNullable<T>.Create(
      TValue.From<Integer>(LValue).AsType<T>);
  end
  else
    raise ENotImplemented.Create(
      'Multiply is not implemented for this type.');
end;

class operator TNullable<T>.Divide(
  const A, B: TNullable<T>): TNullable<T>;
var
  LValue: Integer;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := TNullable<T>.Null;
    Exit;
  end;

  if A.CanCast<Integer> and B.CanCast<Integer> then
  begin
    if B.Cast<Integer> = 0 then
      raise Exception.Create('Division by zero is not allowed');

    {
      Since TInteger is the arithmetic nullable type in this unit,
      preserve T as Integer.

      The original code attempted to create a Double and convert that
      back to T, which is not useful when T = Integer.
    }
    LValue := A.Cast<Integer> div B.Cast<Integer>;

    Result := TNullable<T>.Create(
      TValue.From<Integer>(LValue).AsType<T>);
  end
  else
    raise ENotImplemented.Create(
      'Divide is not implemented for this type.');
end;

class operator TNullable<T>.IntDivide(
  const A, B: TNullable<T>): TNullable<T>;
var
  LValue: Integer;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := TNullable<T>.Null;
    Exit;
  end;

  if not A.CanCast<Integer> or not B.CanCast<Integer> then
    raise Exception.Create(
      'IntDivide is supported only for integer types');

  if B.Cast<Integer> = 0 then
    raise Exception.Create('Division by zero is not allowed');

  LValue := A.Cast<Integer> div B.Cast<Integer>;

  Result := TNullable<T>.Create(
    TValue.From<Integer>(LValue).AsType<T>);
end;

class operator TNullable<T>.Modulus(
  const A, B: TNullable<T>): TNullable<T>;
var
  LValue: Integer;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := TNullable<T>.Null;
    Exit;
  end;

  if not A.CanCast<Integer> or not B.CanCast<Integer> then
    raise Exception.Create(
      'Modulus is supported only for integer types');

  if B.Cast<Integer> = 0 then
    raise Exception.Create('Modulus by zero is not allowed');

  LValue := A.Cast<Integer> mod B.Cast<Integer>;

  Result := TNullable<T>.Create(
    TValue.From<Integer>(LValue).AsType<T>);
end;

class operator TNullable<T>.Equal(
  const A, B: TNullable<T>): Boolean;
begin
  if A.IsNull and B.IsNull then
  begin
    Result := True;
    Exit;
  end;

  if A.IsNull or B.IsNull then
  begin
    Result := False;
    Exit;
  end;

  if A.CanCast<Integer> and B.CanCast<Integer> then
  begin
    Result := A.Cast<Integer> = B.Cast<Integer>;
    Exit;
  end;

  if A.CanCast<string> and B.CanCast<string> then
  begin
    Result := A.Cast<string> = B.Cast<string>;
    Exit;
  end;

  raise ENotImplemented.Create(
    'Equal is not implemented for this type.');
end;

class operator TNullable<T>.NotEqual(
  const A, B: TNullable<T>): Boolean;
begin
  Result := not (A = B);
end;

class operator TNullable<T>.GreaterThan(
  const A, B: TNullable<T>): Boolean;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := False;
    Exit;
  end;

  if A.CanCast<Integer> and B.CanCast<Integer> then
  begin
    Result := A.Cast<Integer> > B.Cast<Integer>;
    Exit;
  end;

  raise ENotImplemented.Create(
    'GreaterThan is not implemented for this type.');
end;

class operator TNullable<T>.GreaterThanOrEqual(
  const A, B: TNullable<T>): Boolean;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := False;
    Exit;
  end;

  if A.CanCast<Integer> and B.CanCast<Integer> then
  begin
    Result := A.Cast<Integer> >= B.Cast<Integer>;
    Exit;
  end;

  raise ENotImplemented.Create(
    'GreaterThanOrEqual is not implemented for this type.');
end;

class operator TNullable<T>.LessThan(
  const A, B: TNullable<T>): Boolean;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := False;
    Exit;
  end;

  if A.CanCast<Integer> and B.CanCast<Integer> then
  begin
    Result := A.Cast<Integer> < B.Cast<Integer>;
    Exit;
  end;

  raise ENotImplemented.Create(
    'LessThan is not implemented for this type.');
end;

class operator TNullable<T>.LessThanOrEqual(
  const A, B: TNullable<T>): Boolean;
begin
  if A.IsNull or B.IsNull then
  begin
    Result := False;
    Exit;
  end;

  if A.CanCast<Integer> and B.CanCast<Integer> then
  begin
    Result := A.Cast<Integer> <= B.Cast<Integer>;
    Exit;
  end;

  raise ENotImplemented.Create(
    'LessThanOrEqual is not implemented for this type.');
end;

class operator TNullable<T>.Implicit(
  const A: TNullable<T>): T;
begin
  if A.IsNull then
    raise Exception.Create(
      'Cannot implicitly convert a null value');

  Result := A.FValue;
end;

class operator TNullable<T>.Implicit(
  const A: T): TNullable<T>;
begin
  Result := TNullable<T>.Create(A);
end;

class function TNullable<T>.Null: TNullable<T>;
begin
  Result.FValue := Default(T);
  Result.FHasValue := False;
end;

end.
