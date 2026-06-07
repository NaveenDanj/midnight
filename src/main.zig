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

    var irBuilder = InstructionBuilder.init(allocator);
    try generateIR(&irBuilder, statements);

    std.debug.print("=== Generated IR ===\n", .{});
    for (irBuilder.instructions.items) |instrunction| {
        std.debug.print("{any}\n", .{instrunction});
    }

    var backend = X86_64Backend.init(allocator);
    const asm_str = try backend.generate(irBuilder.instructions.items);
    try backend.build("./build/output.asm", asm_str);

    defer token_list.deinit(allocator);
}
