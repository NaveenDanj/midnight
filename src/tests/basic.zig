const std = @import("std");
const expect = std.testing.expect;
const Lexer = @import("../lexer/lexer.zig").Lexer;
const Parser = @import("../parser/parser.zig").Parser;
const Token = @import("../lexer/tokens.zig").Token;
const SemanticAnalyzer = @import("../semantic/anaylzer.zig").SemanticAnalyzer;
const SemanticError = @import("../semantic/semantic_error.zig").SemanticError;

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

test "parse expression statement inside function body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\func main() int {
        \\    var int x = 5;
        \\    x + 10;
        \\    return x;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    try expect(statements.len == 1);
    try expect(statements[0].* == .FunctionDecl);

    const body_stmts = statements[0].FunctionDecl.body.statements;
    try expect(body_stmts.len == 3);
    try expect(body_stmts[0].* == .VariableDecl);
    try expect(body_stmts[1].* == .ExpressionStmt);
    try expect(body_stmts[1].ExpressionStmt.* == .Binary);
    try expect(body_stmts[2].* == .ReturnStatement);
}

test "parse member access assignment target" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\struct Person {
        \\    var int age;
        \\}
        \\func main() int {
        \\    var Person p = Person{ age = 10 };
        \\    p.age = 20;
        \\    return p.age;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    try expect(statements.len == 2);
    try expect(statements[1].* == .FunctionDecl);

    const body_stmts = statements[1].FunctionDecl.body.statements;
    try expect(body_stmts.len == 3);
    try expect(body_stmts[1].* == .VarAssignment);
    try expect(body_stmts[1].VarAssignment.target.* == .MemberAccess);
    try expect(std.mem.eql(u8, body_stmts[1].VarAssignment.target.MemberAccess.memberName, "age"));
}

test "semantic analysis accepts valid member assignment" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\struct Person {
        \\    var int age;
        \\}
        \\func main() int {
        \\    var Person p = Person{ age = 10 };
        \\    p.age = 20;
        \\    return p.age;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var semantic = try SemanticAnalyzer.init(allocator);
    try semantic.analyzeProgram(statements);
}

test "semantic analysis rejects immutable struct field assignment" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\struct Person {
        \\    const int age;
        \\}
        \\func main() int {
        \\    var Person p = Person{ age = 10 };
        \\    p.age = 20;
        \\    return p.age;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var semantic = try SemanticAnalyzer.init(allocator);
    try std.testing.expectError(SemanticError.SymbolImmutable, semantic.analyzeProgram(statements));
}

test "semantic analysis rejects assignment to unknown struct member" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\struct Person {
        \\    var int age;
        \\}
        \\func main() int {
        \\    var Person p = Person{ age = 10 };
        \\    p.height = 20;
        \\    return p.age;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var semantic = try SemanticAnalyzer.init(allocator);
    try std.testing.expectError(SemanticError.UndefinedVariable, semantic.analyzeProgram(statements));
}
