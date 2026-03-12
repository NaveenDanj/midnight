const std = @import("std");

pub const TokenType = enum {
    Semicolon,
    Comma,
    LParen,
    RParen,
    LCurly,
    RCurly,
    Underscore,
    Dot,

    // operators
    Equal,
    DoubleEqual,
    Plus,
    Minus,
    Star,
    Slash,
    LessThan,
    GreaterThan,
    LessThanEqual,
    GreaterThanEqual,
    NotEqual,
    BooleanOpNot,

    // literals
    Identifier,
    Digit,
    IntegerLiteral,
    FloatLiteral,
    StringLiteral,
    BooleanLiteral,

    // boolean literals
    KwTrue,
    KwFalse,

    // keywords
    KwReturn,
    KwIf,
    KwElse,
    KwFunc,
    KwVar,
    KwWhile,
    KwConst,

    // keywords with types
    KwInt,
    KwBool,
    KwFloat,
    KwVoid,
    KwString,

    EOF,
};

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8,
    line: u32,
    column: u32,
};
