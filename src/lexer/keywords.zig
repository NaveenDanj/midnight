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
    } else if (std.mem.eql(u8, "true", ident)) {
        return TokenType.KwTrue;
    } else if (std.mem.eql(u8, "false", ident)) {
        return TokenType.KwFalse;
    } else if (std.mem.eql(u8, "func", ident)) {
        return TokenType.KwFunc;
    } else if (std.mem.eql(u8, "var", ident)) {
        return TokenType.KwVar;
    } else {
        return null;
    }
}
