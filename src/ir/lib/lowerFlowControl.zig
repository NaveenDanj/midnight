const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const stmt_ast = @import("../../ast/stmt.zig");
const IfStatement = stmt_ast.IfStatement;
const lowerExpressionWithSemantics = @import("./lowerExpr.zig").lowerExpressionWithSemantics;
const lowerExpressionWithSemanticsAndExpectedTypeAndReceiver = @import("./lowerExpr.zig").lowerExpressionWithSemanticsAndExpectedTypeAndReceiver;
const ReceiverContext = @import("./lowerExpr.zig").ReceiverContext;
const lowerStatementsWithSemantics = @import("../lower.zig").lowerStatementsWithSemantics;
const lowerStatementsWithSemanticsAndReceiver = @import("../lower.zig").lowerStatementsWithSemanticsAndReceiver;
const SemanticResult = @import("../../semantic/result.zig").SemanticResult;
const WhileStatement = stmt_ast.WhileStatement;

pub fn lowerIfStatement(builder: *InstructionBuilder, ifStmt: *IfStatement) anyerror!void {
    try lowerIfStatementWithSemantics(builder, ifStmt, null);
}

pub fn lowerIfStatementWithSemantics(builder: *InstructionBuilder, ifStmt: *IfStatement, semantic: ?*const SemanticResult) anyerror!void {
    try lowerIfStatementWithSemanticsAndReceiver(builder, ifStmt, semantic, null);
}

pub fn lowerIfStatementWithSemanticsAndReceiver(builder: *InstructionBuilder, ifStmt: *IfStatement, semantic: ?*const SemanticResult, receiver_ctx: ?ReceiverContext) anyerror!void {
    const condition = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, ifStmt.expression, semantic, null, receiver_ctx);
    const elseLabel = builder.newLabel();
    const endLabel = builder.newLabel();

    try builder.emit(.{ .JumpIfFalse = .{ .condition = condition, .label = elseLabel } });
    try lowerStatementsWithSemanticsAndReceiver(builder, ifStmt.thenBlock.statements, semantic, receiver_ctx);
    const then_terminated = builder.current_block_terminated;
    if (!then_terminated) {
        try builder.emit(.{ .Jump = .{ .label = endLabel } });
    }

    try builder.emit(.{ .Label = .{ .id = elseLabel } });
    if (ifStmt.elseBlock) |elseBlock| {
        try lowerStatementsWithSemanticsAndReceiver(builder, elseBlock.statements, semantic, receiver_ctx);
    }

    try builder.emit(.{ .Label = .{ .id = endLabel } });
}

pub fn lowerWhileStatement(builder: *InstructionBuilder, whileStmt: *WhileStatement) anyerror!void {
    try lowerWhileStatementWithSemantics(builder, whileStmt, null);
}

pub fn lowerWhileStatementWithSemantics(builder: *InstructionBuilder, whileStmt: *WhileStatement, semantic: ?*const SemanticResult) anyerror!void {
    try lowerWhileStatementWithSemanticsAndReceiver(builder, whileStmt, semantic, null);
}

pub fn lowerWhileStatementWithSemanticsAndReceiver(builder: *InstructionBuilder, whileStmt: *WhileStatement, semantic: ?*const SemanticResult, receiver_ctx: ?ReceiverContext) anyerror!void {
    const startLabel = builder.newLabel();
    const endLabel = builder.newLabel();

    try builder.emit(.{ .Label = .{ .id = startLabel } });
    const condition = try lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, whileStmt.expression, semantic, null, receiver_ctx);
    try builder.emit(.{ .JumpIfFalse = .{ .condition = condition, .label = endLabel } });
    try lowerStatementsWithSemanticsAndReceiver(builder, whileStmt.body.statements, semantic, receiver_ctx);
    if (!builder.current_block_terminated) {
        try builder.emit(.{ .Jump = .{ .label = startLabel } });
    }
    try builder.emit(.{ .Label = .{ .id = endLabel } });
}
