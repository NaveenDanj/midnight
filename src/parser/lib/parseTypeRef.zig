const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const TypeRef = @import("../../ast/type_ref.zig").TypeRef;
const TokenType = @import("../../lexer/tokens.zig").TokenType;

const primitive_type_tokens = [_]TokenType{ .KwInt, .KwFloat, .KwBool, .KwVoid, .KwString };

pub fn parseType(self: *Parser) ParserError!TypeRef {
    var base_type = try parseBaseType(self);
    base_type = try parseArraySuffix(self, base_type);
    return base_type;
}

pub fn parseBaseType(self: *Parser) ParserError!TypeRef {
    for (primitive_type_tokens) |token_type| {
        if (self.check(token_type)) {
            _ = try self.expect(token_type);
            return try mapPrimitiveType(token_type);
        }
    }

    if (self.check(.Identifier)) {
        const struct_name = try self.expect(.Identifier);
        return TypeRef{ .name = struct_name.lexeme };
    }

    return ParserError.UnExpectedToken;
}

pub fn parseArraySuffix(self: *Parser, base_type: TypeRef) ParserError!TypeRef {
    if (self.check(.LBracket)) {
        _ = try self.expect(.LBracket);
        _ = try self.expect(.RBracket);
        return TypeRef{ .name = base_type.name, .is_array = true };
    }

    return base_type;
}

pub fn mapPrimitiveType(token_type: TokenType) ParserError!TypeRef {
    return switch (token_type) {
        .KwInt => TypeRef{ .name = "int" },
        .KwFloat => TypeRef{ .name = "float" },
        .KwBool => TypeRef{ .name = "bool" },
        .KwVoid => TypeRef{ .name = "void" },
        .KwString => TypeRef{ .name = "string" },
        else => ParserError.UnExpectedToken,
    };
}
