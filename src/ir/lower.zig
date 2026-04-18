const std = @import("std");
const InstructionBuilder = @import("./builder.zig").InstructionBuilder;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;
const IfStatement = @import("../parser/lib/parseIf.zig").IfStatement;
const lowerVarAssignment = @import("./lib/lowerVar.zig").lowerVarAssignment;
const lowerVarDeclaration = @import("./lib/lowerVar.zig").lowerVarDeclaration;
const lowerExpression = @import("./lib/lowerExpr.zig").lowerExpression;
const lowerIfStatement = @import("./lib/lowerFlowControl.zig").lowerIfStatement;
const lowerWhileStatement = @import("./lib/lowerFlowControl.zig").lowerWhileStatement;
const lowerFunctionCall = @import("./lib/lowerFunction.zig").lowerFunctionCall;
const lowerFunctionDecl = @import("./lib/lowerFunction.zig").lowerFunctionDecl;
const lowerReturnStatement = @import("./lib/lowerFunction.zig").lowerReturnStatement;

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
                    std.debug.print("Lowering unhandled expression type: {any}\n", .{stmt.ExpressionStmt});
                },
            }
        },
        .ReturnStatement => {
            try lowerReturnStatement(builder, stmt.ReturnStatement);
        },
        .FunctionCallStatement => {
            try lowerFunctionCall(builder, stmt.FunctionCallStatement);
        },
        else => {
            std.debug.print("Lowering unhandled statement type: {any}\n", .{stmt});
        },
    }
}

pub fn lowerStatements(builder: *InstructionBuilder, statements: []*Statement) anyerror!void {
    for (statements) |stmt| {
        try lowerStatement(builder, stmt);
    }
}
