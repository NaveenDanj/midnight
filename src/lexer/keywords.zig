const std = @import("std");
const TokenType = @import("tokens.zig").TokenType;

pub fn lookupKeyword(ident: []const u8) ?TokenType {
    if (std.mem.eql(u8, "int", ident)) {
        return TokenType.KwInt;
    } else if (std.mem.eql(u8, "return", ident)) {
        return TokenType.KwReturn;
    } else if (std.mem.eql(u8, "if", ident)) {
        return TokenType.KwIf;
    } else if (std.mem.eql(u8, "else", ident)) {
        return TokenType.KwElse;
    } else {
        return null;
    }
}
