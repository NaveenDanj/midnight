const std = @import("std");
const InstructionBuilder = @import("./builder.zig").InstructionBuilder;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;
const IfStatement = @import("../parser/lib/parseIf.zig").IfStatement;
const lowerVarAssignment = @import("./lib/lowerVar.zig").lowerVarAssignment;
const lowerVarDeclaration = @import("./lib/lowerVar.zig").lowerVarDeclaration;
const lowerExpression = @import("./lib/lowerExpr.zig").lowerExpression;
const lowerIfStatement = @import("./lib/lowerFlowControl.zig").lowerIfStatement;
const lowerWhileStatement = @import("./lib/lowerFlowControl.zig").lowerWhileStatement;

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
            std.debug.print("Lowering function declaration: {s}\n", .{stmt.FunctionDecl.name});
        },
        .VariableDecl => {
            try lowerVarDeclaration(builder, stmt.VariableDecl);
            std.debug.print("Lowering variable declaration: {s}\n", .{stmt.VariableDecl.name});
        },
        .WhileStatement => {
            try lowerWhileStatement(builder, stmt.WhileStatement);
            std.debug.print("Lowering while statement\n", .{});
        },
        .IfStatement => {
            try lowerIfStatement(builder, stmt.IfStatement);
        },
        .ExpressionStmt => {
            std.debug.print("Lowering expression statement\n", .{});
        },
        .ReturnStatement => {
            std.debug.print("Lowering return statement\n", .{});
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
