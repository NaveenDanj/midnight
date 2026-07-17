const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const stmt_ast = @import("../../ast/stmt.zig");
const VarAssign = stmt_ast.VarAssign;
const VarDecl = stmt_ast.VarDecl;
const lowerLValue = @import("./lowerExpr.zig").lowerLValue;
const lowerExpression = @import("./lowerExpr.zig").lowerExpression;
const Value = @import("../ir.zig").Value;

pub fn lowerVarAssignment(builder: *InstructionBuilder, varAssign: *VarAssign) !void {
    const rhs = try lowerExpression(builder, varAssign.value);
    try lowerLValue(builder, varAssign.target, rhs);
}

pub fn lowerVarDeclaration(builder: *InstructionBuilder, varDecl: *VarDecl) !void {
    const rhs = try lowerExpression(builder, varDecl.initializer);
    try builder.declareVariable(varDecl.name, rhs);
    try builder.emit(.{ .StoreVar = .{ .name = varDecl.name, .value = rhs, .resolvedType = varDecl.varType } });
}
