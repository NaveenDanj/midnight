const std = @import("std");
const midnight = @import("midnight");
const Lexer = @import("lexer/lexer.zig").Lexer;
const Parser = @import("parser/parser.zig").Parser;
const Token = @import("lexer/tokens.zig").Token;
const SemanticAnalyzer = @import("semantic/anaylzer.zig").SemanticAnalyzer;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile("./src/data/struct.mn", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    std.debug.print("Source code:\n{s}\n", .{content});

    var lexer = Lexer.init(content);
    var token_list = try lexer.lexAll(allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var semanticAnalyzer = try SemanticAnalyzer.init(allocator);
    try semanticAnalyzer.analyzeProgram(statements);

    for (token_list.items) |token| {
        std.debug.print("Token: {s} (line {d}, column {d})\n", .{ token.lexeme, token.line + 1, token.column });
    }

    for (statements) |stmt| {
        std.debug.print("Parsed statement: {any}\n", .{stmt});

        if (stmt.* == .FunctionDecl) {
            for (stmt.FunctionDecl.params) |param| {
                std.debug.print("  Param: {s} of type {any}\n", .{ param.name, param.dataType });
            }

            for (stmt.FunctionDecl.body.statements) |bodyStmt| {
                std.debug.print("  Body statement: {any}\n", .{bodyStmt});
            }
        }
    }

    defer token_list.deinit(allocator);
}
