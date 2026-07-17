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
    try expect(std.mem.eql(u8, varDecl.varType.name, "int"));
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

test "parse shared type syntax for arrays and user types" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\struct Bag {
        \\    var int[] values;
        \\}
        \\func first(int[] values, Bag bag) int[] {
        \\    var int[] local = [1, 2];
        \\    return values;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    try expect(statements.len == 2);
    try expect(statements[0].* == .StructDecl);
    try expect(statements[1].* == .FunctionDecl);

    const func = statements[1].FunctionDecl;
    try expect(std.mem.eql(u8, func.returnType.name, "int"));
    try expect(func.returnType.is_array);

    try expect(func.params.len == 2);
    try expect(std.mem.eql(u8, func.params[0].dataType.name, "int"));
    try expect(func.params[0].dataType.is_array);
    try expect(std.mem.eql(u8, func.params[1].dataType.name, "Bag"));

    const body = func.body.statements;
    try expect(body.len == 2);
    try expect(body[0].* == .VariableDecl);
    try expect(std.mem.eql(u8, body[0].VariableDecl.varType.name, "int"));
    try expect(body[0].VariableDecl.varType.is_array);
}

test "parse function call statement using shared argument list" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\func main() int {
        \\    sum(1, 2 + 3);
        \\    return 0;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    try expect(statements.len == 1);
    const body = statements[0].FunctionDecl.body.statements;
    try expect(body.len == 2);
    try expect(body[0].* == .ExpressionStmt);
    try expect(body[0].ExpressionStmt.* == .FunctionCall);
    try expect(std.mem.eql(u8, body[0].ExpressionStmt.FunctionCall.name, "sum"));
    try expect(body[0].ExpressionStmt.FunctionCall.args.len == 2);
    try expect(body[0].ExpressionStmt.FunctionCall.args[0].* == .IntLiteral);
    try expect(body[0].ExpressionStmt.FunctionCall.args[1].* == .Binary);
}

test "parse member function call keeps callee" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\func main() int {
        \\    counter.next(1);
        \\    return 0;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    const call_expr = statements[0].FunctionDecl.body.statements[0].ExpressionStmt;
    try expect(call_expr.* == .FunctionCall);
    try expect(std.mem.eql(u8, call_expr.FunctionCall.name, "next"));
    try expect(call_expr.FunctionCall.args.len == 1);
    const callee = call_expr.FunctionCall.callee orelse return error.TestExpectedEqual;
    try expect(callee.* == .MemberAccess);
    try expect(std.mem.eql(u8, callee.MemberAccess.memberName, "next"));
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
