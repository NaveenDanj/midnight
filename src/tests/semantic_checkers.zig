const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const expr_ast = @import("../ast/expr.zig");
const stmt_ast = @import("../ast/stmt.zig");
const AssignmentChecker = @import("../semantic/assignment_checker.zig").AssignmentChecker;
const FunctionChecker = @import("../semantic/function_checker.zig").FunctionChecker;
const SemanticContext = @import("../semantic/context.zig").SemanticContext;
const SemanticError = @import("../semantic/semantic_error.zig").SemanticError;
const ScopeStack = @import("../semantic/scope.zig").ScopeStack;
const StructChecker = @import("../semantic/struct_checker.zig").StructChecker;
const Type = @import("../semantic/types.zig").Type;

const Expr = expr_ast.Expr;
const Statement = stmt_ast.Statement;

fn makeExpr(allocator: std.mem.Allocator, value: Expr) !*Expr {
    const expr = try allocator.create(Expr);
    expr.* = value;
    return expr;
}

fn makeStatement(allocator: std.mem.Allocator, value: Statement) !*Statement {
    const stmt = try allocator.create(Statement);
    stmt.* = value;
    return stmt;
}

test "struct checker registers structs and validates initialized fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = try SemanticContext.init(allocator);
    var scopeStack = try ScopeStack.init(allocator);
    try scopeStack.pushScope();

    const age = try allocator.create(stmt_ast.StructPropertyField);
    age.* = .{ .name = "age", .fieldType = .{ .kind = .INT }, .isImmutable = false };

    const fields = try allocator.alloc(stmt_ast.StructField, 1);
    fields[0] = .{ .StructProperty = age };

    var structStmt = stmt_ast.StructStmt{ .name = "Person", .fields = fields };
    var checker = StructChecker.init(allocator, &context, &scopeStack);
    try checker.analyzeStructStatement(&structStmt);

    try expect(context.structs.contains("Person"));
    try expect(scopeStack.lookupSymbol("Person").?.kind == .structure);

    const initFields = try allocator.alloc(expr_ast.StructInitField, 1);
    initFields[0] = .{ .name = "age", .value = try makeExpr(allocator, .{ .IntLiteral = .{ .value = 30 } }) };

    var init = expr_ast.StructInitExpr{ .structName = "Person", .fields = initFields };
    try checker.analyzeStructFields(&structStmt, &init);
}

test "struct checker rejects missing initialized fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = try SemanticContext.init(allocator);
    var scopeStack = try ScopeStack.init(allocator);
    try scopeStack.pushScope();

    const age = try allocator.create(stmt_ast.StructPropertyField);
    age.* = .{ .name = "age", .fieldType = .{ .kind = .INT }, .isImmutable = false };

    const fields = try allocator.alloc(stmt_ast.StructField, 1);
    fields[0] = .{ .StructProperty = age };

    var structStmt = stmt_ast.StructStmt{ .name = "Person", .fields = fields };
    var checker = StructChecker.init(allocator, &context, &scopeStack);

    const initFields = try allocator.alloc(expr_ast.StructInitField, 0);
    var init = expr_ast.StructInitExpr{ .structName = "Person", .fields = initFields };

    try expectError(SemanticError.StructFieldUnIntialized, checker.analyzeStructFields(&structStmt, &init));
}

test "assignment checker declares variables and rejects incompatible initializers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = try SemanticContext.init(allocator);
    var scopeStack = try ScopeStack.init(allocator);
    try scopeStack.pushScope();

    var checker = AssignmentChecker.init(allocator, &context, &scopeStack);
    var valid = stmt_ast.VarDecl{
        .immutable = false,
        .name = "count",
        .varType = .{ .kind = .INT },
        .initializer = try makeExpr(allocator, .{ .IntLiteral = .{ .value = 1 } }),
    };
    try checker.analyzeVarDecl(&valid);

    const symbol = scopeStack.lookupSymbol("count").?;
    try expect(symbol.kind == .variable);
    try expectEqual(Type{ .kind = .INT }, symbol.symbolType);

    var invalid = stmt_ast.VarDecl{
        .immutable = false,
        .name = "ready",
        .varType = .{ .kind = .BOOL },
        .initializer = try makeExpr(allocator, .{ .StringLiteral = .{ .value = "no" } }),
    };
    try expectError(SemanticError.TypeMismatch, checker.analyzeVarDecl(&invalid));
}

test "assignment checker rejects writes to immutable variables" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = try SemanticContext.init(allocator);
    var scopeStack = try ScopeStack.init(allocator);
    try scopeStack.pushScope();
    try scopeStack.declareSymbol("limit", .variable, .{ .kind = .INT }, true, &[_]Type{});

    const target = try makeExpr(allocator, .{ .Identifier = .{ .name = "limit" } });
    const value = try makeExpr(allocator, .{ .IntLiteral = .{ .value = 2 } });
    var assignment = stmt_ast.VarAssign{ .target = target, .value = value, .resolvedType = null };

    var checker = AssignmentChecker.init(allocator, &context, &scopeStack);
    try expectError(SemanticError.SymbolImmutable, checker.analyzeVarAssignment(&assignment));
}

test "function checker declares functions validates calls and records returns" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = try SemanticContext.init(allocator);
    var scopeStack = try ScopeStack.init(allocator);
    try scopeStack.pushScope();

    const param = try allocator.create(stmt_ast.Param);
    param.* = .{ .dataType = .{ .kind = .INT }, .name = "value" };
    const params = try allocator.alloc(*stmt_ast.Param, 1);
    params[0] = param;

    const retExpr = try makeExpr(allocator, .{ .IntLiteral = .{ .value = 5 } });
    const retStmt = try allocator.create(stmt_ast.ReturnStatement);
    retStmt.* = .{ .expression = retExpr };
    const bodyStatements = try allocator.alloc(*Statement, 1);
    bodyStatements[0] = try makeStatement(allocator, .{ .ReturnStatement = retStmt });

    const body = try allocator.create(stmt_ast.BlockStmt);
    body.* = .{ .statements = bodyStatements };

    var func = stmt_ast.FunctionDecl{ .name = "identity", .params = params, .body = body, .returnType = .{ .kind = .INT } };
    var checker = FunctionChecker.init(allocator, &context, &scopeStack);
    try checker.declareFunction(&func);
    try checker.analyzeReturn(retStmt);
    try checker.validateReturns(&func);

    const arg = try makeExpr(allocator, .{ .IntLiteral = .{ .value = 10 } });
    const args = try allocator.alloc(*Expr, 1);
    args[0] = arg;
    var call = expr_ast.FunctionCallStmt{ .name = "identity", .args = args };
    try checker.analyzeFunctionCall(&call);

    try expectEqual(Type{ .kind = .INT }, retStmt.resolvedType.?);
}

test "function checker rejects wrong argument counts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = try SemanticContext.init(allocator);
    var scopeStack = try ScopeStack.init(allocator);
    try scopeStack.pushScope();

    const paramTypes = try allocator.alloc(Type, 1);
    paramTypes[0] = .{ .kind = .INT };
    try scopeStack.declareSymbol("identity", .function, .{ .kind = .INT }, true, paramTypes);

    const args = try allocator.alloc(*Expr, 0);
    var call = expr_ast.FunctionCallStmt{ .name = "identity", .args = args };

    var checker = FunctionChecker.init(allocator, &context, &scopeStack);
    try expectError(SemanticError.ArgumentCountMismatch, checker.analyzeFunctionCall(&call));
}
