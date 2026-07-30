const std = @import("std");
const Lexer = @import("../lexer/lexer.zig").Lexer;
const Parser = @import("../parser/parser.zig").Parser;
const SemanticAnalyzer = @import("../semantic/anaylzer.zig").SemanticAnalyzer;
const Statement = @import("../ast/stmt.zig").Statement;

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const io = std.Io.Threaded.global_single_threaded.io();
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var reader_buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &reader_buffer);
    return try reader.interface.allocRemaining(allocator, .unlimited);
}

pub fn parseFromSource(allocator: std.mem.Allocator, source: []const u8) ![]*Statement {
    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(allocator);
    defer token_list.deinit(allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();
    return statements;
}
