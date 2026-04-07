# Recent Changes Since Last Docs Update

This document summarizes compiler and language changes made after the previous documentation update commit (`c54177b`).

## Parser and AST

- Added expression statements, so standalone expressions like `call();` and `a + b;` are parsed as statement nodes.
- Assignment parsing now accepts expression targets and supports member-access lvalues like `person.age = 20;` and nested chains like `person.sample.a = 500;`.
- Added postfix member access and call chaining support in expressions (`obj.field`, `obj.method(...)`).
- Added unary prefix expression parsing for `-expr` and `!expr`.
- Added array literal parsing (`[1, 2, 3]`) and `ArrayLiteral` AST node.
- Added array type parsing in variable declarations (`int[]`, `string[]`, etc.).

## Lexer and Tokens

- Added `[` and `]` token kinds (`LBracket`, `RBracket`).
- Added `empty` keyword token (`KwEmpty`) and keyword mapping.
- Added `KwNull` token type in the token enum (currently token kind is defined, but keyword mapping does not yet map `null`).

## Semantic Analysis

- Semantic analysis is now executed from the main program path.
- Implemented semantic handling for:
  - expression statements
  - member-access type resolution for struct fields and methods
  - member-access assignment validation (field existence, mutability, and type compatibility)
  - unary operator type checking
  - array literal element type checking
- Added support for empty array typing through `EMPTY` type kind (`TypeKind.EMPTY`) and array compatibility path for declarations.
- Struct declarations are now registered in semantic context and symbol scope as structure symbols.
- Struct initialization field checks are now enforced for type and initialization completeness.

## Type System

- `Type` now tracks array shape with `isArray: bool`.
- `TypeKind` now includes `EMPTY` for empty-array inference/compatibility flow.

## Tests

- Added parser and semantic regression tests for expression statements and member-access assignments.
- Added dedicated array tests:
  - array literal parsing
  - semantic acceptance for homogeneous arrays
  - semantic rejection for mixed-type arrays
- Test runner now includes `src/tests/arrays.zig`.

## Notes

- Struct method body analysis is still limited in places (method fields are collected in struct metadata, but method-body semantics for receiver-scoped properties are not fully modeled yet).
- Array indexing expressions are still a planned extension.
