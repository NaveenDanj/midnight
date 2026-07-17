const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const Precedence = @import("./operator.zig").Precedence;
const mapOperatorToPrecedence = @import("./operator.zig").mapOperatorToPrecedence;
const Token = @import("../../lexer/tokens.zig").Token;
const ast = @import("../../ast/expr.zig");
const Expr = ast.Expr;
const BinaryExpr = ast.BinaryExpr;
const IdentifierExpr = ast.IdentifierExpr;
const UnaryExpr = ast.UnaryExpr;
const FunctionCallStmt = ast.FunctionCallStmt;
const MemberAccessExpr = ast.MemberAccessExpr;
const StructInitExpr = ast.StructInitExpr;
const StructInitField = ast.StructInitField;
const ArrayAccess = ast.ArrayAccess;
const parseArrayExpression = @import("./parseArray.zig").parseArrayExpression;

pub fn parseExpr(self: *Parser) ParserError!*Expr {
    return try parsePrecedence(self, .lowest);
}

pub fn parsePrecedence(self: *Parser, precedence: Precedence) ParserError!*Expr {
    var left = try parsePrefix(self);

    while (true) {
        const next = self.peek() orelse break;
        const next_prec = mapOperatorToPrecedence(next.kind);

        if (@intFromEnum(precedence) >= @intFromEnum(next_prec))
            break;

        const op = self.advance() orelse return ParserError.UnExpectedToken;
        left = try parseInfix(self, left, op);
    }

    return left;
}

pub fn parseInfix(self: *Parser, left: *Expr, op: Token) ParserError!*Expr {
    const precedence = mapOperatorToPrecedence(op.kind);
    const right = try parsePrecedence(self, precedence);

    const binary = BinaryExpr{
        .left = left,
        .operator = op.lexeme,
        .right = right,
    };

    const expr = try self.allocator.create(Expr);
    expr.* = .{ .Binary = binary };

    return expr;
}

pub fn parsePrefix(self: *Parser) ParserError!*Expr {
    if (self.check(.Minus) or self.check(.BooleanOpNot)) {
        const op = self.advance() orelse return ParserError.UnExpectedToken;
        const right = try parsePrecedence(self, .prefix);

        const unary = UnaryExpr{
            .operator = op.lexeme,
            .operand = right,
        };

        const expr = try self.allocator.create(Expr);
        expr.* = .{ .Unary = unary };

        return expr;
    }

    return try parsePostFix(self);
}

pub fn parsePostFix(self: *Parser) ParserError!*Expr {
    var expr = try parsePrimary(self);

    while (true) {
        if (self.match(.Dot)) {
            const memberNameToken = try self.expect(.Identifier);

            const memberAccess = MemberAccessExpr{
                .object = expr,
                .memberName = memberNameToken.lexeme,
            };

            const newExpr = try self.allocator.create(Expr);
            newExpr.* = .{ .MemberAccess = memberAccess };
            expr = newExpr;
        } else if (self.check(.LParen)) {
            const args = try parseArgumentList(self);
            const funcCall = FunctionCallStmt{
                .name = switch (expr.*) {
                    .Identifier => expr.Identifier.name,
                    .MemberAccess => expr.MemberAccess.memberName,
                    else => return ParserError.UnExpectedToken,
                },
                .args = args,
                .callee = expr,
            };

            const newExpr = try self.allocator.create(Expr);
            newExpr.* = .{ .FunctionCall = funcCall };
            expr = newExpr;
        } else if (self.match(.LBracket)) {
            const indexExpr = try parseExpr(self);
            _ = try self.expect(.RBracket);

            const arrayAccess = ArrayAccess{
                .array = expr,
                .index = indexExpr,
            };

            const newExpr = try self.allocator.create(Expr);
            newExpr.* = .{ .ArrayAccess = arrayAccess };
            expr = newExpr;
        } else break;
    }
    return expr;
}

pub fn parseArgumentList(self: *Parser) ParserError![]*Expr {
    _ = try self.expect(.LParen);

    var args = try std.ArrayList(*Expr).initCapacity(self.allocator, 0);

    while (!self.check(.RParen)) {
        const arg = try parseExpr(self);
        try args.append(self.allocator, arg);

        if (!self.check(.RParen)) {
            _ = try self.expect(.Comma);
        }
    }

    _ = try self.expect(.RParen);
    return args.items;
}

pub fn parsePrimary(self: *Parser) ParserError!*Expr {
    if (self.check(.Identifier) and self.peekNext().?.kind == .LCurly) {
        return try parseStructInitExpr(self);
    }

    if (self.check(.LBracket)) {
        return try parseArrayExpression(self);
    }

    if (self.check(.Identifier)) {
        return try parseIdentifier(self);
    }

    if (self.check(.IntegerLiteral)) {
        return try parseInteger(self);
    }

    if (self.check(.FloatLiteral)) {
        return try parseFloat(self);
    }

    if (self.check(.StringLiteral)) {
        return try parseString(self);
    }

    if (self.check(.KwTrue) or self.check(.KwFalse)) {
        return try parseBoolean(self);
    }

    if (self.match(.LParen)) {
        const expr = try parseExpr(self);
        _ = try self.expect(.RParen);
        return expr;
    }

    return ParserError.UnExpectedToken;
}

pub fn parseInteger(self: *Parser) ParserError!*Expr {
    const token = try self.expect(.IntegerLiteral);
    const intLiteral = ast.IntLiteral{
        .value = std.fmt.parseInt(i64, token.lexeme, 10) catch 0,
    };
    const expr = try self.allocator.create(Expr);
    expr.* = .{ .IntLiteral = intLiteral };
    return expr;
}

pub fn parseFloat(self: *Parser) ParserError!*Expr {
    const token = try self.expect(.FloatLiteral);
    const floatLiteral = ast.FloatLiteral{
        .value = std.fmt.parseFloat(f64, token.lexeme) catch 0,
    };
    const expr = try self.allocator.create(Expr);
    expr.* = .{ .FloatLiteral = floatLiteral };
    return expr;
}

pub fn parseBoolean(self: *Parser) ParserError!*Expr {
    const boolCheckToken = self.check(.KwTrue);

    if (boolCheckToken) {
        _ = try self.expect(.KwTrue);
        const boolLiteral = ast.BooleanLiteral{
            .value = true,
        };

        const expr = try self.allocator.create(Expr);
        expr.* = .{ .BoolLiteral = boolLiteral };
        return expr;
    } else {
        _ = try self.expect(.KwFalse);
        const boolLiteral = ast.BooleanLiteral{
            .value = false,
        };

        const expr = try self.allocator.create(Expr);
        expr.* = .{ .BoolLiteral = boolLiteral };
        return expr;
    }
}

pub fn parseString(self: *Parser) ParserError!*Expr {
    const token = try self.expect(.StringLiteral);
    const stringLiteral = ast.StringLiteral{
        .value = token.lexeme,
    };
    const expr = try self.allocator.create(Expr);
    expr.* = .{ .StringLiteral = stringLiteral };
    return expr;
}

pub fn parseIdentifier(self: *Parser) ParserError!*Expr {
    const token = try self.expect(.Identifier);

    const ident = IdentifierExpr{
        .name = token.lexeme,
    };

    const expr = try self.allocator.create(Expr);
    expr.* = .{ .Identifier = ident };

    return expr;
}

pub fn parseFuncCallExpr(self: *Parser) ParserError!*Expr {
    const funcName = try self.expect(.Identifier);
    const args = try parseArgumentList(self);

    const funcCall = FunctionCallStmt{
        .name = funcName.lexeme,
        .args = args,
    };

    const expr = try self.allocator.create(Expr);
    expr.* = .{ .FunctionCall = funcCall };
    return expr;
}

pub fn parseStructInitExpr(self: *Parser) ParserError!*Expr {
    const structNameToken = try self.expect(.Identifier);
    _ = try self.expect(.LCurly);

    var fieldList = try std.ArrayList(StructInitField).initCapacity(self.allocator, 0);

    while (!self.check(.RCurly)) {
        const fieldNameToken = try self.expect(.Identifier);
        _ = try self.expect(.Equal);
        const fieldValue = try parseExpr(self);

        const field = StructInitField{
            .name = fieldNameToken.lexeme,
            .value = fieldValue,
        };

        try fieldList.append(self.allocator, field);

        if (!self.check(.RCurly)) {
            _ = try self.expect(.Comma);
        }
    }

    _ = try self.expect(.RCurly);

    const structInit = StructInitExpr{
        .structName = structNameToken.lexeme,
        .fields = fieldList.items,
    };

    const expr = try self.allocator.create(Expr);
    expr.* = .{ .StructInit = structInit };
    return expr;
}
