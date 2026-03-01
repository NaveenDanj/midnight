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
    Plus,
    Minus,
    Multiply,
    Divide,
    LessThan,
    GreaterThan,
    LessThanEqual,
    GreaterThanEqual,
    NotEqual,

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
