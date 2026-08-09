const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const ast_stmt = @import("../../ast/stmt.zig");
const Param = ast_stmt.Param;
const StructField = ast_stmt.StructField;
const StructStmt = ast_stmt.StructStmt;
const StructPropertyField = ast_stmt.StructPropertyField;
const StructMethodField = ast_stmt.StructMethodField;
const Expr = @import("../../ast/expr.zig").Expr;
const MemberAccessExpr = @import("../../ast/expr.zig").MemberAccessExpr;
const StructInitExpr = @import("../../ast/expr.zig").StructInitExpr;
const StructInitField = @import("../../ast/expr.zig").StructInitField;
const parseExpr = @import("./parseExpr.zig").parseExpr;
const parseParameters = @import("parseFunctionDecl.zig").parseParameters;
const parseType = @import("./parseTypeRef.zig").parseType;
const parseBlock = @import("./parseBlock.zig").parseBlock;

pub fn parseStructStatement(self: *Parser) ParserError!*StructStmt {
    _ = try self.expect(.KwStruct);
    const nameToken = try self.expect(.Identifier);
    _ = try self.expect(.LCurly);

    var structList = try std.ArrayList(StructField).initCapacity(self.allocator, 0);

    while (!self.check(.RCurly)) {
        const fieldType = self.peek() orelse return ParserError.UnExpectedToken;
        switch (fieldType.kind) {
            .KwFunc => {
                const methodField = try parseStructFunc(self);
                try structList.append(self.allocator, .{
                    .StructMethod = methodField,
                });
            },
            .KwVar, .KwConst => {
                const structProperty = try parseStructVariableDecl(self);
                try structList.append(self.allocator, .{ .StructProperty = structProperty });
            },
            else => return ParserError.UnExpectedToken,
        }
    }

    _ = self.advance() orelse return ParserError.UnExpectedToken;

    const structStmt = try self.allocator.create(StructStmt);
    structStmt.* = .{
        .name = nameToken.lexeme,
        .fields = structList.items,
    };

    return structStmt;
}

pub fn parseStructFunc(self: *Parser) ParserError!*StructMethodField {
    _ = try self.expect(.KwFunc);
    const kwFuncName = try self.expect(.Identifier);
    _ = try self.expect(.LParen);
    const paramList = try parseParameters(self);

    const returnType = try parseType(self);

    const body = try parseBlock(self);
    const func = try self.allocator.create(StructMethodField);

    func.* = .{
        .name = kwFuncName.lexeme,
        .parameters = paramList,
        .body = body,
        .returnType = returnType,
    };

    return func;
}

pub fn parseStructVariableDecl(self: *Parser) ParserError!*StructPropertyField {
    var isImmutable = false;

    if (self.check(.KwVar)) {
        _ = try self.expect(.KwVar);
        isImmutable = false;
    } else if (self.check(.KwConst)) {
        _ = try self.expect(.KwConst);
        isImmutable = true;
    } else {
        return ParserError.UnExpectedToken;
    }

    var propType = try parseType(self);

    const fieldNameToken = try self.expect(.Identifier);

    if (self.check(.QuestionMark)) {
        _ = try self.expect(.QuestionMark);
        propType.is_nullable = true;
    }

    _ = try self.expect(.Semicolon);

    const propertyField = try self.allocator.create(StructPropertyField);

    propertyField.* = .{
        .name = fieldNameToken.lexeme,
        .fieldType = propType,
        .isImmutable = isImmutable,
    };

    return propertyField;
}
