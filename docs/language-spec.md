# Language Specification (Current)

This document describes the currently implemented syntax and semantics based on parser and analyzer code.

## Lexical Elements

### Punctuation and delimiters

- `;` statement terminator
- `,` separator
- `(` `)` grouping and parameter lists
- `{` `}` blocks and struct initializers
- `[` `]` array literals and array type suffixes
- `.` member access

### Operators

- Assignment: `=`
- Equality: `==`, `!=`
- Arithmetic: `+`, `-`, `*`, `/`
- Comparison: `<`, `<=`, `>`, `>=`
- Unary: `-`, `!`

### Keywords

- Control flow: `if`, `else`, `while`, `return`
- Declarations: `func`, `var`, `const`, `struct`
- Literals: `true`, `false`
- Special keyword: `empty`
- Type keywords: `int`, `float`, `bool`, `void`, `string`

### Literals

- Integer literals
- Float literals
- String literals (double quoted)
- Boolean literals (`true`, `false`)
- Array literals (`[expr, expr, ...]`)

## Types

Supported type kinds:

- `INT`
- `FLOAT`
- `BOOL`
- `STRING`
- `VOID`
- `FUNCTION` (used in symbol/type tagging)
- `STRUCT`
- `EMPTY` (used for empty array semantic flow)

`Type` also tracks `isArray`, so declarations like `int[]` are represented as array-typed values.

## Grammar (EBNF-style)

```ebnf
program             = { statement } ;

statement           = var_decl
                    | return_stmt
                    | if_stmt
                    | while_stmt
                    | function_decl
                    | struct_decl
                    | expr_stmt ;

var_decl            = ("var" | "const") type [ "[" "]" ] identifier "=" expr ";" ;
expr_stmt           = expr "=" expr ";"
                    | expr ";" ;

function_decl       = "func" identifier "(" [ params ] ")" type block ;
params              = param { "," param } ;
param               = type identifier ;

return_stmt         = "return" expr ";" ;

if_stmt             = "if" "(" expr ")" block [ "else" block ] ;
while_stmt          = "while" "(" expr ")" block ;

struct_decl         = "struct" identifier "{" { struct_field } "}" ;
struct_field        = struct_property | struct_method ;
struct_property     = ("var" | "const") type identifier ";" ;
struct_method       = "func" identifier "(" [ params ] ")" type block ;

expr                = precedence_expr ;
precedence_expr     = prefix_expr { binary_op prefix_expr } ;
prefix_expr         = ("-" | "!") prefix_expr | postfix_expr ;
postfix_expr        = primary { "." identifier | "(" [ args ] ")" } ;
primary             = struct_init
                    | array_literal
                    | identifier
                    | integer
                    | float
                    | string
                    | boolean
                    | "(" expr ")" ;

struct_init         = identifier "{" [ init_fields ] "}" ;
init_fields         = init_field { "," init_field } ;
init_field          = identifier "=" expr ;

array_literal       = "[" [ args ] "]" ;
args                = expr { "," expr } ;

type                = "int" | "float" | "bool" | "void" | "string" | identifier ;
```

## Operator Precedence

From low to high:

1. equality: `==`, `!=`
2. comparison: `<`, `<=`, `>`, `>=`
3. sum: `+`, `-`
4. product: `*`, `/`
5. prefix: unary `-`, `!`
6. postfix: member access and calls

## Semantic Rules (Current)

- Declared variables must have initializer type compatible with declared type.
- `const` symbols cannot be reassigned.
- Assignment targets may be identifiers or member-access expressions.
- Member assignment validates field existence, mutability, and type compatibility.
- While/if conditions must evaluate to `bool`.
- Called identifiers must resolve to function symbols.
- Function call argument count and argument types are checked.
- Non-void functions must contain at least one return statement with compatible type.
- Void functions must not return a value.
- Array literals must be homogeneous.
- Empty array literals are represented with `EMPTY` kind and allowed in array declarations.

## Known Language Gaps

- Array indexing expressions are not implemented yet.
- Struct receiver semantics inside method bodies are not fully modeled.
- Return-path completeness for branches/loops is not fully path-sensitive.
