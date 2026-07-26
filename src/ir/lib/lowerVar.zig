const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const stmt_ast = @import("../../ast/stmt.zig");
const VarAssign = stmt_ast.VarAssign;
const VarDecl = stmt_ast.VarDecl;
const lower_expr = @import("./lowerExpr.zig");
const SemanticResult = @import("../../semantic/result.zig").SemanticResult;
const typeResolver = @import("../../semantic/type_resolver.zig");

pub fn lowerVarAssignment(builder: *InstructionBuilder, varAssign: *VarAssign) !void {
    try lowerVarAssignmentWithSemantics(builder, varAssign, null);
}

pub fn lowerVarDeclaration(builder: *InstructionBuilder, varDecl: *VarDecl) !void {
    try lowerVarDeclarationWithSemantics(builder, varDecl, null);
}

pub fn lowerVarAssignmentWithSemantics(builder: *InstructionBuilder, varAssign: *VarAssign, semantic: ?*const SemanticResult) !void {
    const rhs = try lower_expr.lowerExpressionWithSemantics(builder, varAssign.value, semantic);
    if (varAssign.target.* == .Identifier) {
        const resolvedType = if (semantic) |result| result.var_assign_types.get(varAssign) else null;
        try builder.emit(.{ .StoreVar = .{ .name = varAssign.target.Identifier.name, .value = rhs, .resolvedType = resolvedType } });
        return;
    }
    try lower_expr.lowerLValueWithSemantics(builder, varAssign.target, rhs, semantic);
}

pub fn lowerVarDeclarationWithSemantics(builder: *InstructionBuilder, varDecl: *VarDecl, semantic: ?*const SemanticResult) !void {
    const resolvedType = if (semantic) |result|
        result.var_decl_types.get(varDecl) orelse typeResolver.resolveTypeRefUnchecked(varDecl.varType)
    else
        typeResolver.resolveTypeRefUnchecked(varDecl.varType);
    const rhs = try lower_expr.lowerExpressionWithSemanticsAndExpectedType(builder, varDecl.initializer, semantic, resolvedType);
    try builder.declareVariable(varDecl.name, rhs);
    try builder.emit(.{ .StoreVar = .{ .name = varDecl.name, .value = rhs, .resolvedType = resolvedType } });
}
