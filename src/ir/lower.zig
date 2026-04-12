const std = @import("std");
const InstructionBuilder = @import("./builder.zig").InstructionBuilder;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;
const IfStatement = @import("../parser/lib/parseIf.zig").IfStatement;
const lowerVarAssignment = @import("./lib/lowerVar.zig").lowerVarAssignment;
const lowerVarDeclaration = @import("./lib/lowerVar.zig").lowerVarDeclaration;
const lowerExpression = @import("./lib/lowerExpr.zig").lowerExpression;

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

fn lowerStatements(builder: *InstructionBuilder, statements: []*Statement) anyerror!void {
    for (statements) |stmt| {
        try lowerStatement(builder, stmt);
    }
}

fn lowerIfStatement(builder: *InstructionBuilder, ifStmt: *IfStatement) anyerror!void {
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
