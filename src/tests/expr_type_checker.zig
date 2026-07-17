const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const Expr = @import("../ast/expr.zig").Expr;
const ExprTypeChecker = @import("../semantic/expr_type_checker.zig").ExprTypeChecker;
const SemanticContext = @import("../semantic/context.zig").SemanticContext;
const SemanticError = @import("../semantic/semantic_error.zig").SemanticError;
const SemanticResult = @import("../semantic/result.zig").SemanticResult;
const ScopeStack = @import("../semantic/scope.zig").ScopeStack;
const Type = @import("../semantic/types.zig").Type;

fn makeExpr(allocator: std.mem.Allocator, value: Expr) !*Expr {
    const expr = try allocator.create(Expr);
    expr.* = value;
    return expr;
}

test "expression type checker resolves binary numeric operators" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = try SemanticContext.init(allocator);
    var scopeStack = try ScopeStack.init(allocator);
    var semantic_result = SemanticResult.init(allocator);
    try scopeStack.pushScope();

    const left = try makeExpr(allocator, .{ .IntLiteral = .{ .value = 1 } });
    const right = try makeExpr(allocator, .{ .FloatLiteral = .{ .value = 2.5 } });
    const binary = try makeExpr(allocator, .{ .Binary = .{ .left = left, .operator = "+", .right = right } });

    var checker = ExprTypeChecker.init(&context, &scopeStack, &semantic_result);
    const result = try checker.evaluate(binary);

    try expectEqual(Type{ .kind = .FLOAT }, result);
    try expectEqual(Type{ .kind = .FLOAT }, semantic_result.expr_types.get(binary).?);
}

test "expression type checker reads identifiers from scope and returns array element type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = try SemanticContext.init(allocator);
    var scopeStack = try ScopeStack.init(allocator);
    var semantic_result = SemanticResult.init(allocator);
    try scopeStack.pushScope();
    try scopeStack.declareSymbol("values", .variable, .{ .kind = .INT, .isArray = true }, false, &[_]Type{});

    const array = try makeExpr(allocator, .{ .Identifier = .{ .name = "values" } });
    const index = try makeExpr(allocator, .{ .IntLiteral = .{ .value = 0 } });
    const access = try makeExpr(allocator, .{ .ArrayAccess = .{ .array = array, .index = index } });

    var checker = ExprTypeChecker.init(&context, &scopeStack, &semantic_result);
    const result = try checker.evaluate(access);

    try expectEqual(Type{ .kind = .INT }, result);
    try expect(semantic_result.expr_types.get(array).?.isArray);
}

test "expression type checker rejects unsupported binary operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = try SemanticContext.init(allocator);
    var scopeStack = try ScopeStack.init(allocator);
    var semantic_result = SemanticResult.init(allocator);
    try scopeStack.pushScope();

    const left = try makeExpr(allocator, .{ .StringLiteral = .{ .value = "a" } });
    const right = try makeExpr(allocator, .{ .StringLiteral = .{ .value = "b" } });
    const binary = try makeExpr(allocator, .{ .Binary = .{ .left = left, .operator = "-", .right = right } });

    var checker = ExprTypeChecker.init(&context, &scopeStack, &semantic_result);
    try expectError(SemanticError.TypeMismatch, checker.evaluate(binary));
}
