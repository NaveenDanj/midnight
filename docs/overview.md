# Project Overview

## Purpose

Midnight is a hobby compiler project for a small typed language implemented in Zig. The project has moved beyond a frontend-only prototype and now includes:

- lexical analysis
- parsing into AST nodes
- semantic analysis
- IR lowering
- LLVM backend emission
- x86_64 backend emission
- CLI-driven build and run flow

The codebase is still exploratory, but it already supports real end-to-end compilation for a meaningful subset of the language.

## Current Feature Snapshot

### Statements

- variable declarations
- assignment statements
- return statements
- `if` / `else`
- `while`
- function declarations
- struct declarations
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
- array literals

### Types

- `int`
- `float`
- `bool`
- `string`
- `void`
- named struct types
- array type syntax via `TypeRef.is_array`

## Current Compilation Pipeline

1. source file is selected through the CLI
2. lexer tokenizes input
3. parser builds pointer-based AST nodes under `src/ast/`
4. semantic analyzer checks scopes, types, mutability, calls, returns, structs, and prints
5. IR lowering converts AST plus semantic info into `src/ir/ir.zig` instructions
6. selected backend emits LLVM IR, object code, or x86_64 assembly
7. toolchain links an executable when requested
8. `run` executes the resulting artifact

## Sample Programs In The Repository

- `src/data/test3.mn`: loop-heavy benchmark-style sample using function calls and `print`
- `src/data/simple.mn`: variables, structs, conditionals, prints, and arithmetic
- `src/data/struct.mn`: richer struct usage, nested initialization, and recursive function examples
- `src/data/ir.mn`: mixed experimental syntax and future-facing constructs, useful as a feature sketch more than a guaranteed passing sample

## Practical Notes

- The semantic analyzer filename is still `src/semantic/anaylzer.zig`.
- The default backend is LLVM.
- Generated executable paths are placed under `/tmp/midnight-build-<pid>` by default to avoid execution issues on mounted drives.
- Repository-local execution on `vfat` mounts can fail because of Zig cache execution rules and filesystem executable limitations.

## Current Constraints

- array indexing and array element mutation are not fully supported end-to-end
- struct method receiver semantics are incomplete
- return checking is not fully path-sensitive
- diagnostics are still raw Zig error propagation rather than polished compiler diagnostics
