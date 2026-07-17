const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const ast_stmt = @import("../../ast/stmt.zig");
const Statement = ast_stmt.Statement;
const FunctionDecl = ast_stmt.FunctionDecl;
const BlockStmt = ast_stmt.BlockStmt;
const VariableDecl = ast_stmt.VarDecl;
const ReturnStatement = ast_stmt.ReturnStatement;
const IfStatement = ast_stmt.IfStatement;
const WhileStatement = ast_stmt.WhileStatement;
const StructStmt = ast_stmt.StructStmt;
const VarAssign = ast_stmt.VarAssign;
const PrintStatement = ast_stmt.PrintStatement;
const FunctionCallStmt = ast_stmt.FunctionCallStmt;
const Expr = @import("../../ast/expr.zig").Expr;

const parseVarDecl = @import("./parseVarDec.zig").parseVarDecl;
const parseReturnStatement = @import("./parseFunctionDecl.zig").parseReturnStatement;
const parseIfStatement = @import("parseIf.zig").parseIfStatement;
const parseWhileStatement = @import("parseWhile.zig").parseWhileStatement;
const parseFunctionDecl = @import("./parseFunctionDecl.zig").parseFunctionDecl;
const parseStructStatement = @import("./parseStruct.zig").parseStructStatement;
const parseVarAssignment = @import("./parseVarDec.zig").parseVarAssignment;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const parsePrintStatement = @import("./parsePrint.zig").parsePrintStatement;

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
    } else if (self.check(.KwPrint)) {
        const printStatement = try parsePrintStatement(self);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .PrintStatement = printStatement };
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
