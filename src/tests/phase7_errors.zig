const std = @import("std");
const expectError = std.testing.expectError;

const AsmBuilder = @import("../backend/asm_builder.zig").AsmBuilder;
const BackendError = @import("../backend/x86_64/x86_64_backend.zig").BackendError;
const X86_64Backend = @import("../backend/x86_64/x86_64_backend.zig").X86_64Backend;
const Expr = @import("../ast/expr.zig").Expr;
const Instruction = @import("../ir/ir.zig").Instruction;
const Lexer = @import("../lexer/lexer.zig").Lexer;
const LexerError = @import("../lexer/lexer.zig").LexerError;
const SemanticAnalyzer = @import("../semantic/anaylzer.zig").SemanticAnalyzer;
const SemanticError = @import("../semantic/semantic_error.zig").SemanticError;
const Statement = @import("../ast/stmt.zig").Statement;
const FunctionCallStmt = @import("../ast/stmt.zig").FunctionCallStmt;

test "lexer returns error for unknown character" {
    var lexer = Lexer.init("@");
    try expectError(LexerError.UnknownCharacter, lexer.lexAll(std.testing.allocator));
}

test "lexer returns error for unterminated string" {
    var lexer = Lexer.init("\"hello");
    try expectError(LexerError.UnterminatedString, lexer.lexAll(std.testing.allocator));
}

test "semantic analyzer returns unsupported statement for expression statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const expr = try allocator.create(Expr);
    expr.* = .{ .IntLiteral = .{ .value = 1 } };

    const stmt = try allocator.create(Statement);
    stmt.* = .{ .ExpressionStmt = expr };

    const statements = try allocator.alloc(*Statement, 1);
    statements[0] = stmt;

    var analyzer = try SemanticAnalyzer.init(allocator);
    try expectError(SemanticError.UnsupportedStatement, analyzer.analyzeProgram(statements));
}

test "semantic analyzer accepts function call expression statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const arg = try allocator.create(Expr);
    arg.* = .{ .IntLiteral = .{ .value = 1 } };

    const args = try allocator.alloc(*Expr, 1);
    args[0] = arg;

    const call_expr = try allocator.create(Expr);
    call_expr.* = .{ .FunctionCall = FunctionCallStmt{
        .name = "identity",
        .args = args,
    } };

    const call_stmt = try allocator.create(Statement);
    call_stmt.* = .{ .ExpressionStmt = call_expr };

    const ret_expr = try allocator.create(Expr);
    ret_expr.* = .{ .Identifier = .{ .name = "x" } };

    const ret_stmt = try allocator.create(@import("../ast/stmt.zig").ReturnStatement);
    ret_stmt.* = .{ .expression = ret_expr };

    const ret_statement = try allocator.create(Statement);
    ret_statement.* = .{ .ReturnStatement = ret_stmt };

    const param = try allocator.create(@import("../ast/stmt.zig").Param);
    param.* = .{ .dataType = .{ .name = "int" }, .name = "x" };

    const params = try allocator.alloc(*@import("../ast/stmt.zig").Param, 1);
    params[0] = param;

    const body_statements = try allocator.alloc(*Statement, 2);
    body_statements[0] = call_stmt;
    body_statements[1] = ret_statement;

    const body = try allocator.create(@import("../ast/stmt.zig").BlockStmt);
    body.* = .{ .statements = body_statements };

    const func = try allocator.create(@import("../ast/stmt.zig").FunctionDecl);
    func.* = .{
        .name = "identity",
        .params = params,
        .body = body,
        .returnType = .{ .name = "int" },
    };

    const func_stmt = try allocator.create(Statement);
    func_stmt.* = .{ .FunctionDecl = func };

    const statements = try allocator.alloc(*Statement, 1);
    statements[0] = func_stmt;

    var analyzer = try SemanticAnalyzer.init(allocator);
    try analyzer.analyzeProgram(statements);
}

test "backend returns error for unsupported instruction" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var backend = X86_64Backend.init(allocator);
    var asmBuilder = try AsmBuilder.init(allocator);
    defer asmBuilder.deinit();

    var instruction = Instruction{ .FunctionCall = .{ .name = "doWork", .args = &[_]@import("../ir/ir.zig").Value{}, .dest = 0 } };
    try expectError(BackendError.UnsupportedInstruction, backend.lowerInstruction(&asmBuilder, &instruction));
}

test "backend returns error for missing binary resolved type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var backend = X86_64Backend.init(allocator);
    var asmBuilder = try AsmBuilder.init(allocator);
    defer asmBuilder.deinit();

    var instruction = Instruction{ .BinaryOp = .{
        .op = .Add,
        .left = .{ .temp = 0 },
        .right = .{ .temp = 1 },
        .dest = 2,
        .resolvedType = null,
    } };

    try expectError(BackendError.MissingResolvedType, backend.lowerInstruction(&asmBuilder, &instruction));
}

test "backend returns error for unsupported integer binary operation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var backend = X86_64Backend.init(allocator);
    var asmBuilder = try AsmBuilder.init(allocator);
    defer asmBuilder.deinit();

    var instruction = Instruction{ .BinaryOp = .{
        .op = .Equal,
        .left = .{ .temp = 0 },
        .right = .{ .temp = 1 },
        .dest = 2,
        .resolvedType = .{ .kind = .INT },
    } };

    try expectError(BackendError.UnsupportedIntegerBinaryOperation, backend.lowerInstruction(&asmBuilder, &instruction));
}
