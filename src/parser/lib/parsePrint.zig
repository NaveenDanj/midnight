const std = @import("std");
const Expr = @import("../../ast/expr.zig").Expr;
const PrintStatement = @import("../../ast/stmt.zig").PrintStatement;
const Parser = @import("../parser.zig").Parser;
const parseExpr = @import("./parseExpr.zig").parseExpr;

pub fn parsePrintStatement(self: *Parser) !*PrintStatement {
    _ = try self.expect(.KwPrint);
    const value = try parseExpr(self);
    _ = try self.expect(.Semicolon);

    const stmt = try self.allocator.create(PrintStatement);
    stmt.* = .{
        .value = value,
        .resolvedType = null,
    };

    return stmt;
}
