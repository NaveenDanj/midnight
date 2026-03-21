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

## Expression Type Evaluation

Supported expression typing:

- literals resolve to primitive types
- identifier resolves from symbol table
- function call resolves from function symbol return type
- binary expressions:
  - arithmetic operators require numeric compatibility (plus allows string concatenation)
  - equality operators return `bool`

## Implemented Semantic Checks

- variable declaration type compatibility
- assignment target exists and is mutable
- assignment expression type compatibility
- if/while condition must be `bool`
- function symbol lookup and call argument count/type checks
- missing return in non-void function
- value return in void function rejected

## Known Semantic Gaps

- Struct member/property/method semantics are not yet connected to symbol/type resolution.
- Function call expression branch returns symbol type but does not annotate expression with `resolvedType`.
- Return-flow analysis is shallow (no full control-flow path analysis).
- Analyzer allocates temporary `Statement` wrappers in some checks that are unused and can be removed.
- Error variants are broad (`TypeMismatch`) for many distinct causes.

## Current Runtime Failure Root Cause

Sample program uses struct method body:

```mn
func greet() string {
    return first_name + last_name;
}
```

`first_name` and `last_name` are not in current scope as plain identifiers because struct-instance/member semantics (`this.first_name`) are not implemented, causing `UndefinedVariable` during expression type evaluation.
