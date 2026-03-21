# Project Overview

## Purpose

Midnight is a hobby compiler project for a small systems-style programming language. The implementation is written in Zig and currently focuses on frontend compilation phases:

- lexical analysis
- parsing to an AST
- semantic analysis (types, scopes, symbol checks)

The project is intended as a learning and experimentation platform for compiler engineering. The long-term target is to lower to an intermediate representation and eventually support GPU-oriented backends.

## Current Features

- Function declarations with typed parameters and return types
- Variable declarations (`var` and `const`) with explicit types
- Variable assignment statements
- Return statements
- If/else statements
- While loops
- Struct declarations with properties and methods
- Function call expressions and function call statements
- Primitive types: `int`, `float`, `bool`, `string`, `void`
- Binary expressions with precedence parsing

## Current Compilation Pipeline

1. Source file is read from `src/tests/test1.mn`.
2. Lexer tokenizes the source into `Token` values.
3. Parser builds a list of AST statements.
4. Semantic analyzer validates symbols, scope, mutability, and type compatibility.
5. Debug output prints source, tokens, and parsed statements.

## Notable Implementation Details

- The analyzer file is named `anaylzer.zig` (typo in filename).
- Runtime currently uses `std.heap.page_allocator` for parsing/analysis allocations.
- The parser and semantic analyzer operate over pointer-based AST nodes.

## Current Known Runtime Failure

Running `zig build run` currently fails with `UndefinedVariable` in semantic analysis for struct method body identifier resolution (example: using `first_name` inside a struct method without member access semantics).
