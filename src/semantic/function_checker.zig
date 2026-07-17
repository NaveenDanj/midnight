const std = @import("std");

const expr_ast = @import("../ast/expr.zig");
const stmt_ast = @import("../ast/stmt.zig");
const ExprTypeChecker = @import("expr_type_checker.zig").ExprTypeChecker;
const SemanticContext = @import("context.zig").SemanticContext;
const SemanticError = @import("semantic_error.zig").SemanticError;
const ScopeStack = @import("scope.zig").ScopeStack;
const types = @import("types.zig");
const typeCompatibility = @import("type_compatibility.zig");

const FunctionCallStmt = expr_ast.FunctionCallStmt;
const FunctionDecl = stmt_ast.FunctionDecl;
const ReturnStatement = stmt_ast.ReturnStatement;

pub const FunctionChecker = struct {
    allocator: std.mem.Allocator,
    context: *SemanticContext,
    scopeStack: *ScopeStack,

    pub fn init(allocator: std.mem.Allocator, context: *SemanticContext, scopeStack: *ScopeStack) FunctionChecker {
        return .{ .allocator = allocator, .context = context, .scopeStack = scopeStack };
    }

    pub fn declareFunction(self: *FunctionChecker, funcDecl: *FunctionDecl) SemanticError!void {
        var paramTypes = try std.ArrayList(types.Type).initCapacity(self.allocator, 0);
        for (funcDecl.params) |param| {
            try paramTypes.append(self.allocator, param.dataType);
        }

        try self.scopeStack.declareSymbol(funcDecl.name, .function, funcDecl.returnType, true, paramTypes.items);
    }

    pub fn declareParams(self: *FunctionChecker, funcDecl: *FunctionDecl) SemanticError!void {
        for (funcDecl.params) |param| {
            try self.scopeStack.declareSymbol(param.name, .parameter, param.dataType, false, &[_]types.Type{});
        }
    }

    pub fn analyzeReturn(self: *FunctionChecker, retStmt: *ReturnStatement) SemanticError!void {
        var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack);
        const actualType = try exprChecker.evaluate(retStmt.expression);
        retStmt.resolvedType = actualType;
    }

    pub fn validateReturns(self: *FunctionChecker, funcDecl: *FunctionDecl) SemanticError!void {
        _ = self;
        const expectedRetType = funcDecl.returnType;

        if (expectedRetType.kind == .VOID) {
            for (funcDecl.body.statements) |stmt| {
                if (stmt.* == .ReturnStatement) {
                    return SemanticError.TypeMismatch;
                }
            }
            return;
        }

        var hasReturnWithValue = false;
        for (funcDecl.body.statements) |stmt| {
            if (stmt.* == .ReturnStatement) {
                const retStmt = stmt.ReturnStatement;
                if (!typeCompatibility.isAssignable(expectedRetType, retStmt.resolvedType orelse return SemanticError.TypeMismatch)) {
                    return SemanticError.TypeMismatch;
                }
                hasReturnWithValue = true;
            }
        }

        if (!hasReturnWithValue) {
            return SemanticError.MissingReturnStatement;
        }
    }

    pub fn analyzeFunctionCall(self: *FunctionChecker, funcCall: *FunctionCallStmt) SemanticError!void {
        const symbol = self.scopeStack.lookupSymbol(funcCall.name) orelse return SemanticError.UndefinedVariable;
        const params = symbol.params;

        if (symbol.kind != .function) {
            return SemanticError.TypeMismatch;
        }

        if (params.len != funcCall.args.len) {
            return SemanticError.ArgumentCountMismatch;
        }

        var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack);
        for (params, 0..) |expectedParam, i| {
            const argType = try exprChecker.evaluate(funcCall.args[i]);
            if (!typeCompatibility.isAssignable(expectedParam, argType)) {
                return SemanticError.TypeMismatch;
            }
        }
    }
};
