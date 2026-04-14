const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const VarAssign = @import("../../parser/lib/parseVarDec.zig").VarAssign;
const VarDecl = @import("../../parser/lib/parseVarDec.zig").VarDecl;
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
    try builder.emit(.{ .StoreVar = .{ .name = varDecl.name, .value = rhs } });
}
