const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const Statement = @import("./parseStatement.zig").Statement;
const parseStatement = @import("./parseStatement.zig").parseStatement;
const ParserError = @import("../error.zig").ParserError;

pub const BlockStmt = struct {
    statements: []*Statement,
};

pub fn parseBlock(self: *Parser) ParserError!*BlockStmt {
    _ = try self.expect(.LCurly);
    const ArrayList = std.ArrayList;
    var statements = try ArrayList(*Statement).initCapacity(self.allocator, 0);

    while (!self.check(.RCurly)) {
        const stmt = try parseStatement(self);
        try statements.append(self.allocator, stmt);
    }

    _ = self.advance();

    const block = try self.allocator.create(BlockStmt);
    block.* = .{
        .statements = statements.items,
    };

    return block;
}
