# Lexer Design

## Files

- `src/lexer/tokens.zig`
- `src/lexer/keywords.zig`
- `src/lexer/lexer.zig`

## Lexer State

`Lexer` tracks:

- `source`: input bytes
- `start`: token start index
- `current`: current cursor index
- `line`: current line number
- `column`: current column number

## Tokenization Algorithm

1. Skip whitespace (` `, `\r`, `\t`, `\n`).
2. Set `start = current`.
3. Scan one token by leading character.
4. Emit token via `makeToken(kind)`.
5. Repeat until `isAtEnd()`.
6. Append EOF token.

## Recognized Token Classes

- delimiters/punctuation
- arithmetic/comparison/equality operators
- identifiers and keywords
- numeric literals (int/float)
- string literals
- boolean literals through keyword mapping

## Keyword Resolution

Identifier lexemes are post-processed by `lookupKeyword`.
If no keyword matches, token kind remains `Identifier`.

## Numeric Literal Rules

- Digits start numeric scanning.
- A single decimal point is allowed.
- If a decimal point exists, token is `FloatLiteral`; otherwise `IntegerLiteral`.

## String Literal Rules

- Strings start on `"`.
- Scanner advances until closing `"`.
- Newlines inside strings increment line counters.
- Unterminated string currently returns EOF token as error fallback.

## Known Lexer Issues and Notes

- Invalid/unknown characters currently fall through to EOF token instead of dedicated lexical error token.
- Column tracks increment with each `advance()`, but token column currently stores ending position rather than start position.
- Comments are not yet implemented.
