unit LlamaCpp.Completion;

interface

uses
  System.SysUtils,
  System.Generics.Defaults,
  System.Generics.Collections,
  LlamaCpp.CType.Llama,
  LlamaCpp.Wrapper.LlamaModel,
  LlamaCpp.Wrapper.LlamaContext,
  LlamaCpp.Common.Types,
  LlamaCpp.Common.Settings,
  LlamaCpp.Common.State,
  LlamaCpp.Common.Chat.Types,
  LlamaCpp.Types;

type
  TCompletionData = record
    ModelName: string;
    CompletionId: string;
    Created: Int64;
    CompletionTokens: TArray<Integer>;
    PromptTokens: TArray<Integer>;
    ReturnedTokens: Integer;
    FinishReason: string;
    MultibyteFix: Integer;
    StopSequences: TArray<TBytes>;
    TokenEndPosition: Integer;
    CompletionLogprobs: TCompletionLogprobs;
  end;

  TLlamaCompletion = class(TInterfacedObject, ILlamaCompletion)
  private
    FModel: TLlamaModel;
    FContext: TLlamaContext;
    FSettings: TLlamaSettings;
    FContextParams: TLlamaContextParams;
    FMetadata: TMetadata;
    FModelPath: string;
    FCache: ILlamaCache;
    FTokenization: ILlamaTokenization;
    FGenerator: ILlamaGenerator;
    [weak]
    FLlama: ILlama;

    function ContainsBytes(
      const AHayStack, ANeedle: TBytes): Boolean;

    function EndsWithBytes(
      const AHayStack, ANeedle: TBytes): Boolean;

    function CopyBytes(
      const ASource, ANeedle: TBytes): TBytes;

    function IndexOfBytes(
      const ASource, ANeedle: TBytes): Integer;

    procedure LoadCache(
      [ref] AData: TCompletionData);

    procedure SaveCache(
      [ref] AData: TCompletionData);

    procedure CheckStopCriteria(
      [ref] AData: TCompletionData;
      const AStoppingCriteria: IStoppingCriteriaList;
      var AText: TBytes);

    procedure SetupLogitsProcessor(
      [ref] AData: TCompletionData;
      const ASettings: TLlamaCompletionSettings;
      var ALogitsProcessor: ILogitsProcessorList);

    function ProcessAnyStopStream(
      const AStopSequences: TArray<TBytes>;
      const ARemainingText: TBytes): Integer;

    function ProcessAnyStopGenerate(
      [ref] LData: TCompletionData;
      const AAllText: TBytes;
      var AText: TBytes): Boolean;

    function CheckCompleteBytes(
      const AAllText: TBytes;
      var AMultibyteFix: Integer): Boolean;

    function ProcessStreamLogprob(
      [ref] AData: TCompletionData;
      const ASettings: TLlamaCompletionSettings;
      const AToken: Integer;
      const APrompt: TArray<Integer>): TCompletionLogprobs;

    function ProcessGenerateStreamLogprob(
      [ref] AData: TCompletionData;
      const ASettings: TLlamaCompletionSettings;
      const AToken: Integer;
      const APrompt: TArray<Integer>): TCompletionLogprobs;

    function ProcessLogprob(
      [ref] AData: TCompletionData;
      const ASettings: TLlamaCompletionSettings;
      const APrompt: TArray<Integer>): TCompletionLogprobs;

    function DoGenerate(
      [ref] AData: TCompletionData;
      const ASettings: TLlamaCompletionSettings;
      const APrompt: TArray<Integer>;
      var AText: TBytes;
      const AToken: TLlamaToken;
      const AStream: Boolean;
      const ACallback: TCompletionCallback): Boolean;

  private
    function GenerateRandom(
      const ASeed: UInt32): UInt32;

    procedure InternalCreateCompletion(
      const APrompt: TArray<Integer>;
      const AStream: Boolean;
      ASettings: TLlamaCompletionSettings;
      const ACallback: TCompletionCallback;
      const AStoppingCriteria: IStoppingCriteriaList;
      ALogitsProcessor: ILogitsProcessorList;
      const AGrammar: ILlamaGrammar); overload;

    procedure InternalCreateCompletion(
      const APrompt: string;
      const AStream: Boolean;
      ASettings: TLlamaCompletionSettings;
      const ACallback: TCompletionCallback;
      const AStoppingCriteria: IStoppingCriteriaList;
      ALogitsProcessor: ILogitsProcessorList;
      const AGrammar: ILlamaGrammar); overload;

  public
    constructor Create(const ALlama: ILlama);

    function CreateCompletion(
      const APrompt: string;
      ASettings: TLlamaCompletionSettings;
      const AStoppingCriteria: IStoppingCriteriaList = nil;
      const ALogitsProcessor: ILogitsProcessorList = nil;
      const AGrammar: ILlamaGrammar = nil): TCreateCompletionResponse; overload;

    procedure CreateCompletion(
      const APrompt: string;
      ASettings: TLlamaCompletionSettings;
      const ACallback: TCompletionCallback;
      const AStoppingCriteria: IStoppingCriteriaList = nil;
      const ALogitsProcessor: ILogitsProcessorList = nil;
      const AGrammar: ILlamaGrammar = nil); overload;

    function CreateCompletion(
      const APrompt: TArray<Integer>;
      ASettings: TLlamaCompletionSettings;
      const AStoppingCriteria: IStoppingCriteriaList = nil;
      const ALogitsProcessor: ILogitsProcessorList = nil;
      const AGrammar: ILlamaGrammar = nil): TCreateCompletionResponse; overload;

    procedure CreateCompletion(
      const APrompt: TArray<Integer>;
      ASettings: TLlamaCompletionSettings;
      const ACallback: TCompletionCallback;
      const AStoppingCriteria: IStoppingCriteriaList = nil;
      const ALogitsProcessor: ILogitsProcessorList = nil;
      const AGrammar: ILlamaGrammar = nil); overload;
  end;

implementation

uses
  System.Math,
  System.DateUtils,
  LlamaCpp.Api.Llama,
  LlamaCpp.Common.Processor.LogitsScore,
  LlamaCpp.Helper;

{ TLlamaCompletion }

constructor TLlamaCompletion.Create(const ALlama: ILlama);
begin
  FModel := ALlama.Model;
  FContext := ALlama.Context;
  FSettings := ALlama.Settings;
  FContextParams := ALlama.ContextParams;
  FMetadata := ALlama.Metadata;
  FModelPath := ALlama.ModelPath;
  FCache := ALlama.Cache;
  FTokenization := ALlama as ILlamaTokenization;
  FGenerator := ALlama as ILlamaGenerator;
  FLlama := ALlama;
end;

function TLlamaCompletion.GenerateRandom(const ASeed: UInt32): UInt32;
var
  LSeed: UInt32;
begin
  LSeed := ASeed;

  if LSeed = 0 then
    LSeed :=
      UInt32(DateTimeToUnix(Now)) xor
      UInt32(MilliSecondOfTheDay(Now));

  Result :=
    (LSeed * UInt32(1664525)) +
    UInt32(1013904223);

  if Result = 0 then
    Result := 1;
end;

procedure TLlamaCompletion.InternalCreateCompletion(
  const APrompt: string;
  const AStream: Boolean;
  ASettings: TLlamaCompletionSettings;
  const ACallback: TCompletionCallback;
  const AStoppingCriteria: IStoppingCriteriaList;
  ALogitsProcessor: ILogitsProcessorList;
  const AGrammar: ILlamaGrammar);
var
  LPrompt: TArray<Integer>;
begin
  LPrompt := FTokenization.Encode(
    APrompt,
    False,
    (FModel.TokenPrefix() < 0) or ASettings.Suffix.IsEmpty());

  InternalCreateCompletion(
    LPrompt,
    AStream,
    ASettings,
    ACallback,
    AStoppingCriteria,
    ALogitsProcessor,
    AGrammar);
end;

procedure TLlamaCompletion.InternalCreateCompletion(
  const APrompt: TArray<Integer>;
  const AStream: Boolean;
  ASettings: TLlamaCompletionSettings;
  const ACallback: TCompletionCallback;
  const AStoppingCriteria: IStoppingCriteriaList;
  ALogitsProcessor: ILogitsProcessorList;
  const AGrammar: ILlamaGrammar);
var
  LData: TCompletionData;
  LToken: Integer;
  LTextStr: string;
  LLastText: TBytes;
  LAddSpacePrefix: Boolean;
  LBOSTokens: TArray<Integer>;
  LEOSTokens: TArray<Integer>;
  LSuffixSpacePrefix: Integer;
  LPrefixTokens: TArray<Integer>;
  LSuffixTokens: TArray<Integer>;
  LMiddleTokens: TArray<Integer>;
  LRemainingTokens: TArray<Integer>;
  LRemainingText: TBytes;
  LStopIndex: Integer;
  LCompletionResponse: TCreateCompletionResponse;
  LContinue: Boolean;
  LText: TBytes;
  I: Integer;
  LDecodedToken: string;
begin
  LData := Default(TCompletionData);

  LData.CompletionId :=
    'cmpl-' + GUIDToString(TGUID.NewGuid());

  LData.Created := DateTimeToUnix(Now());

  LAddSpacePrefix :=
    FMetadata.ContainsKey('tokenizer.ggml.add_space_prefix') and
    (FMetadata['tokenizer.ggml.add_space_prefix'] = 'true');

  LContinue := True;

  if FModel.TokenCLS() <> -1 then
    LBOSTokens := [FModel.TokenCLS()]
  else
    LBOSTokens := [FModel.TokenBOS()];

  if FModel.TokenSEP() <> -1 then
    LEOSTokens := [FModel.TokenSEP()]
  else
    LEOSTokens := [FModel.TokenEOS()];

  if (Assigned(APrompt) and ASettings.Suffix.IsEmpty()) or
     not FModel.AddBOSToken() or
     (Assigned(LBOSTokens) and
      (LBOSTokens[Low(LBOSTokens)] = -1)) then
    LBOSTokens := nil;

  if (Assigned(APrompt) and ASettings.Suffix.IsEmpty()) or
     (not FModel.AddEOSToken() and
      (FModel.TokenSEP() = -1)) then
    LEOSTokens := nil;

  LSuffixSpacePrefix := 0;

  if LAddSpacePrefix and
     (FModel.TokenSuffix() >= 0) and
     not ASettings.Suffix.IsEmpty() then
  begin
    ASettings.Suffix := '☺' + ASettings.Suffix;
    LSuffixSpacePrefix := 2;
  end;

  LData.CompletionTokens := nil;

  if not Assigned(APrompt) then
    LData.CompletionTokens := [FModel.TokenBOS()];

  LPrefixTokens := nil;

  if (FModel.TokenPrefix() >= 0) and
     not ASettings.Suffix.IsEmpty() then
    LPrefixTokens := [FModel.TokenPrefix()];

  if Assigned(APrompt) then
    LPrefixTokens := LPrefixTokens + APrompt;

  LSuffixTokens := nil;

  if (FModel.TokenSuffix() >= 0) and
     not ASettings.Suffix.IsEmpty then
  begin
    if not ASettings.Suffix.IsEmpty() then
      LSuffixTokens :=
        [FModel.TokenSuffix()] +
        TArrayHelper.Slice<Integer>(
          FTokenization.Encode(
            ASettings.Suffix,
            False,
            False),
          LSuffixSpacePrefix);
  end;

  LMiddleTokens := nil;

  if (FModel.TokenMiddle() >= 0) and
     not ASettings.Suffix.IsEmpty() then
    LMiddleTokens := [FModel.TokenMiddle()];

  if FSettings.SPMInfill then
    LData.PromptTokens :=
      LSuffixTokens +
      LPrefixTokens +
      LMiddleTokens
  else
    LData.PromptTokens :=
      LPrefixTokens +
      LSuffixTokens +
      LMiddleTokens;

  LData.PromptTokens :=
    LBOSTokens +
    LData.PromptTokens +
    LEOSTokens;

  LText := nil;
  LData.ReturnedTokens := 0;

  if not ASettings.ModelName.IsEmpty() then
    LData.ModelName := ASettings.ModelName
  else
    LData.ModelName := FModelPath;

  if Assigned(ASettings.LogitBias) then
    SetupLogitsProcessor(
      LData,
      ASettings,
      ALogitsProcessor);

  if FSettings.Verbose then
    FContext.ResetTimings();

  if Length(LData.PromptTokens) >= FContext.NCtx() then
    raise Exception.CreateFmt(
      'Requested tokens (%d) exceed context window of %d',
      [
        Length(LData.PromptTokens),
        TLlamaApi.Instance.llama_n_ctx(FContext)
      ]);

  if ASettings.MaxTokens <= 0 then
    ASettings.MaxTokens :=
      FContext.NCtx() -
      Length(LData.PromptTokens);

  if not (
    ASettings.MaxTokens +
    Length(LData.PromptTokens) <
    FContext.NCtx()) then
  begin
    ASettings.MaxTokens :=
      FContext.NCtx() -
      Length(LData.PromptTokens);
  end;

  LData.StopSequences := nil;

  for I := Low(ASettings.Stop) to High(ASettings.Stop) do
    LData.StopSequences :=
      LData.StopSequences +
      [
        TEncoding.UTF8.Convert(
          TEncoding.Unicode,
          TEncoding.UTF8,
          TEncoding.Unicode.GetBytes(
            ASettings.Stop[I]))
      ];

  if (ASettings.Logprobs > 0) and
     not FContextParams.LogitsAll then
    raise Exception.Create(
      'logprobs is not supported for models created with logits_all=False');

  if Assigned(FCache) then
    LoadCache(LData);

  if ASettings.Seed > 0 then
    FSettings.Seed := ASettings.Seed
  else
    FSettings.Seed :=
      GenerateRandom(FSettings.Seed);

  LData.FinishReason := 'length';
  LData.MultibyteFix := 0;

  FGenerator.Generate(
    LData.PromptTokens,
    ASettings.ToGeneratorSettings(),
    function(
      const AToken: Integer;
      var AContinue: Boolean): TArray<Integer>
    begin
      AContinue :=
        DoGenerate(
          LData,
          ASettings,
          APrompt,
          LText,
          AToken,
          AStream,
          ACallback);
    end,
    True,
    AStoppingCriteria,
    ALogitsProcessor,
    AGrammar);

  if Assigned(AStoppingCriteria) then
    CheckStopCriteria(
      LData,
      AStoppingCriteria,
      LText);

  if FSettings.Verbose then
    FContext.PrintTimings();

  if AStream then
  begin
    LRemainingTokens :=
      TArrayHelper.Slice<Integer>(
        LData.CompletionTokens,
        LData.ReturnedTokens);

    LRemainingText :=
      FTokenization.Detokenize(
        LRemainingTokens,
        LData.PromptTokens +
        TArrayHelper.Slice<Integer>(
          LRemainingTokens,
          Low(LRemainingTokens),
          LData.ReturnedTokens));

    LStopIndex :=
      ProcessAnyStopStream(
        LData.StopSequences,
        LRemainingText);

    LData.TokenEndPosition := 0;

    for LToken in LRemainingTokens do
    begin
      LData.CompletionLogprobs :=
        Default(TCompletionLogprobs);

      LData.TokenEndPosition :=
        LData.TokenEndPosition +
        Length(
          FTokenization.Detokenize(
            [LToken],
            LData.PromptTokens +
            TArrayHelper.Slice<Integer>(
              LData.CompletionTokens,
              Low(LData.CompletionTokens),
              LData.ReturnedTokens)));

      if ASettings.Logprobs > 0 then
      begin
        if LToken = FModel.TokenBOS() then
          Continue;

        LData.CompletionLogprobs :=
          ProcessStreamLogprob(
            LData,
            ASettings,
            LToken,
            APrompt);
      end;

      if LData.TokenEndPosition >= LStopIndex then
      begin
        LLastText :=
          FTokenization.Detokenize([LToken]);

        if LData.TokenEndPosition =
           LStopIndex - 1 then
          Break;

        Inc(LData.ReturnedTokens);

        LDecodedToken := String.Empty;

        try
          LDecodedToken :=
            TEncoding.UTF8.GetString(
              TArrayHelper.Slice<Byte>(
                LLastText,
                Low(LLastText),
                Length(LLastText) -
                (LData.TokenEndPosition -
                 LStopIndex)));
        except
          on E: EEncodingError do
          begin
          end;
        end;

        LCompletionResponse :=
          TCreateCompletionResponse.Create(
            LData.CompletionId,
            'text_completion',
            LData.ModelName,
            LData.Created,
            [
              TCompletionChoice.Create(
                LDecodedToken,
                0,
                LData.CompletionLogprobs)
            ]);

        ACallback(
          LCompletionResponse,
          LContinue);

        if not LContinue then
          Exit;

        Break;
      end;

      Inc(LData.ReturnedTokens);

      LCompletionResponse :=
        TCreateCompletionResponse.Create(
          LData.CompletionId,
          'text_completion',
          LData.ModelName,
          LData.Created,
          [
            TCompletionChoice.Create(
              FTokenization.Decode([LToken]),
              0,
              LData.CompletionLogprobs)
          ]);

      ACallback(
        LCompletionResponse,
        LContinue);

      if not LContinue then
        Exit;
    end;

    LCompletionResponse :=
      TCreateCompletionResponse.Create(
        LData.CompletionId,
        'text_completion',
        LData.ModelName,
        LData.Created,
        [
          TCompletionChoice.Create(
            String.Empty,
            0,
            Default(TCompletionLogprobs),
            LData.FinishReason)
        ]);

    ACallback(
      LCompletionResponse,
      LContinue);

    if not LContinue then
      Exit;

    if Assigned(FCache) then
      SaveCache(LData);

    Exit;
  end;

  if Assigned(FCache) then
    SaveCache(LData);

  LTextStr :=
    TEncoding.UTF8.GetString(LText);

  if ASettings.Echo then
    LTextStr :=
      FTokenization.Decode(APrompt) +
      LTextStr;

  if (FModel.TokenSuffix() < 0) and
     not ASettings.Suffix.IsEmpty() then
    LTextStr :=
      LTextStr +
      ASettings.Suffix;

  if ASettings.Logprobs > 0 then
    LData.CompletionLogprobs :=
      ProcessLogprob(
        LData,
        ASettings,
        APrompt);

  LCompletionResponse :=
    TCreateCompletionResponse.Create(
      LData.CompletionId,
      'text_completion',
      LData.ModelName,
      LData.Created,
      [
        TCompletionChoice.Create(
          LTextStr,
          0,
          LData.CompletionLogprobs,
          LData.FinishReason)
      ],
      TCompletionUsage.Create(
        Length(LData.PromptTokens),
        Length(LData.CompletionTokens),
        Length(LData.PromptTokens) +
        Length(LData.CompletionTokens)));

  ACallback(
    LCompletionResponse,
    LContinue);
end;

function TLlamaCompletion.DoGenerate(
  [ref] AData: TCompletionData;
  const ASettings: TLlamaCompletionSettings;
  const APrompt: TArray<Integer>;
  var AText: TBytes;
  const AToken: TLlamaToken;
  const AStream: Boolean;
  const ACallback: TCompletionCallback): Boolean;
var
  I: Integer;
  LAllText: TBytes;
  LRemainingTokens: TArray<Integer>;
  LRemainingText: TBytes;
  LRemainingLenght: Integer;
  LFirstStopPosition: Integer;
  LStopSequence: TBytes;
  LRemainingLength: Integer;
  LToken: Integer;
  LDecodeSuccess: Boolean;
  LBS: TBytes;
  LTS: string;
  LCompletionResponse: TCreateCompletionResponse;
  LContinue: Boolean;
begin
  Result := True;
  LContinue := True;

  if TLlamaApi.Instance.llama_token_is_eog(
    FModel.Model,
    AToken) then
  begin
    AText :=
      FTokenization.Detokenize(
        AData.CompletionTokens,
        AData.PromptTokens);

    AData.FinishReason := 'stop';

    Exit(False);
  end;

  AData.CompletionTokens :=
    AData.CompletionTokens + [AToken];

  LAllText :=
    FTokenization.Detokenize(
      AData.CompletionTokens,
      AData.PromptTokens);

  if not CheckCompleteBytes(
    LAllText,
    AData.MultibyteFix) then
    Exit(True);

  if not ProcessAnyStopGenerate(
    AData,
    LAllText,
    AText) then
    Exit(False);

  if AStream then
  begin
    LRemainingTokens :=
      TArrayHelper.Slice<Integer>(
        AData.CompletionTokens,
        AData.ReturnedTokens);

    LRemainingText :=
      FTokenization.Detokenize(
        LRemainingTokens,
        AData.PromptTokens +
        TArrayHelper.Slice<Integer>(
          AData.CompletionTokens,
          Low(AData.CompletionTokens),
          AData.ReturnedTokens));

    LRemainingLenght :=
      Length(LRemainingText);

    LFirstStopPosition := 0;

    for LStopSequence in AData.StopSequences do
    begin
      LRemainingLength :=
        Length(LRemainingText);

      for I :=
        Min(
          Length(LStopSequence),
          LRemainingLength)
        downto 1 do
      begin
        if EndsWithBytes(
          LRemainingText,
          TArrayHelper.Slice<Byte>(
            LStopSequence,
            Low(LStopSequence),
            I)) then
        begin
          if I > LFirstStopPosition then
            LFirstStopPosition := I;

          Break;
        end;
      end;
    end;

    AData.TokenEndPosition := 0;

    if ASettings.Logprobs > 0 then
    begin
      for LToken in LRemainingTokens do
      begin
        if LToken = FModel.TokenBOS() then
          Continue;

        AData.TokenEndPosition :=
          AData.TokenEndPosition +
          Length(
            FTokenization.Detokenize(
              [LToken],
              AData.PromptTokens +
              TArrayHelper.Slice<Integer>(
                AData.CompletionTokens,
                Low(AData.CompletionTokens),
                AData.ReturnedTokens)));

        if AData.TokenEndPosition >
           (LRemainingLenght -
            LFirstStopPosition) then
          Break;

        AData.CompletionLogprobs :=
          ProcessGenerateStreamLogprob(
            AData,
            ASettings,
            LToken,
            APrompt);

        LCompletionResponse :=
          TCreateCompletionResponse.Create(
            AData.CompletionId,
            'text_completion',
            AData.ModelName,
            AData.Created,
            [
              TCompletionChoice.Create(
                FTokenization.Decode(
                  [AToken],
                  AData.PromptTokens +
                  TArrayHelper.Slice<Integer>(
                    AData.CompletionTokens,
                    Low(AData.CompletionTokens),
                    AData.ReturnedTokens)),
                0,
                AData.CompletionLogprobs)
            ]);

        ACallback(
          LCompletionResponse,
          LContinue);

        if not LContinue then
          Exit(False);
      end;
    end
    else
    begin
      while Length(LRemainingTokens) > 0 do
      begin
        LDecodeSuccess := False;

        for I := 1 to Length(LRemainingTokens) + 1 do
        begin
          try
            LBS :=
              FTokenization.Detokenize(
                TArrayHelper.Slice<Integer>(
                  LRemainingTokens,
                  Low(LRemainingTokens),
                  I),
                AData.PromptTokens +
                TArrayHelper.Slice<Integer>(
                  AData.CompletionTokens,
                  Low(AData.CompletionTokens),
                  AData.ReturnedTokens));

            LTS :=
              TEncoding.UTF8.GetString(LBS);

            LDecodeSuccess := True;
            Break;
          except
            on E: EEncodingError do
            begin
            end;
          end;
        end;

        if not LDecodeSuccess then
          Break;

        AData.TokenEndPosition :=
          AData.TokenEndPosition +
          Length(LBS);

        if AData.TokenEndPosition >
           (LRemainingLenght -
            LFirstStopPosition) then
          Break;

        LRemainingTokens :=
          TArrayHelper.Slice<Integer>(
            LRemainingTokens,
            I - 1);

        AData.ReturnedTokens :=
          AData.ReturnedTokens + I;

        LCompletionResponse :=
          TCreateCompletionResponse.Create(
            AData.CompletionId,
            'text_completion',
            AData.ModelName,
            AData.Created,
            [
              TCompletionChoice.Create(
                LTS,
                0)
            ]);

        ACallback(
          LCompletionResponse,
          LContinue);

        if not LContinue then
          Exit(False);
      end;
    end;
  end;

  if Length(AData.CompletionTokens) >=
     ASettings.MaxTokens then
  begin
    AText :=
      FTokenization.Detokenize(
        AData.CompletionTokens,
        AData.PromptTokens);

    AData.FinishReason := 'length';
    Result := False;
  end;
end;

function TLlamaCompletion.CreateCompletion(
  const APrompt: string;
  ASettings: TLlamaCompletionSettings;
  const AStoppingCriteria: IStoppingCriteriaList;
  const ALogitsProcessor: ILogitsProcessorList;
  const AGrammar: ILlamaGrammar): TCreateCompletionResponse;
var
  LResult: TCreateCompletionResponse;
  LCallback: TCompletionCallback;
begin
  LResult := Default(TCreateCompletionResponse);

  LCallback :=
    procedure(
      const AResponse: TCreateCompletionResponse;
      var AContinue: Boolean)
    begin
      LResult := AResponse;
    end;

  InternalCreateCompletion(
    APrompt,
    False,
    ASettings,
    LCallback,
    AStoppingCriteria,
    ALogitsProcessor,
    AGrammar);

  Result := LResult;
end;

procedure TLlamaCompletion.CreateCompletion(
  const APrompt: string;
  ASettings: TLlamaCompletionSettings;
  const ACallback: TCompletionCallback;
  const AStoppingCriteria: IStoppingCriteriaList;
  const ALogitsProcessor: ILogitsProcessorList;
  const AGrammar: ILlamaGrammar);
begin
  InternalCreateCompletion(
    APrompt,
    True,
    ASettings,
    ACallback,
    AStoppingCriteria,
    ALogitsProcessor,
    AGrammar);
end;

function TLlamaCompletion.CreateCompletion(
  const APrompt: TArray<Integer>;
  ASettings: TLlamaCompletionSettings;
  const AStoppingCriteria: IStoppingCriteriaList;
  const ALogitsProcessor: ILogitsProcessorList;
  const AGrammar: ILlamaGrammar): TCreateCompletionResponse;
var
  LResult: TCreateCompletionResponse;
  LCallback: TCompletionCallback;
begin
  LResult := Default(TCreateCompletionResponse);

  LCallback :=
    procedure(
      const AResponse: TCreateCompletionResponse;
      var AContinue: Boolean)
    begin
      LResult := AResponse;
    end;

  InternalCreateCompletion(
    APrompt,
    False,
    ASettings,
    LCallback,
    AStoppingCriteria,
    ALogitsProcessor,
    AGrammar);

  Result := LResult;
end;

procedure TLlamaCompletion.CreateCompletion(
  const APrompt: TArray<Integer>;
  ASettings: TLlamaCompletionSettings;
  const ACallback: TCompletionCallback;
  const AStoppingCriteria: IStoppingCriteriaList;
  const ALogitsProcessor: ILogitsProcessorList;
  const AGrammar: ILlamaGrammar);
begin
  InternalCreateCompletion(
    APrompt,
    True,
    ASettings,
    ACallback,
    AStoppingCriteria,
    ALogitsProcessor,
    AGrammar);
end;

procedure TLlamaCompletion.CheckStopCriteria(
  [ref] AData: TCompletionData;
  const AStoppingCriteria: IStoppingCriteriaList;
  var AText: TBytes);
var
  LInputIds: TArray<Integer>;
  LScores: TArray<TArray<Single>>;
begin
  LInputIds :=
    TInputIdHelper.InputId(
      FLlama.InputIds,
      FLlama.NumberOfTokens);

  LScores :=
    TScoresHelper.Scores(
      FLlama.Scores,
      FLlama.NumberOfTokens);

  if AStoppingCriteria.Execute(
    LInputIds,
    LScores[High(LScores)]) then
  begin
    AText :=
      FTokenization.Detokenize(
        AData.CompletionTokens,
        AData.PromptTokens);

    AData.FinishReason := 'stop';
  end;
end;

procedure TLlamaCompletion.SaveCache(
  [ref] AData: TCompletionData);
var
  LCacheItem: TLlamaState;
begin
  LCacheItem := FLlama.SaveState;

  try
    FCache[
      AData.PromptTokens +
      AData.CompletionTokens] :=
      LCacheItem;
  finally
    LCacheItem.Free;
  end;
end;

procedure TLlamaCompletion.LoadCache(
  [ref] AData: TCompletionData);
var
  LCachePrefixLen: Integer;
  LEvalPrefixLen: Integer;
  LCacheItem: TLlamaState;
  LInputIds: TArray<Integer>;
begin
  try
    LCacheItem :=
      FCache[AData.PromptTokens];

    try
      LCachePrefixLen :=
        FCache.LongestTokenPrefix(
          LCacheItem.InputIds,
          AData.PromptTokens);

      LInputIds :=
        TInputIdHelper.InputId(
          FLlama.InputIds,
          FLlama.NumberOfTokens);

      LEvalPrefixLen :=
        FCache.LongestTokenPrefix(
          LInputIds,
          AData.PromptTokens);

      if LCachePrefixLen >
         LEvalPrefixLen then
        FLlama.LoadState(LCacheItem);
    finally
      LCacheItem.Free;
    end;
  except
  end;
end;

procedure TLlamaCompletion.SetupLogitsProcessor(
  [ref] AData: TCompletionData;
  const ASettings: TLlamaCompletionSettings;
  var ALogitsProcessor: ILogitsProcessorList);
var
  LLogitBiasMap: TArray<TPair<Integer, Single>>;
  LLogitBiasProcessor: TLogitsProcessor;
begin
  LLogitBiasMap := ASettings.LogitBias;

  LLogitBiasProcessor :=
    procedure(
      const AInputIds: TArray<Integer>;
      [ref] const AScores: TArray<Single>)
    var
      LLogitBias: TPair<Integer, Single>;
    begin
      for LLogitBias in LLogitBiasMap do
        AScores[LLogitBias.Key] :=
          LLogitBias.Value +
          AScores[LLogitBias.Key];
    end;

  if not Assigned(ALogitsProcessor) then
    ALogitsProcessor :=
      TDefaultLogitsScoreList.Create();

  ALogitsProcessor.Add(
    LLogitBiasProcessor);
end;

function TLlamaCompletion.ContainsBytes(
  const AHayStack,
  ANeedle: TBytes): Boolean;
var
  I: Integer;
begin
  if not Assigned(ANeedle) or
     (Length(AHayStack) <
      Length(ANeedle)) then
    Exit(False);

  for I := 0 to
    Length(AHayStack) -
    Length(ANeedle) do
  begin
    if CompareMem(
      @AHayStack[I],
      @ANeedle[0],
      Length(ANeedle)) then
      Exit(True);
  end;

  Result := False;
end;

function TLlamaCompletion.EndsWithBytes(
  const AHayStack,
  ANeedle: TBytes): Boolean;
begin
  if not Assigned(ANeedle) or
     (Length(AHayStack) <
      Length(ANeedle)) then
    Exit(False);

  if CompareMem(
    @AHayStack[
      Length(AHayStack) -
      Length(ANeedle)],
    @ANeedle[0],
    Length(ANeedle)) then
    Exit(True);

  Result := False;
end;

function TLlamaCompletion.CopyBytes(
  const ASource,
  ANeedle: TBytes): TBytes;
var
  I: Integer;
begin
  if not Assigned(ANeedle) or
     (Length(ASource) <
      Length(ANeedle)) then
    Exit(nil);

  for I := 0 to
    Length(ASource) -
    Length(ANeedle) do
  begin
    if CompareMem(
      @ASource[I],
      @ANeedle[0],
      Length(ANeedle)) then
    begin
      SetLength(Result, Succ(I));

      Move(
        ASource[0],
        Result[0],
        Succ(I));

      Exit(Result);
    end;
  end;

  Result := nil;
end;

function TLlamaCompletion.IndexOfBytes(
  const ASource,
  ANeedle: TBytes): Integer;
begin
  if not Assigned(ANeedle) then
    Exit(0);

  if Length(ASource) <
     Length(ANeedle) then
    Exit(-1);

  for Result := 0 to
    Length(ASource) -
    Length(ANeedle) do
  begin
    if CompareMem(
      @ASource[Result],
      @ANeedle[0],
      Length(ANeedle)) then
      Exit;
  end;

  Result := -1;
end;

function TLlamaCompletion.ProcessAnyStopGenerate(
  [ref] LData: TCompletionData;
  const AAllText: TBytes;
  var AText: TBytes): Boolean;
var
  I: Integer;
  LAnyStop: TList<TBytes>;
begin
  Result := True;

  LAnyStop := TList<TBytes>.Create;

  try
    for I := 0 to
      Length(LData.StopSequences) - 1 do
    begin
      if ContainsBytes(
        AAllText,
        LData.StopSequences[I]) then
        LAnyStop.Add(
          LData.StopSequences[I]);
    end;

    if LAnyStop.Count > 0 then
    begin
      AText :=
        CopyBytes(
          AAllText,
          LAnyStop[0]);

      LData.FinishReason := 'stop';
      Result := False;
    end;
  finally
    LAnyStop.Free;
  end;
end;

function TLlamaCompletion.ProcessAnyStopStream(
  const AStopSequences: TArray<TBytes>;
  const ARemainingText: TBytes): Integer;
var
  I: Integer;
  LAnyStop: TList<TBytes>;
  LStopIndex: Integer;
begin
  LAnyStop := TList<TBytes>.Create;

  try
    for I := Low(AStopSequences) to
             High(AStopSequences) do
    begin
      if ContainsBytes(
        AStopSequences[I],
        ARemainingText) then
        LAnyStop.Add(
          AStopSequences[I]);
    end;

    if LAnyStop.Count > 0 then
    begin
      Result := Length(ARemainingText);

      for I := 0 to
        LAnyStop.Count - 1 do
      begin
        LStopIndex :=
          IndexOfBytes(
            ARemainingText,
            LAnyStop[I]);

        if (LStopIndex > 0) and
           (LStopIndex < Result) then
          Result := LStopIndex;
      end;
    end
    else
      Result := Length(ARemainingText);
  finally
    LAnyStop.Free;
  end;
end;

function TLlamaCompletion.CheckCompleteBytes(
  const AAllText: TBytes;
  var AMultibyteFix: Integer): Boolean;
var
  I: Integer;
  K: Integer;
  LChar: Byte;
  LNum: Integer;
  LPattern: Integer;
  LAllText: TBytes;
begin
  Result := True;

  { Delphi 10.2 does not support inline local
    variable declarations such as:
      var LAllText := ...
  }
  LAllText :=
    TArrayHelper.Slice<Byte>(
      AAllText,
      -3);

  for I := Low(LAllText) to
           High(LAllText) do
  begin
    if I < 0 then
      Continue;

    LChar := LAllText[I];
    K := 3 - I;

    for LNum := 2 to 4 do
    begin
      case LNum of
        2:
          LPattern := 192;

        3:
          LPattern := 224;

        4:
          LPattern := 240;
      else
        Continue;
      end;

      if (LNum > K) and
         ((LPattern and LChar) =
          LPattern) then
        AMultibyteFix :=
          LNum - K;
    end;
  end;

  if AMultibyteFix > 0 then
  begin
    Dec(AMultibyteFix);
    Result := False;
  end;
end;

function TLlamaCompletion.ProcessStreamLogprob(
  [ref] AData: TCompletionData;
  const ASettings: TLlamaCompletionSettings;
  const AToken: Integer;
  const APrompt: TArray<Integer>): TCompletionLogprobs;
var
  I: Integer;
  LTopLogprob: TDictionary<string, Single>;
  LSortedLogprobs: TArray<TPair<Single, Integer>>;
  LTokenOffset: Integer;
  LTextOffset: Integer;
  LTokenStr: string;
  LLogits: TArray<Single>;
  LCurrentLogprobs: TArray<Single>;
begin
  LTokenStr :=
    FTokenization.Decode([AToken]);

  LTextOffset :=
    Length(APrompt) +
    Length(
      FTokenization.Detokenize(
        TArrayHelper.Slice<Integer>(
          AData.CompletionTokens,
          Low(AData.CompletionTokens),
          AData.ReturnedTokens),
        AData.PromptTokens +
        TArrayHelper.Slice<Integer>(
          AData.CompletionTokens,
          Low(AData.CompletionTokens),
          AData.ReturnedTokens)));

  LTokenOffset :=
    Length(AData.PromptTokens) +
    AData.ReturnedTokens - 1;

  LLogits :=
    TScoresHelper.Scores(
      FLlama.Scores,
      FLlama.NumberOfTokens)
      [LTokenOffset];

  LCurrentLogprobs :=
    TLogits.ToLogprobs(
      [LLogits])[0];

  SetLength(
    LSortedLogprobs,
    Length(LCurrentLogprobs));

  for I :=
    Low(LCurrentLogprobs) to
    High(LCurrentLogprobs) do
  begin
    LSortedLogprobs[I] :=
      TPair<Single, Integer>.Create(
        LCurrentLogprobs[I],
        I);
  end;

  TArray.Sort<TPair<Single, Integer>>(
    LSortedLogprobs,
    TComparer<TPair<Single, Integer>>.Construct(
      function(
        const Left,
        Right: TPair<Single, Integer>): Integer
      begin
        Result :=
          CompareValue(
            Right.Value,
            Left.Value);
      end));

  LTopLogprob :=
    TDictionary<string, Single>.Create;

  try
    for I := 0 to
      Min(
        High(LSortedLogprobs),
        ASettings.Logprobs - 1) do
    begin
      LTopLogprob.AddOrSetValue(
        FTokenization.Decode(
          [LSortedLogprobs[I].Value]),
        LSortedLogprobs[I].Key);
    end;

    LTopLogprob.AddOrSetValue(
      LTokenStr,
      LCurrentLogprobs[AToken]);

    Result :=
      TCompletionLogprobs.Create(
        [LTextOffset],
        [LCurrentLogprobs[AToken]],
        [FTokenization.Decode([AToken])],
        [LTopLogprob.ToArray]);

    Inc(AData.ReturnedTokens);
  finally
    LTopLogprob.Free;
  end;
end;

function TLlamaCompletion.ProcessGenerateStreamLogprob(
  [ref] AData: TCompletionData;
  const ASettings: TLlamaCompletionSettings;
  const AToken: Integer;
  const APrompt: TArray<Integer>): TCompletionLogprobs;
var
  I: Integer;
  LTopLogprob: TDictionary<string, Single>;
  LSortedLogprobs: TArray<TPair<Single, Integer>>;
  LTokenOffset: Integer;
  LTextOffset: Integer;
  LTokenStr: string;
  LLogits: TArray<Single>;
  LCurrentLogprobs: TArray<Single>;
begin
  LTokenStr :=
    FTokenization.Decode(
      [AToken],
      AData.PromptTokens +
      TArrayHelper.Slice<Integer>(
        AData.CompletionTokens,
        Low(AData.CompletionTokens),
        AData.ReturnedTokens));

  LTextOffset :=
    Length(APrompt) +
    Length(
      FTokenization.Detokenize(
        TArrayHelper.Slice<Integer>(
          AData.CompletionTokens,
          Low(AData.CompletionTokens),
          AData.ReturnedTokens),
        AData.PromptTokens +
        TArrayHelper.Slice<Integer>(
          AData.CompletionTokens,
          Low(AData.CompletionTokens),
          AData.ReturnedTokens)));

  LTokenOffset :=
    Length(AData.PromptTokens) +
    AData.ReturnedTokens;

  LLogits :=
    TScoresHelper.Scores(
      FLlama.Scores,
      FLlama.NumberOfTokens)
      [LTokenOffset - 1];

  LCurrentLogprobs :=
    TLogits.ToLogprobs(
      [LLogits])[0];

  SetLength(
    LSortedLogprobs,
    Length(LCurrentLogprobs));

  for I :=
    Low(LCurrentLogprobs) to
    High(LCurrentLogprobs) do
  begin
    LSortedLogprobs[I] :=
      TPair<Single, Integer>.Create(
        LCurrentLogprobs[I],
        I);
  end;

  TArray.Sort<TPair<Single, Integer>>(
    LSortedLogprobs,
    TComparer<TPair<Single, Integer>>.Construct(
      function(
        const Left,
        Right: TPair<Single, Integer>): Integer
      begin
        Result :=
          CompareValue(
            Right.Value,
            Left.Value);
      end));

  LTopLogprob :=
    TDictionary<string, Single>.Create;

  try
    for I := 0 to
      Min(
        High(LSortedLogprobs),
        ASettings.Logprobs - 1) do
    begin
      LTopLogprob.AddOrSetValue(
        FTokenization.Decode(
          [LSortedLogprobs[I].Value]),
        LSortedLogprobs[I].Key);
    end;

    LTopLogprob.AddOrSetValue(
      LTokenStr,
      LCurrentLogprobs[AToken]);

    Result :=
      TCompletionLogprobs.Create(
        [LTextOffset],
        [LCurrentLogprobs[AToken]],
        [
          FTokenization.Decode(
            [AToken],
            AData.PromptTokens +
            TArrayHelper.Slice<Integer>(
              AData.CompletionTokens,
              Low(AData.CompletionTokens),
              AData.ReturnedTokens))
        ],
        [LTopLogprob.ToArray]);

    Inc(AData.ReturnedTokens);
  finally
    LTopLogprob.Free;
  end;
end;

function TLlamaCompletion.ProcessLogprob(
  [ref] AData: TCompletionData;
  const ASettings: TLlamaCompletionSettings;
  const APrompt: TArray<Integer>): TCompletionLogprobs;
var
  I: Integer;
  J: Integer;
  LToken: Integer;
  LTopLogprob: TDictionary<string, Single>;
  LLogprobsToken: TArray<Single>;
  LSortedLogprobs: TArray<TPair<Single, Integer>>;
  LTokenLogprobs: TArray<Single>;
  LTopLobprobs: TArray<TArray<TPair<string, Single>>>;
  LTokens: TArray<string>;
  LTokenOffset: Integer;
  LTextOffset: Integer;
  LTextOffsets: TArray<Integer>;
  LAllTokenStrs: TArray<string>;
  LAllLogprobs: TArray<TArray<Single>>;
  LAllTokens: TArray<Integer>;
  LTokenStr: string;
begin
  LTokenLogprobs := nil;
  LTopLobprobs := nil;
  LTokens := nil;
  LTextOffsets := nil;
  LAllTokenStrs := nil;

  if ASettings.Echo then
  begin
    LTextOffset := 0;
    LTokenOffset := 0;
  end
  else
  begin
    LTextOffset := Length(APrompt);
    LTokenOffset :=
      Length(AData.PromptTokens) - 1;
  end;

  if ASettings.Echo then
  begin
    if AData.PromptTokens[0] =
       FModel.TokenBOS() then
      LAllTokens :=
        TArrayHelper.Slice<Integer>(
          AData.PromptTokens,
          Low(AData.PromptTokens) + 1)
    else
      LAllTokens :=
        TArrayHelper.Slice<Integer>(
          AData.PromptTokens,
          Low(AData.PromptTokens));

    LAllTokens :=
      LAllTokens +
      AData.CompletionTokens;
  end
  else
    LAllTokens :=
      AData.CompletionTokens;

  for I := Low(LAllTokens) to
           High(LAllTokens) do
  begin
    LAllTokenStrs :=
      LAllTokenStrs +
      [
        FTokenization.Decode(
          [LAllTokens[I]],
          TArrayHelper.Slice<Integer>(
            LAllTokens,
            Low(LAllTokens),
            I))
      ];
  end;

  LAllLogprobs :=
    TArrayHelper.Slice<Single>(
      TLogits.ToLogprobs(
        TScoresHelper.Scores(
          FLlama.Scores,
          FLlama.NumberOfTokens)),
      LTokenOffset,
      TInteger.Null,
      1,
      TInteger.Null,
      TInteger.Null,
      1);

  for I := Low(LAllTokens) to
           High(LAllTokens) do
  begin
    LToken := LAllTokens[I];
    LTokenStr := LAllTokenStrs[I];
    LLogprobsToken := LAllLogprobs[I];

    if LToken = FModel.TokenBOS() then
      Continue;

    LTextOffsets :=
      LTextOffsets +
      [
        LTextOffset +
        Length(
          FTokenization.Detokenize(
            TArrayHelper.Slice<Integer>(
              LAllTokens,
              Low(LAllTokens),
              I)))
      ];

    LTokens :=
      LTokens + [LTokenStr];

    SetLength(
      LSortedLogprobs,
      Length(LLogprobsToken));

    for J := 0 to
      High(LLogprobsToken) do
    begin
      LSortedLogprobs[J] :=
        TPair<Single, Integer>.Create(
          LLogprobsToken[J],
          J);
    end;

    TArray.Sort<TPair<Single, Integer>>(
      LSortedLogprobs,
      TComparer<TPair<Single, Integer>>.Construct(
        function(
          const Left,
          Right: TPair<Single, Integer>): Integer
        begin
          Result :=
            CompareValue(
              Right.Value,
              Left.Value);
        end));

    LTokenLogprobs :=
      LTokenLogprobs +
      [LLogprobsToken[LToken]];

    LTopLogprob :=
      TDictionary<string, Single>.Create;

    try
      for J :=
        Low(LSortedLogprobs) to
        Min(
          High(LSortedLogprobs),
          ASettings.Logprobs - 1) do
      begin
        LTopLogprob.AddOrSetValue(
          FTokenization.Decode(
            [LSortedLogprobs[J].Value],
            TArrayHelper.Slice<Integer>(
              LAllTokens,
              Low(LAllTokens),
              I)),
          LSortedLogprobs[J].Key);
      end;

      LTopLogprob.AddOrSetValue(
        LTokenStr,
        LLogprobsToken[LToken]);

      LTopLobprobs :=
        LTopLobprobs +
        [LTopLogprob.ToArray];
    finally
      LTopLogprob.Free;
    end;
  end;

  if ASettings.Echo and
     (Length(LAllTokens) > 0) then
  begin
    LTokenLogprobs[0] := 0;
    LTopLobprobs[0] := nil;
  end;

  Result :=
    TCompletionLogprobs.Create(
      LTextOffsets,
      LTokenLogprobs,
      LTokens,
      LTopLobprobs);
end;

end.
