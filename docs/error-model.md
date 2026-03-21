# Error Model

## Parser Errors

Defined in `src/parser/error.zig`:

- `UnexpectedEndOfFile`
- `UnExpectedToken`
- `UnExpectedEndOfLine`
- `TokenNotFound`
- `OutOfMemory`

Parser and parse helpers return these errors directly.

## Semantic Errors

Defined in `src/semantic/semantic_error.zig`:

- `TypeMismatch`
- `UndefinedVariable`
- `UndefinedFunction`
- `SymbolAlreadyDeclared`
- `OutOfMemory`
- `MissingReturnStatement`
- `SymbolImmutable`
- `ArgumentCountMismatch`

Semantic analyzer propagates these errors directly to caller (`main.zig`).

## Runtime Diagnostic Behavior

- On error, Zig prints stack trace with file and line locations.
- No compiler-specific pretty diagnostics are emitted yet.
- No source snippet extraction or caret-style user-facing diagnostics yet.

## Recommended Diagnostic Improvements

1. Define unified compiler diagnostic struct with:
   - phase (`lexer`, `parser`, `semantic`)
   - message
   - token/span location
   - optional note list
2. Replace broad `TypeMismatch` with targeted variants:
   - `InvalidBinaryOperandTypes`
   - `InvalidReturnType`
   - `InvalidAssignmentType`
   - `ConditionMustBeBool`
3. Preserve original token line/column and lexeme for all diagnostics.
4. Add parser synchronization points (for example at `;` or `}`) to continue after certain syntax errors.
