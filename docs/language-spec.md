# Language Specification

This document describes the language surface supported by the current Midnight parser and semantic analyzer. It is a reference, not a tutorial — see [Examples](./examples.md) for runnable programs.

## Lexical Elements

### Delimiters

`;` `,` `(` `)` `{` `}` `[` `]` `.`

### Operators

| Category | Operators |
|---|---|
| Assignment | `=` |
| Equality | `==`, `!=` |
| Comparison | `<`, `<=`, `>`, `>=` |
| Arithmetic | `+`, `-`, `*`, `/`, `%` |
| Boolean | `&&`, `\|\|` |
| Unary | `-`, `!` |

`+` also performs string concatenation when both operands are `string`.

### Keywords

| Category | Keywords |
|---|---|
| Control flow | `if`, `else`, `while`, `return` |
| Declarations | `func`, `var`, `const`, `struct`, `extern`, `import` |
| Built-in statement | `print` |
| Literals | `true`, `false` |
| Special | `empty` |
| Primitive types | `int`, `float`, `bool`, `void`, `string` |

### Literals

- Integer literals: digit sequences (`100`, `0`).
- Float literals: a digit sequence with a single decimal point (`3.14`).
- String literals: double-quoted (`"hello"`), may span multiple source lines.
- Boolean literals: `true`, `false`.

### Comments

Midnight has no comment syntax yet. There is no `//` or `/* */` form recognized by the lexer.

## Types

Semantic type kinds:

- `INT`, `FLOAT`, `BOOL`, `STRING`, `VOID` — primitives
- `FUNCTION` — function values (used internally for call resolution)
- `STRUCT` — named struct types, tracked with a `struct_name`
- `EMPTY` — the type of an empty array literal (`[]`), compatible with any typed array

Any type can be array-typed. Array-ness is tracked as a flag on `Type`, not as a distinct type kind — `int[]`, `string[]`, and `Person[]` are all valid.

## Grammar

```ebnf
program             = { statement } ;

statement           = var_decl
                    | return_stmt
                    | if_stmt
                    | while_stmt
                    | function_decl
                    | extern_function_decl
                    | struct_decl
                    | import_stmt
                    | print_stmt
                    | expr_stmt ;

var_decl            = ("var" | "const") type identifier "=" expr ";" ;
return_stmt         = "return" expr ";" ;
print_stmt          = "print" "(" expr ")" ";" ;
import_stmt         = "import" string ";" ;

expr_stmt           = expr "=" expr ";"     (* assignment: identifier or member-access lvalue *)
                    | expr ";" ;            (* function call as a standalone statement *)

function_decl       = "func" identifier "(" [ params ] ")" type block ;
extern_function_decl = "extern" "func" identifier "(" [ params ] ")" type ";" ;
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

Notes:

- `else` always takes a block, not another `if`. An `else if` chain is written as a nested `if` inside the `else` block: `else { if (...) { ... } }`.
- `if`/`while` conditions require parentheses; block bodies require braces (no single-statement bodies without `{}`).
- Struct initializer fields use `=`, not `:` (`Person{ name = "Ada" }`).

## Operator Precedence

From lowest to highest:

1. logical or: `||`
2. logical and: `&&`
3. equality: `==`, `!=`
4. comparison: `<`, `<=`, `>`, `>=`
5. sum: `+`, `-`
6. product: `*`, `/`, `%`
7. prefix: unary `-`, `!`
8. postfix: member access (`.`), calls (`()`), indexing (`[]`)

## Declarations

### Variables

```mn
var int count = 0;
const string name = "midnight";
```

`var` bindings are mutable; `const` bindings cannot be reassigned. The declared type must be compatible with the initializer's type — there is no `var` type inference from a bare literal without a declared type.

### Functions

```mn
func add(int a, int b) int {
    return a + b;
}
```

Every function has an explicit parameter list and an explicit return type (no inference, no overloading). Non-`void` functions must contain at least one `return` with a value compatible with the declared return type.

### Extern functions

```mn
extern func midnight_file_read(string path) string;
```

`extern` declares a function implemented outside Midnight (currently the bundled C runtime under `runtime/`) with no body — just a signature terminated by `;`. Extern functions are called the same way as ordinary functions.

### Structs

```mn
struct Point {
    var int x;
    var int y;

    func length() int {
        return x + y;
    }
}
```

A struct body holds only two kinds of members: typed fields (`var`/`const`) and methods (`func`). Methods reference the struct's own fields directly by name (there is no `self`/`this` receiver keyword) — see [Known Limits](#known-limits) for the current state of receiver semantics.

### Imports

```mn
import "std.io.file";
```

`import` takes a dotted module path resolved relative to the standard library root (or the importing file's directory for local modules) and pulls the target module's top-level functions, structs, and variables into scope. See [Compiler Architecture](./compiler-architecture.md#module-layer) for how modules are resolved and compiled.

## Statements

- `var`/`const` declaration
- `return expr;`
- `if (expr) { ... } [else { ... }]`
- `while (expr) { ... }`
- function declaration, extern function declaration, struct declaration
- `import "path";`
- `print(expr);`
- assignment: `target = expr;`, where `target` is an identifier, a member-access chain (`a.b.c`), or an array index expression
- expression statement: currently only function-call expressions are accepted as standalone statements (`doSomething();`)

## Expressions

- literals: int, float, bool, string
- identifiers
- unary: `-expr`, `!expr`
- binary: arithmetic, comparison, equality, boolean
- function calls: `name(args...)`
- member access: `value.field`, `value.method(args...)`
- struct initialization: `TypeName{ field = expr, ... }`
- array literals: `[expr, expr, ...]`, including the empty literal `[]`
- array indexing: `value[expr]` (parses; see [Known Limits](#known-limits))
- grouping: `(expr)`

## Current Semantic Rules

- declared variables must have an initializer type compatible with the declared type
- `const` values cannot be reassigned
- assignments can target identifiers, member-access paths, and array-access paths
- `if` and `while` conditions must evaluate to `bool`
- function calls must resolve to function symbols with matching argument counts and compatible argument types
- non-`void` functions must contain at least one return statement with a compatible return value
- array literals must be homogeneous; the empty literal `[]` uses the `EMPTY` type and can initialize any typed array
- struct initialization validates that every referenced field exists and every value is type-compatible
- `print` rejects struct-typed values

## Known Limits

- array indexing parses and type-checks, but end-to-end support (semantics, IR, both backends) is still incomplete — treat indexing beyond simple read cases as unverified until you've checked it against the current branch
- bare expression statements are only semantically supported for function calls
- struct method receiver semantics (a method mutating or reading its own struct's fields in every position) are still incomplete
- return-flow analysis is not fully path-sensitive (deeply branching functions may need a trailing `return` the analysis can see directly)
- module resolution is wired into the compile pipeline for the LLVM backend; the x86_64 backend does not yet compile imported modules into separate objects

See [Roadmap](./roadmap.md) for what's planned next.
