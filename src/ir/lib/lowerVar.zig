const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const stmt_ast = @import("../../ast/stmt.zig");
const VarAssign = stmt_ast.VarAssign;
const VarDecl = stmt_ast.VarDecl;
const lower_expr = @import("./lowerExpr.zig");
const ReceiverContext = @import("./lowerExpr.zig").ReceiverContext;
const SemanticResult = @import("../../semantic/result.zig").SemanticResult;
const typeResolver = @import("../../semantic/type_resolver.zig");

pub fn lowerVarAssignment(builder: *InstructionBuilder, varAssign: *VarAssign) !void {
    try lowerVarAssignmentWithSemanticsAndReceiver(builder, varAssign, null, null);
}

pub fn lowerVarDeclaration(builder: *InstructionBuilder, varDecl: *VarDecl) !void {
    try lowerVarDeclarationWithSemanticsAndReceiver(builder, varDecl, null, null);
}

pub fn lowerVarAssignmentWithSemantics(builder: *InstructionBuilder, varAssign: *VarAssign, semantic: ?*const SemanticResult) !void {
    try lowerVarAssignmentWithSemanticsAndReceiver(builder, varAssign, semantic, null);
}

pub fn lowerVarDeclarationWithSemantics(builder: *InstructionBuilder, varDecl: *VarDecl, semantic: ?*const SemanticResult) !void {
    try lowerVarDeclarationWithSemanticsAndReceiver(builder, varDecl, semantic, null);
}

pub fn lowerVarAssignmentWithSemanticsAndReceiver(
    builder: *InstructionBuilder,
    varAssign: *VarAssign,
    semantic: ?*const SemanticResult,
    receiver_ctx: ?ReceiverContext,
) !void {
    const resolved_type = if (semantic) |result| result.var_assign_types.get(varAssign) else null;
    const rhs = try lower_expr.lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, varAssign.value, semantic, null, receiver_ctx);
    try lower_expr.lowerLValueWithSemanticsAndReceiverAndType(builder, varAssign.target, rhs, semantic, receiver_ctx, resolved_type);
}

pub fn lowerVarDeclarationWithSemanticsAndReceiver(
    builder: *InstructionBuilder,
    varDecl: *VarDecl,
    semantic: ?*const SemanticResult,
    receiver_ctx: ?ReceiverContext,
) !void {
    const resolvedType = if (semantic) |result|
        result.var_decl_types.get(varDecl) orelse typeResolver.resolveTypeRefUnchecked(varDecl.varType)
    else
        typeResolver.resolveTypeRefUnchecked(varDecl.varType);
    const rhs = try lower_expr.lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, varDecl.initializer, semantic, resolvedType, receiver_ctx);
    try builder.declareVariable(varDecl.name, rhs);
    try builder.emit(.{ .StoreVar = .{ .name = varDecl.name, .value = rhs, .resolvedType = resolvedType } });
}
