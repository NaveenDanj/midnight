const std = @import("std");
const tokens = @import("../lexer//tokens.zig");
const errors = @import("./error.zig").ParserError;
const FunctionDecl = @import("./lib/parseFunctionDecl.zig").FunctionDecl;
const parseFunctionDecl = @import("./lib/parseFunctionDecl.zig").parseFunctionDecl;

pub const Parser = struct {
    tokens: []tokens.Token,
    current: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, tokens_list: []tokens.Token) Parser {
        return .{ .tokens = tokens_list, .current = 0, .allocator = allocator };
    }

    pub fn parseProgram(self: *Parser) ![]*FunctionDecl {
        var functions: std.ArrayList(*FunctionDecl) = .empty;

        while (!self.check(.EOF)) {
            const func = try parseFunctionDecl(self);
            try functions.append(self.allocator, func);
        }

        return functions.items;
    }

    pub fn peek(self: *Parser) ?tokens.Token {
        if (self.current >= self.tokens.len) {
            return null;
        }
        return self.tokens[self.current];
    }

    pub fn advance(self: *Parser) ?tokens.Token {
        if (self.current >= self.tokens.len) {
            return null;
        }

        const token = self.tokens[self.current];
        self.current += 1;
        return token;
    }

    pub fn previous(self: *Parser) ?tokens.Token {
        if (self.current == 1) {
            return null;
        }
        const prevToken = self.tokens[self.current - 1];
        return prevToken;
    }

    pub fn isAtEnd(self: *Parser) bool {
        return self.current == self.tokens.len - 1;
    }

    pub fn match(self: *Parser, kind: tokens.TokenType) bool {
        if (self.isAtEnd()) {
            return false;
        }

        if (self.peek()) |nextToken| {
            if (nextToken.kind == kind) {
                _ = self.advance();
                return true;
            }
        }

        return false;
    }

    pub fn check(self: *Parser, kind: tokens.TokenType) bool {
        const token = self.peek() orelse return false;
        return token.kind == kind;
    }

    pub fn expect(self: *Parser, kind: tokens.TokenType) !tokens.Token {
        if (self.isAtEnd()) {
            return errors.UnexpectedEndOfFile;
        }

        if (self.peek()) |nextToken| {
            if (nextToken.kind == kind) {
                _ = self.advance();
                return nextToken;
            }
        }

        return errors.UnExpectedToken;
    }
};
