const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const ast = @import("../../ast/expr.zig");
const Expr = ast.Expr;
const ArrayExpression = ast.ArrayExpression;
const parseExpr = @import("./parseExpr.zig").parseExpr;

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
