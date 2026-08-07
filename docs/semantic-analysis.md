# Semantic Analysis

## Main Components

- `SemanticAnalyzer`: statement-level orchestration
- `ExprTypeChecker`: expression typing
- `AssignmentChecker`: declarations and assignments
- `FunctionChecker`: function declarations, calls, and returns
- `StructChecker`: struct declarations and struct initialization checks
- `ScopeStack`: nested lexical scope management
- `SemanticContext`: registered structs and functions
- `SemanticResult`: resolved semantic metadata reused by IR lowering

## Scope Model

`ScopeStack` supports:

- `pushScope()`
- `popScope()`
- `declareSymbol()`
- `lookupSymbol()`

Lookup walks from innermost scope outward.

## Symbol Kinds

Current symbol kinds:

- `variable`
- `function`
- `parameter`
- `structure`

Parameters are tracked distinctly from variables, which matters for assignment semantics and function analysis.

## Semantic Workflow

### Program level

- create global scope
- analyze top-level statements in order

### Function declarations

1. resolve parameter types
2. declare the function in scope and semantic context
3. push a function-local scope
4. declare parameters
5. analyze the function body
6. validate return usage against the declared return type

### Blocks

- each block pushes a nested scope
- statements are analyzed sequentially

### Expression statements

- bare function calls such as `loop(100);` are accepted
- non-call expression statements are still rejected as unsupported semantic statements

### Import statements

`ImportStatement` nodes are a no-op at this stage — by the time semantic analysis runs, the module resolver has already turned each imported module's top-level declarations into statements analyzed in the same shared scope, so there's nothing left for `ImportStatement` itself to check.

### Extern function declarations

Extern functions (`funcDecl.isExtern`) skip body analysis (there is no body to analyze) but are still registered as callable function symbols like any other declaration.

## Type System Snapshot

Current type kinds:

- `INT`
- `FLOAT`
- `BOOL`
- `STRING`
- `VOID`
- `FUNCTION`
- `STRUCT`
- `EMPTY`

`Type` also tracks:

- `struct_name`
- `isArray`

## What Is Checked Today

### Variable declarations

- declared type must be assignable from initializer type
- `const` and `var` declarations are added to scope
- struct initializers are checked field-by-field
- typed arrays can be initialized from homogeneous array literals
- empty array literals are allowed through `EMPTY`

### Assignments

- assignment target must resolve in scope
- immutable targets are rejected
- identifier assignments check type compatibility
- member assignments validate field existence and mutability
- array assignment rules exist in the checker, but end-to-end indexing support is still incomplete elsewhere

### Control flow

- `if` and `while` conditions must be `bool`

### Functions

- declared functions are registered in semantic context
- call argument count must match
- call argument types must be assignable
- return expressions are checked against declared return type

### Structs

- struct declarations are registered in context
- field types are resolved
- struct initialization requires known fields and compatible values

### Prints

- print statements record their resolved type
- printing structs is rejected

## Expression Typing

The expression type checker handles:

- literals
- identifiers
- unary expressions
- binary expressions
- function calls
- member access
- array literals
- array access typing paths
- struct initialization expressions

Notable rules:

- numeric operators accept numeric operands
- `+` also supports string concatenation
- equality and comparison operators return `bool`
- boolean operators expect boolean operands
- member access resolves through struct metadata

## Modules and Shared Scope

The compile pipeline analyzes the entry file and every transitively imported module into one shared top-level scope (`SemanticAnalyzer.beginSharedScope` / `endSharedScope`), so declarations made while analyzing one module stay visible while analyzing the file that imports it — without merging their ASTs together. Each module is still lowered and emitted separately; see [Compiler Architecture § Module Layer](./compiler-architecture.md#module-layer).

## Current Weak Spots

- diagnostics are broad, often returning `TypeMismatch` for many distinct causes
- receiver-aware semantics inside struct methods are still limited
- return-flow validation is not fully path-sensitive
- array indexing support is only partially implemented across parser, semantics, IR, and backend
