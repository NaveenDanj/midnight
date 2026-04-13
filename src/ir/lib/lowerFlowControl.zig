const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const IfStatement = @import("../../parser/lib/parseIf.zig").IfStatement;
const lowerExpression = @import("./lowerExpr.zig").lowerExpression;
const lowerStatements = @import("../lower.zig").lowerStatements;
const WhileStatement = @import("../../parser/lib/parseWhile.zig").WhileStatement;

pub fn lowerIfStatement(builder: *InstructionBuilder, ifStmt: *IfStatement) anyerror!void {
    const condition = try lowerExpression(builder, ifStmt.expression);
    const elseLabel = builder.newLabel();
    const endLabel = builder.newLabel();

    try builder.emit(.{ .JumpIfFalse = .{ .condition = condition, .label = elseLabel } });
    try lowerStatements(builder, ifStmt.thenBlock.statements);
    try builder.emit(.{ .Jump = .{ .label = endLabel } });

    try builder.emit(.{ .Label = .{ .id = elseLabel } });
    if (ifStmt.elseBlock) |elseBlock| {
        try lowerStatements(builder, elseBlock.statements);
    }

    try builder.emit(.{ .Label = .{ .id = endLabel } });
}

pub fn lowerWhileStatement(builder: *InstructionBuilder, whileStmt: *WhileStatement) anyerror!void {
    const condition = try lowerExpression(builder, whileStmt.expression);
    const startLabel = builder.newLabel();
    const endLabel = builder.newLabel();

    try builder.emit(.{ .JumpWhileTrue = .{ .condition = condition, .label = startLabel } });
    try builder.emit(.{ .Label = .{ .id = startLabel } });
    try lowerStatements(builder, whileStmt.body.statements);
    try builder.emit(.{ .Jump = .{ .label = startLabel } });
    try builder.emit(.{ .Label = .{ .id = endLabel } });
}
