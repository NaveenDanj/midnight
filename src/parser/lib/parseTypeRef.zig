const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const TypeRef = @import("../../ast/type_ref.zig").TypeRef;
const TokenType = @import("../../lexer/tokens.zig").TokenType;
const std = @import("std");

const primitive_type_tokens = [_]TokenType{ .KwInt, .KwFloat, .KwBool, .KwVoid, .KwString };

pub fn parseType(self: *Parser) ParserError!TypeRef {
    var base_type = try parseBaseType(self);
    base_type = try parseArraySuffix(self, base_type);

    if (self.check(.QuestionMark)) {
        _ = try self.expect(.QuestionMark);
        base_type.is_nullable = true;
    }

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

        var array_type = TypeRef{
            .name = base_type.name,
            .is_array = true,
            .dynamic_array = false,
            .static_length = null,
        };

        if (self.check(.IntegerLiteral)) {
            const length = try self.expect(.IntegerLiteral);
            array_type.static_length = std.fmt.parseInt(u32, length.lexeme, 10) catch return ParserError.UnExpectedToken;
        } else if (self.check(.Underscore)) {
            _ = try self.expect(.Underscore);
            array_type.dynamic_array = true;
        } else if (self.check(.RBracket)) {
            // Keep `int[]` working as a shorthand for dynamic arrays.
            array_type.dynamic_array = true;
        } else {
            return ParserError.UnExpectedToken;
        }

        _ = try self.expect(.RBracket);
        return array_type;
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
