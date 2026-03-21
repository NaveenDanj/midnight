# Language Specification (Current)

This document describes the currently implemented syntax and semantics based on parser and analyzer code.

## Lexical Elements

### Punctuation and delimiters

- `;` statement terminator
- `,` separator
- `(` `)` grouping and parameter lists
- `{` `}` blocks
- `.` dot token (member-access semantics not fully implemented)

### Operators

- Assignment: `=`
- Equality: `==`, `!=`
- Arithmetic: `+`, `-`, `*`, `/`
- Comparison: `<`, `<=`, `>`, `>=`
- Unary logical not token: `!` (unary expression parsing not implemented yet)

### Keywords

- Control flow: `if`, `else`, `while`, `return`
- Declarations: `func`, `var`, `const`, `struct`
- Literals: `true`, `false`
- Type keywords: `int`, `float`, `bool`, `void`, `string`

### Literals

- Integer literals
- Float literals
- String literals (double quoted)
- Boolean literals (`true`, `false`)

## Types

Supported type kinds:

- `INT`
- `FLOAT`
- `BOOL`
- `STRING`
- `VOID`
- `FUNCTION` (used in symbol/type tagging)

## Grammar (EBNF-style)

```ebnf
program            = { statement } ;

statement          = var_decl
                   | return_stmt
                   | if_stmt
                   | while_stmt
                   | function_decl
                   | struct_decl
                   | var_assign
                   | function_call_stmt ;

var_decl           = ("var" | "const") type identifier "=" expr ";" ;
var_assign         = identifier "=" expr ";" ;

function_decl      = "func" identifier "(" [ params ] ")" type block ;
params             = param { "," param } ;
param              = type identifier ;

return_stmt        = "return" expr ";" ;

if_stmt            = "if" "(" expr ")" block [ "else" block ] ;
while_stmt         = "while" "(" expr ")" block ;

struct_decl        = "struct" identifier "{" { struct_field } "}" ;
struct_field       = struct_property | struct_method ;
struct_property    = ("var" | "const") type identifier ";" ;
struct_method      = "func" identifier "(" [ params ] ")" type block ;

function_call_stmt = identifier "(" [ args ] ")" ";" ;
args               = expr { "," expr } ;

expr               = precedence_expr ;
precedence_expr    = primary { binary_op primary } ;
primary            = function_call_expr
                   | identifier
                   | integer
                   | float
                   | string
                   | boolean
                   | "(" expr ")" ;
function_call_expr = identifier "(" [ args ] ")" ;

type               = "int" | "float" | "bool" | "void" | "string" ;
```

## Operator Precedence

From low to high:

1. equality: `==`, `!=`
2. comparison: `<`, `<=`, `>`, `>=`
3. sum: `+`, `-`
4. product: `*`, `/`

## Semantic Rules (Current)

- Declared variables must have initializer type compatible with declared type.
- `const` symbols cannot be reassigned.
- Assigned variable names must already be declared.
- While/if conditions must evaluate to `bool`.
- Called function identifiers must resolve to function symbols.
- Function call argument count and argument types are checked.
- Function declarations are added to scope and then their bodies are analyzed.
- Non-void functions must contain at least one return statement with compatible type.
- Void functions must not return a value.

## Known Language Gaps

- Unary expressions are not parsed.
- Member access expressions are not parsed/typed.
- Struct instance semantics are not implemented.
- Return-path completeness for branches/loops is not fully proven (only presence of compatible return is checked at top-level body scan).
