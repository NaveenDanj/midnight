const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const stmt_ast = @import("../../ast/stmt.zig");
const IfStatement = stmt_ast.IfStatement;
const lowerExpressionWithSemantics = @import("./lowerExpr.zig").lowerExpressionWithSemantics;
const lowerStatementsWithSemantics = @import("../lower.zig").lowerStatementsWithSemantics;
const SemanticResult = @import("../../semantic/result.zig").SemanticResult;
const WhileStatement = stmt_ast.WhileStatement;

pub fn lowerIfStatement(builder: *InstructionBuilder, ifStmt: *IfStatement) anyerror!void {
    try lowerIfStatementWithSemantics(builder, ifStmt, null);
}

pub fn lowerIfStatementWithSemantics(builder: *InstructionBuilder, ifStmt: *IfStatement, semantic: ?*const SemanticResult) anyerror!void {
    const condition = try lowerExpressionWithSemantics(builder, ifStmt.expression, semantic);
    const elseLabel = builder.newLabel();
    const endLabel = builder.newLabel();

    try builder.emit(.{ .JumpIfFalse = .{ .condition = condition, .label = elseLabel } });
    try lowerStatementsWithSemantics(builder, ifStmt.thenBlock.statements, semantic);
    try builder.emit(.{ .Jump = .{ .label = endLabel } });

    try builder.emit(.{ .Label = .{ .id = elseLabel } });
    if (ifStmt.elseBlock) |elseBlock| {
        try lowerStatementsWithSemantics(builder, elseBlock.statements, semantic);
    }

    try builder.emit(.{ .Label = .{ .id = endLabel } });
}

pub fn lowerWhileStatement(builder: *InstructionBuilder, whileStmt: *WhileStatement) anyerror!void {
    try lowerWhileStatementWithSemantics(builder, whileStmt, null);
}

pub fn lowerWhileStatementWithSemantics(builder: *InstructionBuilder, whileStmt: *WhileStatement, semantic: ?*const SemanticResult) anyerror!void {
    const startLabel = builder.newLabel();
    const endLabel = builder.newLabel();

    try builder.emit(.{ .Label = .{ .id = startLabel } });
    const condition = try lowerExpressionWithSemantics(builder, whileStmt.expression, semantic);
    try builder.emit(.{ .JumpIfFalse = .{ .condition = condition, .label = endLabel } });
    try lowerStatementsWithSemantics(builder, whileStmt.body.statements, semantic);
    try builder.emit(.{ .Jump = .{ .label = startLabel } });
    try builder.emit(.{ .Label = .{ .id = endLabel } });
}
