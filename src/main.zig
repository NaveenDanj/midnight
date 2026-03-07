const std = @import("std");
const midnight = @import("midnight");
const Lexer = @import("lexer/lexer.zig").Lexer;
const Parser = @import("parser/parser.zig").Parser;
const Token = @import("lexer/tokens.zig").Token;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile("./src/tests/test1.mn", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    std.debug.print("Source code:\n{s}\n", .{content});

    var lexer = Lexer.init(content);
    var token_list = try lexer.lexAll(allocator);
    var parser = Parser.init(allocator, token_list.items);
    const funcList = try parser.parseProgram();

    // for (token_list.items) |token| {
    //     std.debug.print("Token: {s} (line {d}, column {d})\n", .{ token.lexeme, token.line, token.column });
    // }

    for (funcList) |func| {
        std.debug.print("Parsed function: {s}\n", .{func.name});
        std.debug.print("Return type: {s}\n", .{func.returnType});
    }

    defer token_list.deinit(allocator);
}
