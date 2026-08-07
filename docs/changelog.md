# Recent Changes Since Last Docs Update

This document summarizes compiler and language changes made since the previous documentation refresh (2026-07-25).

## Language

- Added `extern func name(params) returnType;` — declares a function with no Midnight body, implemented outside the language (currently the bundled C runtime under `runtime/`). Parsed via `isExtern` on the shared `parseFunctionDecl` path; semantic analysis registers extern functions as ordinary callable symbols and skips body analysis.
- Added `import "path";` — resolves a dotted module path (`std.io.file`) or relative source path against the standard library root or the importing file's directory, and brings the target module's top-level functions, structs, and variables into scope.
- Fixed a string-comparison bug (`==`/`!=` over `string` values).

## Module Resolution

- Added `src/module/module_resolver.zig` (`ModuleResolver`), which walks `import` statements, resolves and parses each target module, and detects circular imports.
- Added `src/module/module_compiler.zig` (`ModuleCompiler`), which compiles each resolved module into its own object file (LLVM backend) and synthesizes the `extern` declarations the entry file's IR needs to call across module boundaries.
- Wired module resolution and compilation into `pipeline.compileSource` — this is no longer unwired, in-progress infrastructure. The entry file and every transitively imported module are now analyzed together into one shared top-level semantic scope.
- The x86_64 backend does not yet drive `ModuleCompiler`; module object compilation is LLVM-only for now.

## Standard Library

- Added `src/std/io/file.mn` (`File` struct) and `src/std/io/input.mn` (`Input` struct), both built on `extern` bindings into the C runtime.
- Added sample programs demonstrating standard library usage: `src/data/test4.mn`, `src/data/test5.mn`.

## CLI

- Added a `--std-lib <path>` flag to `run`/`build` (parsed, but not yet forwarded into the compile pipeline — see [Roadmap](./roadmap.md)).

## Build and Platform Support

- Added Windows support: `build.zig` auto-detects LLVM under common MSYS2/UCRT64 locations before falling back to `-Dllvm-root`, instead of panicking outright.
- Added a release workflow (`.github/workflows/release.yml`) that builds Linux and Windows x86_64 binaries on tagged GitHub Releases, bundling the LLVM shared library/DLL alongside the binary.
- Tagged `v0.1.0-alpha.2`.

## Lexer

- Added dedicated `LexerError` values (`UnknownCharacter`, `UnterminatedString`) instead of falling through to an EOF token on invalid input or an unterminated string.

## Tests

- Added regression coverage for the array, expression-statement, and member-access-assignment behavior introduced in the prior update cycle, plus coverage growth alongside the extern/import/module work above.

## Notes

- Struct method receiver semantics are still limited — this remains a known gap, not new breakage.
- Array indexing is still not fully wired end-to-end; treat it as a planned extension, not a regression.
