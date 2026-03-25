const std = @import("std");
const expect = std.testing.expect;
const Lexer = @import("../lexer/lexer.zig").Lexer;
const Parser = @import("../parser/parser.zig").Parser;
const Token = @import("../lexer/tokens.zig").Token;

test "Test variable declaration parsing" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source = "var int x = 5;";
    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    try expect(statements.len == 1);
    const stmt = statements[0];
    try expect(stmt.* == .VariableDecl);
    const varDecl = stmt.VariableDecl;
    try expect(std.mem.eql(u8, varDecl.name, "x"));
    try expect(varDecl.varType.kind == .INT);
    try expect(varDecl.initializer.* == .IntLiteral);
    try expect(varDecl.initializer.IntLiteral.value == 5);
    try expect(varDecl.immutable == false);

    defer token_list.deinit(std.testing.allocator);
}
