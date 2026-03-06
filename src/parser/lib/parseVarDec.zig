const Parser = @import("../parser.zig").Parser;

pub const VarDecl = struct {
    name: []const u8,
    typeName: []const u8,
    initializer: ?[]const u8,
};

pub fn parseVarDecl(self: *Parser) !*VarDecl {
    _ = try self.expect(.KwVar);
    const dataType = try self.expect(.KwInt);
    const name = try self.expect(.Identifier);
    _ = try self.expect(.Equal);
    const initializer = try self.expect(.Digit);
    _ = try self.expect(.Semicolon);
    const varDec = try self.allocator.create(VarDecl);

    varDec.* = .{
        .name = name.lexeme,
        .typeName = dataType.lexeme,
        .initializer = initializer.lexeme,
    };

    return varDec;
}
