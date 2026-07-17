const std = @import("std");
const InstructionBuilder = @import("./builder.zig").InstructionBuilder;
const stmt_ast = @import("../ast/stmt.zig");
const Statement = stmt_ast.Statement;
const IfStatement = stmt_ast.IfStatement;
const lowerVarAssignment = @import("./lib/lowerVar.zig").lowerVarAssignment;
const lowerVarDeclaration = @import("./lib/lowerVar.zig").lowerVarDeclaration;
const lowerExpression = @import("./lib/lowerExpr.zig").lowerExpression;
const lowerIfStatement = @import("./lib/lowerFlowControl.zig").lowerIfStatement;
const lowerWhileStatement = @import("./lib/lowerFlowControl.zig").lowerWhileStatement;
const lowerFunctionCall = @import("./lib/lowerFunction.zig").lowerFunctionCall;
const lowerFunctionDecl = @import("./lib/lowerFunction.zig").lowerFunctionDecl;
const lowerReturnStatement = @import("./lib/lowerFunction.zig").lowerReturnStatement;
const LowerError = @import("./lower_error.zig").LowerError;

pub fn generateIR(builder: *InstructionBuilder, statements: []*Statement) anyerror!void {
    for (statements) |stmt| {
        try lowerStatement(builder, stmt);
    }
}

pub fn lowerStatement(builder: *InstructionBuilder, stmt: *Statement) anyerror!void {
    switch (stmt.*) {
        .VarAssignment => {
            try lowerVarAssignment(builder, stmt.VarAssignment);
        },
        .FunctionDecl => {
            const funcDecl = try lowerFunctionDecl(builder, stmt.FunctionDecl);
            try builder.emit(funcDecl);
            std.debug.print("Lowering function declaration: {s}\n", .{stmt.FunctionDecl.name});
        },
        .VariableDecl => {
            try lowerVarDeclaration(builder, stmt.VariableDecl);
        },
        .WhileStatement => {
            try lowerWhileStatement(builder, stmt.WhileStatement);
        },
        .IfStatement => {
            try lowerIfStatement(builder, stmt.IfStatement);
        },
        .ExpressionStmt => {
            switch (stmt.ExpressionStmt.*) {
                .FunctionCall => {
                    try lowerFunctionCall(builder, &stmt.ExpressionStmt.FunctionCall);
                },
                else => {
                    return LowerError.UnsupportedExpression;
                },
            }
        },
        .ReturnStatement => {
            try lowerReturnStatement(builder, stmt.ReturnStatement);
        },
        .FunctionCallStatement => {
            try lowerFunctionCall(builder, stmt.FunctionCallStatement);
        },
        .PrintStatement => {
            const printValue = try lowerExpression(builder, stmt.PrintStatement.value);
            try builder.emit(.{ .PrintCall = .{ .value = printValue, .resolvedType = stmt.PrintStatement.resolvedType } });
        },
        .StructDecl => {},
        else => {
            return LowerError.UnsupportedStatement;
        },
    }
}

pub fn lowerStatements(builder: *InstructionBuilder, statements: []*Statement) anyerror!void {
    for (statements) |stmt| {
        try lowerStatement(builder, stmt);
    }
}
