# SOLID Codebase Review

This review looks at the Midnight Zig codebase through the SOLID principles. The project is a small language implementation with these major phases:

- Lexing: `src/lexer/`
- Parsing and AST construction: `src/parser/`
- Semantic analysis: `src/semantic/`
- IR lowering: `src/ir/`
- Runtime/backend work: `src/runtime/`, `src/backend/`

Overall, the project is in a healthy exploratory stage. The phase folders are clear, the parser is already split by grammar area, and the tests cover meaningful parser, semantic, and IR behavior. The main improvement opportunity is to turn the current feature-by-feature growth into stronger contracts between phases, so new language features do not require broad edits across parser, semantic analysis, IR lowering, backend generation, tests, and docs.

## Executive Summary

What the code gets right:

- The project has a good high-level compiler pipeline: source -> tokens -> AST -> semantic analysis -> IR -> backend.
- Parser feature modules such as `parseExpr.zig`, `parseStruct.zig`, `parseVarDec.zig`, and `parseFunctionDecl.zig` keep the parser approachable.
- The semantic layer has explicit concepts for scopes, symbols, types, and semantic errors.
- IR is modeled as a typed union instead of raw strings, which is a strong base for future backends.
- Tests exercise real language snippets, not only isolated helper functions.

What most needs improvement:

- `SemanticAnalyzer` has too many responsibilities and is becoming the central place for every language rule.
- AST types are coupled to semantic state through `resolvedType`, so parsing and semantic analysis are not cleanly separated.
- The backend both emits assembly and runs external build commands, which mixes code generation, linking, execution, and cleanup.
- Several switch statements must be updated every time a new expression, statement, type, or instruction is added.
- Some errors are hidden by fallbacks or panics instead of being reported through structured diagnostics.
- Documentation is behind the implementation: the architecture docs still say there is no IR/lowering phase, but the code has one.

## Single Responsibility Principle

Single Responsibility Principle says a module should have one reason to change.

### What Is Good

The broad folder layout respects compiler phases. `Lexer` scans tokens, `Parser` owns cursor movement, parser lib files handle language constructs, `ScopeStack` manages nested scopes, and `InstructionBuilder` emits IR.

Good examples:

- `src/lexer/lexer.zig` is focused on scanning.
- `src/semantic/scope.zig` is focused on symbol scope stack behavior.
- `src/ir/builder.zig` is focused on emitting instructions, temporary ids, labels, and variable mappings.
- `src/backend/asm_builder.zig` separates formatted assembly buffering from the x86 backend.

### What Is Wrong

`src/semantic/anaylzer.zig` is doing too much. It owns top-level traversal, block traversal, function declarations, return checking, variable declaration checks, assignment checks, expression typing, struct initialization validation, function-call validation, print validation, and type compatibility. Examples:

- Program and block traversal are in `analyzeProgram` and `analyzeBlock`.
- Function declaration and return checking are in `analyzeFunctionDecl`.
- Expression typing is in `evaluateExprType`.
- Assignment target rules are in `analyzeVarAssignment`.
- Struct initialization rules are in `analyzeStructFields`.

This means every new language feature is likely to change the same file. That raises merge conflict risk and makes the analyzer harder to test in isolation.

`src/backend/x86_64/x86_64_backend.zig` also has several reasons to change:

- Assembly text generation: `generate`, `lowerInstruction`, `lowerIntBinaryOp`, `lowerFloatBinaryOp`.
- Object/executable building: `build`.
- External process execution: `runCommand`.
- Running the output binary as verification.
- Temporary/object file cleanup.

`src/main.zig` currently hardcodes the sample source file and output path, runs every compiler phase, prints IR, builds assembly, links, and executes the result. That is fine for early development, but it should become a thin CLI over a reusable compiler pipeline.

### Recommended Improvements

Split semantic analysis into smaller services:

- `StatementAnalyzer`: dispatch and block traversal.
- `ExpressionTypeChecker`: returns expression types and owns operator typing.
- `AssignmentChecker`: validates assignable targets and immutability.
- `FunctionChecker`: validates declarations, calls, and returns.
- `StructChecker`: validates struct declarations, member access, and struct initialization.
- `TypeCompatibility`: centralizes compatibility and coercion rules.

Split backend responsibilities:

- `X86_64Emitter`: IR instruction -> assembly.
- `ToolchainRunner`: nasm/gcc invocation.
- `BuildArtifactManager`: paths and cleanup.
- `CompilerDriver` or `Pipeline`: orchestrates lex/parse/analyze/lower/backend.

## Open/Closed Principle

Open/Closed Principle says code should be open for extension but closed for modification.

### What Is Good

The parser uses a Pratt-style expression parser, which is a good extensible structure for operator precedence. `mapOperatorToPrecedence` gives one obvious place to add precedence rules.

IR instructions are represented as a union in `src/ir/ir.zig`, which gives compile-time exhaustiveness pressure. This is valuable in Zig because adding an instruction can expose missing handling at compile time.

### What Is Wrong

Adding one expression kind currently requires edits across many switch statements:

- `Expr` union in `src/parser/lib/parseExpr.zig`.
- Parser prefix/postfix/primary logic.
- `SemanticAnalyzer.evaluateExprType`.
- `lowerExpression`.
- Backend lowering if it reaches native code.
- Tests that assert exact instruction counts.

This is normal in a compiler, but the current shape makes feature extension broad and easy to miss.

Some places also use fallback behavior that hides unsupported cases:

- `lowerExpression` returns a new temp for unsupported expression kinds without emitting an instruction.
- `SemanticAnalyzer.analyzeProgram` and `analyzeBlock` have `else` branches that silently ignore unhandled statement variants.
- Backend lowering uses `@panic` for unsupported instructions and operations.

### Recommended Improvements

Prefer explicit unsupported-feature errors over silent fallbacks:

- Add an `IrLowerError.UnsupportedExpression` or similar.
- Return errors from backend lowering instead of panicking for expected unsupported features.
- Remove silent analyzer `else` branches once all statement variants are handled, or make them return `SemanticError.UnsupportedStatement`.

Introduce small dispatch helpers:

- `lowerExpression` can be split by expression family: literals, access expressions, calls, aggregate expressions, operators.
- `evaluateExprType` can delegate operator rules to a table/function like `resolveBinaryOperator`.
- Backend instruction lowering can be grouped by instruction family instead of one large switch.

## Liskov Substitution Principle

Liskov Substitution Principle is less directly visible because this Zig code does not use inheritance. The equivalent concern here is whether values with the same apparent role can be substituted safely.

### What Is Good

`Type` is explicit and simple. It has `kind`, optional `struct_name`, and `isArray`. That makes most type checks straightforward.

`Value` in IR separates temporary values, constants, variables, parameters, and array indexes. That is a good start for making IR operands explicit.

### What Is Wrong

Some functions assume a union variant without checking it. For example, backend lowering for `StoreVar` assumes `inst.value.temp`. If the IR ever stores a constant, parameter, or other `Value`, this will fail. Similar assumptions appear in backend print and binary operations.

`Type.equals` compares struct names using optional slice equality by pointer-like optional comparison, while `areTypesCompatible` compares struct names with `std.mem.eql`. The compatibility behavior is therefore not consistently substitutable across the codebase.

`evaluateExprType` returns an array type for `ArrayAccess` while an index access should usually return the element type. Assignment logic manually constructs a non-array type later, which hints that `ArrayAccess` is not substituting as "the expression value at this index" consistently.

### Recommended Improvements

- Add helper functions for IR value loading, such as `emitLoadValueIntoReg(value, reg)`, so backend code can handle all `Value` variants consistently.
- Make `Type.equals` and `areTypesCompatible` share the same implementation or clearly separate strict equality from assignability/coercion.
- Revisit `ArrayAccess` typing so it returns the element type unless the language intentionally treats indexed access as an array view.

## Interface Segregation Principle

Interface Segregation Principle says callers should not depend on behavior they do not use.

### What Is Good

The parser helper files expose relatively specific functions. For example, variable parsing, struct parsing, control-flow parsing, and expression parsing are split into separate files. This makes individual grammar areas easier to find.

`ScopeStack` gives a small useful API: push, pop, declare, lookup.

### What Is Wrong

The AST node definitions live inside parser modules and are imported directly by semantic analysis and IR lowering. For example, `SemanticAnalyzer` imports many parser lib files, and IR lowering imports parser AST types directly. This makes downstream phases depend on parser implementation modules instead of a stable AST interface.

The parser also imports semantic `Type` directly. This means parsing a type annotation constructs semantic types immediately. That is convenient now, but it couples syntax parsing to semantic representation.

### Recommended Improvements

Create dedicated AST/model modules:

- `src/ast/expr.zig`
- `src/ast/stmt.zig`
- `src/ast/type_ref.zig`

Then parser modules produce AST nodes, semantic modules consume AST nodes and produce type information, and IR modules consume either typed AST or a semantic result. This keeps parser helper files from becoming the public interface of the entire compiler.

Consider separating syntactic type references from semantic types:

- Parser output: `TypeRef{ name = "int", is_array = false }`
- Semantic output: `Type{ kind = .INT }`

That keeps the parser responsible for syntax and lets semantic analysis own type resolution.

## Dependency Inversion Principle

Dependency Inversion Principle says high-level policy should not depend directly on low-level details.

### What Is Good

The code already has a pipeline shape where each phase can be reasoned about independently. `InstructionBuilder` gives IR lowering a target abstraction instead of forcing lowerers to build raw arrays manually.

### What Is Wrong

High-level orchestration in `main.zig` depends directly on concrete lexer, parser, semantic analyzer, IR builder, x86 backend, hardcoded file paths, and backend build behavior.

Semantic analysis and IR lowering depend on parser-internal module paths. Backend generation depends directly on concrete external commands `nasm` and `gcc`.

### Recommended Improvements

Add a compiler pipeline abstraction:

```zig
pub const CompileOptions = struct {
    source_path: []const u8,
    emit_ir: bool = false,
    backend: BackendKind = .x86_64,
};

pub fn compile(allocator: std.mem.Allocator, options: CompileOptions) !CompileResult {
    // lex -> parse -> analyze -> lower -> optional backend
}
```

Make `main.zig` parse CLI options and call the pipeline. Keep process execution outside the backend emitter so tests can generate assembly without invoking system tools.

## Cross-Cutting Design Issues

### AST Mutability

Many AST nodes contain `resolvedType`, and semantic analysis mutates those fields. This makes the AST both parse output and semantic output.

This works, but it creates coupling:

- Parser creates fields it cannot know.
- Semantic analysis mutates parser-owned structures.
- IR lowering depends on semantic mutation having already happened.

Better options:

- Build a typed AST after semantic analysis.
- Keep a side table from expression pointer/id to `Type`.
- Return semantic facts in a `SemanticResult` structure.

For this project, a side table is probably the smallest good next step.

### Error Handling and Diagnostics

The lexer returns EOF for unknown characters and unterminated strings. Parser numeric parsing catches parse failures and turns them into `0`. Backend lowering uses `@panic` for unsupported operations.

These are risky because users get misleading output or hard crashes instead of source-aware diagnostics.

Recommended direction:

- Add lexer errors for unknown character and unterminated string.
- Preserve token spans in diagnostics.
- Return structured errors for unsupported IR/backend features.
- Replace debug prints with a diagnostics/logging option.

### Duplication

Duplicated logic appears in:

- Function call parsing in `parseExpr.zig` and `parseFunctionDecl.zig`.
- Type parsing and array type parsing in `parseVarDec.zig` and `parseStruct.zig`.
- Operator mapping in parser precedence, semantic type checking, IR binary op mapping, and backend binary lowering.

This is where bugs will creep in as the language grows. Centralize syntax-to-operator mapping and type-reference parsing first.

### Memory Ownership

The code allocates many AST nodes with an arena in tests, which is sensible. Production `main.zig` uses `page_allocator` and only deinitializes tokens. Several `ArrayList.items` slices escape without explicit ownership documentation.

Recommended direction:

- Use an arena for compile-session allocations.
- Document which returned slices are arena-owned.
- Add `deinit` where long-lived structures own hash maps or array lists outside an arena.

### Tests

The tests are useful and concrete. The main concern is brittleness: IR tests often assert exact instruction counts and positions. That can make harmless IR improvements look like failures.

Keep some exact tests for deterministic lowering, but add more semantic assertions:

- Does the IR contain a `JumpIfFalse` to the expected label?
- Does a variable declaration eventually emit one `StoreVar` for the variable?
- Does a function body contain `ParamBind` for each parameter?

This preserves confidence while allowing internal lowering changes.

## Prioritized Refactoring Roadmap

1. Add `src/ast/` and move AST definitions out of parser lib modules.
2. Create `src/parser/lib/parseTypeRef.zig` to centralize primitive, struct, and array type parsing.
3. Replace parser-time semantic `Type` construction with syntactic `TypeRef`.
4. Split `SemanticAnalyzer.evaluateExprType` into `ExpressionTypeChecker`.
5. Move `areTypesCompatible` into a dedicated type compatibility module.
6. Make unsupported analyzer/lowerer/backend cases return errors instead of silent fallbacks or panics.
7. Split backend assembly emission from build/link/run commands.
8. Add a reusable compile pipeline called by `main.zig`.
9. Update architecture docs to include IR, runtime, and backend phases.
10. Add diagnostic spans and replace debug prints with optional tracing.

## Suggested Target Architecture

```text
src/
  ast/
    expr.zig
    stmt.zig
    type_ref.zig
  lexer/
  parser/
    parser.zig
    lib/
  semantic/
    analyzer.zig
    expr_type_checker.zig
    statement_checker.zig
    type_compatibility.zig
    diagnostics.zig
  ir/
    ir.zig
    builder.zig
    lower/
  backend/
    backend.zig
    x86_64/
      emitter.zig
      toolchain.zig
  compiler/
    pipeline.zig
    options.zig
```

This keeps the current strengths but gives each phase a clearer public contract.

## Verification Note

I attempted to run:

```bash
zig build test
```

The command failed before compiling tests because the build runner in `.zig-cache` could not be spawned:

```text
error: failed to spawn build runner .zig-cache/o/.../build: AccessDenied
```

So this review is based on source inspection, not a passing test run.

