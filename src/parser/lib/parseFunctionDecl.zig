const Parser = @import("../parser.zig").Parser;
const std = @import("std");
const parseBlock = @import("./parseBlock.zig").parseBlock;
const ast_stmt = @import("../../ast/stmt.zig");
const FunctionDecl = ast_stmt.FunctionDecl;
const FunctionCallStmt = ast_stmt.FunctionCallStmt;
const ReturnStatement = ast_stmt.ReturnStatement;
const Param = ast_stmt.Param;
const Expr = @import("../../ast/expr.zig").Expr;
const parseType = @import("./parseTypeRef.zig").parseType;
const parseExpr = @import("parseExpr.zig").parseExpr;
const parseArgumentList = @import("parseExpr.zig").parseArgumentList;

pub fn parseFunctionDecl(self: *Parser) !*FunctionDecl {
    _ = try self.expect(.KwFunc);
    const name = try self.expect(.Identifier);
    _ = try self.expect(.LParen);
    const params = try parseParameters(self);

    const returnType = try parseType(self);

    const body = try parseBlock(self);
    const func = try self.allocator.create(FunctionDecl);

    func.* = .{
        .name = name.lexeme,
        .params = params,
        .body = body,
        .returnType = returnType,
    };

    return func;
}

pub fn parseParameters(self: *Parser) ![]*Param {
    const ArrayList = std.ArrayList;
    var params = try ArrayList(*Param).initCapacity(self.allocator, 0);

    while (!self.check(.RParen)) {
        const dataType = try parseType(self);
        const paramName = try self.expect(.Identifier);

        const param = try self.allocator.create(Param);
        param.* = .{
            .dataType = dataType,
            .name = paramName.lexeme,
        };

        try params.append(self.allocator, param);

        if (!self.check(.RParen)) {
            _ = try self.expect(.Comma);
        }
    }

    _ = try self.expect(.RParen);

    return params.toOwnedSlice(self.allocator);
}

pub fn parseReturnStatement(self: *Parser) !*ReturnStatement {
    _ = try self.expect(.KwReturn);
    const expr = try parseExpr(self);
    const ret = try self.allocator.create(ReturnStatement);
    ret.* = .{ .expression = expr };
    _ = try self.expect(.Semicolon);
    return ret;
}

pub fn parseFunctionCall(self: *Parser) !*FunctionCallStmt {
    const funcName = try self.expect(.Identifier);
    const args = try parseArgumentList(self);
    _ = try self.expect(.Semicolon);

    const varAssignment = try self.allocator.create(FunctionCallStmt);
    varAssignment.* = .{ .args = args, .name = funcName.lexeme, .callee = null };
    return varAssignment;
}
