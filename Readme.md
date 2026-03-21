# Midnight

Midnight is a personal programming language and compiler project written in Zig.
The current implementation covers lexer, parser, AST construction, and a semantic analysis pass.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Current Status](#current-status)
3. [Documentation](#documentation)
4. [Repository Structure](#repository-structure)
5. [Known Runtime Limitation](#known-runtime-limitation)
6. [Roadmap](#roadmap)

## Quick Start

Prerequisites:

- Zig 0.15.2 (or compatible 0.15.x)

Build and run:

```bash
zig build run
```

Run tests:

```bash
zig build test
```

## Current Status

Implemented:

- Lexer and token model
- Pratt-style expression parsing with precedence
- Statement parsing for:
  - variable declarations (`var`, `const`)
  - assignment
  - `if` / `else`
  - `while`
  - function declarations
  - function calls
  - struct declarations
- AST node allocation and tree construction
- Semantic analysis for:
  - scope stack and symbol table management
  - declaration and assignment checks
  - basic type compatibility checks
  - if/while condition type checks
  - function call argument checks
  - function return checks

## Documentation

All detailed documentation is available under the `docs` folder.

- [Documentation Index](docs/index.md)
- [Project Overview](docs/overview.md)
- [Getting Started](docs/getting-started.md)
- [Language Specification](docs/language-spec.md)
- [Compiler Architecture](docs/compiler-architecture.md)
- [Lexer Design](docs/lexer.md)
- [Parser and AST](docs/parser.md)
- [Semantic Analysis](docs/semantic-analysis.md)
- [Error Model](docs/error-model.md)
- [Examples](docs/examples.md)
- [Roadmap](docs/roadmap.md)

## Repository Structure

```text
.
|- build.zig
|- build.zig.zon
|- Readme.md
|- Todo.md
|- docs/
|  |- index.md
|  |- overview.md
|  |- getting-started.md
|  |- language-spec.md
|  |- compiler-architecture.md
|  |- lexer.md
|  |- parser.md
|  |- semantic-analysis.md
|  |- error-model.md
|  |- examples.md
|  |- roadmap.md
|- src/
   |- main.zig
   |- root.zig
   |- lexer/
   |- parser/
   |- semantic/
   |- tests/
```

## Known Runtime Limitation

Current sample program (`src/tests/test1.mn`) triggers a semantic error (`UndefinedVariable`) for struct method identifier usage because member access/receiver semantics are not fully implemented yet.

## Roadmap

Primary next steps:

1. Struct member access and method semantics
2. Unary/member expression support in parser and semantic analysis
3. Better diagnostics with source spans
4. Typed AST completion and improved return-flow analysis
5. IR design and lowering pipeline