# Getting Started

## Prerequisites

- Zig 0.15.2 or compatible 0.15.x toolchain
- Windows, Linux, or macOS terminal

## Build and Run

From repository root:

```bash
zig build run
```

This compiles and runs the executable defined in `build.zig`, which reads the sample source file at `src/tests/test1.mn`.

## Run Tests

```bash
zig build test
```

`build.zig` defines test execution for both:

- module tests (`src/root.zig`)
- executable-root tests (`src/main.zig`)

## Project Layout

- `src/main.zig`: CLI/program entrypoint, orchestrates lexing/parsing/semantic analysis
- `src/lexer/`: token and lexical scanner logic
- `src/parser/`: parser state, AST statement/expression builders
- `src/parser/lib/`: statement-specific parsing modules
- `src/semantic/`: type system, scope stack, symbol table, semantic analyzer
- `src/tests/`: sample Midnight source files

## Current Execution Behavior

On run, the compiler currently:

1. prints the source text
2. lexes tokens
3. parses statements
4. runs semantic analysis
5. prints tokens and statement debug structures

If semantic errors are found, execution terminates with a Zig error trace.
