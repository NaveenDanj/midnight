# Midnight

Midnight is a personal programming language and compiler project written in Zig.
The current implementation covers lexer, parser, AST construction, and a semantic analysis pass.

## Table of Contents

1. [Quick Start](#quick-start)
2. [CLI Usage](#cli-usage)
3. [Current Status](#current-status)
4. [Documentation](#documentation)
5. [Repository Structure](#repository-structure)
6. [Known Runtime Limitation](#known-runtime-limitation)
7. [Roadmap](#roadmap)

## Quick Start

Prerequisites:

- Zig 0.15.2 (or compatible 0.15.x)

Build and run:

```bash
zig build run -- run src/data/test3.mn
```

Run tests:

```bash
zig build test
```

## CLI Usage

Midnight currently supports two CLI commands:

```bash
midnight run <file.mn>
midnight build <file.mn> [-o output]
```

When running through Zig build, pass CLI arguments after `--`:

```bash
zig build run -- run src/data/test3.mn
zig build run -- build src/data/test3.mn -o /tmp/midnight-build/app
```

Available options:

```text
--backend llvm|x86_64
--emit-ir
--emit-asm
--emit-llvm-ir
-o, --output <path>
```

The default backend is `llvm`. By default, generated executables are placed under a per-process `/tmp/midnight-build-<pid>` directory so the compiler can run even when the repository is stored on a mounted drive that blocks executable files.

If this repository is on `/run/media/naveendanj/STORAGE`, use external Zig cache and prefix directories:

```bash
zig build run \
  --cache-dir /tmp/midnight-zig-cache \
  --global-cache-dir /tmp/midnight-zig-global-cache \
  --prefix /tmp/midnight-zig-out \
  -- run src/data/test3.mn
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
- CLI commands:
  - `run`
  - `build`
- Compiler pipeline for lexing, parsing, semantic analysis, IR lowering, backend emission, linking, and optional execution

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
   |- cli/
   |- compiler/
   |- backend/
   |- ir/
   |- lexer/
   |- parser/
   |- semantic/
   |- tests/
```

## Known Runtime Limitation

Function codegen and advanced language features are still partial. Some programs may pass parsing and semantic analysis but fail during backend emission or linking.

## Roadmap

Primary next steps:

1. Struct member access and method semantics
2. Unary/member expression support in parser and semantic analysis
3. Better diagnostics with source spans
4. Typed AST completion and improved return-flow analysis
5. More complete function codegen and CLI commands such as `check`, `ir`, and `asm`

## License
This project is licensed under the MIT License - see the LICENSE file for details.
