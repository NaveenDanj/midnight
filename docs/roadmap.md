# Roadmap

This roadmap reflects the state of the project as of 2026-08-07.

## Near Term

1. Forward the `--std-lib` CLI flag into `CompileOptions` and remove the hardcoded, machine-specific default standard library path in `src/cli/options.zig` and `src/compiler/pipeline.zig`.
2. Complete array indexing and array element assignment across semantics, IR lowering, and both backend paths.
3. Bring module compilation (per-module object files) to the x86_64 backend, matching the existing LLVM path.
4. Improve return-flow analysis so branch-heavy functions do not rely on shallow top-level return checks.
5. Add better compiler diagnostics with source spans and user-facing messages.
6. Keep expanding parser, semantic, IR, backend, module, and pipeline regression coverage.

## Language Work

1. Add clearer struct method receiver semantics.
2. Revisit `void` return behavior so the syntax and semantic rules are more natural.
3. Decide on numeric coercion rules more explicitly.
4. Continue tightening array semantics beyond homogeneous literals.
5. Add comment syntax (`//`, `/* */`) to the lexer.

## IR And Backend Work

1. Add stronger validation around generated IR before backend emission.
2. Improve lowering coverage for partially modeled instructions such as indexing-related operations.
3. Reduce backend gaps between the LLVM and x86_64 paths.
4. Explore basic optimization passes once correctness is more stable.

## Standard Library

1. Expand `std.io` beyond file and input handling (e.g. structured output, environment access).
2. Add collection/string-utility modules once array indexing is fully supported.

## Tooling And Project Health

1. Improve `zig build test` reliability across mounted-drive and restricted environments.
2. Keep CI (`.github/workflows/ci.yml`) and release (`.github/workflows/release.yml`) workflows in sync with build requirements.
3. Keep docs synchronized with implementation changes.
4. Separate stable sample programs from experimental feature sketches in `src/data/`.
