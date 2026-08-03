const std = @import("std");
const Lexer = @import("../lexer/lexer.zig").Lexer;
const Parser = @import("../parser/parser.zig").Parser;
const SemanticAnalyzer = @import("../semantic/anaylzer.zig").SemanticAnalyzer;
const Statement = @import("../ast/stmt.zig").Statement;

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, 1024 * 1024);
}

pub fn parseFromSource(allocator: std.mem.Allocator, source: []const u8) ![]*Statement {
    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(allocator);
    defer token_list.deinit(allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();
    return statements;
}
