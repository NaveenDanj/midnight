const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const FunctionDecl = @import("./parseFunctionDecl.zig").FunctionDecl;
const BlockStmt = @import("./parseBlock.zig").BlockStmt;
const VariableDecl = @import("./parseVarDec.zig").VarDecl;
const ReturnStatement = @import("./parseFunctionDecl.zig").ReturnStatement;
const IfStatement = @import("parseIf.zig").IfStatement;
const WhileStatement = @import("parseWhile.zig").WhileStatement;

const parseVarDecl = @import("./parseVarDec.zig").parseVarDecl;
const parseReturnStatement = @import("./parseFunctionDecl.zig").parseReturnStatement;
const parseIfStatement = @import("parseIf.zig").parseIfStatement;
const parseWhileStatement = @import("parseWhile.zig").parseWhileStatement;

pub const Statement = union(enum) {
    FunctionDecl: *FunctionDecl,
    Block: *BlockStmt,
    VariableDecl: *VariableDecl,
    ReturnStatement: *ReturnStatement,
    IfStatement: *IfStatement,
    WhileStatement: *WhileStatement,
};

pub fn parseStatement(self: *Parser) ParserError!*Statement {
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
    } else if (self.check(.KwIf)) {
        const ifStatement = try parseIfStatement(self);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .IfStatement = ifStatement };
        return statement;
    } else if (self.check(.KwWhile)) {
        const whileStatement = try parseWhileStatement(self);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .WhileStatement = whileStatement };
        return statement;
    } else {
        return ParserError.UnExpectedToken;
    }
}
