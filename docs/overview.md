# Project Overview

## Purpose

Midnight is an experimental systems programming language and compiler, implemented in Zig. It runs a full source-to-executable pipeline:

- lexical analysis
- parsing into AST nodes
- semantic analysis
- IR lowering
- module resolution and compilation (`import`)
- backend emission (LLVM or x86_64)
- linking
- optional execution

The codebase is early-stage but already supports real end-to-end compilation for a meaningful subset of the language, including a small standard library.

## Current Feature Snapshot

### Statements

- variable declarations (`var`, `const`)
- assignment statements (identifier, member-access, and array-index targets)
- return statements
- `if` / `else`
- `while`
- function declarations
- extern function declarations (`extern func ...;`)
- struct declarations
- import statements (`import "std.io.file";`)
- print statements
- expression statements for function calls

### Expressions

- integer, float, bool, and string literals
- identifiers
- unary expressions (`-`, `!`)
- binary arithmetic and comparison expressions
- equality expressions
- boolean `&&` and `||`
- function calls
- member access
- struct initialization
- array literals and array indexing

### Types

- `int`, `float`, `bool`, `string`, `void`
- named struct types
- array types, written `T[]` for any base type `T`

## Current Compilation Pipeline

1. the CLI selects a source file and options (`run` or `build`)
2. the lexer tokenizes the input
3. the parser builds pointer-based AST nodes under `src/ast/`
4. the module resolver walks `import` statements, resolving dotted paths (`std.io.file`) against the standard library root or the importing file's directory, and detects circular imports
5. the semantic analyzer checks scopes, types, mutability, calls, returns, structs, and prints — the entry file and every transitively imported module are analyzed into one shared top-level scope
6. IR lowering converts AST plus semantic info into `src/ir/ir.zig` instructions
7. on the LLVM backend, each imported module is compiled into its own object file and the entry file's instructions get synthesized `extern` declarations for cross-module calls
8. the selected backend emits LLVM IR, object code, or x86_64 assembly
9. the toolchain links an executable (and the object files of any imported modules) when requested
10. `run` executes the resulting artifact

## Standard Library

A small standard library lives under `src/std/`, built on `extern` bindings into the C runtime (`runtime/`):

- `std.io.file` — the `File` struct: read/write/append/exists/delete/copy/move/create/directory operations
- `std.io.input` — the `Input` struct: `readLine`, `readInt`, `readFloat`, `readBool`

Import a module with its dotted path (`import "std.io.file";`) — see [Examples](./examples.md#imports-and-the-standard-library).

## Sample Programs In The Repository

- `src/data/simple.mn` — variables, structs, conditionals, prints, and arithmetic
- `src/data/struct.mn` — nested struct initialization, 2D arrays, and recursion
- `src/data/test3.mn` — loop-heavy benchmark-style sample, imports the bundled `std.mn` sample
- `src/data/test4.mn`, `src/data/test5.mn` — standard library usage (`std.io.file`, `std.io.input`)
- `src/data/ir.mn` — mixed experimental syntax, useful as a feature sketch more than a guaranteed-passing sample

## Practical Notes

- The semantic analyzer's filename is `src/semantic/anaylzer.zig` (intentional existing spelling — not a typo to silently "fix").
- The default backend is x86_64 in `pipeline.CompileOptions`, and LLVM at the CLI layer (`--backend` defaults to `llvm`).
- Generated executable paths are placed under `/tmp/midnight-build-<pid>` by default to avoid execution issues on mounted drives.
- Repository-local execution on `vfat` mounts can fail because of Zig cache execution rules and filesystem executable limitations — pass explicit `--cache-dir`/`--global-cache-dir`/`--prefix` in that case (see [Getting Started](./getting-started.md#mounted-drive-notes)).

## Current Constraints

- array indexing is not fully supported end-to-end across every backend path
- struct method receiver semantics are incomplete
- return checking is not fully path-sensitive
- module compilation into separate objects is implemented for the LLVM backend only
- diagnostics are still raw Zig error propagation rather than polished, source-span-aware compiler diagnostics

See [Roadmap](./roadmap.md) for what's planned next.
