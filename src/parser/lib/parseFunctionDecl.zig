const Parser = @import("../parser.zig").Parser;
const std = @import("std");
const parseBlock = @import("./parseBlock.zig").parseBlock;
const BlockStmt = @import("./parseBlock.zig").BlockStmt;
const Type = @import("../../semantic/types.zig").Type;
const Expr = @import("./parseExpr.zig").Expr;
const parseExpr = @import("./parseExpr.zig").parseExpr;

pub const FunctionDecl = struct {
    name: []const u8,
    params: []*Param,
    body: *BlockStmt,
    returnType: []const u8,
};

pub const ReturnStatement = struct {
    expression: *Expr,
    resolvedType: ?Type = null,
};

const Param = struct { dataType: []const u8, name: []const u8 };

pub fn parseFunctionDecl(self: *Parser) !*FunctionDecl {
    _ = try self.expect(.KwFunc);
    const name = try self.expect(.Identifier);
    _ = try self.expect(.LParen);
    const params = try parseParameters(self);

    const returnTypeToken = try self.expect(.KwInt);

    const body = try parseBlock(self);
    const func = try self.allocator.create(FunctionDecl);

    func.* = .{
        .name = name.lexeme,
        .params = params,
        .body = body,
        .returnType = returnTypeToken.lexeme,
    };

    return func;
}

pub fn parseParameters(self: *Parser) ![]*Param {
    const ArrayList = std.ArrayList;
    var params = try ArrayList(*Param).initCapacity(self.allocator, 0);

    while (!self.check(.RParen)) {
        const dataType = try self.expect(.KwInt);
        const paramName = try self.expect(.Identifier);

        const param = try self.allocator.create(Param);
        param.* = .{
            .dataType = dataType.lexeme,
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
    ret.* = .{ .expression = expr, .resolvedType = null };
    _ = try self.expect(.Semicolon);
    return ret;
}
