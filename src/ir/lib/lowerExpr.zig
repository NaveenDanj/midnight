const std = @import("std");
const Instruction = @import("../ir.zig").Instruction;
const Value = @import("../ir.zig").Value;
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const Expr = @import("../../parser/lib/parseExpr.zig").Expr;
const BinaryOp = @import("../ir.zig").BinaryOp;
const Statement = @import("../../parser/lib/parseStatement.zig").Statement;

pub fn lowerExpression(builder: *InstructionBuilder, expr: *Expr) !Value {
    switch (expr.*) {
        .IntLiteral => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadConstInt = .{ .dest = t, .value = expr.IntLiteral.value } });
            return .{ .temp = t };
        },

        .FloatLiteral => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadConstFloat = .{ .dest = t, .value = expr.FloatLiteral.value } });
            return .{ .temp = t };
        },

        .BoolLiteral => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadConstBool = .{ .dest = t, .value = expr.BoolLiteral.value } });
            return .{ .temp = t };
        },

        .StringLiteral => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadConstString = .{ .dest = t, .value = expr.StringLiteral.value } });
            return .{ .temp = t };
        },

        .Identifier => {
            const t = builder.newTemp();
            try builder.emit(.{ .LoadVar = .{ .dest = t, .name = expr.Identifier.name } });
            return .{ .temp = t };
        },

        .ArrayLiteral => {
            const tempId = builder.newTemp();

            for (expr.ArrayLiteral.elements, 0..) |element, index| {
                const elemValue = try lowerExpression(builder, element);
                try builder.emit(.{ .StoreIndex = .{
                    .array = .{ .temp = tempId },
                    .index = .{ .arrayIndex = @intCast(index) },
                    .value = elemValue,
                } });
            }

            return .{ .temp = tempId };
        },

        .Binary => {
            const leftValue = try lowerExpression(builder, expr.Binary.left);
            const rightValue = try lowerExpression(builder, expr.Binary.right);
            const t = builder.newTemp();

            try builder.emit(.{ .BinaryOp = .{
                .op = mapOperatorToBinaryOp(expr.Binary.operator),
                .left = leftValue,
                .right = rightValue,
                .dest = t,
            } });
            return .{ .temp = t };
        },

        .MemberAccess => {
            const obj = try lowerExpression(builder, expr.MemberAccess.object.?);
            const t = builder.newTemp();
            try builder.emit(.{ .LoadField = .{
                .object = obj,
                .fieldName = expr.MemberAccess.memberName,
                .dest = t,
            } });
            return .{ .temp = t };
        },

        .ArrayAccess => {
            const array = try lowerExpression(builder, expr.ArrayAccess.array);
            const index = try lowerExpression(builder, expr.ArrayAccess.index);
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
                const v = try lowerExpression(builder, arg);
                try args.append(builder.allocator, v);
            }

            const t = builder.newTemp();
            try builder.emit(.{
                .FunctionCall = .{ .name = expr.FunctionCall.name, .args = args.items, .dest = t },
            });
            return .{ .temp = t };
        },

        // Handle other expression types (literals, variable references, function calls, etc.)
        else => {
            // For now, we just return a temporary value for any expression type
            // In a real implementation, you would generate the correct IR based on the expression kind
            return .{ .temp = builder.newTemp() };
        },
    }
}

pub fn lowerLValue(builder: *InstructionBuilder, expr: *Expr, value: Value) !void {
    switch (expr.*) {
        .Identifier => {
            try builder.emit(.{ .StoreVar = .{ .name = expr.Identifier.name, .value = value } });
        },

        .MemberAccess => {
            const obj = try lowerExpression(builder, expr.MemberAccess.object.?);
            try builder.emit(.{ .StoreField = .{
                .object = obj,
                .fieldName = expr.MemberAccess.memberName,
                .value = value,
            } });
        },

        .ArrayAccess => {
            const array = try lowerExpression(builder, expr.ArrayAccess.array);
            const index = try lowerExpression(builder, expr.ArrayAccess.index);
            try builder.emit(.{ .StoreIndex = .{
                .array = array,
                .index = index,
                .value = value,
            } });
        },

        // Handle other lvalue types (array indexing, struct field access, etc.)
        else => {
            @panic("Unsupported lvalue expression");
        },
    }
}

fn mapOperatorToBinaryOp(operator: []const u8) BinaryOp {
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
    @panic("Unknown operator");
}
