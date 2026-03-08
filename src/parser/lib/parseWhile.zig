const Expr = @import("parseExpr.zig").Expr;
const BlockStmt = @import("parseBlock.zig").BlockStmt;
const parseBlock = @import("parseBlock.zig").parseBlock;
const Parser = @import("../parser.zig").Parser;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const ParserError = @import("../error.zig").ParserError;

pub const WhileStatement = struct {
    expression: *Expr,
    body: *BlockStmt,
};

pub fn parseWhileStatement(self: *Parser) ParserError!*WhileStatement {
    _ = try self.expect(.KwWhile);
    _ = try self.expect(.LParen);
    const expr = try parseExpr(self);
    _ = try self.expect(.RParen);
    const block = try parseBlock(self);
    const whileStmt = try self.allocator.create(WhileStatement);
    whileStmt.* = .{ .expression = expr, .body = block };
    return whileStmt;
}
