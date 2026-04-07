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
- otherwise parse as expression statement:
	- `expr = expr;` becomes assignment statement (target can be identifier or member access)
	- `expr;` becomes expression statement

## Expression Parsing

The expression parser (`parseExpr.zig`) uses precedence climbing:

- parse prefix expression (`-`, `!`) or fall through to postfix/primary
- while next operator has higher precedence than current level, parse infix
- recursively parse right-hand side using operator precedence
- parse postfix chains for member access and call syntax

### Expression variants

- literals: int, float, bool, string
- identifier
- binary
- unary
- array literal
- function call expression
- member access expression
- struct initialization expression
- grouped expression `(expr)`
- expression statement wrapper node

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

Struct initialization expressions are parsed in expression context:

- `TypeName{ field = expr, ... }`

## Array Parsing Model

- Array literals are parsed as expressions: `[expr, expr, ...]`.
- Empty array literals are valid: `[]`.
- Variable declarations support array type suffix after type: `int[]`, `string[]`, and so on.

## Parser Error Handling

Parser returns `ParserError` values:

- `UnexpectedEndOfFile`
- `UnExpectedToken`
- `UnExpectedEndOfLine`
- `TokenNotFound`
- `OutOfMemory`

Current strategy is fail-fast with no synchronization/recovery.

## Extension Points

- Add array indexing support in lvalue/rvalue expressions.
- Consider assignment expressions at expression level if language should support chained assignment.
- Add richer parser diagnostics carrying token context.
