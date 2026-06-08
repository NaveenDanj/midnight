const std = @import("std");
const Expr = @import("parseExpr.zig").Expr;
const Type = @import("../../semantic/types.zig").Type;
const Parser = @import("../parser.zig").Parser;
const parseExpr = @import("./parseExpr.zig").parseExpr;

pub const PrintStatement = struct {
    value: *Expr,
    resolvedType: ?Type = null,
};

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
