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

const Expr = expr_ast.Expr;
const FunctionCallStmt = expr_ast.FunctionCallStmt;
const FunctionDecl = stmt_ast.FunctionDecl;
const Param = stmt_ast.Param;
const ReturnStatement = stmt_ast.ReturnStatement;
const StructMethodField = stmt_ast.StructMethodField;
const StructStmt = stmt_ast.StructStmt;

pub const FunctionChecker = struct {
    allocator: std.mem.Allocator,
    context: *SemanticContext,
    scopeStack: *ScopeStack,
    result: *SemanticResult,
    receiver_struct: ?*const StructStmt,

    pub fn init(allocator: std.mem.Allocator, context: *SemanticContext, scopeStack: *ScopeStack, result: *SemanticResult, receiver_struct: ?*const StructStmt) FunctionChecker {
        return .{
            .allocator = allocator,
            .context = context,
            .scopeStack = scopeStack,
            .result = result,
            .receiver_struct = receiver_struct,
        };
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
        try self.declareMethodParams(funcDecl.params);
    }

    pub fn declareMethodParams(self: *FunctionChecker, params: []*Param) SemanticError!void {
        for (params) |param| {
            const paramType = self.result.param_types.get(param) orelse try typeResolver.resolveTypeRef(self.context, param.dataType);
            try self.result.param_types.put(param, paramType);
            try self.scopeStack.declareSymbol(param.name, .parameter, paramType, false, &[_]types.Type{});
        }
    }

    pub fn analyzeReturn(self: *FunctionChecker, retStmt: *ReturnStatement) SemanticError!void {
        var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result, self.receiver_struct);
        const actualType = try exprChecker.evaluate(retStmt.expression);
        try self.result.return_types.put(retStmt, actualType);
    }

    pub fn validateReturns(self: *FunctionChecker, funcDecl: *FunctionDecl) SemanticError!void {
        const expectedRetType = self.result.function_return_types.get(funcDecl) orelse try typeResolver.resolveTypeRef(self.context, funcDecl.returnType);
        if (!funcDecl.isExtern) {
            try self.validateReturnBlock(funcDecl.body.?.statements, expectedRetType);
        }
    }

    pub fn validateMethodReturns(self: *FunctionChecker, method: *StructMethodField) SemanticError!void {
        const expectedRetType = self.result.struct_method_return_types.get(method) orelse try typeResolver.resolveTypeRef(self.context, method.returnType);
        try self.validateReturnBlock(method.body.statements, expectedRetType);
    }

    pub fn analyzeFunctionCall(self: *FunctionChecker, funcCall: *FunctionCallStmt) SemanticError!void {
        if (funcCall.callee) |callee| {
            switch (callee.*) {
                .MemberAccess => {
                    const object_expr = callee.MemberAccess.object orelse return SemanticError.TypeMismatch;
                    var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result, self.receiver_struct);
                    const object_type = try exprChecker.evaluate(object_expr);
                    const method = try self.lookupStructMethod(object_type, funcCall.name) orelse return SemanticError.UndefinedVariable;
                    return try self.validateArgs(method.parameters, funcCall.args);
                },
                else => {},
            }
        }

        if (self.scopeStack.lookupSymbol(funcCall.name)) |symbol| {
            if (symbol.kind != .function) {
                return SemanticError.TypeMismatch;
            }

            if (symbol.params.len != funcCall.args.len) {
                return SemanticError.ArgumentCountMismatch;
            }

            var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result, self.receiver_struct);
            for (symbol.params, 0..) |expectedParam, i| {
                const argType = try exprChecker.evaluate(funcCall.args[i]);
                if (!typeCompatibility.isAssignable(expectedParam, argType)) {
                    return SemanticError.TypeMismatch;
                }
            }
            return;
        }

        if (self.receiver_struct) |receiver_struct| {
            const receiver_type = types.Type{ .kind = .STRUCT, .struct_name = receiver_struct.name };
            const method = try self.lookupStructMethod(receiver_type, funcCall.name) orelse return SemanticError.UndefinedVariable;
            return try self.validateArgs(method.parameters, funcCall.args);
        }

        return SemanticError.UndefinedVariable;
    }

    fn validateArgs(self: *FunctionChecker, params: []*Param, args: []*Expr) SemanticError!void {
        if (params.len != args.len) {
            return SemanticError.ArgumentCountMismatch;
        }

        var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result, self.receiver_struct);
        for (params, 0..) |param, i| {
            const expectedParam = self.result.param_types.get(param) orelse try typeResolver.resolveTypeRef(self.context, param.dataType);
            const argType = try exprChecker.evaluate(args[i]);
            if (!typeCompatibility.isAssignable(expectedParam, argType)) {
                return SemanticError.TypeMismatch;
            }
        }
    }

    fn validateReturnBlock(self: *FunctionChecker, statements: []*stmt_ast.Statement, expectedRetType: types.Type) SemanticError!void {
        if (expectedRetType.kind == .VOID) {
            for (statements) |stmt| {
                if (stmt.* == .ReturnStatement) {
                    return SemanticError.TypeMismatch;
                }
            }
            return;
        }

        var hasReturnWithValue = false;
        for (statements) |stmt| {
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

    fn lookupStructMethod(self: *FunctionChecker, object_type: types.Type, method_name: []const u8) SemanticError!?*StructMethodField {
        if (object_type.kind != .STRUCT) {
            return SemanticError.TypeMismatch;
        }

        const struct_def = self.context.structs.get(object_type.struct_name orelse return SemanticError.UndefinedVariable) orelse return SemanticError.UndefinedVariable;
        for (struct_def.fields) |field| {
            switch (field) {
                .StructMethod => |method_ptr| {
                    if (std.mem.eql(u8, method_ptr.name, method_name)) {
                        return method_ptr;
                    }
                },
                .StructProperty => {},
            }
        }

        return null;
    }
};
