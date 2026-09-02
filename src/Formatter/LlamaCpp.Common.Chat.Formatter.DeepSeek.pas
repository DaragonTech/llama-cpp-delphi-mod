unit LlamaCpp.Common.Chat.Formatter.DeepSeek;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  LlamaCpp.Common.Types,
  LlamaCpp.Common.Settings,
  LlamaCpp.Common.Chat.Types,
  LlamaCpp.Common.Chat.Format;

type
  // Formatter for DeepSeek-Coder-V2 / DeepSeek-V2 style instruct models.
  // Prompt shape (as embedded in the model's tokenizer_config.json chat_template):
  //
  //   {system_prompt}
  //
  //   User: {message}
  //
  //   Assistant: {message}<|end_of_sentence|>
  //
  //   ... repeated ...
  //
  //   User: {message}
  //
  //   Assistant:
  //
  // NOTE: The literal begin-of-sentence token is intentionally NOT written into
  // the prompt text here — it's left to the tokenizer's default add-bos
  // behavior, same as TVicunaChatFormatter does for <s>.
  TDeepSeekChatFormatter = class(TInterfacedObject, ILlamaChatFormater)
  private
    function Format(const ASettings: TLlamaChatCompletionSettings)
    : TChatFormatterResponse;
  end;

implementation

{ TDeepSeekChatFormatter }

function TDeepSeekChatFormatter.Format(
  const ASettings: TLlamaChatCompletionSettings): TChatFormatterResponse;
var
  LRoles: TDictionary<string, string>;
  LSystemMessage: string;
  LSeparator: string;
  LSeparator2: string;
  LMessages: TArray<TPair<string, string>>;
  LPrompt: string;
begin
  LRoles := TDictionary<string, string>.Create();
  try
    LSystemMessage := 'You are an AI programming assistant, utilizing the DeepSeek Coder model, ' +
      'developed by DeepSeek Company, and you only answer questions related to computer science. ' +
      'For politically sensitive questions, security and privacy issues, and other non-computer ' +
      'science questions, you will refuse to answer.';

    LRoles.Add('user', 'User');
    LRoles.Add('assistant', 'Assistant');

    // Blank line between turns, matching the model's own chat_template.
    LSeparator := #10#10;
    // Assistant turns are closed with the model's actual EOS marker.
    // Built from explicit codepoints ($FF5C = fullwidth vertical line,
    // $2581 = SentencePiece meta-space) instead of literal glyphs, so this
    // string can't be silently corrupted if the .pas file is ever saved
    // or reopened with a non-UTF8 encoding.
    LSeparator2 := #10#10 + '<' + Chr($FF5C) + 'end' + Chr($2581) + 'of' +
      Chr($2581) + 'sentence' + Chr($FF5C) + '>';

    LMessages := TLlamaChatFormat.MapRoles(ASettings.Messages, LRoles);
    LMessages := LMessages + [
      TPair<string, string>.Create(LRoles['assistant'], '')];

    LPrompt := TLlamaChatFormat.FormatAddColonTwo(LSystemMessage, LMessages, LSeparator, LSeparator2);

    Result := TChatFormatterResponse.Create(LPrompt);
  finally
    LRoles.Free();
  end;
end;

end.
