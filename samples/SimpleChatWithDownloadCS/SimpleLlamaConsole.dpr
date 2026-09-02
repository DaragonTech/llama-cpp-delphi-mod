program SimpleLlamaConsole;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.Math,
  Vcl.Forms, Vcl.StdCtrls, Vcl.Controls, Vcl.ExtCtrls,
  LlamaCpp.Api,
  LlamaCpp.Llama,
  LlamaCpp.Common.Settings,
  LlamaCpp.Common.Chat.Types,
  LlamaCpp.Common.Types,
  Variants,
  GPUUtils;

var
  Llama: TLlama;
  Settings: TLlamaChatCompletionSettings;
  Response: TCreateChatCompletionResponse;
  Messages: TArray<TChatCompletionRequestMessage>;
  ModelPath: string;
  Question: string;

function InputMemo(const ACaption: string): string;
var
  Form: TForm;
  Memo: TMemo;
  BtnOK: TButton;
  BtnCancel: TButton;
  ButtonPanel: TPanel;
begin
  Result := '';

  Form := TForm.Create(nil);
  try
    Form.Caption := ACaption;
    Form.Width := 600;
    Form.Height := 400;
    Form.Position := poScreenCenter;
    Form.BorderStyle := bsSizeable;

    ButtonPanel := TPanel.Create(Form);
    ButtonPanel.Parent := Form;
    ButtonPanel.Align := alBottom;
    ButtonPanel.Height := 45;
    ButtonPanel.BevelOuter := bvNone;

    Memo := TMemo.Create(Form);
    Memo.Parent := Form;
    Memo.Align := alClient;
    Memo.ScrollBars := ssVertical;
    Memo.WordWrap := True;

    BtnOK := TButton.Create(Form);
    BtnOK.Parent := ButtonPanel;
    BtnOK.Caption := 'OK';
    BtnOK.ModalResult := mrOk;
    BtnOK.Default := True;
    BtnOK.Width := 80;
    BtnOK.Height := 28;
    BtnOK.Left := ButtonPanel.Width - 180;
    BtnOK.Top := 8;
    BtnOK.Anchors := [akRight, akBottom];

    BtnCancel := TButton.Create(Form);
    BtnCancel.Parent := ButtonPanel;
    BtnCancel.Caption := 'Cancel';
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Cancel := True;
    BtnCancel.Width := 80;
    BtnCancel.Height := 28;
    BtnCancel.Left := ButtonPanel.Width - 90;
    BtnCancel.Top := 8;
    BtnCancel.Anchors := [akRight, akBottom];

    Form.ActiveControl := Memo;

    if Form.ShowModal = mrOk then
      Result := Memo.Text;
  finally
    Form.Free;
  end;
end;

var
  usecuda : boolean;
  ModelFile: string;
  LibSubdir: string;
  Grammar: ILlamaGrammar;

begin
  try
    UseCUDA := HasVulkanGPU;
    //UseCUDA := HasCudaGPU(TPath.GetDirectoryName(ParamStr(0))+'lib-cuda-cu12.4-x64');

    { Change this to your GGUF model(s) }
    if UseCUDA = true then begin
      LibSubdir := 'lib-cuda-cu12.4-x64';
      ModelFile :=  'DeepSeek-Coder-V2-Lite-Instruct.Q4_K_M.gguf'
    end else begin
      LibSubdir := 'lib';
      ModelFile :=  'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    end;

    SetExceptionMask([
      exInvalidOp,
      exDenormalized,
      exZeroDivide,
      exOverflow,
      exUnderflow,
      exPrecision
    ]);
    { Change this to the directory containing llama.dll }
    TLlamaCppApis.LoadAll(
      TPath.Combine(
        TPath.GetDirectoryName(ParamStr(0)),
        LibSubdir));

    try
      ModelPath :=
        TPath.Combine(
          TPath.GetDirectoryName(ParamStr(0))+'\models\',
          ModelFile);

      Llama := TLlama.Create(nil);
      try
        Llama.ModelPath := ModelPath;

        { TinyLlama uses the Zephyr chat format }
        if UseCUDA = true then begin
          Llama.Settings.NGpuLayers := 99;
          Llama.Settings.ChatFormat := 'deepseek';
        end else begin
          Llama.Settings.NGpuLayers := 0; // use cpu
          Llama.Settings.ChatFormat := 'zephyr';
        end;

        { Context size }
        Llama.Settings.NCtx := 2048;

        //Grammar := TLlamaGrammar.FromString('YOUR GRAMMAR'); // Optional

        Writeln('Loading model...');
        Llama.Init;

        Writeln('Ready.');
        Writeln;

        while True do
        begin
          Write('You: ');
          Question := InputMemo('Enter prompt');

          if trim(Question) = '' then
          Break;

          Writeln(Question);

          if SameText(Question, 'exit') then
            Break;

          Messages := [
            TChatCompletionRequestMessage.System(
              'You are a helpful assistant.'),
            TChatCompletionRequestMessage.User(
              Question)
          ];

          Settings :=
            TLlamaChatCompletionSettings.Create(
              Messages);

          Response :=
            Llama.CreateChatCompletion(
              Settings);

              {
          Response :=
            Llama.CreateChatCompletion(
              Settings, nil, nil, grammar); }

          Writeln;
          Writeln(
            'AI: ',
            VarToStr(
              Response.Choices[0].Message.Content));
          Writeln;
        end;

      finally
        Llama.Free;
      end;

    finally
      TLlamaCppApis.UnloadAll;
    end;

  except
    on E: Exception do
    begin
      Writeln(
        E.ClassName,
        ': ',
        E.Message);

      Readln;
    end;
  end;
end.