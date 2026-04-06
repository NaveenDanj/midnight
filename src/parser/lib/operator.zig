const std = @import("std");
const TokenType = @import("../../lexer/tokens.zig").TokenType;

pub const Precedence = enum(u8) { lowest = 0, equality, comparison, sum, product, prefix, postfix };

pub fn mapOperatorToPrecedence(token: TokenType) Precedence {
    return switch (token) {
        .BooleanOpNot => Precedence.prefix,
        .Plus, .Minus => Precedence.sum,
        .Star, .Slash => Precedence.product,
        .LessThan, .LessThanEqual => Precedence.comparison,
        .GreaterThan, .GreaterThanEqual => Precedence.comparison,
        .DoubleEqual, .NotEqual => Precedence.equality,
        else => Precedence.lowest,
    };
}
