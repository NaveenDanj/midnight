const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const ParserError = @import("../error.zig").ParserError;
const Expr = @import("./parseExpr.zig").Expr;
const Type = @import("../../semantic/types.zig").Type;
const TypeKind = @import("../../semantic/types.zig").TypeKind;
const TokenType = @import("../../lexer/tokens.zig").TokenType;
const MemberAccessExpr = @import("./parseStruct.zig").MemberAccessExpr;


pub const VarDecl = struct {
    immutable: bool,
    name: []const u8,
    varType: Type,
    initializer: *Expr,
};

pub const VarAssign = struct {
    target: *Expr,
    value: *Expr,
};

pub const varTypeList = [_]TokenType{ .KwInt, .KwFloat, .KwBool, .KwVoid, .KwString };

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

    const dataType = try checkForType(self);
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

pub fn parseVarAssignment(self: *Parser , target: *Expr) ParserError!*VarAssign {
    _ = try self.expect(.Equal);
    const value = try parseExpr(self);
    _ = try self.expect(.Semicolon);

    // TODO: we should ideally check if the target is a valid lvalue (identifier or member access) here and return an error if it's not. For now, we'll just assume the programmer is doing the right thing and handle errors during semantic analysis.
    switch (target.*) {
        .Identifier => {},
        .MemberAccess => {},
        else => return ParserError.UnExpectedToken,
    }

    const varAssign = try self.allocator.create(VarAssign);
    varAssign.* = .{
        .target = target,
        .value = value,
    };

    return varAssign;
}

pub fn checkForType(self: *Parser) ParserError!Type {

    // check for primitive types
    for (varTypeList) |dataType| {
        if (self.check(dataType)) {
            _ = try self.expect(dataType);
            return mapType(dataType);
        }
    }

    // check for user defined struct types
    if (self.check(.Identifier)) {
        const structNameToken = try self.expect(.Identifier);
        return Type{ .kind = .STRUCT, .struct_name = structNameToken.lexeme };
    }

    return ParserError.UnExpectedToken;
}

pub fn parseLSide (self: *Parser) ParserError!*Expr {
    var expr = try parseExpr(self);

    while(true) {
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
        // TODO: add support for array indexing here
        } else {
            break;
        }
    }

    return expr;
}


pub fn mapType(tokenTypeKind: TokenType) Type {
    return switch (tokenTypeKind) {
        .KwInt => Type{ .kind = .INT },
        .KwFloat => Type{ .kind = .FLOAT },
        .KwBool => Type{ .kind = .BOOL },
        .KwVoid => Type{ .kind = .VOID },
        .KwString => Type{ .kind = .STRING },
        else => Type{ .kind = .VOID },
    };
}
