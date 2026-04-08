const std = @import("std");
const Instruction = @import("./ir.zig").Instruction;
const Value = @import("./ir.zig").Value;
const InstructionBuilder = @import("./builder.zig").InstructionBuilder;
const Expr = @import("../parser//lib//parseExpr.zig").Expr;
const BinaryOp = @import("./ir.zig").BinaryOp;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;

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

        .BinaryExpr => {
            const leftValue = try lowerExpression(builder, expr.BinaryExpr.left);
            const rightValue = try lowerExpression(builder, expr.BinaryExpr.right);
            const t = builder.newTemp();

            try builder.emit(.{ .BinaryOp = .{
                .op = expr.Binary.operator,
                .left = leftValue,
                .right = rightValue,
                .dest = t,
            } });
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
