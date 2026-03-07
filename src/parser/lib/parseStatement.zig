const Parser = @import("../parser.zig").Parser;
const parseVarDecl = @import("./parseVarDec.zig").parseVarDecl;

const FunctionDecl = @import("./parseFunctionDecl.zig").FunctionDecl;
const BlockStmt = @import("./parseBlock.zig").BlockStmt;
const VariableDecl = @import("./parseVarDec.zig").VarDecl;

pub const Statement = union(enum) {
    FunctionDecl: *FunctionDecl,
    Block: *BlockStmt,
    VariableDecl: *VariableDecl,
};

pub fn parseStatement(self: *Parser) !*Statement {
    if (self.check(.KwVar)) {
        const varDecl = try parseVarDecl(self);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .VariableDecl = varDecl };
        return statement;
    } else {
        return error.UnExpectedToken;
    }
}
