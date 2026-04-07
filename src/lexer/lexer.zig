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
            self.skipWhitespace();
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

    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            switch (c) {
                ' ', '\r', '\t' => {
                    _ = self.advance();
                },
                '\n' => {
                    _ = self.advance();
                    self.line += 1;
                    self.column = 0;
                },
                else => return,
            }
        }
    }

    pub fn scanToken(self: *Lexer) Token {
        if (self.isAtEnd()) {
            return self.makeToken(TokenType.EOF);
        }

        const c = self.advance();

        switch (c) {
            ';' => return self.makeToken(TokenType.Semicolon),
            ',' => return self.makeToken(TokenType.Comma),
            ')' => return self.makeToken(TokenType.RParen),
            '(' => return self.makeToken(TokenType.LParen),
            '{' => return self.makeToken(TokenType.LCurly),
            '}' => return self.makeToken(TokenType.RCurly),
            '[' => return self.makeToken(TokenType.LBracket),
            ']' => return self.makeToken(TokenType.RBracket),
            '.' => return self.makeToken(TokenType.Dot),

            '+' => return self.makeToken(TokenType.Plus),
            '-' => return self.makeToken(TokenType.Minus),
            '*' => return self.makeToken(TokenType.Star),
            '/' => return self.makeToken(TokenType.Slash),
            '"' => return self.scanString(),

            '!' => return if (self.isMatch('='))
                self.makeToken(TokenType.NotEqual)
            else
                self.makeToken(TokenType.BooleanOpNot),

            '=' => return if (self.isMatch('='))
                self.makeToken(TokenType.DoubleEqual)
            else
                self.makeToken(TokenType.Equal),

            '<' => return if (self.isMatch('='))
                self.makeToken(TokenType.LessThanEqual)
            else
                self.makeToken(TokenType.LessThan),

            '>' => return if (self.isMatch('='))
                self.makeToken(TokenType.GreaterThanEqual)
            else
                self.makeToken(TokenType.GreaterThan),

            else => {},
        }

        if (std.ascii.isAlphabetic(c) or c == '_') {
            while (!self.isAtEnd() and
                (std.ascii.isAlphabetic(self.peek()) or
                    std.ascii.isDigit(self.peek()) or
                    self.peek() == '_'))
            {
                _ = self.advance();
            }

            const ident = self.source[self.start..self.current];
            if (lookupKeyword(ident)) |token_type| {
                return self.makeToken(token_type);
            }
            return self.makeToken(TokenType.Identifier);
        }

        if (std.ascii.isDigit(c)) {
            var hasDot = false;
            while (!self.isAtEnd() and (std.ascii.isDigit(self.peek()) or self.peek() == '.')) {
                if (self.peek() == '.') {
                    if (hasDot) {
                        break;
                    }
                    hasDot = true;
                }
                _ = self.advance();
            }

            if (hasDot) {
                return self.makeToken(TokenType.FloatLiteral);
            }
            return self.makeToken(TokenType.IntegerLiteral);
            // return self.makeToken(.Digit);
        }

        return self.makeToken(TokenType.EOF);
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

    pub fn scanString(self: *Lexer) Token {
        while (!self.isAtEnd() and self.peek() != '"') {
            if (self.peek() == '\n') {
                self.line += 1;
                self.column = 0;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            return self.makeToken(TokenType.EOF);
        }

        _ = self.advance();

        return self.makeToken(TokenType.StringLiteral);
    }
};
