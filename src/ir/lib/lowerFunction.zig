const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const stmt_ast = @import("../../ast/stmt.zig");
const FunctionDecl = stmt_ast.FunctionDecl;
const FunctionCallStmt = stmt_ast.FunctionCallStmt;
const Statement = stmt_ast.Statement;
const ReturnStatement = stmt_ast.ReturnStatement;
const Value = @import("../ir.zig").Value;

const Instruction = @import("../ir.zig").Instruction;
const lowerStatementWithSemantics = @import("../lower.zig").lowerStatementWithSemantics;
const lowerExpressionWithSemantics = @import("./lowerExpr.zig").lowerExpressionWithSemantics;
const SemanticResult = @import("../../semantic/result.zig").SemanticResult;
const typeResolver = @import("../../semantic/type_resolver.zig");

pub fn lowerFunctionDecl(
    builder: *InstructionBuilder,
    funcDecl: *FunctionDecl,
) anyerror!Instruction {
    return lowerFunctionDeclWithSemantics(builder, funcDecl, null);
}

pub fn lowerFunctionDeclWithSemantics(
    builder: *InstructionBuilder,
    funcDecl: *FunctionDecl,
    semantic: ?*const SemanticResult,
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

    try lowerBlockWithSemantics(&newBuilder, funcDecl.body.statements, semantic);

    const returnType = if (semantic) |result|
        result.function_return_types.get(funcDecl) orelse typeResolver.resolveTypeRefUnchecked(funcDecl.returnType)
    else
        typeResolver.resolveTypeRefUnchecked(funcDecl.returnType);

    return .{ .FunctionIR = .{
        .name = funcDecl.name,
        .params = funcDecl.params,
        .body = newBuilder.instructions.items,
        .returnType = returnType,
    } };
}

pub fn lowerFunctionCall(builder: *InstructionBuilder, funcCall: *FunctionCallStmt) anyerror!void {
    try lowerFunctionCallWithSemantics(builder, funcCall, null);
}

pub fn lowerFunctionCallWithSemantics(builder: *InstructionBuilder, funcCall: *FunctionCallStmt, semantic: ?*const SemanticResult) anyerror!void {
    const temp = builder.newTemp();
    var args = try std.ArrayList(Value).initCapacity(builder.allocator, funcCall.args.len);

    for (funcCall.args) |arg| {
        const v = try lowerExpressionWithSemantics(builder, arg, semantic);
        try args.append(builder.allocator, v);
    }

    try builder.emit(.{
        .FunctionCall = .{ .name = funcCall.name, .args = args.items, .dest = temp },
    });
}

pub fn lowerBlock(builder: *InstructionBuilder, statements: []*Statement) anyerror!void {
    try lowerBlockWithSemantics(builder, statements, null);
}

pub fn lowerBlockWithSemantics(builder: *InstructionBuilder, statements: []*Statement, semantic: ?*const SemanticResult) anyerror!void {
    for (statements) |stmt| {
        try lowerStatementWithSemantics(builder, stmt, semantic);
    }
}

pub fn lowerReturnStatement(builder: *InstructionBuilder, stmt: *ReturnStatement) anyerror!void {
    try lowerReturnStatementWithSemantics(builder, stmt, null);
}

pub fn lowerReturnStatementWithSemantics(builder: *InstructionBuilder, stmt: *ReturnStatement, semantic: ?*const SemanticResult) anyerror!void {
    const value = try lowerExpressionWithSemantics(builder, stmt.expression, semantic);
    try builder.emit(.{ .Return = .{ .value = value } });
}
