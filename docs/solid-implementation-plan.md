# SOLID Improvement Implementation Plan

This plan converts the SOLID review into incremental implementation work. The goal is to improve design without stopping feature development or rewriting the compiler all at once.

## Guiding Rules

- Keep the compiler runnable after every phase.
- Prefer moving code before rewriting behavior.
- Add tests around existing behavior before changing architecture.
- Do not mix behavior changes with file reorganization unless the behavior change is the point of the step.
- Keep old public functions temporarily as wrappers when that reduces migration risk.

## Phase 0: Stabilize The Baseline

Purpose: make future refactors safer.

Tasks:

- Fix the local `zig build test` execution issue if it is caused by `.zig-cache` permissions.
- Add a short `docs/refactor-log.md` or update this plan after each completed phase.
- Add smoke tests for the full frontend pipeline: lex -> parse -> semantic analyze -> IR lower.
- Add tests for existing edge cases before changing them:
  - unknown lexer character
  - unterminated string
  - invalid integer/float literal
  - unsupported IR expression lowering
  - unsupported backend instruction

Expected files:

- `src/tests/`
- `docs/solid-implementation-plan.md`

Acceptance criteria:

- `zig build test` runs locally.
- Existing behavior is captured, even if some tests document current bugs.

Risk:

- Low. This phase mostly creates safety rails.

## Phase 1: Centralize Type Syntax Parsing

Purpose: remove duplicated parser logic and prepare for separating parser types from semantic types.

Current problem:

- `checkForType` and `checkForArrayType` live in `parseVarDec.zig`.
- `parseStruct.zig` has its own array type helper.
- Function declarations, variable declarations, parameters, and struct fields depend on shared parsing behavior through an awkward import path.

Tasks:

- Create `src/parser/lib/parseTypeRef.zig`.
- Move primitive type token recognition into it.
- Move array suffix parsing into it.
- Keep the returned value as the existing semantic `Type` for now to avoid a large change.
- Replace imports of `checkForType` and `checkForArrayType` from `parseVarDec.zig`.
- Delete duplicated array type parsing from `parseStruct.zig`.

Suggested API:

```zig
pub fn parseType(self: *Parser) ParserError!Type
pub fn parseArraySuffix(self: *Parser, base: Type) ParserError!Type
```

Expected files:

- Add `src/parser/lib/parseTypeRef.zig`
- Update `src/parser/lib/parseVarDec.zig`
- Update `src/parser/lib/parseStruct.zig`
- Update `src/parser/lib/parseFunctionDecl.zig`

Acceptance criteria:

- All variable, parameter, function return, and struct field type parsing still works.
- No parser module imports type parsing from `parseVarDec.zig`.

Risk:

- Low. This is mostly code movement.

## Phase 2: Centralize Function Call Parsing

Purpose: remove duplicate call parsing and reduce future parser drift.

Current problem:

- `parseExpr.zig` parses postfix function calls.
- `parseFunctionDecl.zig` has a separate `parseFunctionCall`.
- Statement parsing mostly uses expression statements now, so the older function-call parser path can diverge.

Tasks:

- Create one shared helper for parsing argument lists.
- Use it from postfix call parsing.
- If `FunctionCallStatement` remains necessary, make it wrap a parsed call expression instead of re-parsing the same grammar.
- Prefer representing calls as expressions and statement calls as `ExpressionStmt`.

Suggested API:

```zig
pub fn parseArgumentList(self: *Parser) ParserError![]*Expr
```

Expected files:

- `src/parser/lib/parseExpr.zig`
- `src/parser/lib/parseFunctionDecl.zig`
- `src/parser/lib/parseStatement.zig`

Acceptance criteria:

- Function calls parse the same way in expression and statement positions.
- Member calls such as `object.method()` keep their `callee` information.
- Existing parser and semantic tests still pass.

Risk:

- Medium. Function calls are used by parser, semantic analysis, and IR lowering.

## Phase 3: Introduce AST Modules

Purpose: stop making downstream compiler phases depend on parser implementation files.

Current problem:

- AST node definitions are scattered inside parser helper modules.
- Semantic analysis and IR lowering import parser lib files directly.
- Parser modules expose implementation details as the compiler's public AST contract.

Tasks:

- Create `src/ast/expr.zig`.
- Create `src/ast/stmt.zig`.
- Create `src/ast/type_ref.zig` later, or start with only `expr.zig` and `stmt.zig`.
- Move AST structs and unions from parser modules into `src/ast/`.
- Leave parser functions in `src/parser/lib/`, but make them construct `ast.Expr` and `ast.Statement`.
- Update semantic and IR imports to depend on `src/ast/` instead of parser helper files.

Migration order:

1. Move expression structs and `Expr`.
2. Move statement union and statement structs with minimal behavior changes.
3. Update imports in semantic analyzer.
4. Update imports in IR lowerers.
5. Update tests.

Expected files:

- Add `src/ast/expr.zig`
- Add `src/ast/stmt.zig`
- Possibly add `src/ast/mod.zig`
- Update parser, semantic, IR, and tests imports.

Acceptance criteria:

- Semantic and IR modules do not import `src/parser/lib/*` only to access AST types.
- Parser lib modules remain responsible for parsing only.
- No behavior changes are intended in this phase.

Risk:

- Medium-high because many imports and type names will move.

## Phase 4: Extract Type Compatibility

Purpose: make type rules consistent and testable.

Current problem:

- `Type.equals` and `SemanticAnalyzer.areTypesCompatible` do not share one implementation.
- Numeric compatibility, struct equality, void handling, and string handling live inside the analyzer.

Tasks:

- Create `src/semantic/type_compatibility.zig`.
- Move assignability/compatibility rules out of `SemanticAnalyzer`.
- Define two separate concepts:
  - strict equality: exact same type
  - assignability: allowed assignment or operation compatibility
- Update semantic analyzer to call the new module.
- Add direct unit tests for compatibility behavior.

Suggested API:

```zig
pub fn equals(a: Type, b: Type) bool
pub fn isAssignable(expected: Type, actual: Type) bool
pub fn commonNumericType(left: Type, right: Type) ?Type
```

Expected files:

- Add `src/semantic/type_compatibility.zig`
- Update `src/semantic/types.zig`
- Update `src/semantic/anaylzer.zig`
- Add tests in `src/tests/`

Acceptance criteria:

- Struct name comparison uses `std.mem.eql`.
- Numeric compatibility is tested directly.
- `SemanticAnalyzer` no longer owns type compatibility rules.

Risk:

- Medium. Type compatibility affects many semantic tests.

## Phase 5: Extract Expression Type Checking

Purpose: reduce `SemanticAnalyzer` responsibility and make expression rules easier to extend.

Current problem:

- `SemanticAnalyzer.evaluateExprType` is large and handles every expression kind.
- It mutates AST nodes by setting `resolvedType`.
- Operator typing is embedded in string comparisons.

Tasks:

- Create `src/semantic/expr_type_checker.zig`.
- Move `evaluateExprType` into this module.
- Pass a context object containing scope stack, struct context, allocator, and compatibility functions.
- Extract binary operator typing into a helper like `resolveBinaryOperator`.
- Keep setting `resolvedType` for now to avoid changing IR lowering in the same phase.

Suggested API:

```zig
pub const ExprTypeChecker = struct {
    pub fn init(context: *SemanticContext, scope_stack: *ScopeStack) ExprTypeChecker
    pub fn evaluate(self: *ExprTypeChecker, expr: *Expr) SemanticError!Type
};
```

Expected files:

- Add `src/semantic/expr_type_checker.zig`
- Update `src/semantic/anaylzer.zig`
- Update semantic tests if needed

Acceptance criteria:

- `SemanticAnalyzer` delegates expression typing.
- Expression type checker can be tested directly.
- Existing semantics remain unchanged.

Risk:

- Medium. This moves central logic but can preserve behavior.

## Phase 6: Extract Statement-Level Semantic Checkers

Purpose: finish breaking up the semantic god module.

Current problem:

- `SemanticAnalyzer` handles functions, assignments, structs, blocks, print statements, and traversal.

Tasks:

- Create `src/semantic/assignment_checker.zig`.
- Create `src/semantic/function_checker.zig`.
- Create `src/semantic/struct_checker.zig`.
- Keep `SemanticAnalyzer` as the orchestrator.
- Move one checker at a time, with tests after each move.

Suggested order:

1. Move struct declaration/init/member helper logic.
2. Move assignment logic.
3. Move function declaration/call/return checking.
4. Leave block/program traversal in `SemanticAnalyzer`.

Expected files:

- Add semantic checker modules.
- Shrink `src/semantic/anaylzer.zig`.

Acceptance criteria:

- `SemanticAnalyzer` mostly coordinates traversal and delegates feature rules.
- Each checker has focused tests.

Risk:

- Medium-high. This phase touches the densest area of the project.

## Phase 7: Replace Silent Fallbacks And Panics With Errors

Purpose: make unsupported behavior explicit and easier to diagnose.

Current problem:

- Analyzer has silent `else` branches for unhandled statements.
- IR lowering returns a temp for unsupported expressions.
- Backend uses `@panic` for unsupported instructions and operations.
- Lexer can turn invalid input into EOF.

Tasks:

- Add `UnsupportedStatement` to semantic errors.
- Add `src/ir/lower_error.zig` or an error set in lower modules.
- Add backend error set for unsupported instructions/operators.
- Replace `@panic` where the input can come from source code or incomplete compiler support.
- Add lexer errors for unknown character and unterminated string.

Expected files:

- `src/semantic/semantic_error.zig`
- `src/semantic/anaylzer.zig`
- `src/ir/lib/lowerExpr.zig`
- `src/backend/x86_64/x86_64_backend.zig`
- `src/lexer/lexer.zig`
- `src/parser/error.zig` if parser diagnostics need expansion

Acceptance criteria:

- Unsupported compiler features return errors instead of silently succeeding or crashing.
- Tests assert those errors.

Risk:

- Medium. Some existing tests may depend on current fallback behavior.

## Phase 8: Improve IR Value Handling In Backend

Purpose: make backend lowering safer when IR `Value` is not always `.temp`.

Current problem:

- Backend code assumes several values are `.temp`.
- This makes IR operands less substitutable and can break as IR grows.

Tasks:

- Add helper functions:
  - load `Value` into a register
  - load `Value` into an XMM register for floats
  - store a register into a destination temp
- Update `StoreVar`, `PrintCall`, and binary operation lowering to use helpers.
- Add tests for backend assembly generation with different `Value` variants if feasible.

Suggested API:

```zig
fn emitLoadValueIntoReg(self: *X86_64Backend, asm: *AsmBuilder, value: Value, reg: []const u8) !void
fn emitStoreRegToTemp(self: *X86_64Backend, asm: *AsmBuilder, reg: []const u8, temp: u32) !void
```

Expected files:

- `src/backend/x86_64/x86_64_backend.zig`
- Possibly `src/backend/x86_64/value_emitter.zig`

Acceptance criteria:

- Backend no longer directly accesses `.temp` except inside value helper functions.
- Unsupported `Value` variants return a backend error.

Risk:

- Medium. Backend behavior is lower-level and can be fragile.

## Phase 9: Split Backend Emission From Toolchain Execution

Purpose: separate assembly generation from build/link/run side effects.

Current problem:

- `X86_64Backend.build` writes files, runs `nasm`, runs `gcc`, executes the output, and deletes files.
- Tests cannot safely use backend generation without triggering external side effects if they call the wrong method.

Tasks:

- Rename current assembly generation role to `X86_64Emitter`.
- Create `src/backend/toolchain.zig` for `nasm`/`gcc` execution.
- Create a build artifact/path helper if needed.
- Make "run output binary" an explicit option, not default backend behavior.

Suggested API:

```zig
pub fn emitAssembly(allocator: std.mem.Allocator, instructions: []Instruction) ![]const u8
pub fn assembleAndLink(allocator: std.mem.Allocator, options: ToolchainOptions) !BuildArtifact
pub fn runArtifact(allocator: std.mem.Allocator, artifact: BuildArtifact) !void
```

Expected files:

- `src/backend/x86_64/x86_64_backend.zig`
- Add `src/backend/toolchain.zig`
- Update `src/main.zig`

Acceptance criteria:

- Assembly can be generated without invoking external commands.
- Linking and running are separate, explicit steps.
- Existing `zig build run` behavior can be preserved by calling all steps.

Risk:

- Medium. Main program behavior changes if not wired carefully.

## Phase 10: Add A Compiler Pipeline Module

Purpose: move orchestration out of `main.zig` and make the compiler reusable from tests/tools.

Current problem:

- `main.zig` hardcodes input and output paths and manually wires every phase.

Tasks:

- Create `src/compiler/pipeline.zig`.
- Create `CompileOptions` and `CompileResult`.
- Move lex/parse/analyze/lower/backend orchestration into the pipeline.
- Keep CLI concerns in `main.zig`.
- Add tests that call the pipeline on in-memory source or a fixture file.

Suggested API:

```zig
pub const CompileOptions = struct {
    source_path: []const u8,
    output_dir: []const u8 = "/tmp/midnight-build",
    emit_ir: bool = false,
    emit_asm: bool = true,
    link: bool = false,
    run: bool = false,
};

pub const CompileResult = struct {
    statements: []*Statement,
    instructions: []Instruction,
    asm_text: ?[]const u8,
};
```

Expected files:

- Add `src/compiler/pipeline.zig`
- Possibly add `src/compiler/options.zig`
- Update `src/main.zig`
- Update `build.zig` only if module exports change

Acceptance criteria:

- `main.zig` is mostly argument parsing plus a call to the pipeline.
- Tests can compile source without invoking `nasm`, `gcc`, or executing output.

Risk:

- Medium. This touches the app entrypoint.

## Phase 11: Separate TypeRef From Semantic Type

Purpose: fully decouple parser syntax from semantic type resolution.

Current problem:

- Parser produces semantic `Type` directly.
- Struct type names and primitive type names are resolved during parsing.

Tasks:

- Create `src/ast/type_ref.zig`.
- Change parser type parsing to return `TypeRef`.
- Add semantic type resolver.
- Update variable declarations, parameters, function returns, struct fields, and array types to store `TypeRef` in AST.
- During semantic analysis, resolve `TypeRef` to `Type`.

Suggested data model:

```zig
pub const TypeRef = struct {
    name: []const u8,
    is_array: bool = false,
};
```

Expected files:

- `src/ast/type_ref.zig`
- Parser type parsing modules
- Semantic type resolver
- AST declarations
- Tests

Acceptance criteria:

- Parser no longer imports `src/semantic/types.zig`.
- Semantic analysis owns all type resolution.

Risk:

- High. This is a larger design change and should happen after earlier cleanup.

## Phase 12: Move From Mutable AST Types To Semantic Result

Purpose: remove semantic mutation from parser-owned AST nodes.

Current problem:

- AST nodes contain `resolvedType`.
- IR lowering depends on semantic analysis having mutated those fields.

Tasks:

- Assign stable ids to expressions or use expression pointers as keys.
- Add `SemanticResult` with maps for expression types, symbol information, and diagnostics.
- Change expression type checker to write to `SemanticResult`.
- Update IR lowering to read types from `SemanticResult` instead of AST fields.
- Remove `resolvedType` fields from AST after migration.

Suggested data model:

```zig
pub const SemanticResult = struct {
    expr_types: std.AutoHashMap(*const Expr, Type),
};
```

Expected files:

- Add `src/semantic/result.zig`
- Update semantic checker modules
- Update IR lowerers
- Update AST modules

Acceptance criteria:

- Parser output is immutable syntax data.
- Semantic type facts live outside the AST.
- IR lowering explicitly requires semantic facts.

Risk:

- High. This affects semantic analysis and IR lowering contracts.

## Phase 13: Documentation And Test Hardening

Purpose: keep docs aligned with the new architecture and make tests less brittle.

Tasks:

- Update `docs/compiler-architecture.md` to include IR, backend, and pipeline modules.
- Update `docs/semantic-analysis.md` after semantic checker extraction.
- Add an architecture diagram for source -> tokens -> AST -> semantic result -> IR -> backend.
- Rewrite brittle IR tests where exact instruction counts are not the real behavior under test.
- Keep a small number of exact IR layout tests for deterministic lowering.

Acceptance criteria:

- Docs match the actual code structure.
- Tests describe compiler behavior instead of only internal instruction positions.

Risk:

- Low.

## Recommended Work Order

1. Phase 0: Stabilize baseline.
2. Phase 1: Centralize type parsing.
3. Phase 2: Centralize function call parsing.
4. Phase 4: Extract type compatibility.
5. Phase 5: Extract expression type checker.
6. Phase 6: Extract semantic checkers.
7. Phase 7: Replace fallbacks/panics with errors.
8. Phase 8: Improve backend value handling.
9. Phase 9: Split backend/toolchain.
10. Phase 10: Add compiler pipeline.
11. Phase 3: Introduce AST modules.
12. Phase 11: Separate `TypeRef` from semantic `Type`.
13. Phase 12: Introduce `SemanticResult`.
14. Phase 13: Update docs and harden tests.

The AST and semantic-result work are intentionally later because they are broad. The earlier phases reduce duplication and centralize behavior first, making the larger moves safer.

## First Sprint Proposal

For the first sprint, do only these:

1. Fix `zig build test` execution.
2. Add `parseTypeRef.zig` while still returning current `Type`.
3. Centralize function argument parsing.
4. Extract `type_compatibility.zig`.
5. Add focused tests for type parsing and compatibility.

This gives immediate SOLID improvement with relatively low risk.

