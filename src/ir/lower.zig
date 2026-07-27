const std = @import("std");
const InstructionBuilder = @import("./builder.zig").InstructionBuilder;
const stmt_ast = @import("../ast/stmt.zig");
const Statement = stmt_ast.Statement;
const lower_var = @import("./lib/lowerVar.zig");
const lower_expr = @import("./lib/lowerExpr.zig");
const lower_flow = @import("./lib/lowerFlowControl.zig");
const lower_function = @import("./lib/lowerFunction.zig");
const lower_struct_decl = @import("./lib/lowerStruct.zig");
const ReceiverContext = @import("./lib/lowerExpr.zig").ReceiverContext;

const LowerError = @import("./lower_error.zig").LowerError;
const SemanticResult = @import("../semantic/result.zig").SemanticResult;

pub fn generateIR(builder: *InstructionBuilder, statements: []*Statement) anyerror!void {
    try generateIRWithSemantics(builder, statements, null);
}

pub fn generateIRWithSemantics(builder: *InstructionBuilder, statements: []*Statement, semantic: ?*const SemanticResult) anyerror!void {
    for (statements) |stmt| {
        try lowerStatementWithSemantics(builder, stmt, semantic);
    }
}

pub fn lowerStatement(builder: *InstructionBuilder, stmt: *Statement) anyerror!void {
    try lowerStatementWithSemanticsAndReceiver(builder, stmt, null, null);
}

pub fn lowerStatementWithSemantics(builder: *InstructionBuilder, stmt: *Statement, semantic: ?*const SemanticResult) anyerror!void {
    try lowerStatementWithSemanticsAndReceiver(builder, stmt, semantic, null);
}

pub fn lowerStatementWithSemanticsAndReceiver(
    builder: *InstructionBuilder,
    stmt: *Statement,
    semantic: ?*const SemanticResult,
    receiver_ctx: ?ReceiverContext,
) anyerror!void {
    switch (stmt.*) {
        .VarAssignment => {
            try lower_var.lowerVarAssignmentWithSemanticsAndReceiver(builder, stmt.VarAssignment, semantic, receiver_ctx);
        },
        .FunctionDecl => {
            const funcDecl = try lower_function.lowerFunctionDeclWithSemantics(builder, stmt.FunctionDecl, semantic);
            try builder.emit(funcDecl);
            std.debug.print("Lowering function declaration: {s}\n", .{stmt.FunctionDecl.name});
        },
        .VariableDecl => {
            try lower_var.lowerVarDeclarationWithSemanticsAndReceiver(builder, stmt.VariableDecl, semantic, receiver_ctx);
        },
        .WhileStatement => {
            try lower_flow.lowerWhileStatementWithSemanticsAndReceiver(builder, stmt.WhileStatement, semantic, receiver_ctx);
        },
        .IfStatement => {
            try lower_flow.lowerIfStatementWithSemanticsAndReceiver(builder, stmt.IfStatement, semantic, receiver_ctx);
        },
        .ExpressionStmt => {
            switch (stmt.ExpressionStmt.*) {
                .FunctionCall => {
                    try lower_function.lowerFunctionCallWithSemanticsAndReceiver(builder, &stmt.ExpressionStmt.FunctionCall, semantic, receiver_ctx);
                },
                else => {
                    return LowerError.UnsupportedExpression;
                },
            }
        },
        .ReturnStatement => {
            try lower_function.lowerReturnStatementWithSemanticsAndReceiver(builder, stmt.ReturnStatement, semantic, receiver_ctx);
        },
        .FunctionCallStatement => {
            try lower_function.lowerFunctionCallWithSemanticsAndReceiver(builder, stmt.FunctionCallStatement, semantic, receiver_ctx);
        },
        .PrintStatement => {
            const printValue = try lower_expr.lowerExpressionWithSemanticsAndExpectedTypeAndReceiver(builder, stmt.PrintStatement.value, semantic, null, receiver_ctx);
            const resolvedType = if (semantic) |result| result.print_types.get(stmt.PrintStatement) else null;
            try builder.emit(.{ .PrintCall = .{ .value = printValue, .resolvedType = resolvedType } });
        },
        .StructDecl => {
            try lower_struct_decl.lowerStructDeclWithSemantics(builder, stmt.StructDecl, semantic);
        },
        else => {
            return LowerError.UnsupportedStatement;
        },
    }
}

pub fn lowerStatements(builder: *InstructionBuilder, statements: []*Statement) anyerror!void {
    try lowerStatementsWithSemantics(builder, statements, null);
}

pub fn lowerStatementsWithSemantics(builder: *InstructionBuilder, statements: []*Statement, semantic: ?*const SemanticResult) anyerror!void {
    try lowerStatementsWithSemanticsAndReceiver(builder, statements, semantic, null);
}

pub fn lowerStatementsWithSemanticsAndReceiver(
    builder: *InstructionBuilder,
    statements: []*Statement,
    semantic: ?*const SemanticResult,
    receiver_ctx: ?ReceiverContext,
) anyerror!void {
    for (statements) |stmt| {
        try lowerStatementWithSemanticsAndReceiver(builder, stmt, semantic, receiver_ctx);
    }
}
