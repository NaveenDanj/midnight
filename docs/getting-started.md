# Getting Started

## Prerequisites

- Zig `0.15.2` or a compatible `0.15.x` release
- LLVM development tools discoverable through `llvm-config`
- a Unix-like shell environment for the current build and run flow

## Basic Commands

Run the current sample program:

```bash
zig build run -- run src/data/test3.mn
```

Build a Midnight program without running it:

```bash
zig build run -- build src/data/test3.mn -o /tmp/midnight-build/app
```

Run the generated program:

```bash
/tmp/midnight-build/app
```

Print CLI help:

```bash
zig build run -- help
```

Show the compiler version:

```bash
zig build run -- version
```

## Useful Flags

```text
--backend llvm|x86_64
--emit-ir
--emit-asm
--emit-llvm-ir
-o, --output <path>
```

Examples:

```bash
zig build run -- run src/data/test3.mn --emit-ir
zig build run -- run src/data/test3.mn --emit-llvm-ir
zig build run -- run src/data/test3.mn --backend x86_64 --emit-asm
zig build run -- build src/data/test3.mn --backend llvm -o /tmp/midnight-build/app
```

## Mounted Drive Notes

If the repository is on a mounted `vfat` drive such as `/run/media/naveendanj/STORAGE`, plain `zig build run` may fail with `AccessDenied` because Zig tries to execute cached build artifacts inside the repository.

Use external cache and install directories instead:

```bash
zig build run \
  --cache-dir /tmp/midnight-zig-cache \
  --global-cache-dir /tmp/midnight-zig-global-cache \
  --prefix /tmp/midnight-zig-out \
  -- run src/data/test3.mn
```

If you build a binary directly onto that `vfat` mount, it may also fail to run as `./build/out` because the mount can require an executable extension such as `.exe`. Outputs under `/tmp` avoid that problem.

## What The Compiler Does Today

For `midnight run <file.mn>`, the project currently:

1. reads the source file
2. lexes it into tokens
3. parses it into AST nodes
4. runs semantic analysis
5. lowers to IR
6. emits assembly or LLVM object/IR output
7. links an executable
8. optionally runs the executable

## Tests

Run the test suite with:

```bash
zig build test
```

The tree currently includes parser, semantic, IR, backend, and pipeline tests.

## Project Layout

- `src/main.zig`: CLI entrypoint
- `src/cli/`: command parsing and option translation
- `src/compiler/`: compilation pipeline
- `src/ast/`: AST node definitions
- `src/lexer/`: lexer and token definitions
- `src/parser/`: parser and parse helpers
- `src/semantic/`: semantic analysis, scopes, symbols, and types
- `src/ir/`: IR instructions and lowering
- `src/backend/`: LLVM backend, x86_64 backend, and toolchain integration
- `src/data/`: sample Midnight programs
- `src/tests/`: Zig test coverage
