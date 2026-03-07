const std = @import("std");
const TokenType = @import("../../lexer/tokens.zig").TokenType;

pub const Precedence = enum(u8) { lowest = 0, sum, product };

pub fn mapOperatorToPrecedence(token: TokenType) Precedence {
    return switch (token) {
        .Plus, .Minus => Precedence.sum,
        .Star, .Slash => Precedence.product,
        else => Precedence.lowest,
    };
}
