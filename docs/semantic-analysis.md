# Semantic Analysis

## Core Components

- `SemanticAnalyzer`: orchestrates semantic checks
- `ScopeStack`: nested lexical scopes
- `Symbol`: name, kind, type, immutability, function params
- `Type` and `TypeKind`: simple nominal type system

## Scope Model

`ScopeStack` operations:

- `pushScope()` creates a new hash map scope
- `popScope()` removes current scope
- `declareSymbol()` inserts symbol into current scope and prevents redeclaration in same scope
- `lookupSymbol()` searches from innermost scope outward

## Analyzer Workflow

### Program level

- creates global scope
- visits each top-level statement

### Function declarations

1. collects parameter types
2. declares function symbol in enclosing scope
3. enters function-local scope
4. validates return behavior against declared return type
5. declares parameters as local symbols
6. analyzes function body block

### Block statements

- each block introduces a new scope
- analyzes nested statements in that scope

## Type Compatibility Rules

`areTypesCompatible(expected, actual)` currently implements:

- `void` expected type: always incompatible
- `string` expected type: only `string` actual
- numeric expected types (`int` or `float`): both numeric types accepted
- otherwise exact kind equality

This means numeric assignment/calls are permissive across int/float.

Additional current behavior:

- struct compatibility checks include struct-name equality
- array shape (`isArray`) participates in practical compatibility through expression typing flow
- empty array literals produce `EMPTY` kind and can initialize typed arrays

## Expression Type Evaluation

Supported expression typing:

- literals resolve to primitive types
- identifier resolves from symbol table
- function call resolves from function symbol return type
- member access resolves against struct field/method declarations
- unary expressions:
  - `-expr` requires numeric operand
  - `!expr` requires boolean operand
- array literals:
  - empty arrays resolve to `EMPTY` array type
  - non-empty arrays require homogeneous element types and resolve to typed array
- binary expressions:
  - arithmetic operators require numeric compatibility (plus allows string concatenation)
  - equality operators return `bool`

## Implemented Semantic Checks

- variable declaration type compatibility
- assignment target exists and is mutable
- member assignment checks struct field existence, mutability, and assignment type compatibility
- assignment expression type compatibility
- if/while condition must be `bool`
- function symbol lookup and call argument count/type checks
- missing return in non-void function
- value return in void function rejected
- struct declarations are added to semantic scope/context as structure symbols
- struct initialization validates field names, types, and required-field initialization

## Known Semantic Gaps

- Struct method bodies are not fully analyzed with receiver-aware member semantics.
- Function call expression branch returns symbol type but expression resolvedType annotations are still partial.
- Return-flow analysis is shallow (no full control-flow path analysis).
- Analyzer allocates temporary `Statement` wrappers in some checks that are unused and can be removed.
- Error variants are broad (`TypeMismatch`) for many distinct causes.
