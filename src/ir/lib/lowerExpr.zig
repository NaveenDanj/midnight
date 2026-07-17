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
    return lowerExpressionWithSemantics(builder, expr, null);
}

pub fn lowerExpressionWithSemantics(builder: *InstructionBuilder, expr: *Expr, semantic: ?*const SemanticResult) !Value {
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

            for (expr.ArrayLiteral.elements, 0..) |element, index| {
                const elemValue = try lowerExpressionWithSemantics(builder, element, semantic);
                try builder.emit(.{ .StoreIndex = .{
                    .array = .{ .temp = tempId },
                    .index = .{ .arrayIndex = @intCast(index) },
                    .value = elemValue,
                } });
            }

            return .{ .temp = tempId };
        },

        .Binary => {
            const leftValue = try lowerExpressionWithSemantics(builder, expr.Binary.left, semantic);
            const rightValue = try lowerExpressionWithSemantics(builder, expr.Binary.right, semantic);
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
                const value = try lowerExpressionWithSemantics(builder, field.value, semantic);
                try builder.emit(.{ .StoreField = .{
                    .object = .{ .temp = tempId },
                    .fieldName = field.name,
                    .value = value,
                } });
            }

            return .{ .temp = tempId };
        },

        .MemberAccess => {
            const obj = try lowerExpressionWithSemantics(builder, expr.MemberAccess.object.?, semantic);
            const t = builder.newTemp();
            try builder.emit(.{ .LoadField = .{
                .object = obj,
                .fieldName = expr.MemberAccess.memberName,
                .dest = t,
            } });
            return .{ .temp = t };
        },

        .ArrayAccess => {
            const array = try lowerExpressionWithSemantics(builder, expr.ArrayAccess.array, semantic);
            const index = try lowerExpressionWithSemantics(builder, expr.ArrayAccess.index, semantic);
            const t = builder.newTemp();
            try builder.emit(.{ .LoadIndex = .{
                .array = array,
                .index = index,
                .dest = t,
            } });
            return .{ .temp = t };
        },

        .FunctionCall => {
            var args = try std.ArrayList(Value).initCapacity(builder.allocator, expr.FunctionCall.args.len);

            for (expr.FunctionCall.args) |arg| {
                const v = try lowerExpressionWithSemantics(builder, arg, semantic);
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
            const obj = try lowerExpressionWithSemantics(builder, expr.MemberAccess.object.?, semantic);
            try builder.emit(.{ .StoreField = .{
                .object = obj,
                .fieldName = expr.MemberAccess.memberName,
                .value = value,
            } });
        },

        .ArrayAccess => {
            const array = try lowerExpressionWithSemantics(builder, expr.ArrayAccess.array, semantic);
            const index = try lowerExpressionWithSemantics(builder, expr.ArrayAccess.index, semantic);
            try builder.emit(.{ .StoreIndex = .{
                .array = array,
                .index = index,
                .value = value,
            } });
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
