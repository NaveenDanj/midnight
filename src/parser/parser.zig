const tokens = @import("../lexer//tokens.zig");

pub const Parser = struct {
    tokens: []tokens.Token,
    current: usize,

    pub fn Init(tokens_list: []tokens.Token) Parser {
        return .{
            .tokens = tokens_list,
            .current = 0,
        };
    }

    fn peek(self: *Parser) ?tokens.Token {
        if (self.current >= self.tokens.len) {
            return null;
        }
        return self.tokens[self.current + 1];
    }

    fn advance(self: *Parser) ?tokens.Token {
        if (self.current >= self.tokens.len) {
            return null;
        }

        const token = self.tokens[self.current];
        self.current += 1;
        return token;
    }

    fn isAtEnd(self: *Parser) bool {
        return self.current == self.tokens.len - 1;
    }

    fn match(self: *Parser, kind: tokens.TokenType) bool {
        if (self.isAtEnd()) {
            return false;
        }

        const nextToken = self.peek();

        if (nextToken == null) {
            return false;
        }

        if (nextToken.kind == kind) {
            self.advance();
            return true;
        }

        return false;
    }

    // fn expect(self: *Parser, kind: tokens.TokenType) !tokens.Token {

    //     if (self.isAtEnd()) {
    //         return error.Un
    //     }

    // }

};
