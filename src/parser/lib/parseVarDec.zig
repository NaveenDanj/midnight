const Parser = @import("../parser.zig").Parser;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const ParserError = @import("../error.zig").ParserError;
const Expr = @import("./parseExpr.zig").Expr;
const Type = @import("../../semantic/types.zig").Type;
const TypeKind = @import("../../semantic/types.zig").TypeKind;
const TokenType = @import("../../lexer/tokens.zig").TokenType;

pub const VarDecl = struct {
    immutable: bool,
    name: []const u8,
    varType: Type,
    initializer: *Expr,
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

pub fn checkForType(self: *Parser) ParserError!Type {
    for (varTypeList) |dataType| {
        if (self.check(dataType)) {
            _ = try self.expect(dataType);
            return mapType(dataType);
        }
    }

    return ParserError.UnExpectedToken;
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
