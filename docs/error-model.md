# Error Model

There are no structured diagnostic objects yet — every layer (lexer, parser, semantic analysis, backends) reports errors as plain Zig error sets that bubble up with Zig's own stack traces. There is no source-span/caret diagnostic printer.

## Lexer Errors

Defined in `src/lexer/lexer.zig` (`LexerError`):

- `UnknownCharacter` — an unrecognized character was encountered
- `UnterminatedString` — a string literal was not closed before end-of-file

## Parser Errors

Defined in `src/parser/error.zig` (`ParserError`, which folds in `LexerError` since the parser drives tokenization):

- `UnexpectedEndOfFile`
- `UnExpectedToken`
- `UnExpectedEndOfLine`
- `TokenNotFound`
- `OutOfMemory`
- `UnknownCharacter`
- `UnterminatedString`

## Semantic Errors

Defined in `src/semantic/semantic_error.zig` (`SemanticError`):

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

Common sources today:

- `TypeMismatch`: incompatible assignment, invalid operand types, bad condition types, or bad return types
- `UnsupportedStatement`: non-call expression statements in semantic analysis
- `MissingReturnStatement`: non-`void` function without a direct return the current (non-path-sensitive) analysis can see

## Backend Errors

x86_64 backend (`src/backend/x86_64/x86_64_backend.zig`, `BackendError`):

- `MissingResolvedType`
- `UnsupportedValue`
- `UnsupportedBinaryOperationType`
- `UnsupportedInstruction`
- `UnsupportedIntegerBinaryOperation`
- `UnsupportedFloatBinaryOperation`
- `UnsupportedStringBinaryOperation`
- `UnsupportedPrintType`

LLVM backend (`src/backend/llvm/llvm_backend.zig`, `LLVMBackendError`):

- `ArgumentCountMismatch`
- `FunctionNotFound`
- `MissingResolvedType`
- `OutOfMemory`
- `UnsupportedBinaryOperation`
- `UnsupportedUnaryOperation`
- `UnsupportedInstruction`
- `UnsupportedType`
- `UnsupportedValue`
- `LLVMModuleVerificationFailed`
- `LLVMTargetInitializationFailed`
- `LLVMTargetLookupFailed`
- `LLVMTargetMachineCreationFailed`
- `LLVMTargetEmissionFailed`

Both backend error sets exist because the two backends are independent codegen paths over the same `[]Instruction` slice — an instruction unsupported by one backend may already be supported by the other.

## Module Resolution Errors

`src/module/module_resolver.zig` reports `error.CircularDependency` when an import cycle is detected while resolving modules.

## Current Diagnostic Behavior

- errors bubble up as Zig errors
- Zig prints stack traces with source locations in the compiler's own code, not in the `.mn` source
- there is no compiler-specific pretty printer yet
- there are no source snippets or caret diagnostics yet

## Recommended Next Improvements

1. Replace generic `TypeMismatch` cases with more precise semantic errors.
2. Attach source spans to AST nodes and diagnostics.
3. Add user-facing compiler messages instead of raw Zig stack traces for normal compile failures.
4. Distinguish unsupported features from actual malformed user programs more clearly.

See [Roadmap](./roadmap.md) for prioritization.
