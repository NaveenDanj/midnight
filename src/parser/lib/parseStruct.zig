const std = @import("std");
const Type = @import("../../semantic/types.zig").Type;
const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const Param = @import("parseFunctionDecl.zig").Param;
const Expr = @import("./parseExpr.zig").Expr;
const parseParameters = @import("parseFunctionDecl.zig").parseParameters;
const checkForType = @import("parseVarDec.zig").checkForType;
const parseBlock = @import("./parseBlock.zig").parseBlock;
const BlockStmt = @import("./parseBlock.zig").BlockStmt;

const StructField = union(enum) {
    StructProperty: *StructPropertyField,
    StructMethod: *StructMethodField,
};

pub const StructStmt = struct {
    name: []const u8,
    fields: []StructField,
};

const StructPropertyField = struct {
    name: []const u8,
    fieldType: Type,
    isImmutable: bool,
};

const StructMethodParameter = struct {
    name: []const u8,
    paramType: Type,
};

pub const MemberAccessExpr = struct {
    object: ?*Expr = null,
    memberName: []const u8,
    resolvedType: ?Type = null,
};

pub const StructInitExpr = struct {
    structName: []const u8,
    fields: []StructInitField,
    resolvedType: ?Type = null,
};

pub const StructInitField = struct {
    name: []const u8,
    value: *Expr,
};

const StructMethodField = struct { name: []const u8, parameters: []*Param, body: *BlockStmt, returnType: Type };

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

    const returnType = try checkForType(self);

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

    const propType = try checkForType(self);

    const fieldNameToken = try self.expect(.Identifier);
    _ = try self.expect(.Semicolon);

    const propertyField = try self.allocator.create(StructPropertyField);

    propertyField.* = .{
        .name = fieldNameToken.lexeme,
        .fieldType = propType,
        .isImmutable = isImmutable,
    };

    return propertyField;
}
