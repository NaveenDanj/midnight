# Compiler Architecture

## High-Level Flow

```text
source (.mn)
  -> lexer (Token stream)
  -> parser (AST statements/expressions)
  -> semantic analyzer (scope + type checks)
  -> diagnostics / debug prints
```

## Core Modules

### Entrypoint

- `src/main.zig`
- Responsibilities:
  - read sample source file
  - construct lexer, parser, semantic analyzer
  - execute all frontend phases
  - print debug traces

### Lexer Layer

- `src/lexer/tokens.zig`: token enum and token struct
- `src/lexer/keywords.zig`: identifier-to-keyword mapping
- `src/lexer/lexer.zig`: scanner state machine and token emission

### Parser Layer

- `src/parser/parser.zig`: parser cursor, token navigation helpers, program loop
- `src/parser/lib/`: statement and expression parsers
  - `parseExpr.zig`: Pratt-like precedence parser
  - `parseStatement.zig`: statement dispatcher
  - `parseFunctionDecl.zig`: function declarations and returns
  - `parseVarDec.zig`: variable declarations and assignments
  - `parseIf.zig`, `parseWhile.zig`, `parseBlock.zig`
  - `parseStruct.zig`: struct declarations

### Semantic Layer

- `src/semantic/types.zig`: type system and literal wrappers
- `src/semantic/symbol.zig`: symbol representation
- `src/semantic/scope.zig`: nested scope stack
- `src/semantic/anaylzer.zig`: semantic passes for statements/expressions
- `src/semantic/semantic_error.zig`: semantic error set

## AST Ownership Strategy

- AST nodes are heap allocated (`allocator.create`) and linked by pointers.
- Parsed statement list is returned as `[]*Statement`.
- Expression trees use recursive pointer references (`Binary.left`, `Binary.right`).

## Build System

`build.zig` defines:

- module `midnight` rooted at `src/root.zig`
- executable `midnight` rooted at `src/main.zig`
- top-level step `zig build run`
- top-level step `zig build test`

## Data Model Summary

### Token

- kind (`TokenType`)
- lexeme slice
- line and column counters

### Statement union variants

- FunctionDecl
- Block
- VariableDecl
- ReturnStatement
- IfStatement
- WhileStatement
- StructDecl
- VarAssignment
- FunctionCallStatement

### Expression union variants

- Binary
- IntLiteral
- FloatLiteral
- BoolLiteral
- StringLiteral
- Identifier
- FunctionCall

## Design Strengths

- Clear module boundaries by compilation phase
- Good use of explicit AST types
- Scope lookup from innermost to outermost is clean
- Precedence parsing structure is easy to extend

## Current Constraints

- No separate diagnostic reporting layer (errors are propagated as Zig errors)
- No parser recovery strategy
- No IR/lowering phase yet
- No formal unit tests for lexer/parser/semantic behavior beyond basic Zig test harness scaffold
