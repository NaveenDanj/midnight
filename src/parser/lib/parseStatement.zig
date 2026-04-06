const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const FunctionDecl = @import("./parseFunctionDecl.zig").FunctionDecl;
const BlockStmt = @import("./parseBlock.zig").BlockStmt;
const VariableDecl = @import("./parseVarDec.zig").VarDecl;
const ReturnStatement = @import("./parseFunctionDecl.zig").ReturnStatement;
const IfStatement = @import("parseIf.zig").IfStatement;
const WhileStatement = @import("parseWhile.zig").WhileStatement;
const StructStmt = @import("./parseStruct.zig").StructStmt;
const VarAssign = @import("./parseVarDec.zig").VarAssign;
const FunctionCallStmt = @import("./parseFunctionDecl.zig").FunctionCallStmt;

const parseVarDecl = @import("./parseVarDec.zig").parseVarDecl;
const parseReturnStatement = @import("./parseFunctionDecl.zig").parseReturnStatement;
const parseIfStatement = @import("parseIf.zig").parseIfStatement;
const parseWhileStatement = @import("parseWhile.zig").parseWhileStatement;
const parseFunctionDecl = @import("./parseFunctionDecl.zig").parseFunctionDecl;
const parseStructStatement = @import("./parseStruct.zig").parseStructStatement;
const parseVarAssignment = @import("./parseVarDec.zig").parseVarAssignment;
const parseFunctionCall = @import("parseFunctionDecl.zig").parseFunctionCall;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const Expr = @import("./parseExpr.zig").Expr;

pub const Statement = union(enum) { FunctionDecl: *FunctionDecl, Block: *BlockStmt, VariableDecl: *VariableDecl, ReturnStatement: *ReturnStatement, IfStatement: *IfStatement, WhileStatement: *WhileStatement, StructDecl: *StructStmt, VarAssignment: *VarAssign, FunctionCallStatement: *FunctionCallStmt , ExpressionStmt: *Expr };

pub fn parseStatement(self: *Parser) ParserError!*Statement {
    if (self.check(.KwVar) or self.check(.KwConst)) {
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
    } else if (self.check(.KwFunc)) {
        const funcDecl = try parseFunctionDecl(self);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .FunctionDecl = funcDecl };
        return statement;
    } else if (self.check(.KwStruct)) {
        const structDecl = try parseStructStatement(self);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .StructDecl = structDecl };
        return statement;  
    } else {
        return try parseExpressionStatement(self);
    }
}




fn parseExpressionStatement(self: *Parser) ParserError!*Statement {
    const expr = try parseExpr(self);
    if (self.check(.Equal)) {
        const varAssign = try parseVarAssignment(self, expr);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .VarAssignment = varAssign };
        return statement;
    } else if (self.check(.Semicolon)) {
        _ = try self.expect(.Semicolon);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .ExpressionStmt = expr };
        return statement;
    } 
    
    return ParserError.UnExpectedToken;

}