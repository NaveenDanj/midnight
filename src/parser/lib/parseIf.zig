const std = @import("std");
const Expr = @import("parseExpr.zig").Expr;
const BlockStmt = @import("parseBlock.zig").BlockStmt;
const parseBlock = @import("parseBlock.zig").parseBlock;
const Parser = @import("../parser.zig").Parser;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const ParserError = @import("../error.zig").ParserError;

pub const IfStatement = struct {
    expression: *Expr,
    thenBlock: *BlockStmt,
    elseBlock: ?*BlockStmt = null,
};

pub fn parseIfStatement(self: *Parser) ParserError!*IfStatement {
    _ = try self.expect(.KwIf);
    _ = try self.expect(.LParen);
    const expr = try parseExpr(self);
    _ = try self.expect(.RParen);

    const thenBlock = try parseBlock(self);

    var elseBlock: ?*BlockStmt = null;

    if (self.check(.KwElse)) {
        _ = try self.expect(.KwElse);
        elseBlock = try parseBlock(self);
    }

    const stmt = try self.allocator.create(IfStatement);
    stmt.* = .{
        .expression = expr,
        .thenBlock = thenBlock,
        .elseBlock = elseBlock,
    };

    return stmt;
}
