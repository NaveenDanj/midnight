const std = @import("std");

pub const TokenType = enum {
    Semicolon,
    Comma,
    LParen,
    RParen,
    LCurly,
    RCurly,

    // operators
    Equal,
    DoubleEqual,
    Plus,
    Minus,
    Multiply,
    Divide,
    LessThan,
    GreaterThan,
    LessThanEqual,
    GreaterThanEqual,
    NotEqual,
    BooleanOpNot,

    // literals
    Identifier,
    Digit,
    String,

    // keywords
    KwInt,
    KwReturn,
    KwIf,
    KwElse,

    EOF,
};

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8,
    line: u32,
    column: u32,
};
