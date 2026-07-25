# Error Model

## Parser Errors

Defined in `src/parser/error.zig`:

- `UnexpectedEndOfFile`
- `UnExpectedToken`
- `UnExpectedEndOfLine`
- `TokenNotFound`
- `OutOfMemory`

These are returned directly by parser helpers and the main parser loop.

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
- `FunctionAlreadyDeclared`
- `StructAlreadyDeclared`
- `StructFieldMismatch`
- `StructFieldUnIntialized`
- `UnsupportedStatement`

Current common sources:

- `TypeMismatch`: incompatible assignment, invalid operand types, bad condition types, or bad return types
- `UnsupportedStatement`: non-call expression statements in semantic analysis
- `MissingReturnStatement`: non-void function without a direct return the current analysis can see

## Backend Errors

LLVM backend errors currently include:

- `ArgumentCountMismatch`
- `FunctionNotFound`
- `MissingResolvedType`
- `UnsupportedBinaryOperation`
- `UnsupportedInstruction`
- `UnsupportedType`
- `UnsupportedValue`
- `LLVMModuleVerificationFailed`
- target initialization and emission failures

x86_64 backend errors include unsupported instruction and type cases where lowering is incomplete.

## Current Diagnostic Behavior

- errors bubble up as Zig errors
- Zig prints stack traces with source locations
- there is no compiler-specific pretty printer yet
- there are no source snippets or caret diagnostics yet

## Recommended Next Improvements

1. Replace generic `TypeMismatch` cases with more precise semantic errors.
2. Attach source spans to AST nodes and diagnostics.
3. Add user-facing compiler messages instead of raw Zig stack traces for normal compile failures.
4. Distinguish unsupported features from actual malformed user programs more clearly.
