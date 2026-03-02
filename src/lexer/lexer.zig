const std = @import("std");
const Token = @import("tokens.zig").Token;
const TokenType = @import("tokens.zig").TokenType;
const lookupKeyword = @import("keywords.zig").lookupKeyword;

pub const Lexer = struct {
    source: []const u8,
    start: usize,
    current: usize,
    line: u32,
    column: u32,

    pub fn init(source: []const u8) Lexer {
        return .{
            .source = source,
            .column = 0,
            .line = 0,
            .start = 0,
            .current = 0,
        };
    }

    pub fn lexAll(self: *Lexer, allocator: std.mem.Allocator) !std.ArrayList(Token) {
        var tokens: std.ArrayList(Token) = .empty;

        while (!self.isAtEnd()) {
            self.start = self.current;
            try tokens.append(allocator, self.scanToken());
        }

        try tokens.append(allocator, Token{
            .kind = TokenType.EOF,
            .lexeme = "",
            .line = self.line,
            .column = self.column,
        });

        return tokens;
    }

    pub fn scanToken(self: *Lexer) Token {
        if (self.isAtEnd()) {
            return self.makeToken(TokenType.EOF);
        }
        const c = self.advance();

        return switch (c) {
            ';' => self.makeToken(TokenType.Semicolon),
            ',' => self.makeToken(TokenType.Comma),
            ')' => self.makeToken(TokenType.RParen),
            '(' => self.makeToken(TokenType.LParen),
            '{' => self.makeToken(TokenType.LCurly),
            '}' => self.makeToken(TokenType.RCurly),

            '+' => self.makeToken(TokenType.Plus),
            '-' => self.makeToken(TokenType.Minus),
            '*' => self.makeToken(TokenType.Multiply),
            '/' => self.makeToken(TokenType.Divide),

            '!' => if (self.isMatch('=')) self.makeToken(TokenType.NotEqual) else self.makeToken(TokenType.BooleanOpNot),
            '=' => if (self.isMatch('=')) self.makeToken(TokenType.DoubleEqual) else self.makeToken(TokenType.Equal),
            '<' => if (self.isMatch('=')) self.makeToken(TokenType.LessThanEqual) else self.makeToken(TokenType.LessThanEqual),
            '>' => if (self.isMatch('=')) self.makeToken(TokenType.GreaterThanEqual) else self.makeToken(TokenType.GreaterThanEqual),

            ' ', '\r', '\t' => self.scanToken(), // skip whitespace
            '\n' => {
                self.line += 1;
                self.column = 0;
                return self.scanToken();
            },

            else => {
                if (std.ascii.isAlphabetic(c)) {
                    while (std.ascii.isAlphabetic(self.peek())) {
                        _ = self.advance();
                    }
                    const ident = self.source[self.start..self.current];
                    const kw = lookupKeyword(ident);
                    if (kw) |token_type| {
                        return self.makeToken(token_type);
                    } else {
                        return self.makeToken(TokenType.Identifier);
                    }
                } else if (std.ascii.isDigit(c)) {
                    while (std.ascii.isDigit(self.peek())) {
                        _ = self.advance();
                    }
                    return self.makeToken(TokenType.Digit);
                } else {
                    return self.makeToken(TokenType.EOF);
                }
            },
        };
    }

    pub fn makeToken(self: *Lexer, kind: TokenType) Token {
        return Token{
            .kind = kind,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = self.column,
        };
    }

    pub fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.source.len;
    }

    pub fn advance(self: *Lexer) u8 {
        if (self.isAtEnd()) {
            return 0;
        }
        const c = self.source[self.current];
        self.column += 1;
        self.current += 1;
        return c;
    }

    pub fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) {
            return 0;
        }
        return self.source[self.current];
    }

    pub fn isMatch(self: *Lexer, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        self.column += 1;
        return true;
    }
};
