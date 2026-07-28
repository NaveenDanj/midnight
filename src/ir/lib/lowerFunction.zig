const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const stmt_ast = @import("../../ast/stmt.zig");
const TypeRef = @import("../../ast/type_ref.zig").TypeRef;
const FunctionDecl = stmt_ast.FunctionDecl;
const FunctionCallStmt = stmt_ast.FunctionCallStmt;
const Param = stmt_ast.Param;
const ReturnStatement = stmt_ast.ReturnStatement;
const Statement = stmt_ast.Statement;
const StructMethodField = stmt_ast.StructMethodField;
const StructStmt = stmt_ast.StructStmt;
const Expr = @import("../../ast/expr.zig").Expr;
const BlockStmt = stmt_ast.BlockStmt;

const Instruction = @import("../ir.zig").Instruction;
const lowerStatementWithSemanticsAndReceiver = @import("../lower.zig").lowerStatementWithSemanticsAndReceiver;
const lowerExpressionWithSemanticsAndExpectedTypeAndReceiver = @import("./lowerExpr.zig").lowerExpressionWithSemanticsAndExpectedTypeAndReceiver;
const ReceiverContext = @import("./lowerExpr.zig").ReceiverContext;
const SemanticResult = @import("../../semantic/result.zig").SemanticResult;
const Type = @import("../../semantic/types.zig").Type;
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
    const return_type = if (semantic) |result|
        result.function_return_types.get(funcDecl) orelse typeResolver.resolveTypeRefUnchecked(funcDecl.returnType)
    else
        typeResolver.resolveTypeRefUnchecked(funcDecl.returnType);
    return lowerCallableBody(builder, funcDecl.name, funcDecl.params, funcDecl.body, return_type, semantic, null, funcDecl.isExtern);
}

pub fn lowerStructMethodWithSemantics(
    builder: *InstructionBuilder,
    structDecl: *StructStmt,
    method: *StructMethodField,
    semantic: ?*const SemanticResult,
) anyerror!Instruction {
    const params = try synthesizeMethodParams(builder, structDecl, method);
    const mangled_name = try std.fmt.allocPrint(builder.allocator, "{s}__{s}", .{ structDecl.name, method.name });
    const receiver_ctx = ReceiverContext{
        .struct_decl = structDecl,
        .receiver_name = "self",
    };
    const return_type = if (semantic) |result|
        result.struct_method_return_types.get(method) orelse typeResolver.resolveTypeRefUnchecked(method.returnType)
    else
        typeResolver.resolveTypeRefUnchecked(method.returnType);

    return lowerCallableBody(builder, mangled_name, params, method.body, return_type, semantic, receiver_ctx, false);
}

pub fn lowerFunctionCall(builder: *InstructionBuilder, funcCall: *FunctionCallStmt) anyerror!void {
    try lowerFunctionCallWithSemanticsAndReceiver(builder, funcCall, null, null);
}

pub fn lowerFunctionCallWithSemantics(builder: *InstructionBuilder, funcCall: *FunctionCallStmt, semantic: ?*const SemanticResult) anyerror!void {
    try lowerFunctionCallWithSemanticsAndReceiver(builder, funcCall, semantic, null);
}

pub fn lowerFunctionCallWithSemanticsAndReceiver(
    builder: *InstructionBuilder,
    funcCall: *FunctionCallStmt,
    semantic: ?*const SemanticResult,
    receiver_ctx: ?ReceiverContext,
) anyerror!void {
    var call_expr = Expr{ .FunctionCall = funcCall.* };
    _ = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, &call_expr, semantic, null, receiver_ctx);
}

pub fn lowerBlock(builder: *InstructionBuilder, statements: []*Statement) anyerror!void {
    try lowerBlockWithSemanticsAndReceiver(builder, statements, null, null);
}

pub fn lowerBlockWithSemantics(builder: *InstructionBuilder, statements: []*Statement, semantic: ?*const SemanticResult) anyerror!void {
    try lowerBlockWithSemanticsAndReceiver(builder, statements, semantic, null);
}

pub fn lowerBlockWithSemanticsAndReceiver(builder: *InstructionBuilder, statements: []*Statement, semantic: ?*const SemanticResult, receiver_ctx: ?ReceiverContext) anyerror!void {
    for (statements) |stmt| {
        try lowerStatementWithSemanticsAndReceiver(builder, stmt, semantic, receiver_ctx);
        if (builder.current_block_terminated) {
            break;
        }
    }
}

pub fn lowerReturnStatement(builder: *InstructionBuilder, stmt: *ReturnStatement) anyerror!void {
    try lowerReturnStatementWithSemanticsAndReceiver(builder, stmt, null, null);
}

pub fn lowerReturnStatementWithSemantics(builder: *InstructionBuilder, stmt: *ReturnStatement, semantic: ?*const SemanticResult) anyerror!void {
    try lowerReturnStatementWithSemanticsAndReceiver(builder, stmt, semantic, null);
}

pub fn lowerReturnStatementWithSemanticsAndReceiver(builder: *InstructionBuilder, stmt: *ReturnStatement, semantic: ?*const SemanticResult, receiver_ctx: ?ReceiverContext) anyerror!void {
    const value = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, stmt.expression, semantic, null, receiver_ctx);
    try builder.emit(.{ .Return = .{ .value = value } });
}

fn lowerCallableBody(
    builder: *InstructionBuilder,
    name: []const u8,
    params: []*Param,
    body: ?*BlockStmt,
    return_type: Type,
    semantic: ?*const SemanticResult,
    receiver_ctx: ?ReceiverContext,
    isExtern: bool,
) anyerror!Instruction {
    var newBuilder = InstructionBuilder.init(builder.allocator);

    for (params, 0..) |param, index| {
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

    if (!isExtern) {
        // TODO: Add proper error handling for when body is null, as it should not be null for non-extern functions.
        const block = body orelse return error.NotAFunction;
        try lowerBlockWithSemanticsAndReceiver(&newBuilder, block.statements, semantic, receiver_ctx);
    }

    return .{ .FunctionIR = .{
        .name = name,
        .params = params,
        .body = newBuilder.instructions.items,
        .returnType = return_type,
        .isExtern = isExtern,
    } };
}

fn synthesizeMethodParams(builder: *InstructionBuilder, structDecl: *StructStmt, method: *StructMethodField) ![]*Param {
    const params = try builder.allocator.alloc(*Param, method.parameters.len + 1);
    const self_param = try builder.allocator.create(Param);
    self_param.* = .{
        .dataType = .{ .name = structDecl.name },
        .name = "self",
    };
    params[0] = self_param;

    for (method.parameters, 0..) |param, index| {
        params[index + 1] = param;
    }

    return params;
}
