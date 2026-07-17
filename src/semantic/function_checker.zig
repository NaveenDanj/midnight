const std = @import("std");

const expr_ast = @import("../ast/expr.zig");
const stmt_ast = @import("../ast/stmt.zig");
const ExprTypeChecker = @import("expr_type_checker.zig").ExprTypeChecker;
const SemanticContext = @import("context.zig").SemanticContext;
const SemanticError = @import("semantic_error.zig").SemanticError;
const SemanticResult = @import("result.zig").SemanticResult;
const ScopeStack = @import("scope.zig").ScopeStack;
const types = @import("types.zig");
const typeCompatibility = @import("type_compatibility.zig");
const typeResolver = @import("type_resolver.zig");

const FunctionCallStmt = expr_ast.FunctionCallStmt;
const FunctionDecl = stmt_ast.FunctionDecl;
const ReturnStatement = stmt_ast.ReturnStatement;

pub const FunctionChecker = struct {
    allocator: std.mem.Allocator,
    context: *SemanticContext,
    scopeStack: *ScopeStack,
    result: *SemanticResult,

    pub fn init(allocator: std.mem.Allocator, context: *SemanticContext, scopeStack: *ScopeStack, result: *SemanticResult) FunctionChecker {
        return .{ .allocator = allocator, .context = context, .scopeStack = scopeStack, .result = result };
    }

    pub fn declareFunction(self: *FunctionChecker, funcDecl: *FunctionDecl) SemanticError!void {
        var paramTypes = try std.ArrayList(types.Type).initCapacity(self.allocator, 0);
        for (funcDecl.params) |param| {
            const paramType = try typeResolver.resolveTypeRef(self.context, param.dataType);
            try self.result.param_types.put(param, paramType);
            try paramTypes.append(self.allocator, paramType);
        }

        const returnType = try typeResolver.resolveTypeRef(self.context, funcDecl.returnType);
        try self.result.function_return_types.put(funcDecl, returnType);
        try self.scopeStack.declareSymbol(funcDecl.name, .function, returnType, true, paramTypes.items);
    }

    pub fn declareParams(self: *FunctionChecker, funcDecl: *FunctionDecl) SemanticError!void {
        for (funcDecl.params) |param| {
            const paramType = self.result.param_types.get(param) orelse try typeResolver.resolveTypeRef(self.context, param.dataType);
            try self.result.param_types.put(param, paramType);
            try self.scopeStack.declareSymbol(param.name, .parameter, paramType, false, &[_]types.Type{});
        }
    }

    pub fn analyzeReturn(self: *FunctionChecker, retStmt: *ReturnStatement) SemanticError!void {
        var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result);
        const actualType = try exprChecker.evaluate(retStmt.expression);
        try self.result.return_types.put(retStmt, actualType);
    }

    pub fn validateReturns(self: *FunctionChecker, funcDecl: *FunctionDecl) SemanticError!void {
        const expectedRetType = self.result.function_return_types.get(funcDecl) orelse try typeResolver.resolveTypeRef(self.context, funcDecl.returnType);

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
                if (!typeCompatibility.isAssignable(expectedRetType, self.result.return_types.get(retStmt) orelse return SemanticError.TypeMismatch)) {
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

        var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result);
        for (params, 0..) |expectedParam, i| {
            const argType = try exprChecker.evaluate(funcCall.args[i]);
            if (!typeCompatibility.isAssignable(expectedParam, argType)) {
                return SemanticError.TypeMismatch;
            }
        }
    }
};
