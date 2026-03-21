# Parser and AST

## Parser Core

`src/parser/parser.zig` provides:

- token cursor management (`peek`, `peekNext`, `advance`, `previous`)
- helpers (`check`, `match`, `expect`, `isAtEnd`)
- top-level loop (`parseProgram`) that repeatedly calls `parseStatement`

## Statement Parsing

`parseStatement` dispatches by lookahead:

- `var` / `const` -> variable declaration
- `return` -> return statement
- `if` -> if statement
- `while` -> while statement
- `func` -> function declaration
- `struct` -> struct declaration
- identifier followed by `=` -> assignment
- identifier followed by `(` -> function call statement

## Expression Parsing

The expression parser (`parseExpr.zig`) uses precedence climbing:

- parse primary expression
- while next operator has higher precedence than current level, parse infix
- recursively parse right-hand side using operator precedence

### Expression variants

- literals: int, float, bool, string
- identifier
- binary
- function call expression
- grouped expression `(expr)`

## AST Node Summary

### FunctionDecl

- name
- params (`[]*Param`)
- body (`*BlockStmt`)
- returnType

### VarDecl

- immutable flag
- name
- varType
- initializer expression

### IfStatement

- condition expression
- then block
- optional else block

### WhileStatement

- condition expression
- body block

### StructStmt

- name
- fields (property or method union)

## Struct Parsing Model

Inside a struct body, only two field categories are accepted:

- property declarations (`var`/`const` + type + name + `;`)
- method declarations (`func` signature + return type + block)

## Parser Error Handling

Parser returns `ParserError` values:

- `UnexpectedEndOfFile`
- `UnExpectedToken`
- `UnExpectedEndOfLine`
- `TokenNotFound`
- `OutOfMemory`

Current strategy is fail-fast with no synchronization/recovery.

## Extension Points

- Add unary parsing before `parsePrimary` fallthrough.
- Add member access/call chaining in expression parser using `.` token.
- Add assignment expressions at expression level if language should support it.
- Add richer parser diagnostics carrying token context.
