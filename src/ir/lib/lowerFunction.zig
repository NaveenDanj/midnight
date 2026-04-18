const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const FunctionDecl = @import("../../parser//lib/parseFunctionDecl.zig").FunctionDecl;
const FunctionCallStmt = @import("../../parser/lib/parseFunctionDecl.zig").FunctionCallStmt;
const Statement = @import("../../parser/lib/parseStatement.zig").Statement;
const ReturnStatement = @import("../../parser/lib/parseFunctionDecl.zig").ReturnStatement;
const lowerStatement = @import("../lower.zig").lowerStatement;
const lowerExpression = @import("./lowerExpr.zig").lowerExpression;
const Value = @import("../ir.zig").Value;
const Instruction = @import("../ir.zig").Instruction;

pub fn lowerFunctionDecl(
    builder: *InstructionBuilder,
    funcDecl: *FunctionDecl,
) anyerror!Instruction {
    var newBuilder = InstructionBuilder.init(builder.allocator);

    for (funcDecl.params, 0..) |param, index| {
        try newBuilder.emit(.{
            .ParamBind = .{
                .name = param.name,
                .index = @intCast(index),
            },
        });

        try newBuilder.declareVariable(param.name, .{
            .paramIndex = @intCast(index),
        });
    }

    try lowerBlock(&newBuilder, funcDecl.body.statements);

    return .{ .FunctionIR = .{
        .name = funcDecl.name,
        .params = funcDecl.params,
        .body = newBuilder.instructions.items,
        .returnType = funcDecl.returnType,
    } };
}

pub fn lowerFunctionCall(builder: *InstructionBuilder, funcCall: *FunctionCallStmt) anyerror!void {
    const temp = builder.newTemp();
    var args = try std.ArrayList(Value).initCapacity(builder.allocator, funcCall.args.len);

    for (funcCall.args) |arg| {
        const v = try lowerExpression(builder, arg);
        try args.append(builder.allocator, v);
    }

    try builder.emit(.{
        .FunctionCall = .{ .name = funcCall.name, .args = args.items, .dest = temp },
    });
}

pub fn lowerBlock(builder: *InstructionBuilder, statements: []*Statement) anyerror!void {
    for (statements) |stmt| {
        try lowerStatement(builder, stmt);
    }
}

pub fn lowerReturnStatement(builder: *InstructionBuilder, stmt: *ReturnStatement) anyerror!void {
    const value = try lowerExpression(builder, stmt.expression);
    try builder.emit(.{ .Return = .{ .value = value } });
}
