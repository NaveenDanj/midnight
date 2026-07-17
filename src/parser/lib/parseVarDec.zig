const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const ParserError = @import("../error.zig").ParserError;
const Expr = @import("../../ast/expr.zig").Expr;
const MemberAccessExpr = @import("../../ast/expr.zig").MemberAccessExpr;
const ast_stmt = @import("../../ast/stmt.zig");
const VarDecl = ast_stmt.VarDecl;
const VarAssign = ast_stmt.VarAssign;
const parseType = @import("./parseTypeRef.zig").parseType;

pub fn parseVarDecl(self: *Parser) !*VarDecl {
    var isImmutable: bool = false;

    if (!self.check(.KwVar) and !self.check(.KwConst)) {
        return ParserError.UnExpectedToken;
    }

    if (self.check(.KwConst)) {
        _ = try self.expect(.KwConst);
        isImmutable = true;
    } else {
        _ = try self.expect(.KwVar);
        isImmutable = false;
    }

    const dataType = try parseType(self);

    const name = try self.expect(.Identifier);
    _ = try self.expect(.Equal);
    const initializer = try parseExpr(self);
    _ = try self.expect(.Semicolon);
    const varDec = try self.allocator.create(VarDecl);

    varDec.* = .{
        .immutable = isImmutable,
        .name = name.lexeme,
        .varType = dataType,
        .initializer = initializer,
    };

    return varDec;
}

pub fn parseVarAssignment(self: *Parser, target: *Expr) ParserError!*VarAssign {
    _ = try self.expect(.Equal);
    const value = try parseExpr(self);
    _ = try self.expect(.Semicolon);

    switch (target.*) {
        .Identifier => {},
        .MemberAccess => {},
        .ArrayAccess => {},
        else => return ParserError.UnExpectedToken,
    }

    const varAssign = try self.allocator.create(VarAssign);
    varAssign.* = .{
        .target = target,
        .value = value,
        .resolvedType = null,
    };

    return varAssign;
}

pub fn parseLSide(self: *Parser) ParserError!*Expr {
    var expr = try parseExpr(self);

    while (true) {
        if (self.check(.Dot)) {
            _ = try self.expect(.Dot);
            const fieldNameToken = try self.expect(.Identifier);

            const fieldAccess = try self.allocator.create(MemberAccessExpr);

            fieldAccess.* = .{
                .object = expr,
                .memberName = fieldNameToken.lexeme,
                .resolvedType = null,
            };

            expr = try self.allocator.create(Expr);
            expr.* = .{ .MemberAccess = fieldAccess.* };
        } else if (self.check(.LBracket)) {
            _ = try self.expect(.LBracket);
            const indexExpr = try parseExpr(self);
            _ = try self.expect(.RBracket);

            const arrayAccess = try self.allocator.create(Expr);
            arrayAccess.* = .{
                .ArrayAccess = .{
                    .array = expr,
                    .index = indexExpr,
                    .resolvedType = null,
                },
            };

            expr = arrayAccess;
        } else {
            break;
        }
    }

    return expr;
}
