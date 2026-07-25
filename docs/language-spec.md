# Language Specification (Current)

This document describes the language surface that the current Midnight parser and semantic analyzer are aiming to support today.

## Lexical Elements

### Delimiters

- `;`
- `,`
- `(`
- `)`
- `{`
- `}`
- `[`
- `]`
- `.`

### Operators

- assignment: `=`
- equality: `==`, `!=`
- comparison: `<`, `<=`, `>`, `>=`
- arithmetic: `+`, `-`, `*`, `/`, `%`
- boolean: `&&`, `||`
- unary: `-`, `!`

### Keywords

- control flow: `if`, `else`, `while`, `return`
- declarations: `func`, `var`, `const`, `struct`
- built-in statement: `print`
- literals: `true`, `false`
- special keyword: `empty`
- primitive type names: `int`, `float`, `bool`, `void`, `string`

## Types

Supported semantic type kinds:

- `INT`
- `FLOAT`
- `BOOL`
- `STRING`
- `VOID`
- `FUNCTION`
- `STRUCT`
- `EMPTY`

Array-typed values are represented by `Type.isArray`.

## Grammar Sketch

```ebnf
program             = { statement } ;

statement           = var_decl
                    | return_stmt
                    | if_stmt
                    | while_stmt
                    | function_decl
                    | struct_decl
                    | print_stmt
                    | expr_stmt ;

var_decl            = ("var" | "const") type identifier "=" expr ";" ;
return_stmt         = "return" expr ";" ;
print_stmt          = "print" expr ";" ;

expr_stmt           = expr "=" expr ";"
                    | expr ";" ;

function_decl       = "func" identifier "(" [ params ] ")" type block ;
params              = param { "," param } ;
param               = type identifier ;

if_stmt             = "if" "(" expr ")" block [ "else" block ] ;
while_stmt          = "while" "(" expr ")" block ;

struct_decl         = "struct" identifier "{" { struct_field } "}" ;
struct_field        = struct_property | struct_method ;
struct_property     = ("var" | "const") type identifier ";" ;
struct_method       = "func" identifier "(" [ params ] ")" type block ;

expr                = precedence_expr ;
precedence_expr     = prefix_expr { binary_op prefix_expr } ;
prefix_expr         = ("-" | "!") prefix_expr | postfix_expr ;
postfix_expr        = primary { "." identifier | "(" [ args ] ")" | "[" expr "]" } ;

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

type                = base_type [ "[" "]" ] ;
base_type           = "int" | "float" | "bool" | "void" | "string" | identifier ;
```

## Operator Precedence

From low to high:

1. equality: `==`, `!=`
2. comparison: `<`, `<=`, `>`, `>=`
3. sum: `+`, `-`
4. product: `*`, `/`, `%`
5. prefix: unary `-`, `!`
6. postfix: member access, calls, indexing

## Current Semantic Rules

- declared variables must have an initializer type compatible with the declared type
- `const` values cannot be reassigned
- assignments can target identifiers, member access paths, and partially modeled array access paths
- `if` and `while` conditions must evaluate to `bool`
- function calls must resolve to function symbols with matching argument counts and compatible argument types
- non-void functions must contain at least one return statement with a compatible return value
- array literals must be homogeneous
- empty array literals use the `EMPTY` type path and can initialize typed arrays
- struct initialization validates known fields and compatible field values

## Important Current Limits

- the parser supports array access syntax, but array indexing is not fully implemented end-to-end across semantics, IR, and backends
- bare expression statements are only semantically supported for function calls
- struct receiver semantics inside methods are still incomplete
- return analysis is not fully path-sensitive
- `return` currently always expects an expression in the parser, so `void` function behavior is stricter and more limited than a finished language design would likely want
