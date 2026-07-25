# Midnight

Midnight is a small programming language and compiler project written in Zig. The current codebase includes a full source-to-executable pipeline:

- lexer
- parser and AST construction
- semantic analysis
- IR lowering
- LLVM and x86_64 backend paths
- CLI commands for building and running `.mn` programs

## Quick Start

Prerequisites:

- Zig `0.15.2` or another compatible `0.15.x` release
- LLVM development tools available to `llvm-config` for the LLVM backend build

Run the sample program:

```bash
zig build run -- run src/data/test3.mn
```

Build a Midnight source file without running it:

```bash
zig build run -- build src/data/test3.mn -o /tmp/midnight-build/app
```

Run the produced executable:

```bash
/tmp/midnight-build/app
```

Run tests:

```bash
zig build test
```

## CLI

Midnight currently supports:

```bash
midnight run <file.mn>
midnight build <file.mn> [-o output]
midnight version
midnight help
```

When invoking through Zig, place Midnight CLI arguments after `--`:

```bash
zig build run -- run src/data/test3.mn
zig build run -- build src/data/test3.mn -o /tmp/midnight-build/app
zig build run -- run src/data/test3.mn --backend x86_64 --emit-ir
zig build run -- run src/data/test3.mn --backend llvm --emit-llvm-ir
```

Supported options:

```text
--backend llvm|x86_64
--emit-ir
--emit-asm
--emit-llvm-ir
-o, --output <path>
```

Defaults:

- backend: `llvm`
- build output: a per-process directory under `/tmp/midnight-build-<pid>`

## Mounted Drive Notes

If the repository lives on a mounted `vfat` drive such as `/run/media/...`, Zig may fail to execute build artifacts from the repository-local cache with `AccessDenied`. In that case, use external cache and install directories:

```bash
zig build run \
  --cache-dir /tmp/midnight-zig-cache \
  --global-cache-dir /tmp/midnight-zig-global-cache \
  --prefix /tmp/midnight-zig-out \
  -- run src/data/test3.mn
```

Also note that executables written directly onto `vfat` mounts with `showexec` may not run unless they have a DOS-style executable extension such as `.exe`. Writing outputs under `/tmp` avoids that issue.

## Current Language Surface

Implemented and documented in the current tree:

- variable declarations with `var` and `const`
- typed function declarations and returns
- `if` / `else`
- `while`
- assignments
- function calls in expression and statement position
- primitive types: `int`, `float`, `bool`, `string`, `void`
- unary operators: `-`, `!`
- binary arithmetic, comparison, equality, and boolean operators
- struct declarations with fields and methods
- struct initialization
- member access and member assignment
- array type syntax and array literals
- print statements

## Current Compiler Pipeline

```text
source (.mn)
  -> lexer
  -> parser
  -> semantic analyzer
  -> IR lowering
  -> backend emission
  -> link
  -> optional run
```

The project now has real IR and backend phases, so the docs in `docs/` describe both frontend and backend work, not just parsing and semantic analysis.

## Examples

Recursive function:

```mn
func factorial(int n) int {
    if (n == 1) {
        return 1;
    }

    return n * factorial(n - 1);
}

print(factorial(5));
```

Loop and mutation:

```mn
func countdown(int start) int {
    var int current = start;

    while (current > 0) {
        print(current);
        current = current - 1;
    }

    return 0;
}

countdown(3);
```

Struct and nested assignment:

```mn
struct Sample {
    var int a;
    var int b;
}

struct Person {
    var string first_name;
    var Sample sample;
}

var Person person = Person{
    first_name = "Naveen",
    sample = Sample{
        a = 10,
        b = 20
    }
};

person.sample.a = 99;
print(person.first_name);
```

More examples are in [docs/examples.md](docs/examples.md).

## Documentation

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
- [Changelog](docs/changelog.md)

## Repository Layout

```text
.
|- Readme.md
|- build.zig
|- docs/
|- src/
|  |- ast/
|  |- backend/
|  |- cli/
|  |- compiler/
|  |- data/
|  |- ir/
|  |- lexer/
|  |- parser/
|  |- semantic/
|  |- tests/
```

## Known Gaps

- array indexing and array element assignment are present in the IR model but not fully implemented end-to-end
- struct method receiver semantics are still incomplete
- return-flow analysis is still shallow rather than fully path-sensitive
- diagnostics are still surfaced as Zig errors rather than user-friendly compiler messages

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
