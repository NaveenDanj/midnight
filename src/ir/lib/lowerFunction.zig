const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const FunctionDecl = @import("../../parser//lib/parseFunctionDecl.zig").FunctionDecl;
const FunctionCallStmt = @import("../../parser/lib/parseFunctionDecl.zig").FunctionCallStmt;
const Value = @import("../ir.zig").Value;

const lowerExpression = @import("./lowerExpr.zig").lowerExpression;

pub fn lowerFunctionDecl(builder: *InstructionBuilder, funcDecl: FunctionDecl) anyerror!void {
    for (funcDecl.params, 0..) |param, index| {
        try builder.emit(.{
            .ParamBind = .{
                .name = param.name,
                .index = @intCast(index),
            },
        });
    }
}

pub fn lowerFunctionCall(builder: *InstructionBuilder, funcCall: *FunctionCallStmt) anyerror!void {
    var args = try std.ArrayList(Value).initCapacity(builder.allocator, funcCall.args.len);

    for (funcCall.args) |arg| {
        // Lower each argument and add it to the args list
        const v = try lowerExpression(builder, arg);
        try args.append(builder.allocator, v);
    }

    try builder.emit(.{
        .FunctionCall = .{ .name = funcCall.name, .args = args.items, .dest = undefined },
    });
}
