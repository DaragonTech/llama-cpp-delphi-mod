unit LlamaCpp.Common.Grammar;

interface

uses
  System.SysUtils,
  System.Classes,
  LlamaCpp.Common.Types;

const
  LLAMA_GRAMMAR_DEFAULT_ROOT = 'root';

  JSON_GBNF =
    'root   ::= object' + #13#10 +
    'value  ::= object | array | string | number | ("true" | "false" | "null") ws' + #13#10 +
    #13#10 +
    'object ::=' + #13#10 +
    '  "{" ws (' + #13#10 +
    '            string ":" ws value' + #13#10 +
    '    ("," ws string ":" ws value)*' + #13#10 +
    '  )? "}" ws' + #13#10 +
    #13#10 +
    'array  ::=' + #13#10 +
    '  "[" ws (' + #13#10 +
    '            value' + #13#10 +
    '    ("," ws value)*' + #13#10 +
    '  )? "]" ws' + #13#10 +
    #13#10 +
    'string ::=' + #13#10 +
    '  "\"" (' + #13#10 +
    '    [^"\\\x7F\x00-\x1F] |' + #13#10 +
    '    "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4}) # escapes' + #13#10 +
    '  )* "\"" ws' + #13#10 +
    #13#10 +
    'number ::=' + #13#10 +
    '  ("-"? ([0-9] | [1-9] [0-9]{0,15})) ("." [0-9]+)? ([eE] [-+]? [0-9] [1-9]{0,15})? ws' + #13#10 +
    #13#10 +
    '# Optional space: by convention, applied in this grammar after literal chars when allowed' + #13#10 +
    'ws ::= | " " | "\n" [ \t]{0,20}' + #13#10;

type
  TLlamaGrammar = class(TInterfacedObject, ILlamaGrammar)
  private
    FGrammar: string;
    FRoot: string;

    function GetGrammar: string;
    procedure SetGrammar(const AGrammar: string);

    function GetRoot: string;
    procedure SetRoot(const ARoot: string);

  public
    constructor Create(const AGrammar: string);

    procedure Reset;

    class function FromString(
      const AGrammar: string): ILlamaGrammar; static;

    class function FromFile(
      const AFileName: string): ILlamaGrammar; static;

    class function FromJsonSchema(
      const AJsonSchema: string): ILlamaGrammar; static;

    class function JsonSchemaToGBNF(
      const ASchema: string;
      const APropOrder: TArray<string> = nil): string; static;

    property Grammar: string
      read GetGrammar
      write SetGrammar;

    property Root: string
      read GetRoot
      write SetRoot;
  end;

implementation

{ TLlamaGrammar }

constructor TLlamaGrammar.Create(const AGrammar: string);
begin
  inherited Create;

  FGrammar := AGrammar;
  FRoot := LLAMA_GRAMMAR_DEFAULT_ROOT;
end;

function TLlamaGrammar.GetGrammar: string;
begin
  Result := FGrammar;
end;

procedure TLlamaGrammar.SetGrammar(const AGrammar: string);
begin
  FGrammar := AGrammar;
end;

function TLlamaGrammar.GetRoot: string;
begin
  Result := FRoot;
end;

procedure TLlamaGrammar.SetRoot(const ARoot: string);
begin
  FRoot := ARoot;
end;

procedure TLlamaGrammar.Reset;
begin
  // Nothing to reset here.
end;

class function TLlamaGrammar.FromString(
  const AGrammar: string): ILlamaGrammar;
begin
  Result := TLlamaGrammar.Create(AGrammar);
end;

class function TLlamaGrammar.FromFile(
  const AFileName: string): ILlamaGrammar;
var
  LGrammarFile: TStringList;
begin
  LGrammarFile := TStringList.Create;
  try
    try
      LGrammarFile.LoadFromFile(AFileName);

      if Trim(LGrammarFile.Text) = '' then
        raise Exception.Create(
          'Error: Grammar file is empty');

      Result := TLlamaGrammar.FromString(
        LGrammarFile.Text);

    except
      on E: Exception do
        raise Exception.CreateFmt(
          'Error reading grammar file: %s',
          [E.Message]);
    end;

  finally
    LGrammarFile.Free;
  end;
end;

class function TLlamaGrammar.FromJsonSchema(
  const AJsonSchema: string): ILlamaGrammar;
begin
  Result := TLlamaGrammar.FromString(
    JsonSchemaToGBNF(AJsonSchema));
end;

class function TLlamaGrammar.JsonSchemaToGBNF(
  const ASchema: string;
  const APropOrder: TArray<string>): string;
begin
  raise ENotImplemented.Create(
    'Not implemented.');
end;

end.
