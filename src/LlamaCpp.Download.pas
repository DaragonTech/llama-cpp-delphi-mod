unit LlamaCpp.Download;

interface

uses
  System.SysUtils,
  System.Classes;

type
  TWriteData = procedure(
    Sender: TObject;
    const AText: string) of object;

  THuggingFace = class(TPersistent)
  private
    FUserName: string;
    FToken: string;

  public
    function BuildUrl(
      const AUri: string): string;

  published
    property UserName: string
      read FUserName
      write FUserName;

    property Token: string
      read FToken
      write FToken;
  end;

  TLlamaDownload = class(TComponent)
  public
    class var Default: TLlamaDownload;

  private
    FRoot: string;
    FOnWriteData: TWriteData;
    FHuggingFace: THuggingFace;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    class constructor Create;
    class destructor Destroy;

    function Download(
      const AUrl: string;
      const ARepoName: string;
      const ABranch: string = '';
      const AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// llama-2-7b-chat.Q4_K_M.gguf
    /// Size: 4.08 GB
    /// Max RAM/VRAM required: 6.58 GB
    /// </summary>
    function DownloadLlama2_Chat_7B(
      AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// llama-30b.Q4_K_M.gguf
    /// Size: 4.92 GB
    /// </summary>
    function DownloadLlama3_Chat_30B(
      AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// moxin-alpaca-chat-7b.Q4_K_M.gguf
    /// Size: 4.89 GB
    /// </summary>
    function DownloadAlpaca_Chat_7B(
      AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// qwen1_5-7b-chat-q4_k_m.gguf
    /// Size: 4.77 GB
    /// </summary>
    function DownloadQwen_Chat_7B(
      AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// Featherlite-Vicuna-13B-chat.Q4_K_M.gguf
    /// Size: 7.87 GB
    /// </summary>
    function DownloadVicuna_Chat_13B(
      AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// mistrallite.Q4_K_M.gguf
    /// Size: 4.37 GB
    /// Max RAM/VRAM required: 6.87 GB
    /// </summary>
    function DownloadMistrallite_7B(
      AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// FsfairX-Zephyr-Chat-v0.1.Q4_K_M.gguf
    /// Size: 4.37 GB
    /// </summary>
    function DownloadZephyr_Chat(
      AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// model-q4_K.gguf
    /// Size: 4.37 GB
    /// </summary>
    function DownloadSaiga_7B(
      AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// Gemma-The-Writer-Mighty-Sword-9B-D_AU-Q4_k_m.gguf
    /// Size: 5.64 GB
    /// </summary>
    function DownloadGemma_9B(
      AFiles: TArray<string> = nil):
      TArray<string>;

    /// <summary>
    /// Default model:
    /// tinyllama-1.1b-chat-v1.0.Q4_K_S.gguf
    /// Size: 644 MB
    /// </summary>
    function DownloadTinyLlama_1_1B(
      AFiles: TArray<string> = nil):
      TArray<string>;

  published
    property Root: string
      read FRoot
      write FRoot;

    property HuggingFace: THuggingFace
      read FHuggingFace;

    property OnWriteData: TWriteData
      read FOnWriteData
      write FOnWriteData;
  end;

implementation

uses
  {$IFDEF MSWINDOWS}
  Windows,
  {$ENDIF MSWINDOWS}

  {$IFDEF POSIX}
  Posix.Base,
  Posix.Fcntl,
  {$ENDIF POSIX}

  System.IOUtils;

type
  TStreamHandle = Pointer;

{$IFDEF MSWINDOWS}

procedure RunGitCommand(
  const AGitCommand: string;
  const AWorkingDirectory: string;
  const AWriteCallback: TProc<string>);
var
  LStartupInfo: TStartupInfo;
  LProcessInfo: TProcessInformation;
  LSecurityAttributes: TSecurityAttributes;
  LReadPipe: THandle;
  LWritePipe: THandle;
  LBuffer: TBytes;
  LBytesRead: Cardinal;
  LCmd: string;
begin
  FillChar(
    LSecurityAttributes,
    SizeOf(LSecurityAttributes),
    0);

  LSecurityAttributes.nLength :=
    SizeOf(LSecurityAttributes);

  LSecurityAttributes.bInheritHandle :=
    True;

  if not CreatePipe(
    LReadPipe,
    LWritePipe,
    @LSecurityAttributes,
    0) then
  begin
    raise Exception.Create(
      'Failed to create pipe');
  end;

  try
    if not SetHandleInformation(
      LReadPipe,
      HANDLE_FLAG_INHERIT,
      0) then
    begin
      raise Exception.Create(
        'Failed to set handle information');
    end;

    FillChar(
      LStartupInfo,
      SizeOf(LStartupInfo),
      0);

    LStartupInfo.cb :=
      SizeOf(LStartupInfo);

    LStartupInfo.hStdOutput :=
      LWritePipe;

    LStartupInfo.hStdError :=
      LWritePipe;

    LStartupInfo.dwFlags :=
      STARTF_USESTDHANDLES or
      STARTF_USESHOWWINDOW;

    LStartupInfo.wShowWindow :=
      SW_HIDE;

    FillChar(
      LProcessInfo,
      SizeOf(LProcessInfo),
      0);

    LCmd :=
      'cmd.exe /C "' +
      AGitCommand +
      '"';

    UniqueString(LCmd);

    SetEnvironmentVariable(
      'GIT_LFS_SKIP_SMUDGE',
      '1');

    if not CreateProcess(
      nil,
      PChar(LCmd),
      nil,
      nil,
      True,
      0,
      nil,
      PChar(AWorkingDirectory),
      LStartupInfo,
      LProcessInfo) then
    begin
      raise Exception.Create(
        'Failed to execute Git command');
    end;

    CloseHandle(LWritePipe);

    {
      Important: after closing it here, reset it to zero
      so we do not accidentally close the same handle twice.
    }
    LWritePipe := 0;

    try
      SetLength(
        LBuffer,
        4096);

      while True do
      begin
        if not ReadFile(
          LReadPipe,
          LBuffer[0],
          Length(LBuffer),
          LBytesRead,
          nil) then
          Break;

        if LBytesRead = 0 then
          Break;

        if Assigned(AWriteCallback) then
        begin
          AWriteCallback(
            TEncoding.UTF8.GetString(
              LBuffer,
              0,
              Integer(LBytesRead)));
        end;
      end;

    finally
      WaitForSingleObject(
        LProcessInfo.hProcess,
        INFINITE);

      CloseHandle(
        LProcessInfo.hProcess);

      CloseHandle(
        LProcessInfo.hThread);
    end;

  finally
    if LWritePipe <> 0 then
      CloseHandle(LWritePipe);

    CloseHandle(LReadPipe);
  end;
end;

{$ENDIF MSWINDOWS}

{$IFDEF POSIX}

function popen(
  const command: MarshaledAString;
  const _type: MarshaledAString):
  TStreamHandle;
  cdecl;
  external libc name _PU + 'popen';

function pclose(
  filehandle: TStreamHandle):
  Int32;
  cdecl;
  external libc name _PU + 'pclose';

function fgets(
  buffer: Pointer;
  size: Int32;
  Stream: TStreamHandle):
  Pointer;
  cdecl;
  external libc name _PU + 'fgets';

function BufferToString(
  const ABuffer: Pointer;
  AMaxSize: UInt32): string;
var
  LCursor: ^UInt8;
  LEndOfBuffer: NativeUInt;
begin
  Result := '';

  if not Assigned(ABuffer) then
    Exit;

  LCursor :=
    ABuffer;

  LEndOfBuffer :=
    NativeUInt(LCursor) +
    AMaxSize;

  while
    (NativeUInt(LCursor) < LEndOfBuffer) and
    (LCursor^ <> 0) do
  begin
    Result :=
      Result +
      Chr(LCursor^);

    LCursor :=
      Pointer(
        Succ(
          NativeUInt(LCursor)));
  end;
end;

procedure RunGitCommand(
  const AGitCommand: string;
  const AWorkingDirectory: string;
  const AWriteCallback: TProc<string>);
var
  LHandle: TStreamHandle;
  LData: array[0..511] of UInt8;
  LMarshaller: TMarshaller;
  LDir: string;
begin
  {
    Delphi 10.2 does not support:

      var LDir := ...

    Declare it normally above instead.
  }
  LDir :=
    TDirectory.GetCurrentDirectory;

  try
    TDirectory.SetCurrentDirectory(
      AWorkingDirectory);

    try
      LHandle :=
        popen(
          LMarshaller.AsAnsi(
            'GIT_LFS_SKIP_SMUDGE=1 ' +
            AGitCommand).ToPointer,
          'r');

      try
        while
          fgets(
            @LData[0],
            SizeOf(LData),
            LHandle) <> nil do
        begin
          if Assigned(AWriteCallback) then
          begin
            AWriteCallback(
              BufferToString(
                @LData[0],
                SizeOf(LData)));
          end;
        end;

      finally
        pclose(LHandle);
      end;

    except
      on E: Exception do
      begin
        Writeln(
          E.ClassName,
          ': ',
          E.Message);
      end;
    end;

  finally
    TDirectory.SetCurrentDirectory(
      LDir);
  end;
end;

{$ENDIF POSIX}

{ TLlamaDownload }

constructor TLlamaDownload.Create(
  AOwner: TComponent);
begin
  inherited Create(AOwner);

  if not (csDesigning in ComponentState) then
    FRoot :=
      TPath.GetDownloadsPath;

  FHuggingFace :=
    THuggingFace.Create;
end;

destructor TLlamaDownload.Destroy;
begin
  FHuggingFace.Free;

  inherited;
end;

class constructor TLlamaDownload.Create;
begin
  Default :=
    TLlamaDownload.Create(nil);
end;

class destructor TLlamaDownload.Destroy;
begin
  Default.Free;
end;

function TLlamaDownload.Download(
  const AUrl,
  ARepoName: string;
  const ABranch: string;
  const AFiles: TArray<string>):
  TArray<string>;
const
  GIT_LFS_INSTALL =
    'git lfs install';

  GIT_CLONE_POINTERS_TEMPLATE =
    'git clone %s';

  GIT_CHECKOUT_BRANCH_TEMPLATE =
    'git checkout %s';

  GIT_FETCH_POINTERS_TEMPLATE =
    'git lfs fetch --include="%s"';

  GIT_LFS_CHECKOUT_TEMPLATE =
    'git lfs checkout %s';

var
  LModelsPath: string;
  LRepoFolder: string;
  LFile: string;
  LWriteCallback: TProc<string>;
begin
  LModelsPath :=
    TPath.Combine(
      Root,
      'LlamaCppDelphi');

  LRepoFolder :=
    TPath.Combine(
      LModelsPath,
      ARepoName);

  if not TDirectory.Exists(LModelsPath) then
    TDirectory.CreateDirectory(
      LModelsPath);

  LWriteCallback := nil;

  if Assigned(FOnWriteData) then
  begin
    LWriteCallback :=
      procedure(AData: string)
      begin
        FOnWriteData(
          Self,
          AData);
      end;
  end;

  // Clone large-file pointers only
  RunGitCommand(
    GIT_LFS_INSTALL,
    LModelsPath,
    LWriteCallback);

  RunGitCommand(
    Format(
      GIT_CLONE_POINTERS_TEMPLATE,
      [AUrl]),
    LModelsPath,
    LWriteCallback);

  if not TDirectory.Exists(LRepoFolder) then
  begin
    raise Exception.Create(
      'Repository folder not found.');
  end;

  // Checkout branch
  if Trim(ABranch) <> '' then
  begin
    RunGitCommand(
      Format(
        GIT_CHECKOUT_BRANCH_TEMPLATE,
        [ABranch]),
      LRepoFolder,
      LWriteCallback);
  end;

  // Fetch user-required pointer files
  RunGitCommand(
    Format(
      GIT_FETCH_POINTERS_TEMPLATE,
      [String.Join(', ', AFiles)]),
    LRepoFolder,
    LWriteCallback);

  Result := nil;

  for LFile in AFiles do
  begin
    if not TFile.Exists(
      TPath.Combine(
        LRepoFolder,
        LFile)) then
      Continue;

    RunGitCommand(
      Format(
        GIT_LFS_CHECKOUT_TEMPLATE,
        [LFile]),
      LRepoFolder,
      LWriteCallback);

    Result :=
      Result +
      [
        TPath.Combine(
          LRepoFolder,
          LFile)
      ];
  end;

  if Length(Result) = 0 then
    Result := [LRepoFolder];
end;

function TLlamaDownload.DownloadLlama2_Chat_7B(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['llama-2-7b-chat.Q4_K_M.gguf'];

  Result :=
    Download(
      'https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF',
      'Llama-2-7B-Chat-GGUF',
      '',
      AFiles);
end;

function TLlamaDownload.DownloadLlama3_Chat_30B(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['Meta-Llama-3-8B-Instruct.Q4_K_M.gguf'];

  Result :=
    Download(
      'https://huggingface.co/QuantFactory/Meta-Llama-3-8B-Instruct-GGUF',
      'Meta-Llama-3-8B-Instruct-GGUF',
      '',
      AFiles);
end;

function TLlamaDownload.DownloadAlpaca_Chat_7B(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['moxin-alpaca-chat-7b.Q4_K_M.gguf'];

  Result :=
    Download(
      'https://huggingface.co/mradermacher/moxin-alpaca-chat-7b-GGUF',
      'moxin-alpaca-chat-7b-GGUF',
      '',
      AFiles);
end;

function TLlamaDownload.DownloadQwen_Chat_7B(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['qwen1_5-7b-chat-q4_k_m.gguf'];

  Result :=
    Download(
      'https://huggingface.co/Qwen/Qwen1.5-7B-Chat-GGUF',
      'Qwen1.5-7B-Chat-GGUF',
      '',
      AFiles);
end;

function TLlamaDownload.DownloadVicuna_Chat_13B(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['Featherlite-Vicuna-13B-chat.Q4_K_M.gguf'];

  Result :=
    Download(
      'https://huggingface.co/mradermacher/Featherlite-Vicuna-13B-chat-GGUF',
      'Featherlite-Vicuna-13B-chat-GGUF',
      '',
      AFiles);
end;

function TLlamaDownload.DownloadMistrallite_7B(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['mistrallite.Q4_K_M.gguf'];

  Result :=
    Download(
      'https://huggingface.co/TheBloke/MistralLite-7B-GGUF',
      'MistralLite-7B-GGUF',
      '',
      AFiles);
end;

function TLlamaDownload.DownloadZephyr_Chat(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['FsfairX-Zephyr-Chat-v0.1.Q4_K_M.gguf'];

  Result :=
    Download(
      'https://huggingface.co/mradermacher/FsfairX-Zephyr-Chat-v0.1-GGUF',
      'FsfairX-Zephyr-Chat-v0.1-GGUF',
      '',
      AFiles);
end;

function TLlamaDownload.DownloadSaiga_7B(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['model-q4_K.gguf'];

  Result :=
    Download(
      'https://huggingface.co/IlyaGusev/saiga_mistral_7b_gguf',
      'saiga_mistral_7b_gguf',
      '',
      AFiles);
end;

function TLlamaDownload.DownloadGemma_9B(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['Gemma-The-Writer-Mighty-Sword-9B-D_AU-Q4_k_m.gguf'];

  Result :=
    Download(
      FHuggingFace.BuildUrl(
        'DavidAU/Gemma-The-Writer-Mighty-Sword-9B-GGUF'),
      'Gemma-The-Writer-Mighty-Sword-9B-GGUF',
      '',
      AFiles);
end;

function TLlamaDownload.DownloadTinyLlama_1_1B(
  AFiles: TArray<string>):
  TArray<string>;
begin
  if Length(AFiles) = 0 then
    AFiles :=
      ['tinyllama-1.1b-chat-v1.0.Q4_K_S.gguf'];

  Result :=
    Download(
      FHuggingFace.BuildUrl(
        'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF'),
      'TinyLlama-1.1B-Chat-v1.0-GGUF',
      '',
      AFiles);
end;

{ THuggingFace }

function THuggingFace.BuildUrl(
  const AUri: string): string;
var
  LAuth: string;
begin
  {
    Delphi 10.2 does not support:

      var LAuth := String.Empty;
  }
  LAuth := '';

  if (FUserName <> '') and
     (FToken <> '') then
  begin
    LAuth :=
      Format(
        '%s:%s@',
        [
          FUserName,
          FToken
        ]);
  end;

  Result :=
    Format(
      'https://%shuggingface.co/%s',
      [
        LAuth,
        AUri
      ]);
end;

end.
