const std = @import("std");
const Instruction = @import("../ir.zig").Instruction;
const Value = @import("../ir.zig").Value;
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const Expr = @import("../../ast/expr.zig").Expr;
const BinaryOp = @import("../ir.zig").BinaryOp;
const LowerError = @import("../lower_error.zig").LowerError;
const SemanticResult = @import("../../semantic/result.zig").SemanticResult;
const Type = @import("../../semantic/types.zig").Type;

pub fn lowerExpression(builder: *InstructionBuilder, expr: *Expr) !Value {
    return lowerExpressionWithSemanticsAndExpectedType(builder, expr, null, null);
}

pub fn lowerExpressionWithSemantics(builder: *InstructionBuilder, expr: *Expr, semantic: ?*const SemanticResult) !Value {
    return lowerExpressionWithSemanticsAndExpectedType(builder, expr, semantic, null);
}

pub fn lowerExpressionWithSemanticsAndExpectedType(
    builder: *InstructionBuilder,
    expr: *Expr,
    semantic: ?*const SemanticResult,
    expected_type: ?Type,
) !Value {
    switch (expr.*) {
        .IntLiteral => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadConstInt = .{
                .dest = t,
                .value = expr.IntLiteral.value,
                .resolvedType = .{ .isArray = false, .kind = .INT, .struct_name = null },
            } });
            return .{ .temp = t };
        },

        .FloatLiteral => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadConstFloat = .{
                .dest = t,
                .value = expr.FloatLiteral.value,
                .resolvedType = .{ .isArray = false, .kind = .FLOAT, .struct_name = null },
            } });
            return .{ .temp = t };
        },

        .BoolLiteral => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadConstBool = .{
                .dest = t,
                .value = expr.BoolLiteral.value,
                .resolvedType = .{ .isArray = false, .kind = .BOOL, .struct_name = null },
            } });
            return .{ .temp = t };
        },

        .StringLiteral => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadConstString = .{
                .dest = t,
                .value = expr.StringLiteral.value,
                .resolvedType = .{ .isArray = false, .kind = .STRING, .struct_name = null },
            } });
            return .{ .temp = t };
        },

        .Identifier => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadVar = .{ .dest = t, .name = expr.Identifier.name, .resolvedType = lookupExprType(semantic, expr) } });
            return .{ .temp = t };
        },

        .ArrayLiteral => {
            const tempId = builder.newTemp();
            const array_type = expectedArrayAllocationType(lookupExprType(semantic, expr), expected_type) orelse inferArrayLiteralType(expr.ArrayLiteral.elements);

            try builder.emit(.{ .AllocArray = .{
                .length = @intCast(expr.ArrayLiteral.elements.len),
                .dest = tempId,
                .resolvedType = array_type,
            } });

            for (expr.ArrayLiteral.elements, 0..) |element, index| {
                const elemValue = try lowerExpressionWithSemanticsAndExpectedType(builder, element, semantic, null);
                try builder.emit(.{ .StoreIndex = .{
                    .array = .{ .temp = tempId },
                    .index = .{ .constantInt = std.math.cast(i64, index) orelse return LowerError.IndexOutOfBounds },
                    .value = elemValue,
                    .resolvedType = arrayElementType(array_type),
                } });
            }

            return .{ .temp = tempId };
        },

        .Unary => {
            const operandValue = try lowerExpressionWithSemanticsAndExpectedType(builder, expr.Unary.operand, semantic, null);
            const t = builder.newTemp();

            try builder.emit(.{ .UnaryOp = .{
                .op = expr.Unary.operator,
                .operand = operandValue,
                .dest = t,
                .resolvedType = lookupExprType(semantic, expr),
            } });
            return .{ .temp = t };
        },

        .Binary => {
            const leftValue = try lowerExpressionWithSemanticsAndExpectedType(builder, expr.Binary.left, semantic, null);
            const rightValue = try lowerExpressionWithSemanticsAndExpectedType(builder, expr.Binary.right, semantic, null);
            const t = builder.newTemp();

            try builder.emit(.{ .BinaryOp = .{
                .op = try mapOperatorToBinaryOp(expr.Binary.operator),
                .left = leftValue,
                .right = rightValue,
                .dest = t,
                .resolvedType = lookupExprType(semantic, expr),
            } });
            return .{ .temp = t };
        },

        .StructInit => {
            const tempId = builder.newTemp();

            try builder.emit(.{ .AllocStruct = .{
                .structType = expr.StructInit.structName,
                .dest = tempId,
            } });

            for (expr.StructInit.fields) |field| {
                const value = try lowerExpressionWithSemanticsAndExpectedType(builder, field.value, semantic, null);
                try builder.emit(.{ .StoreField = .{
                    .object = .{ .temp = tempId },
                    .fieldName = field.name,
                    .value = value,
                } });
            }

            return .{ .temp = tempId };
        },

        .MemberAccess => {
            const obj = try lowerExpressionWithSemanticsAndExpectedType(builder, expr.MemberAccess.object.?, semantic, null);
            const t = builder.newTemp();
            try builder.emit(.{ .LoadField = .{
                .object = obj,
                .fieldName = expr.MemberAccess.memberName,
                .dest = t,
            } });
            return .{ .temp = t };
        },

        .ArrayAccess => {
            const array = try lowerExpressionWithSemanticsAndExpectedType(builder, expr.ArrayAccess.array, semantic, null);
            const index = try lowerExpressionWithSemanticsAndExpectedType(builder, expr.ArrayAccess.index, semantic, null);
            const t = builder.newTemp();
            try builder.emit(.{ .LoadIndex = .{
                .array = array,
                .index = index,
                .dest = t,
                .resolvedType = lookupExprType(semantic, expr),
            } });
            return .{ .temp = t };
        },

        .FunctionCall => {
            var args = try std.ArrayList(Value).initCapacity(builder.allocator, expr.FunctionCall.args.len);

            for (expr.FunctionCall.args) |arg| {
                const v = try lowerExpressionWithSemanticsAndExpectedType(builder, arg, semantic, null);
                try args.append(builder.allocator, v);
            }

            const t = builder.newTemp();
            try builder.emit(.{
                .FunctionCall = .{ .name = expr.FunctionCall.name, .args = args.items, .dest = t },
            });
            return .{ .temp = t };
        },

        else => {
            return LowerError.UnsupportedExpression;
        },
    }
}

pub fn lowerLValue(builder: *InstructionBuilder, expr: *Expr, value: Value) !void {
    return lowerLValueWithSemantics(builder, expr, value, null);
}

pub fn lowerLValueWithSemantics(builder: *InstructionBuilder, expr: *Expr, value: Value, semantic: ?*const SemanticResult) !void {
    switch (expr.*) {
        .Identifier => {
            try builder.emit(.{ .StoreVar = .{ .name = expr.Identifier.name, .value = value, .resolvedType = lookupExprType(semantic, expr) } });
        },

        .MemberAccess => {
            const obj = try lowerExpressionWithSemanticsAndExpectedType(builder, expr.MemberAccess.object.?, semantic, null);
            try builder.emit(.{ .StoreField = .{
                .object = obj,
                .fieldName = expr.MemberAccess.memberName,
                .value = value,
            } });
        },

        .ArrayAccess => {
            const array = try lowerExpressionWithSemanticsAndExpectedType(builder, expr.ArrayAccess.array, semantic, null);
            const index = try lowerExpressionWithSemanticsAndExpectedType(builder, expr.ArrayAccess.index, semantic, null);
            try builder.emit(.{
                .StoreIndex = .{
                    .array = array,
                    .index = index,
                    .value = value,
                    .resolvedType = .{ .isArray = false, .kind = .INT, .struct_name = null },
                },
            });
        },

        else => {
            return LowerError.UnsupportedLValue;
        },
    }
}

fn lookupExprType(semantic: ?*const SemanticResult, expr: *const Expr) ?Type {
    if (semantic) |result| {
        return result.expr_types.get(expr);
    }
    return null;
}

fn arrayElementType(array_type: Type) Type {
    return .{
        .kind = array_type.kind,
        .isArray = false,
        .struct_name = array_type.struct_name,
    };
}

fn inferArrayLiteralType(elements: []*Expr) Type {
    if (elements.len == 0) {
        return .{ .kind = .EMPTY, .isArray = true, .staticLength = 0 };
    }

    const first = inferExpressionType(elements[0]);
    return .{
        .kind = first.kind,
        .isArray = true,
        .dynamicArray = false,
        .staticLength = @intCast(elements.len),
        .struct_name = first.struct_name,
    };
}

fn expectedArrayAllocationType(inferred_type: ?Type, expected_type: ?Type) ?Type {
    if (expected_type) |typ| {
        if (typ.isArray) {
            return typ;
        }
    }
    return inferred_type;
}

fn inferExpressionType(expr: *const Expr) Type {
    return switch (expr.*) {
        .IntLiteral => .{ .kind = .INT },
        .FloatLiteral => .{ .kind = .FLOAT },
        .BoolLiteral => .{ .kind = .BOOL },
        .StringLiteral => .{ .kind = .STRING },
        .ArrayLiteral => inferArrayLiteralType(expr.ArrayLiteral.elements),
        else => .{ .kind = .INT },
    };
}

fn mapOperatorToBinaryOp(operator: []const u8) LowerError!BinaryOp {
    if (std.mem.eql(u8, operator, "+")) return .Add;
    if (std.mem.eql(u8, operator, "-")) return .Subtract;
    if (std.mem.eql(u8, operator, "*")) return .Multiply;
    if (std.mem.eql(u8, operator, "/")) return .Divide;
    if (std.mem.eql(u8, operator, "%")) return .Modulo;
    if (std.mem.eql(u8, operator, "==")) return .Equal;
    if (std.mem.eql(u8, operator, "!=")) return .NotEqual;
    if (std.mem.eql(u8, operator, "<")) return .LessThan;
    if (std.mem.eql(u8, operator, "<=")) return .LessThanOrEqual;
    if (std.mem.eql(u8, operator, ">")) return .GreaterThan;
    if (std.mem.eql(u8, operator, ">=")) return .GreaterThanOrEqual;
    if (std.mem.eql(u8, operator, "&&")) return .And;
    if (std.mem.eql(u8, operator, "||")) return .Or;
    return LowerError.UnknownOperator;
}
