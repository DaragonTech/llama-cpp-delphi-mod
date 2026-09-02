program LlamaModelDownloader;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  LlamaCpp.Download;

procedure ShowModels;
begin
  Writeln('Available models:');
  Writeln;
  Writeln('  tinyllama     TinyLlama 1.1B Chat');
  Writeln('  llama2        Llama 2 7B Chat');
  Writeln('  llama3        Llama 3 8B Instruct');
  Writeln('  alpaca        Moxin Alpaca Chat 7B');
  Writeln('  qwen          Qwen 1.5 7B Chat');
  Writeln('  vicuna        Featherlite Vicuna 13B Chat');
  Writeln('  mistrallite   MistralLite 7B');
  Writeln('  zephyr        Zephyr Chat');
  Writeln('  saiga         Saiga 7B');
  Writeln('  gemma         Gemma Writer 9B');
  Writeln;
  Writeln('Usage:');
  Writeln('  ', ExtractFileName(ParamStr(0)), ' <model>');
  Writeln;
  Writeln('Example:');
  Writeln('  ', ExtractFileName(ParamStr(0)), ' tinyllama');
end;

procedure DownloadModel(const AName: string);
var
  Downloader: TLlamaDownload;
  Files: TArray<string>;
  I: Integer;
begin
  Downloader := TLlamaDownload.Create(nil);
  try
    if SameText(AName, 'tinyllama') then
      Files := Downloader.DownloadTinyLlama_1_1B

    else if SameText(AName, 'llama2') then
      Files := Downloader.DownloadLlama2_Chat_7B

    else if SameText(AName, 'llama3') then
      Files := Downloader.DownloadLlama3_Chat_30B

    else if SameText(AName, 'alpaca') then
      Files := Downloader.DownloadAlpaca_Chat_7B

    else if SameText(AName, 'qwen') then
      Files := Downloader.DownloadQwen_Chat_7B

    else if SameText(AName, 'vicuna') then
      Files := Downloader.DownloadVicuna_Chat_13B

    else if SameText(AName, 'mistrallite') then
      Files := Downloader.DownloadMistrallite_7B

    else if SameText(AName, 'zephyr') then
      Files := Downloader.DownloadZephyr_Chat

    else if SameText(AName, 'saiga') then
      Files := Downloader.DownloadSaiga_7B

    else if SameText(AName, 'gemma') then
      Files := Downloader.DownloadGemma_9B

    else
    begin
      Writeln('Unknown model: ', AName);
      Writeln;
      ShowModels;
      Exit;
    end;

    Writeln('Download completed.');
    Writeln;

    for I := Low(Files) to High(Files) do
      Writeln(Files[I]);

  finally
    Downloader.Free;
  end;
end;

begin
  try
    if ParamCount = 0 then
    begin
      ShowModels;
      Exit;
    end;

    DownloadModel(ParamStr(1));

  except
    on E: Exception do
    begin
      Writeln('Error: ', E.Message);
      Halt(1);
    end;
  end;
end.