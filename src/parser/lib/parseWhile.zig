const Expr = @import("../../ast/expr.zig").Expr;
const ast_stmt = @import("../../ast/stmt.zig");
const BlockStmt = ast_stmt.BlockStmt;
const WhileStatement = ast_stmt.WhileStatement;
const parseBlock = @import("parseBlock.zig").parseBlock;
const Parser = @import("../parser.zig").Parser;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const ParserError = @import("../error.zig").ParserError;

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
