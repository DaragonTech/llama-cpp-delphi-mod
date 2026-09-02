# llama-cpp-delphi Mod

> **Delphi meets local AI. No cloud. No ceremony. Just code.**

This is a fork of **llama-cpp-delphi**, modified by **DaragonTech** with
a focus on simplicity, compatibility, and getting local LLMs running
inside Delphi without unnecessary friction.

A few things have changed from upstream.

## KEEP IT SIMPLE

The original VCL demos have been replaced with **two CLI utilities**.

Personally, I found the original GUI samples a little too complex for
developers who just want to experiment with local AI, understand how the
library works, and start coding.

The CLI examples keep the path from **zero to inference** short.

## KEEP IT SIMPLE --- PART 2

No Delphi package to install.

No component to drop onto a form.

Just add:

``` text
src
src/Formatter
```

to your Delphi search path and start coding.

Some may consider this a regression. Personally, I don't.

## DEEPSEEK SUPPORT

A **DeepSeek formatter** has been added, allowing DeepSeek models to be
used through the library.

## GPUUTILS

A new `GPUUtils` unit provides convenient GPU detection functionality.

Use it to determine whether a supported GPU/backend is available before
deciding how your model should run.

## DELPHI 10 SUPPORT

Still running an older Delphi toolchain?

No problem.

This fork includes changes to maintain **Delphi 10 compatibility**, making it possible to compile the project without requiring the latest Delphi release.

Legacy compiler. Modern AI.

## CREATECHATCOMPLETION FIX

A fix for `CreateChatCompletion` has been integrated.

Credit goes to **@Krekeler** for the fix!

## UPSTREAM README

Want the full details about the original **llama-cpp-delphi** project?

The original, pre-fork README is preserved as: `README.original.md`

## BINARIES

Get the compatible Llama binaries from https://github.com/Embarcadero/llama-cpp-delphi/releases/tag/main-b3-d4ec316

Place the unziped libraries within the `lib` subdirectory within the path were your compiled executable is located.

The demo SimpleLlamaConsole.dpr from its first lines expects the files from https://github.com/Embarcadero/llama-cpp-delphi/tree/main/samples/SimpleChatWithDownload/lib/windows_x64 within `/lib/` and the files from lib-cuda-cu12.4-x64 within the `/lib-cuda-cu12.4-x64` subdirectory.

## LICENSE

This project is licensed under the **MIT License**.

See: `LICENSE` for details.

------------------------------------------------------------------------

**llama.cpp + Delphi // local inference // your machine // your rules**