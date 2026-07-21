# Getting Started

## Prerequisites

- Zig 0.15.2 or compatible 0.15.x toolchain
- Windows, Linux, or macOS terminal

## Build and Run

From repository root:

```bash
zig build run -- run src/data/test3.mn
```

This compiles the Midnight CLI and asks it to run the sample source file at `src/data/test3.mn`.

To build a Midnight program without running it:

```bash
zig build run -- build src/data/test3.mn -o /tmp/midnight-build/app
```

Then run the generated executable directly:

```bash
/tmp/midnight-build/app
```

## CLI Commands

```bash
midnight run <file.mn>
midnight build <file.mn> [-o output]
```

When invoking through Zig, put Midnight CLI arguments after `--`:

```bash
zig build run -- run src/data/test3.mn
zig build run -- build src/data/test3.mn -o /tmp/midnight-build/app
```

Supported options:

```text
--backend llvm|x86_64
--emit-ir
--emit-asm
--emit-llvm-ir
-o, --output <path>
```

The default backend is `llvm`.

## Mounted Drive Note

If the repository is on a `vfat` mounted drive such as `/run/media/naveendanj/STORAGE`, plain `zig build run` may fail with `AccessDenied` because Zig tries to execute its build runner from `.zig-cache` inside the repository.

Use external cache and install directories:

```bash
zig build run \
  --cache-dir /tmp/midnight-zig-cache \
  --global-cache-dir /tmp/midnight-zig-global-cache \
  --prefix /tmp/midnight-zig-out \
  -- run src/data/test3.mn
```

## Run Tests

```bash
zig build test
```

`build.zig` defines test execution for both:

- module tests (`src/root.zig`)
- executable-root tests (`src/main.zig`)

## Project Layout

- `src/main.zig`: CLI entrypoint and command dispatcher
- `src/cli/`: command parsing and CLI options
- `src/compiler/`: compiler pipeline orchestration
- `src/backend/`: LLVM, x86_64, and toolchain integration
- `src/ir/`: IR instruction model and lowering
- `src/lexer/`: token and lexical scanner logic
- `src/parser/`: parser state, AST statement/expression builders
- `src/parser/lib/`: statement-specific parsing modules
- `src/semantic/`: type system, scope stack, symbol table, semantic analyzer
- `src/tests/`: sample Midnight source files

## Current Execution Behavior

For `midnight run <file.mn>`, the compiler currently:

1. reads the source file
2. lexes tokens
3. parses statements
4. runs semantic analysis
5. lowers to IR
6. emits backend output
7. links an executable
8. runs the executable

If semantic errors are found, execution terminates with a Zig error trace.
