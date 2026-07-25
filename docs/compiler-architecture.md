# Compiler Architecture

## High-Level Flow

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

- `src/compiler/pipeline.zig`

Responsibilities:

- read source text
- run lexer, parser, semantic analyzer, and IR lowering
- optionally emit assembly or LLVM IR
- optionally link an executable
- optionally run the executable

### AST Layer

- `src/ast/expr.zig`
- `src/ast/stmt.zig`
- `src/ast/type_ref.zig`

This layer is the shared syntax model consumed by parser, semantic analysis, and IR lowering.

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
- `src/parser/lib/parseTypeRef.zig`

### Semantic Layer

- `src/semantic/anaylzer.zig`
- `src/semantic/expr_type_checker.zig`
- `src/semantic/function_checker.zig`
- `src/semantic/assignment_checker.zig`
- `src/semantic/struct_checker.zig`
- `src/semantic/type_compatibility.zig`
- `src/semantic/context.zig`
- `src/semantic/scope.zig`
- `src/semantic/symbol.zig`
- `src/semantic/types.zig`

Responsibilities:

- scope creation and symbol lookup
- type compatibility checks
- variable declaration and assignment validation
- function declaration, call, and return validation
- struct declaration and struct initialization validation
- print statement validation

### IR Layer

- `src/ir/ir.zig`
- `src/ir/builder.zig`
- `src/ir/lower.zig`
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

- `src/backend/llvm/`
- `src/backend/x86_64/`
- `src/backend/toolchain.zig`

Current backend split:

- LLVM backend can emit LLVM IR, assembly, and object files
- x86_64 backend emits assembly
- toolchain support links and runs final artifacts

## AST Summary

### Statement variants

- `PrintStatement`
- `FunctionDecl`
- `Block`
- `VariableDecl`
- `ReturnStatement`
- `IfStatement`
- `WhileStatement`
- `StructDecl`
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

`build.zig` currently:

- defines the reusable `midnight` module at `src/root.zig`
- defines the CLI executable at `src/main.zig`
- configures LLVM include and library paths through `llvm-config`
- exposes `zig build run`
- exposes `zig build test`

## Current Architectural Constraints

- diagnostics are still error-set driven, not structured diagnostic objects
- control-flow and return analysis are still shallow compared to a CFG-based design
- some IR instruction variants exist ahead of complete backend support
- the sample programs under `src/data/` mix stable coverage examples with experimental inputs
