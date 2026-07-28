const std = @import("std");

pub const TokenType = enum {
    Semicolon,
    Comma,
    LParen,
    RParen,
    LCurly,
    RCurly,
    LBracket,
    RBracket,
    Underscore,
    Dot,
    Pipe,
    Ampersand,
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
    BooleanOpAnd,
    BooleanOpOr,
    Modulo,

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
    KwStruct,
    KwEmpty,
    KwPrint,
    KwExtern,

    // keywords with types
    KwInt,
    KwBool,
    KwFloat,
    KwVoid,
    KwString,
    KwNull,

    EOF,
};

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8,
    literal_value: ?[]const u8,
    line: u32,
    column: u32,
};
