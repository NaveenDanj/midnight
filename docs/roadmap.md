# Roadmap

This roadmap is based on current source implementation and TODO notes.

## Phase 1: Frontend Stabilization

1. Implement struct member access semantics (`obj.field`, `obj.method()`).
2. Add explicit method receiver semantics (`this`/`self`) in struct methods.
3. Add unary expression parsing and semantic checks.
4. Add better parser and semantic diagnostics with source context.
5. Add focused unit tests for lexer/parser/semantic modules.

## Phase 2: Type System and AST Enrichment

1. Attach resolved type information for every expression and statement where relevant.
2. Improve function return analysis (path-sensitive).
3. Add richer type compatibility policy (explicit numeric conversions, if desired).
4. Add user-defined type symbols for structs and instance typing.

## Phase 3: IR and Lowering

1. Define minimal intermediate representation (SSA-like or three-address form).
2. Lower AST to IR with explicit control-flow blocks.
3. Add validation passes for IR.
4. Add baseline optimization passes (constant folding, dead code elimination).

## Phase 4: Backend Strategy

1. Prototype SPIR-V oriented codegen path for compute workloads.
2. Evaluate optional LLVM backend for CPU execution path.
3. Build end-to-end compile and execution pipeline.

## Engineering Track Items

- Introduce CI for `zig build` and `zig build test`.
- Add benchmark inputs and performance tracking.
- Maintain language specification docs as parser changes.
- Add changelog/versioning strategy for syntax and semantics.
