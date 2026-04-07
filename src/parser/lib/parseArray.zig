const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const Type = @import("../../semantic/types.zig").Type;
const TokenType = @import("../../lexer/tokens.zig").TokenType;
const Expr = @import("./parseExpr.zig").Expr;
const parseExpr = @import("./parseExpr.zig").parseExpr;

pub const ArrayExpression = struct {
    elements: []*Expr,
    resolvedType: ?Type = null,
};

pub fn parseArrayExpression(self: *Parser) ParserError!*Expr {
    _ = try self.expect(.LBracket);
    var elementsList: std.ArrayList(*Expr) = .empty;

    if (!self.check(.RBracket)) {
        while (true) {
            const element = try parseExpr(self);
            try elementsList.append(self.allocator, element);

            if (self.check(.Comma)) {
                _ = try self.expect(.Comma);
            } else {
                break;
            }
        }
    }

    _ = try self.expect(.RBracket);

    const arrayExpr = try self.allocator.create(Expr);
    arrayExpr.* = .{
        .ArrayLiteral = ArrayExpression{
            .elements = elementsList.items,
            .resolvedType = null,
        },
    };

    return arrayExpr;
}