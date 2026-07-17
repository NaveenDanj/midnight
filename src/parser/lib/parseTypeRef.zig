const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const Type = @import("../../semantic/types.zig").Type;
const TokenType = @import("../../lexer/tokens.zig").TokenType;

const primitive_type_tokens = [_]TokenType{ .KwInt, .KwFloat, .KwBool, .KwVoid, .KwString };

pub fn parseType(self: *Parser) ParserError!Type {
    var base_type = try parseBaseType(self);
    base_type = try parseArraySuffix(self, base_type);
    return base_type;
}

pub fn parseBaseType(self: *Parser) ParserError!Type {
    for (primitive_type_tokens) |token_type| {
        if (self.check(token_type)) {
            _ = try self.expect(token_type);
            return try mapPrimitiveType(token_type);
        }
    }

    if (self.check(.Identifier)) {
        const struct_name = try self.expect(.Identifier);
        return Type{ .kind = .STRUCT, .struct_name = struct_name.lexeme };
    }

    return ParserError.UnExpectedToken;
}

pub fn parseArraySuffix(self: *Parser, base_type: Type) ParserError!Type {
    if (self.check(.LBracket)) {
        _ = try self.expect(.LBracket);
        _ = try self.expect(.RBracket);
        return Type{
            .kind = base_type.kind,
            .struct_name = base_type.struct_name,
            .isArray = true,
        };
    }

    return base_type;
}

pub fn mapPrimitiveType(token_type: TokenType) ParserError!Type {
    return switch (token_type) {
        .KwInt => Type{ .kind = .INT },
        .KwFloat => Type{ .kind = .FLOAT },
        .KwBool => Type{ .kind = .BOOL },
        .KwVoid => Type{ .kind = .VOID },
        .KwString => Type{ .kind = .STRING },
        else => ParserError.UnExpectedToken,
    };
}
