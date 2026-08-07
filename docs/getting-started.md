# Getting Started

## Prerequisites

- Zig `0.15.2` (or a compatible `0.15.x` release)
- LLVM development tools discoverable through `llvm-config` (non-Windows), or `-Dllvm-root=<path>` passed to `zig build` on Windows
- a Unix-like shell environment for the current build and run flow

## Building

```bash
zig build
```

## Basic Commands

Run a sample program:

```bash
zig build run -- run src/data/simple.mn
```

Build a Midnight program without running it:

```bash
zig build run -- build src/data/simple.mn -o /tmp/midnight-build/app
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
--backend llvm|x86_64   (default: llvm)
--emit-ir
--emit-asm
--emit-llvm-ir
-o, --output <path>
```

Examples:

```bash
zig build run -- run src/data/simple.mn --emit-ir
zig build run -- run src/data/simple.mn --emit-llvm-ir
zig build run -- run src/data/simple.mn --backend x86_64 --emit-asm
zig build run -- build src/data/simple.mn --backend llvm -o /tmp/midnight-build/app
```

## Downloading a Prebuilt Binary

Tagged releases publish prebuilt binaries for Linux and Windows (x86_64) via GitHub Releases:

```text
https://github.com/NaveenDanj/midnight/releases
```

Each release archive bundles the `midnight` (or `midnight.exe`) binary alongside the LLVM shared library it links against, so no separate LLVM install is required to run a downloaded build. Building from source is still required to compile with a different LLVM version or to work on the compiler itself.

## Known Limitation: Standard Library Path

`import "std.io.file";`-style imports currently resolve against a standard library path that defaults to the original development machine's absolute path (see `src/cli/options.zig` and `src/compiler/pipeline.zig`). The `--std-lib` flag is parsed by the CLI but not yet forwarded into the compile pipeline, so it has no effect. Until this is fixed, run programs that `import` standard library modules from within a checkout of this repository, or edit the relevant `std_lib_path` default in `src/compiler/pipeline.zig` and rebuild.

## Mounted Drive Notes

If the repository is on a mounted `vfat` drive (for example `/run/media/<user>/STORAGE`), plain `zig build run` may fail with `AccessDenied` because Zig tries to execute cached build artifacts inside the repository.

Use external cache and install directories instead:

```bash
zig build run \
  --cache-dir /tmp/midnight-zig-cache \
  --global-cache-dir /tmp/midnight-zig-global-cache \
  --prefix /tmp/midnight-zig-out \
  -- run src/data/simple.mn
```

If you build a binary directly onto that `vfat` mount, it may also fail to run as `./build/out` because the mount can require an executable extension such as `.exe`. Outputs under `/tmp` avoid that problem.

## What The Compiler Does Today

For `midnight run <file.mn>`, the pipeline:

1. reads the source file
2. lexes it into tokens
3. parses it into AST nodes
4. resolves `import` statements into modules
5. runs semantic analysis across the entry file and every imported module in a shared top-level scope
6. lowers to IR
7. compiles imported modules into separate object files (LLVM backend only)
8. emits assembly or LLVM object/IR output
9. links an executable
10. optionally runs the executable

## Tests

Run the test suite with:

```bash
zig build test
```

This runs three suites in parallel: tests in the `midnight` module (`src/root.zig`), tests in the exe root module (`src/main.zig`), and the aggregate suite in `src/test_runner.zig`, which imports every file under `src/tests/`.

There is no built-in single-test filter. To add coverage for new work, add `test "..."` blocks to an existing (or new) file in `src/tests/` and register new files in `src/test_runner.zig`.

## Project Layout

- `src/main.zig` — CLI entrypoint
- `src/cli/` — command parsing and option translation
- `src/compiler/` — compilation pipeline
- `src/ast/` — AST node definitions
- `src/lexer/` — lexer and token definitions
- `src/parser/` — parser and parse helpers
- `src/semantic/` — semantic analysis, scopes, symbols, and types
- `src/ir/` — IR instructions and lowering
- `src/module/` — import resolution and per-module compilation
- `src/backend/` — LLVM backend, x86_64 backend, and toolchain integration
- `src/std/` — the Midnight standard library
- `src/data/` — sample Midnight programs
- `src/tests/` — Zig test coverage
- `runtime/` — prebuilt C object files linked into compiled executables
