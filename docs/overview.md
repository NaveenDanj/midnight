# Project Overview

## Purpose

Midnight is a hobby compiler project for a small systems-style programming language. The implementation is written in Zig and currently includes a frontend pipeline plus early backend/codegen work:

- lexical analysis
- parsing to an AST
- semantic analysis (types, scopes, symbol checks)
- IR lowering
- LLVM and x86_64 backend experiments
- CLI-driven build and run commands

The project is intended as a learning and experimentation platform for compiler engineering. The long-term target is to continue improving the IR/backend layers and eventually support GPU-oriented backends.

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
- CLI commands for running and building `.mn` files

## Current Compilation Pipeline

1. Source file is selected through the CLI (`midnight run <file.mn>` or `midnight build <file.mn>`).
2. Lexer tokenizes the source into `Token` values.
3. Parser builds a list of AST statements.
4. Semantic analyzer validates symbols, scope, mutability, and type compatibility.
5. IR lowering converts AST/semantic output into compiler IR.
6. The selected backend emits assembly/object output.
7. The toolchain links an executable.
8. `run` executes the artifact; `build` leaves the artifact on disk.

## Notable Implementation Details

- The analyzer file is named `anaylzer.zig` (typo in filename).
- CLI execution uses the process arena allocator provided by Zig startup.
- The parser and semantic analyzer operate over pointer-based AST nodes.
- Default generated artifacts use `/tmp/midnight-build-<pid>` to avoid executable permission issues on mounted drives.

## CLI Usage

```bash
zig build run -- run src/data/test3.mn
zig build run -- build src/data/test3.mn -o /tmp/midnight-build/app
```

When the repository is on a mounted `vfat` drive, use external Zig cache and prefix directories:

```bash
zig build run \
  --cache-dir /tmp/midnight-zig-cache \
  --global-cache-dir /tmp/midnight-zig-global-cache \
  --prefix /tmp/midnight-zig-out \
  -- run src/data/test3.mn
```

## Current Known Limitations

Function codegen and advanced language features are still partial. Some programs may pass parsing and semantic analysis but fail during backend emission or linking.
