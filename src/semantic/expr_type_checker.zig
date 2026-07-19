const std = @import("std");

const expr_ast = @import("../ast/expr.zig");
const SemanticContext = @import("context.zig").SemanticContext;
const SemanticError = @import("semantic_error.zig").SemanticError;
const SemanticResult = @import("result.zig").SemanticResult;
const ScopeStack = @import("scope.zig").ScopeStack;
const types = @import("types.zig");
const typeCompatibility = @import("type_compatibility.zig");

const Expr = expr_ast.Expr;

pub const ExprTypeChecker = struct {
    context: *SemanticContext,
    scopeStack: *ScopeStack,
    result: *SemanticResult,

    pub fn init(context: *SemanticContext, scopeStack: *ScopeStack, result: *SemanticResult) ExprTypeChecker {
        return .{ .context = context, .scopeStack = scopeStack, .result = result };
    }

    pub fn evaluate(self: *ExprTypeChecker, expr: *Expr) SemanticError!types.Type {
        switch (expr.*) {
            .Binary => {
                return try self.record(expr, try self.resolveBinaryOperator(expr));
            },
            .IntLiteral => {
                return try self.record(expr, types.INT);
            },
            .FloatLiteral => {
                return try self.record(expr, types.FLOAT);
            },
            .BoolLiteral => {
                return try self.record(expr, types.BOOL);
            },
            .StringLiteral => {
                return try self.record(expr, types.STRING);
            },
            .Identifier => {
                const idExpr = expr.Identifier;
                const symbol = self.scopeStack.lookupSymbol(idExpr.name) orelse return SemanticError.UndefinedVariable;
                return try self.record(expr, symbol.symbolType);
            },
            .FunctionCall => {
                const funcExpr = expr.FunctionCall;
                const symbol = self.scopeStack.lookupSymbol(funcExpr.name) orelse return SemanticError.UndefinedVariable;
                if (symbol.kind != .function) {
                    return SemanticError.TypeMismatch;
                }
                return try self.record(expr, symbol.symbolType);
            },
            .StructInit => {
                const structInit = expr.StructInit;
                var symbol = self.scopeStack.lookupSymbol(structInit.structName) orelse return SemanticError.UndefinedVariable;
                if (symbol.kind != .structure) {
                    return SemanticError.TypeMismatch;
                }
                symbol.symbolType.struct_name = structInit.structName;
                return try self.record(expr, symbol.symbolType);
            },
            .ExpressionStmt => {
                std.debug.print("Evaluating expression statement: {any}\n", .{expr.ExpressionStmt});
                return try self.record(expr, try self.evaluate(expr.ExpressionStmt));
            },
            .MemberAccess => {
                const object = expr.MemberAccess;
                const memberName = object.memberName;
                const objectType = try self.evaluate(object.object orelse return SemanticError.TypeMismatch);

                if (objectType.kind != .STRUCT) {
                    return SemanticError.TypeMismatch;
                }

                const userDefinedType = self.context.structs.get(objectType.struct_name orelse return SemanticError.UndefinedVariable) orelse return SemanticError.UndefinedVariable;

                for (userDefinedType.fields) |field| {
                    switch (field) {
                        .StructProperty => |property_ptr| {
                            const property = property_ptr.*;
                            if (std.mem.eql(u8, property.name, memberName)) {
                                return try self.record(expr, self.result.struct_property_types.get(property_ptr) orelse return SemanticError.TypeMismatch);
                            }
                        },
                        .StructMethod => |method_ptr| {
                            const method = method_ptr.*;
                            if (std.mem.eql(u8, method.name, memberName)) {
                                return try self.record(expr, self.result.struct_method_return_types.get(method_ptr) orelse return SemanticError.TypeMismatch);
                            }
                        },
                    }
                }

                return SemanticError.UndefinedVariable;
            },
            .Unary => {
                const unary = expr.Unary;
                const operandType = try self.evaluate(unary.operand);

                if (std.mem.eql(u8, unary.operator, "-")) {
                    if (operandType.isNumeric()) {
                        return self.record(expr, operandType);
                    }
                    return SemanticError.TypeMismatch;
                }

                if (std.mem.eql(u8, unary.operator, "!")) {
                    if (operandType.kind == .BOOL) {
                        return self.record(expr, types.BOOL);
                    }
                    return SemanticError.TypeMismatch;
                }

                return SemanticError.TypeMismatch;
            },
            .ArrayLiteral => {
                const arrayExpr = expr.ArrayLiteral;

                if (arrayExpr.elements.len == 0) {
                    return self.record(expr, types.Type{ .kind = .EMPTY, .isArray = true, .struct_name = null });
                }

                const firstElemType = try self.evaluate(arrayExpr.elements[0]);

                for (arrayExpr.elements) |elem| {
                    const elemType = try self.evaluate(elem);
                    if (!typeCompatibility.isAssignable(firstElemType, elemType)) {
                        return SemanticError.TypeMismatch;
                    }
                }

                return self.record(expr, types.Type{ .kind = firstElemType.kind, .isArray = true, .struct_name = firstElemType.struct_name });
            },
            .ArrayAccess => {
                const arrayAccess = expr.ArrayAccess;
                const arrayType = try self.evaluate(arrayAccess.array);

                if (!arrayType.isArray) {
                    return SemanticError.TypeMismatch;
                }

                const indexType = try self.evaluate(arrayAccess.index);
                if (indexType.kind != .INT) {
                    return SemanticError.TypeMismatch;
                }

                return self.record(expr, types.Type{ .kind = arrayType.kind, .isArray = false, .struct_name = arrayType.struct_name });
            },
        }
    }

    fn resolveBinaryOperator(self: *ExprTypeChecker, expr: *Expr) SemanticError!types.Type {
        const binary = expr.Binary;
        const leftType = try self.evaluate(binary.left);
        const rightType = try self.evaluate(binary.right);

        if (!typeCompatibility.isAssignable(leftType, rightType)) {
            return SemanticError.TypeMismatch;
        }

        if (isArithmeticOperator(binary.operator)) {
            if (typeCompatibility.commonNumericType(leftType, rightType)) |resultType| {
                return resultType;
            }

            if (leftType.kind == .STRING and std.mem.eql(u8, binary.operator, "+")) {
                return types.STRING;
            }

            return SemanticError.TypeMismatch;
        }

        if (isComparisonOperator(binary.operator)) {
            return types.BOOL;
        }

        return SemanticError.TypeMismatch;
    }

    fn record(self: *ExprTypeChecker, expr: *Expr, resolved: types.Type) SemanticError!types.Type {
        try self.result.expr_types.put(expr, resolved);
        return resolved;
    }
};

fn isArithmeticOperator(operator: []const u8) bool {
    return std.mem.eql(u8, operator, "+") or
        std.mem.eql(u8, operator, "-") or
        std.mem.eql(u8, operator, "*") or
        std.mem.eql(u8, operator, "/");
}

fn isComparisonOperator(operator: []const u8) bool {
    return std.mem.eql(u8, operator, "==") or
        std.mem.eql(u8, operator, "!=") or
        std.mem.eql(u8, operator, "<") or
        std.mem.eql(u8, operator, ">") or
        std.mem.eql(u8, operator, "<=") or
        std.mem.eql(u8, operator, ">=");
}
