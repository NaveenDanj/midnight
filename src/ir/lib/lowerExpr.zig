const std = @import("std");
const Instruction = @import("../ir.zig").Instruction;
const Value = @import("../ir.zig").Value;
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const Expr = @import("../../ast/expr.zig").Expr;
const BinaryOp = @import("../ir.zig").BinaryOp;
const LowerError = @import("../lower_error.zig").LowerError;
const SemanticResult = @import("../../semantic/result.zig").SemanticResult;
const Type = @import("../../semantic/types.zig").Type;
const stmt_ast = @import("../../ast/stmt.zig");

const StructStmt = stmt_ast.StructStmt;

pub const ReceiverContext = struct {
    struct_decl: *const StructStmt,
    receiver_name: []const u8,
};

fn isReceiverMemberIdentifier(semantic: ?*const SemanticResult, expr: *const Expr, struct_decl: *const StructStmt) bool {
    if (semantic) |result| {
        return result.receiver_member_exprs.contains(expr);
    }
    return receiverHasProperty(struct_decl, expr.Identifier.name);
}

pub fn lowerExpression(builder: *InstructionBuilder, expr: *Expr) !Value {
    return lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr, null, null, null);
}

pub fn lowerExpressionWithSemantics(builder: *InstructionBuilder, expr: *Expr, semantic: ?*const SemanticResult) !Value {
    return lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr, semantic, null, null);
}

pub fn lowerExpressionWithSemanticsAndExpectedType(
    builder: *InstructionBuilder,
    expr: *Expr,
    semantic: ?*const SemanticResult,
    expected_type: ?Type,
) !Value {
    return lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr, semantic, expected_type, null);
}

pub fn lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(
    builder: *InstructionBuilder,
    expr: *Expr,
    semantic: ?*const SemanticResult,
    expected_type: ?Type,
    receiver_ctx: ?ReceiverContext,
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
            if (receiver_ctx) |ctx| {
                if (isReceiverMemberIdentifier(semantic, expr, ctx.struct_decl)) {
                    const t = builder.newTemp();
                    try builder.emit(.{ .LoadField = .{
                        .object = .{ .variable = ctx.receiver_name },
                        .fieldName = expr.Identifier.name,
                        .dest = t,
                    } });
                    return .{ .temp = t };
                }
            }

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
                const elemValue = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, element, semantic, null, receiver_ctx);
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
            const operandValue = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr.Unary.operand, semantic, null, receiver_ctx);
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
            const leftValue = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr.Binary.left, semantic, null, receiver_ctx);
            const rightValue = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr.Binary.right, semantic, null, receiver_ctx);
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
                .definition = expr.StructInit,
                .resolvedType = lookupExprType(semantic, expr),
            } });

            for (expr.StructInit.fields, 0..) |field, index| {
                const value = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, field.value, semantic, null, receiver_ctx);
                try builder.emit(.{ .StoreField = .{
                    .object = .{ .temp = tempId },
                    .fieldName = field.name,
                    .value = value,
                    .fieldIndex = @intCast(index),
                    .resolvedType = lookupExprType(semantic, field.value),
                } });
            }

            return .{ .temp = tempId };
        },
        .MemberAccess => {
            const obj = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr.MemberAccess.object.?, semantic, null, receiver_ctx);
            const t = builder.newTemp();
            try builder.emit(.{ .LoadField = .{
                .object = obj,
                .fieldName = expr.MemberAccess.memberName,
                .dest = t,
            } });
            return .{ .temp = t };
        },
        .ArrayAccess => {
            const array = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr.ArrayAccess.array, semantic, null, receiver_ctx);
            const index = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr.ArrayAccess.index, semantic, null, receiver_ctx);
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
            var extra_receiver_arg: ?Value = null;
            var call_name = expr.FunctionCall.name;

            if (expr.FunctionCall.callee) |callee| {
                switch (callee.*) {
                    .MemberAccess => {
                        const object_expr = callee.MemberAccess.object orelse return LowerError.UnsupportedExpression;
                        const object_value = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, object_expr, semantic, null, receiver_ctx);
                        const object_type = lookupExprType(semantic, object_expr) orelse return LowerError.UnsupportedExpression;
                        const struct_name = object_type.struct_name orelse return LowerError.UnsupportedExpression;
                        call_name = try mangleMethodName(builder, struct_name, expr.FunctionCall.name);
                        extra_receiver_arg = object_value;
                    },
                    else => {},
                }
            } else if (receiver_ctx) |ctx| {
                if (receiverHasMethod(ctx.struct_decl, expr.FunctionCall.name)) {
                    call_name = try mangleMethodName(builder, ctx.struct_decl.name, expr.FunctionCall.name);
                    extra_receiver_arg = .{ .variable = ctx.receiver_name };
                }
            }

            const arg_count = expr.FunctionCall.args.len + @as(usize, if (extra_receiver_arg != null) 1 else 0);
            var args = try std.ArrayList(Value).initCapacity(builder.allocator, arg_count);

            if (extra_receiver_arg) |receiver_arg| {
                try args.append(builder.allocator, receiver_arg);
            }

            for (expr.FunctionCall.args) |arg| {
                const v = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, arg, semantic, null, receiver_ctx);
                try args.append(builder.allocator, v);
            }

            const t = builder.newTemp();
            try builder.emit(.{
                .FunctionCall = .{ .name = call_name, .args = args.items, .dest = t },
            });
            return .{ .temp = t };
        },
        .NullLiteral => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadConstNull = .{
                .dest = t,
                .resolvedType = .{ .isArray = false, .kind = .NULL, .struct_name = null },
            } });
            return .{ .temp = t };
        },
        else => return LowerError.UnsupportedExpression,
    }
}

pub fn lowerLValue(builder: *InstructionBuilder, expr: *Expr, value: Value) !void {
    return lowerLValueWithSemanticsAndReceiverAndType(builder, expr, value, null, null, null);
}

pub fn lowerLValueWithSemantics(builder: *InstructionBuilder, expr: *Expr, value: Value, semantic: ?*const SemanticResult) !void {
    return lowerLValueWithSemanticsAndReceiverAndType(builder, expr, value, semantic, null, null);
}

pub fn lowerLValueWithSemanticsAndReceiver(
    builder: *InstructionBuilder,
    expr: *Expr,
    value: Value,
    semantic: ?*const SemanticResult,
    receiver_ctx: ?ReceiverContext,
) !void {
    return lowerLValueWithSemanticsAndReceiverAndType(builder, expr, value, semantic, receiver_ctx, null);
}

pub fn lowerLValueWithSemanticsAndReceiverAndType(
    builder: *InstructionBuilder,
    expr: *Expr,
    value: Value,
    semantic: ?*const SemanticResult,
    receiver_ctx: ?ReceiverContext,
    store_type: ?Type,
) !void {
    switch (expr.*) {
        .Identifier => {
            if (receiver_ctx) |ctx| {
                if (isReceiverMemberIdentifier(semantic, expr, ctx.struct_decl)) {
                    try builder.emit(.{
                        .StoreField = .{
                            .object = .{ .variable = ctx.receiver_name },
                            .fieldName = expr.Identifier.name,
                            .value = value,
                            .fieldIndex = 0,
                            .resolvedType = store_type orelse lookupExprType(semantic, expr),
                        },
                    });
                    return;
                }
            }

            try builder.emit(.{ .StoreVar = .{ .name = expr.Identifier.name, .value = value, .resolvedType = store_type orelse lookupExprType(semantic, expr) } });
        },
        .MemberAccess => {
            const obj = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr.MemberAccess.object.?, semantic, null, receiver_ctx);
            try builder.emit(.{
                .StoreField = .{
                    .object = obj,
                    .fieldName = expr.MemberAccess.memberName,
                    .value = value,
                    .fieldIndex = 0,
                    .resolvedType = store_type orelse lookupExprType(semantic, expr),
                },
            });
        },
        .ArrayAccess => {
            const array = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr.ArrayAccess.array, semantic, null, receiver_ctx);
            const index = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, expr.ArrayAccess.index, semantic, null, receiver_ctx);
            try builder.emit(.{
                .StoreIndex = .{
                    .array = array,
                    .index = index,
                    .value = value,
                    .resolvedType = store_type orelse .{ .isArray = false, .kind = .INT, .struct_name = null },
                },
            });
        },
        else => return LowerError.UnsupportedLValue,
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

fn receiverHasProperty(struct_decl: *const StructStmt, name: []const u8) bool {
    for (struct_decl.fields) |field| {
        switch (field) {
            .StructProperty => |property_ptr| {
                if (std.mem.eql(u8, property_ptr.name, name)) return true;
            },
            .StructMethod => {},
        }
    }
    return false;
}

fn receiverHasMethod(struct_decl: *const StructStmt, name: []const u8) bool {
    for (struct_decl.fields) |field| {
        switch (field) {
            .StructMethod => |method_ptr| {
                if (std.mem.eql(u8, method_ptr.name, name)) return true;
            },
            .StructProperty => {},
        }
    }
    return false;
}

fn mangleMethodName(builder: *InstructionBuilder, struct_name: []const u8, method_name: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(builder.allocator, "{s}__{s}", .{ struct_name, method_name });
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
