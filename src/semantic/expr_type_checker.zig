const std = @import("std");

const expr_ast = @import("../ast/expr.zig");
const stmt_ast = @import("../ast/stmt.zig");
const SemanticContext = @import("context.zig").SemanticContext;
const SemanticError = @import("semantic_error.zig").SemanticError;
const SemanticResult = @import("result.zig").SemanticResult;
const ScopeStack = @import("scope.zig").ScopeStack;
const types = @import("types.zig");
const typeCompatibility = @import("type_compatibility.zig");

const Expr = expr_ast.Expr;
const StructMethodField = stmt_ast.StructMethodField;
const StructStmt = stmt_ast.StructStmt;

pub const ExprTypeChecker = struct {
    context: *SemanticContext,
    scopeStack: *ScopeStack,
    result: *SemanticResult,
    receiver_struct: ?*const StructStmt,

    pub fn init(context: *SemanticContext, scopeStack: *ScopeStack, result: *SemanticResult, receiver_struct: ?*const StructStmt) ExprTypeChecker {
        return .{
            .context = context,
            .scopeStack = scopeStack,
            .result = result,
            .receiver_struct = receiver_struct,
        };
    }

    pub fn evaluate(self: *ExprTypeChecker, expr: *Expr) SemanticError!types.Type {
        switch (expr.*) {
            .Binary => return try self.record(expr, try self.resolveBinaryOperator(expr)),
            .IntLiteral => return try self.record(expr, types.INT),
            .FloatLiteral => return try self.record(expr, types.FLOAT),
            .BoolLiteral => return try self.record(expr, types.BOOL),
            .StringLiteral => return try self.record(expr, types.STRING),
            .NullLiteral => return try self.record(expr, types.NULL),
            .Identifier => {
                const idExpr = expr.Identifier;
                if (self.scopeStack.lookupSymbol(idExpr.name)) |symbol| {
                    return try self.record(expr, symbol.symbolType);
                }
                if (try self.resolveReceiverMemberType(idExpr.name)) |member_type| {
                    return try self.record(expr, member_type);
                }
                return SemanticError.UndefinedVariable;
            },
            .FunctionCall => {
                const funcExpr = expr.FunctionCall;
                if (funcExpr.callee) |callee| {
                    switch (callee.*) {
                        .MemberAccess => {
                            const object_expr = callee.MemberAccess.object orelse return SemanticError.TypeMismatch;
                            const object_type = try self.evaluate(object_expr);
                            const method = try self.lookupStructMethod(object_type, funcExpr.name) orelse return SemanticError.UndefinedVariable;
                            return try self.record(expr, self.result.struct_method_return_types.get(method) orelse return SemanticError.TypeMismatch);
                        },
                        else => {},
                    }
                }

                if (self.scopeStack.lookupSymbol(funcExpr.name)) |symbol| {
                    if (symbol.kind != .function) {
                        return SemanticError.TypeMismatch;
                    }
                    return try self.record(expr, symbol.symbolType);
                }

                if (self.receiver_struct) |receiver_struct| {
                    const receiver_type = types.Type{ .kind = .STRUCT, .struct_name = receiver_struct.name };
                    const method = try self.lookupStructMethod(receiver_type, funcExpr.name) orelse return SemanticError.UndefinedVariable;
                    return try self.record(expr, self.result.struct_method_return_types.get(method) orelse return SemanticError.TypeMismatch);
                }

                return SemanticError.UndefinedVariable;
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
            .ExpressionStmt => return try self.record(expr, try self.evaluate(expr.ExpressionStmt)),
            .MemberAccess => {
                const access = expr.MemberAccess;
                const member_name = access.memberName;
                const object_type = try self.evaluate(access.object orelse return SemanticError.TypeMismatch);

                if (object_type.kind != .STRUCT) {
                    return SemanticError.TypeMismatch;
                }

                const user_defined_type = self.context.structs.get(object_type.struct_name orelse return SemanticError.UndefinedVariable) orelse return SemanticError.UndefinedVariable;

                for (user_defined_type.fields) |field| {
                    switch (field) {
                        .StructProperty => |property_ptr| {
                            if (std.mem.eql(u8, property_ptr.name, member_name)) {
                                return try self.record(expr, self.result.struct_property_types.get(property_ptr) orelse return SemanticError.TypeMismatch);
                            }
                        },
                        .StructMethod => |method_ptr| {
                            if (std.mem.eql(u8, method_ptr.name, member_name)) {
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
                const operator = unary.operator;

                if (operator == .Negate) {
                    if (operandType.isNumeric()) {
                        return try self.record(expr, operandType);
                    }
                    return SemanticError.TypeMismatch;
                }

                if (operator == .Not) {
                    if (operandType.kind == .BOOL) {
                        return try self.record(expr, types.BOOL);
                    }
                    return SemanticError.TypeMismatch;
                }

                return SemanticError.TypeMismatch;
            },
            .ArrayLiteral => {
                const arrayExpr = expr.ArrayLiteral;

                if (arrayExpr.elements.len == 0) {
                    return try self.record(expr, types.Type{ .kind = .EMPTY, .isArray = true, .staticLength = 0, .struct_name = null });
                }

                const firstElemType = try self.evaluate(arrayExpr.elements[0]);
                for (arrayExpr.elements) |elem| {
                    const elemType = try self.evaluate(elem);
                    if (!typeCompatibility.isAssignable(firstElemType, elemType)) {
                        return SemanticError.TypeMismatch;
                    }
                }

                return try self.record(expr, types.Type{
                    .kind = firstElemType.kind,
                    .isArray = true,
                    .dynamicArray = false,
                    .staticLength = @intCast(arrayExpr.elements.len),
                    .struct_name = firstElemType.struct_name,
                });
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

                return try self.record(expr, types.Type{
                    .kind = arrayType.kind,
                    .isArray = false,
                    .struct_name = arrayType.struct_name,
                });
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

    fn resolveReceiverMemberType(self: *ExprTypeChecker, member_name: []const u8) SemanticError!?types.Type {
        const receiver_struct = self.receiver_struct orelse return null;

        for (receiver_struct.fields) |field| {
            switch (field) {
                .StructProperty => |property_ptr| {
                    if (std.mem.eql(u8, property_ptr.name, member_name)) {
                        return self.result.struct_property_types.get(property_ptr) orelse SemanticError.TypeMismatch;
                    }
                },
                .StructMethod => |method_ptr| {
                    if (std.mem.eql(u8, method_ptr.name, member_name)) {
                        return self.result.struct_method_return_types.get(method_ptr) orelse SemanticError.TypeMismatch;
                    }
                },
            }
        }

        return null;
    }

    fn lookupStructMethod(self: *ExprTypeChecker, object_type: types.Type, method_name: []const u8) SemanticError!?*const StructMethodField {
        if (object_type.kind != .STRUCT) return SemanticError.TypeMismatch;

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

fn isArithmeticOperator(operator: []const u8) bool {
    return std.mem.eql(u8, operator, "+") or
        std.mem.eql(u8, operator, "-") or
        std.mem.eql(u8, operator, "*") or
        std.mem.eql(u8, operator, "/") or
        std.mem.eql(u8, operator, "%");
}

fn isComparisonOperator(operator: []const u8) bool {
    return std.mem.eql(u8, operator, "==") or
        std.mem.eql(u8, operator, "!=") or
        std.mem.eql(u8, operator, "<") or
        std.mem.eql(u8, operator, "<=") or
        std.mem.eql(u8, operator, ">") or
        std.mem.eql(u8, operator, ">=");
}
