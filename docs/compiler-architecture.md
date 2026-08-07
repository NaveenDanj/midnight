# Compiler Architecture

## High-Level Flow

```text
source (.mn)
  -> lexer
  -> parser
  -> module resolution (import statements)
  -> semantic analyzer
  -> IR lowering
  -> module compilation (LLVM backend)
  -> backend emission
  -> link
  -> optional run
```

## Main Modules

### Entrypoint

- `src/main.zig`
- parses CLI arguments
- dispatches `run`, `build`, `help`, and `version`

### CLI Layer

- `src/cli/commands.zig`
- `src/cli/compiler_options.zig`
- `src/cli/handle_commands.zig`
- `src/cli/options.zig`

Responsibilities:

- parse command-line arguments
- translate flags to pipeline options
- print help and version output

Supported commands:

```bash
midnight run <file.mn>
midnight build <file.mn> [-o output]
midnight help
midnight version
```

### Compiler Pipeline

- `src/compiler/pipeline.zig` (`compileFile` / `compileSource`)

Responsibilities:

- read source text
- run the lexer, parser, module resolver, semantic analyzer, and IR lowering
- compile imported modules into separate object files (LLVM backend)
- optionally emit assembly or LLVM IR
- optionally link an executable
- optionally run the executable

This is the central orchestration point — read it first when tracing how a `.mn` file becomes an executable.

### AST Layer

- `src/ast/expr.zig`
- `src/ast/stmt.zig`
- `src/ast/type_ref.zig`

This layer is the shared syntax model consumed by the parser, semantic analysis, module resolution, and IR lowering.

### Lexer Layer

- `src/lexer/tokens.zig`
- `src/lexer/keywords.zig`
- `src/lexer/lexer.zig`

### Parser Layer

- `src/parser/parser.zig`
- `src/parser/lib/parseStatement.zig`
- `src/parser/lib/parseExpr.zig`
- `src/parser/lib/parseFunctionDecl.zig`
- `src/parser/lib/parseVarDec.zig`
- `src/parser/lib/parseStruct.zig`
- `src/parser/lib/parseIf.zig`
- `src/parser/lib/parseWhile.zig`
- `src/parser/lib/parseBlock.zig`
- `src/parser/lib/parseArray.zig`
- `src/parser/lib/parseTypeRef.zig`
- `src/parser/lib/parseImport.zig`
- `src/parser/lib/parsePrint.zig`
- `src/parser/lib/operator.zig` — precedence table

### Module Layer

- `src/module/module_resolver.zig`
- `src/module/module_compiler.zig`

Responsibilities:

- `ModuleResolver` walks `import` statements, resolves each dotted path (`std.io.file`) to a source file under the standard library root or the importing file's directory, parses it, and recursively resolves its own imports, detecting circular dependencies along the way
- `ModuleCompiler` (LLVM backend only) takes the resolved module graph, lowers and emits each module into its own object file, and synthesizes the `extern` declarations the entry file's IR needs to call across module boundaries
- resolved modules and the entry file are analyzed together into one shared top-level semantic scope, so declarations from an imported module stay visible without merging ASTs together

The x86_64 backend does not yet drive `ModuleCompiler` — imports are resolved, but per-module object compilation is LLVM-only today.

### Semantic Layer

- `src/semantic/anaylzer.zig` (entrypoint: `SemanticAnalyzer`)
- `src/semantic/expr_type_checker.zig`
- `src/semantic/function_checker.zig`
- `src/semantic/assignment_checker.zig`
- `src/semantic/struct_checker.zig`
- `src/semantic/type_compatibility.zig`
- `src/semantic/type_resolver.zig`
- `src/semantic/context.zig`
- `src/semantic/scope.zig`
- `src/semantic/symbol.zig`
- `src/semantic/types.zig`
- `src/semantic/result.zig`

Responsibilities:

- scope creation and symbol lookup
- type compatibility checks
- variable declaration and assignment validation
- function declaration, call, and return validation
- struct declaration and struct initialization validation
- print statement validation

IR lowering consumes `SemanticAnalyzer.result` for resolved type info.

### IR Layer

- `src/ir/ir.zig` — the `Instruction` model
- `src/ir/builder.zig` (`InstructionBuilder`) — assigns temps and labels
- `src/ir/lower.zig` (`generateIRWithSemantics`) — drives lowering
- `src/ir/lib/lowerExpr.zig`
- `src/ir/lib/lowerFlowControl.zig`
- `src/ir/lib/lowerFunction.zig`
- `src/ir/lib/lowerStruct.zig`
- `src/ir/lib/lowerVar.zig`

Responsibilities:

- encode backend-facing instructions
- assign temps and labels
- lower AST control flow into jumps and labels
- preserve semantic type information where backends need it

### Backend Layer

Two independent codegen paths consume the same `[]Instruction` slice:

- `src/backend/llvm/` — `llvm_backend.zig` is the entrypoint (`emitLLVMAssembly`, `emitLLVMIR`, `emitLLVMObject`); `llvm_context.zig` and `llvm_type_mapper.zig` hold shared state and type mapping; `llvm_emitter.zig` dispatches to per-construct emitters under `backend/llvm/lib/` (`function_emitter.zig`, `bin_op_emitter.zig`, `arr_emitter.zig`, `struct_emitter.zig`, `print_emitter.zig`, `unary_op.zig`, `predicates.zig`). Bindings to the LLVM C API live in `src/llvm.zig`.
- `src/backend/x86_64/x86_64_backend.zig` — emits assembly directly, using `src/backend/asm_builder.zig`.
- `src/backend/toolchain.zig` — assembles/links/runs produced artifacts for both backends (`assembleAndLink`, `linkObjects`, `runArtifact`).

## AST Summary

### Statement variants

- `PrintStatement`
- `FunctionDecl` (with an `isExtern` flag for extern declarations)
- `Block`
- `VariableDecl`
- `ReturnStatement`
- `IfStatement`
- `WhileStatement`
- `StructDecl`
- `ImportStatement`
- `VarAssignment`
- `FunctionCallStatement`
- `ExpressionStmt`

### Expression variants

- `Binary`
- `IntLiteral`
- `FloatLiteral`
- `BoolLiteral`
- `StringLiteral`
- `Identifier`
- `ArrayLiteral`
- `ArrayAccess`
- `FunctionCall`
- `MemberAccess`
- `StructInit`
- `ExpressionStmt`
- `Unary`

## Build System Notes

`build.zig`:

- defines the reusable `midnight` module at `src/root.zig`
- defines the CLI executable at `src/main.zig`
- configures LLVM include and library paths through `llvm-config` (non-Windows), or `-Dllvm-root=<path>` / `-Dllvm-lib-name=<name>` on Windows
- exposes `zig build run` and `zig build test`

Release builds (`.github/workflows/release.yml`) produce Linux and Windows x86_64 archives on tagged GitHub Releases, bundling the compiled binary together with the LLVM shared library/DLL it links against.

## Current Architectural Constraints

- diagnostics are still error-set driven, not structured diagnostic objects
- control-flow and return analysis are still shallow compared to a CFG-based design
- some IR instruction variants exist ahead of complete backend support
- module compilation into separate object files is implemented for the LLVM backend only
- the sample programs under `src/data/` mix stable coverage examples with experimental inputs
