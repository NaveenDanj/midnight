const std = @import("std");
const midnight = @import("midnight");
const Lexer = @import("lexer/lexer.zig").Lexer;
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

    for (token_list.items) |token| {
        std.debug.print(
            "Token: {d} '{s}' at line {d}, column {d}\n",
            .{ token.kind, token.lexeme, token.line, token.column },
        );
    }

    defer token_list.deinit(allocator);
}
