const std = @import("std");

const expr_ast = @import("../ast/expr.zig");
const stmt_ast = @import("../ast/stmt.zig");
const ExprTypeChecker = @import("expr_type_checker.zig").ExprTypeChecker;
const SemanticContext = @import("context.zig").SemanticContext;
const SemanticError = @import("semantic_error.zig").SemanticError;
const SemanticResult = @import("result.zig").SemanticResult;
const ScopeStack = @import("scope.zig").ScopeStack;
const StructChecker = @import("struct_checker.zig").StructChecker;
const types = @import("types.zig");
const typeCompatibility = @import("type_compatibility.zig");
const typeResolver = @import("type_resolver.zig");

const VarAssign = stmt_ast.VarAssign;
const VarDecl = stmt_ast.VarDecl;

pub const AssignmentChecker = struct {
    allocator: std.mem.Allocator,
    context: *SemanticContext,
    scopeStack: *ScopeStack,
    result: *SemanticResult,

    pub fn init(allocator: std.mem.Allocator, context: *SemanticContext, scopeStack: *ScopeStack, result: *SemanticResult) AssignmentChecker {
        return .{ .allocator = allocator, .context = context, .scopeStack = scopeStack, .result = result };
    }

    pub fn analyzeVarDecl(self: *AssignmentChecker, varDecl: *VarDecl) SemanticError!void {
        const varType = try typeResolver.resolveTypeRef(self.context, varDecl.varType);
        try self.result.var_decl_types.put(varDecl, varType);
        try self.scopeStack.declareSymbol(varDecl.name, .variable, varType, varDecl.immutable, &[_]types.Type{});

        var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result);
        const initType = try exprChecker.evaluate(varDecl.initializer);

        if (varType.isArray and initType.kind == .EMPTY) {
            return;
        }

        if (!typeCompatibility.isAssignable(varType, initType)) {
            return SemanticError.TypeMismatch;
        }

        if (varType.kind == .STRUCT) {
            const structDef = self.context.structs.get(varType.struct_name orelse return SemanticError.TypeMismatch) orelse return SemanticError.TypeMismatch;
            var structChecker = StructChecker.init(self.allocator, self.context, self.scopeStack, self.result);
            try structChecker.analyzeStructFields(structDef, &varDecl.initializer.StructInit);
        }
    }

    pub fn analyzeVarAssignment(self: *AssignmentChecker, varAssign: *VarAssign) SemanticError!void {
        switch (varAssign.target.*) {
            .Identifier => {
                const symbol = self.scopeStack.lookupSymbol(varAssign.target.Identifier.name) orelse return SemanticError.UndefinedVariable;

                if (symbol.kind != .variable) {
                    return SemanticError.TypeMismatch;
                }

                if (symbol.isImmutable) {
                    return SemanticError.SymbolImmutable;
                }

                var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result);
                const symbolType = symbol.symbolType;
                const exprKind = try exprChecker.evaluate(varAssign.value);

                if (!typeCompatibility.isAssignable(symbolType, exprKind)) {
                    return SemanticError.TypeMismatch;
                }

                try self.result.var_assign_types.put(varAssign, exprKind);
            },
            .MemberAccess => {
                const object = varAssign.target.MemberAccess.object orelse return SemanticError.TypeMismatch;
                var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result);
                const objectType = try exprChecker.evaluate(object);
                const memberName = varAssign.target.MemberAccess.memberName;

                if (objectType.kind != .STRUCT) {
                    return SemanticError.TypeMismatch;
                }

                const userDefinedType = self.context.structs.get(objectType.struct_name orelse return SemanticError.UndefinedVariable) orelse return SemanticError.UndefinedVariable;

                var found = false;
                for (userDefinedType.fields) |field| {
                    switch (field) {
                        .StructProperty => |property_ptr| {
                            const property = property_ptr.*;
                            if (std.mem.eql(u8, property.name, memberName)) {
                                if (property.isImmutable) {
                                    return SemanticError.SymbolImmutable;
                                }
                                const exprType = try exprChecker.evaluate(varAssign.value);
                                const fieldType = self.result.struct_property_types.get(property_ptr) orelse try typeResolver.resolveTypeRef(self.context, property.fieldType);
                                if (!typeCompatibility.isAssignable(fieldType, exprType)) {
                                    return SemanticError.TypeMismatch;
                                }
                                found = true;
                                try self.result.var_assign_types.put(varAssign, exprType);
                                break;
                            }
                        },
                        .StructMethod => |method_ptr| {
                            const method = method_ptr.*;
                            if (std.mem.eql(u8, method.name, memberName)) {
                                return SemanticError.TypeMismatch;
                            }
                        },
                    }
                }

                if (!found) {
                    return SemanticError.UndefinedVariable;
                }
            },
            .ArrayAccess => {
                const arrayAccess = varAssign.target.ArrayAccess;
                var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result);
                const arrayType = try exprChecker.evaluate(arrayAccess.array);

                if (!arrayType.isArray) {
                    return SemanticError.TypeMismatch;
                }

                const indexType = try exprChecker.evaluate(arrayAccess.index);
                if (indexType.kind != .INT) {
                    return SemanticError.TypeMismatch;
                }

                const exprType = try exprChecker.evaluate(varAssign.value);
                if (!typeCompatibility.isAssignable(types.Type{ .kind = arrayType.kind, .isArray = false, .struct_name = arrayType.struct_name }, exprType)) {
                    return SemanticError.TypeMismatch;
                }
                try self.result.var_assign_types.put(varAssign, exprType);
            },
            else => {
                return SemanticError.TypeMismatch;
            },
        }
    }
};
