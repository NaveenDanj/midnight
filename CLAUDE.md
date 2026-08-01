# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Midnight is an experimental systems programming language and compiler written in Zig (`0.15.2`+). The codebase implements a full source-to-executable pipeline: lexer → parser → semantic analyzer → IR lowering → backend emission (LLVM or x86_64) → link → optional run. It is early-stage; language surface and diagnostics are still evolving (see "Known Gaps" below).

## Build, Run, Test

Requires Zig `0.15.2` (or compatible `0.15.x`) and LLVM dev tools available via `llvm-config` (non-Windows) or `-Dllvm-root=<path>` (Windows, since `llvm-config` isn't available there).

```bash
zig build                     # build the `midnight` executable
zig build run -- run <file.mn>          # compile and run a .mn program
zig build run -- build <file.mn> -o <output>  # compile without running
zig build test                # run all tests (mod tests + exe tests + src/test_runner.zig suite)
```

CLI flags accepted after `--`:

```text
--backend llvm|x86_64   (default: llvm)
--emit-ir
--emit-asm
--emit-llvm-ir
-o, --output <path>
```

LLVM linking on Windows requires passing `-Dllvm-root=<path to LLVM install>` to `zig build` (the build panics otherwise, since `llvm-config` isn't invoked on Windows). Optional `-Dllvm-lib-name=<name>` overrides the linked library name (defaults to `LLVM-C` on Windows, `LLVM-21` elsewhere).

If the repo lives on a mounted `vfat` drive, pass explicit cache/prefix dirs to avoid `AccessDenied`:

```bash
zig build run --cache-dir /tmp/midnight-zig-cache --global-cache-dir /tmp/midnight-zig-global-cache --prefix /tmp/midnight-zig-out -- run src/data/test3.mn
```

### Running a single test

There is no built-in single-test filter wired into `build.zig`. All Zig `test` blocks are aggregated via `src/test_runner.zig`, which imports each file under `src/tests/`. To add coverage for new work, add `test "..."` blocks to an existing (or new) file in `src/tests/` and register new files in `src/test_runner.zig`. `zig build test` runs three suites in parallel: tests in the `midnight` module (`src/root.zig`), tests in the exe root module (`src/main.zig`), and the aggregate suite in `src/test_runner.zig`.

## Architecture

### Pipeline entrypoint

`src/compiler/pipeline.zig` (`compileFile` / `compileSource`) is the central orchestration point: it runs lexer → parser → semantic analyzer → IR lowering, then conditionally emits assembly/LLVM IR, links, and runs, based on `CompileOptions`. Read this file first when tracing how a `.mn` file becomes an executable — most other layers exist because this pipeline calls into them.

`src/main.zig` → `src/cli/commands.zig` (arg parsing) → `src/cli/handle_commands.zig` (dispatch) → `src/cli/compiler_options.zig` (translates CLI options to `pipeline.CompileOptions`) → `pipeline.compileFile`.

### Layered structure

Each layer only depends on layers before it in this list; the AST (`src/ast/`) is the shared data model that parser, semantic analysis, and IR lowering all consume:

- **Lexer** (`src/lexer/`): `lexer.zig`, `tokens.zig`, `keywords.zig`.
- **Parser** (`src/parser/`, driven by `src/compiler/parser.zig`): recursive-descent parser split by construct under `src/parser/lib/` (`parseStatement.zig`, `parseExpr.zig`, `parseFunctionDecl.zig`, `parseVarDec.zig`, `parseStruct.zig`, `parseIf.zig`, `parseWhile.zig`, `parseBlock.zig`, `parseArray.zig`, `parseTypeRef.zig`, `parseImport.zig`, `parsePrint.zig`, `operator.zig` for precedence). Produces AST nodes defined in `src/ast/` (`expr.zig`, `stmt.zig`, `type_ref.zig`).
- **Semantic analysis** (`src/semantic/`): `anaylzer.zig` (entrypoint `SemanticAnalyzer`) walks the AST using `scope.zig`/`symbol.zig` for scoping, `type_resolver.zig`/`type_compatibility.zig`/`types.zig` for type checking, and per-construct checkers (`function_checker.zig`, `assignment_checker.zig`, `struct_checker.zig`, `expr_type_checker.zig`). Errors are Zig error sets defined in `semantic_error.zig`; results collected in `result.zig`. IR lowering consumes `semanticAnalyzer.result` for resolved type info.
- **IR** (`src/ir/`): `ir.zig` defines the `Instruction` model; `builder.zig` (`InstructionBuilder`) assigns temps/labels; `lower.zig` (`generateIRWithSemantics`) drives lowering, delegating per-construct to `src/ir/lib/` (`lowerExpr.zig`, `lowerFlowControl.zig`, `lowerFunction.zig`, `lowerStruct.zig`, `lowerVar.zig`).
- **Backends** (`src/backend/`): two independent codegen paths consume the same `[]Instruction` slice.
  - `backend/llvm/`: `llvm_backend.zig` is the entrypoint (`emitLLVMAssembly`, `emitLLVMIR`, `emitLLVMObject`); `llvm_context.zig` and `llvm_type_mapper.zig` hold shared state/type mapping; `llvm_emitter.zig` dispatches to per-construct emitters under `backend/llvm/lib/` (`function_emitter.zig`, `bin_op_emitter.zig`, `arr_emitter.zig`, `struct_emitter.zig`, `print_emitter.zig`, `unary_op.zig`, `predicates.zig`). Bindings to the LLVM C API live in `src/llvm.zig`.
  - `backend/x86_64/x86_64_backend.zig`: emits assembly directly, using `backend/asm_builder.zig`.
  - `backend/toolchain.zig`: assembles/links/runs produced artifacts for both backends (`assembleAndLink`, `linkObject`, `runArtifact`).
- **Module resolution** (`src/module/module_resolver.zig`): resolves `import` statements into `Module`s (functions/structs/variables), with circular-dependency detection. This is newly added and not yet wired into `pipeline.compileSource` (see the "handle module resolution for import statements" comment there) — treat it as in-progress infrastructure, not a finished feature.

### Runtime

`runtime/` contains prebuilt C object files (`string.o`, `file.o`, `input.o`) linked into Midnight-compiled executables for functionality that can't reasonably be implemented in Midnight itself (memory, I/O, OS interaction). Per `CONTRIBUTING.md`, don't reimplement language-level features in the C runtime.

### Error handling convention

There are no structured diagnostic objects yet — all errors (parser, semantic, backend) are plain Zig error sets (`src/parser/error.zig`, `src/semantic/semantic_error.zig`) that bubble up as Zig errors with stack traces. There's no source-span/caret diagnostic printer yet; keep this in mind when working on error paths — precise, user-facing compiler diagnostics are a known gap, not a regression to fix incidentally.

## Language Surface (current)

`var`/`const` declarations, typed functions with returns, `if`/`else`, `while`, assignments, function calls, primitives (`int`, `float`, `bool`, `string`, `void`), unary (`-`, `!`) and binary operators, structs (fields + methods, initialization, member access/assignment), array literals/type syntax, `print`. Sample `.mn` programs live in `src/data/`. Full spec: `docs/language-spec.md`; more examples: `docs/examples.md`.

## Known Gaps (don't treat as bugs to silently "fix" without checking docs/roadmap.md)

- Array indexing/element assignment exist in the IR model but aren't fully wired end-to-end.
- Struct method receiver semantics are incomplete.
- Return-flow analysis is shallow (not path-sensitive/CFG-based).
- `import`/module resolution (`src/module/module_resolver.zig`) exists but isn't yet called from the compile pipeline.
- Diagnostics are raw Zig errors, not structured/user-friendly compiler messages.

## Docs

Detailed design docs live in `docs/`: `overview.md`, `language-spec.md`, `compiler-architecture.md`, `lexer.md`, `parser.md`, `semantic-analysis.md`, `error-model.md`, `roadmap.md`, `changelog.md`, `examples.md`. Check `docs/roadmap.md` before assuming a missing feature is unintentional.

## Contribution conventions (from CONTRIBUTING.md)

- Keep PRs focused on a single feature/bug (not "parser rewrite + new syntax + optimizer").
- Commit style: `type(scope): summary`, e.g. `feat(parser): add struct initialization`, `fix(lexer): handle escaped strings`.
- Zig style: prefer explicit code, early returns, minimal nesting, avoid unnecessary allocations.
- New language features should be evaluated against: does it reduce complexity, is the syntax obvious, is it beginner-friendly, can the compiler optimize it well, does it introduce hidden behavior.
