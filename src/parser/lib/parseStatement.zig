const Parser = @import("../parser.zig").Parser;
const FunctionDecl = @import("./parseFunctionDecl.zig").FunctionDecl;
const BlockStmt = @import("./parseBlock.zig").BlockStmt;
const VariableDecl = @import("./parseVarDec.zig").VarDecl;
const ReturnStatement = @import("./parseFunctionDecl.zig").ReturnStatement;

const parseVarDecl = @import("./parseVarDec.zig").parseVarDecl;
const parseReturnStatement = @import("./parseFunctionDecl.zig").parseReturnStatement;

pub const Statement = union(enum) {
    FunctionDecl: *FunctionDecl,
    Block: *BlockStmt,
    VariableDecl: *VariableDecl,
    ReturnStatement: *ReturnStatement,
};

pub fn parseStatement(self: *Parser) !*Statement {
    if (self.check(.KwVar)) {
        const varDecl = try parseVarDecl(self);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .VariableDecl = varDecl };
        return statement;
    } else if (self.check(.KwReturn)) {
        const retStatement = try parseReturnStatement(self);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .ReturnStatement = retStatement };
        return statement;
    } else {
        return error.UnExpectedToken;
    }
}
