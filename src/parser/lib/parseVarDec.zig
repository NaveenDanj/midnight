const Parser = @import("../parser.zig").Parser;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const ParserError = @import("../error.zig").ParserError;
const Expr = @import("./parseExpr.zig").Expr;

pub const VarDecl = struct {
    name: []const u8,
    typeName: []const u8,
    initializer: *Expr,
};

pub fn parseVarDecl(self: *Parser) !*VarDecl {
    if (!self.check(.KwVar) and !self.check(.KwConst)) {
        return ParserError.UnExpectedToken;
    }

    if (self.check(.KwConst)) {
        _ = try self.expect(.KwConst);
    } else {
        _ = try self.expect(.KwVar);
    }

    const dataType = try self.expect(.KwInt);
    const name = try self.expect(.Identifier);
    _ = try self.expect(.Equal);
    const initializer = try parseExpr(self);
    _ = try self.expect(.Semicolon);
    const varDec = try self.allocator.create(VarDecl);

    varDec.* = .{
        .name = name.lexeme,
        .typeName = dataType.lexeme,
        .initializer = initializer,
    };

    return varDec;
}
