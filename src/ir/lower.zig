const std = @import("std");
const InstructionBuilder = @import("./builder.zig").InstructionBuilder;
const stmt_ast = @import("../ast/stmt.zig");
const Statement = stmt_ast.Statement;
const lower_var = @import("./lib/lowerVar.zig");
const lower_expr = @import("./lib/lowerExpr.zig");
const lower_flow = @import("./lib/lowerFlowControl.zig");
const lower_function = @import("./lib/lowerFunction.zig");
const lower_struct_decl = @import("./lib/lowerStruct.zig");

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
    try lowerStatementWithSemantics(builder, stmt, null);
}

pub fn lowerStatementWithSemantics(builder: *InstructionBuilder, stmt: *Statement, semantic: ?*const SemanticResult) anyerror!void {
    switch (stmt.*) {
        .VarAssignment => {
            try lower_var.lowerVarAssignmentWithSemantics(builder, stmt.VarAssignment, semantic);
        },
        .FunctionDecl => {
            const funcDecl = try lower_function.lowerFunctionDeclWithSemantics(builder, stmt.FunctionDecl, semantic);
            try builder.emit(funcDecl);
            std.debug.print("Lowering function declaration: {s}\n", .{stmt.FunctionDecl.name});
        },
        .VariableDecl => {
            try lower_var.lowerVarDeclarationWithSemantics(builder, stmt.VariableDecl, semantic);
        },
        .WhileStatement => {
            try lower_flow.lowerWhileStatementWithSemantics(builder, stmt.WhileStatement, semantic);
        },
        .IfStatement => {
            try lower_flow.lowerIfStatementWithSemantics(builder, stmt.IfStatement, semantic);
        },
        .ExpressionStmt => {
            switch (stmt.ExpressionStmt.*) {
                .FunctionCall => {
                    try lower_function.lowerFunctionCallWithSemantics(builder, &stmt.ExpressionStmt.FunctionCall, semantic);
                },
                else => {
                    return LowerError.UnsupportedExpression;
                },
            }
        },
        .ReturnStatement => {
            try lower_function.lowerReturnStatementWithSemantics(builder, stmt.ReturnStatement, semantic);
        },
        .FunctionCallStatement => {
            try lower_function.lowerFunctionCallWithSemantics(builder, stmt.FunctionCallStatement, semantic);
        },
        .PrintStatement => {
            const printValue = try lower_expr.lowerExpressionWithSemantics(builder, stmt.PrintStatement.value, semantic);
            const resolvedType = if (semantic) |result| result.print_types.get(stmt.PrintStatement) else null;
            try builder.emit(.{ .PrintCall = .{ .value = printValue, .resolvedType = resolvedType } });
        },
        .StructDecl => {
            try lower_struct_decl.lowerStructDecl(builder, stmt.StructDecl);
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
    for (statements) |stmt| {
        try lowerStatementWithSemantics(builder, stmt, semantic);
    }
}
