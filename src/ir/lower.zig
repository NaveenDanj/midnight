const std = @import("std");
const InstructionBuilder = @import("./builder.zig").InstructionBuilder;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;
const lowerVarAssignment = @import("./lib/lowerVar.zig").lowerVarAssignment;

pub fn generateIR(builder: *InstructionBuilder, statements: []*Statement) !void {
    for (statements) |stmt| {
        try lowerStatement(builder, stmt);
    }
}

pub fn lowerStatement(builder: *InstructionBuilder, stmt: *Statement) !void {
    switch (stmt.*) {
        .VarAssignment => {
            try lowerVarAssignment(builder, stmt.VarAssignment);
        },
        .FunctionDecl => {
            std.debug.print("Lowering function declaration: {s}\n", .{stmt.FunctionDecl.name});
        },
        .VariableDecl => {
            std.debug.print("Lowering variable declaration: {s}\n", .{stmt.VariableDecl.name});
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
