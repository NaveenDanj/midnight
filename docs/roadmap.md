# Roadmap

This roadmap reflects the state of the project as of 2026-07-25.

## Near Term

1. Complete array indexing and array element assignment across semantics, IR lowering, and both backend paths.
2. Improve return-flow analysis so branch-heavy functions do not rely on shallow top-level return checks.
3. Add better compiler diagnostics with source spans and user-facing messages.
4. Keep expanding parser, semantic, IR, backend, and pipeline regression coverage.

## Language Work

1. Add clearer struct method receiver semantics.
2. Revisit `void` return behavior so the syntax and semantic rules are more natural.
3. Decide on numeric coercion rules more explicitly.
4. Continue tightening array semantics beyond homogeneous literals.

## IR And Backend Work

1. Add stronger validation around generated IR before backend emission.
2. Improve lowering coverage for partially modeled instructions such as indexing-related operations.
3. Reduce backend gaps between the LLVM and x86_64 paths.
4. Explore basic optimization passes once correctness is more stable.

## Tooling And Project Health

1. Improve `zig build test` reliability across mounted-drive and restricted environments.
2. Add CI for build and test workflows.
3. Keep docs synchronized with implementation changes.
4. Separate stable sample programs from experimental feature sketches in `src/data/`.
