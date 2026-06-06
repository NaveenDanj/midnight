const std = @import("std");
const midnight = @import("midnight");
const Lexer = @import("lexer/lexer.zig").Lexer;
const Parser = @import("parser/parser.zig").Parser;
const Token = @import("lexer/tokens.zig").Token;
const SemanticAnalyzer = @import("semantic/anaylzer.zig").SemanticAnalyzer;
const generateIR = @import("ir/lower.zig").generateIR;
const InstructionBuilder = @import("ir/builder.zig").InstructionBuilder;
const Executor = @import("runtime/executor.zig").Executor;
const X86_64Backend = @import("backend/x86_64/x86_64_backend.zig").X86_64Backend;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile("./src/data/simple.mn", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var lexer = Lexer.init(content);
    var token_list = try lexer.lexAll(allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var semanticAnalyzer = try SemanticAnalyzer.init(allocator);
    try semanticAnalyzer.analyzeProgram(statements);

    // for (token_list.items) |token| {
    //     std.debug.print("Token: {s} (line {d}, column {d})\n", .{ token.lexeme, token.line + 1, token.column });
    // }

    // for (statements) |stmt| {
    //     std.debug.print("Parsed statement: {any}\n", .{stmt});

    //     if (stmt.* == .FunctionDecl) {
    //         for (stmt.FunctionDecl.params) |param| {
    //             std.debug.print("  Param: {s} of type {any}\n", .{ param.name, param.dataType });
    //         }

    //         for (stmt.FunctionDecl.body.statements) |bodyStmt| {
    //             std.debug.print("  Body statement: {any}\n", .{bodyStmt});
    //         }
    //     }
    // }

    var irBuilder = InstructionBuilder.init(allocator);
    try generateIR(&irBuilder, statements);

    std.debug.print("=== Generated IR ===\n", .{});
    for (irBuilder.instructions.items) |instrunction| {
        std.debug.print("{any}\n", .{instrunction});
    }

    std.debug.print("\n=== Executing ===\n", .{});
    // var executor = Executor.init(allocator);
    // defer executor.deinit();

    // try executor.run(irBuilder.instructions.items);
    // executor.printResult();

    var backend = X86_64Backend.init(allocator);
    const asm_str = try backend.generate(irBuilder.instructions.items);
    std.debug.print("\n=== Generated Assembly ===\n{s}\n", .{asm_str});

    try backend.writeAsm(asm_str, "./build/output.asm");

    defer token_list.deinit(allocator);
}
