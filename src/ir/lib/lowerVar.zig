const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const VarAssign = @import("../../parser/lib/parseVarDec.zig").VarAssign;
const lowerLValue = @import("./lowerExpr.zig").lowerLValue;
const lowerExpression = @import("./lowerExpr.zig").lowerExpression;
const Value = @import("../ir.zig").Value;

pub fn lowerVarAssignment(builder: *InstructionBuilder, varAssign: *VarAssign) !void {
    const rhs = try lowerExpression(builder, varAssign.value);
    try lowerLValue(builder, varAssign.target, rhs);
}
