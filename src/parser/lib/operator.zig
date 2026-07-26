const std = @import("std");
const TokenType = @import("../../lexer/tokens.zig").TokenType;

pub const Precedence = enum(u8) {
    lowest = 0,
    logical_or,
    logical_and,
    equality,
    comparison,
    sum,
    product,
    prefix,
    postfix,
};

pub fn mapOperatorToPrecedence(token: TokenType) Precedence {
    return switch (token) {
        .BooleanOpNot => .prefix,

        .Star, .Slash, .Modulo => .product,
        .Plus, .Minus => .sum,

        .LessThan,
        .LessThanEqual,
        .GreaterThan,
        .GreaterThanEqual,
        => .comparison,

        .DoubleEqual,
        .NotEqual,
        => .equality,

        .BooleanOpAnd => .logical_and,
        .BooleanOpOr => .logical_or,

        else => .lowest,
    };
}
