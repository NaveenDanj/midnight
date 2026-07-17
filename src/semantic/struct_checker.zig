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

const StructInitExpr = expr_ast.StructInitExpr;
const StructStmt = stmt_ast.StructStmt;

pub const StructChecker = struct {
    allocator: std.mem.Allocator,
    context: *SemanticContext,
    scopeStack: *ScopeStack,
    result: *SemanticResult,

    pub fn init(allocator: std.mem.Allocator, context: *SemanticContext, scopeStack: *ScopeStack, result: *SemanticResult) StructChecker {
        return .{ .allocator = allocator, .context = context, .scopeStack = scopeStack, .result = result };
    }

    pub fn analyzeStructStatement(self: *StructChecker, structStmt: *StructStmt) SemanticError!void {
        try self.scopeStack.declareSymbol(structStmt.name, .structure, types.Type{ .kind = .STRUCT, .struct_name = structStmt.name }, true, &[_]types.Type{});
        try self.context.addStruct(structStmt);
    }

    pub fn analyzeStructFields(self: *StructChecker, structDef: *StructStmt, structInitStmt: *StructInitExpr) SemanticError!void {
        var hashMap = std.StringHashMap(types.Type).init(self.allocator);
        defer hashMap.deinit();

        for (structDef.fields) |field| {
            switch (field) {
                .StructProperty => {
                    const property = field.StructProperty;
                    const fieldType = try typeResolver.resolveTypeRef(self.context, property.fieldType);
                    try self.result.struct_property_types.put(property, fieldType);
                    _ = try hashMap.put(property.name, fieldType);
                },
                .StructMethod => |method| {
                    const returnType = try typeResolver.resolveTypeRef(self.context, method.returnType);
                    try self.result.struct_method_return_types.put(method, returnType);
                },
            }
        }

        var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack, self.result);
        for (structInitStmt.fields) |field| {
            const expectedType = hashMap.get(field.name) orelse return SemanticError.StructFieldMismatch;
            const actualType = try exprChecker.evaluate(field.value);

            if (!typeCompatibility.isAssignable(expectedType, actualType)) {
                return SemanticError.StructFieldMismatch;
            }
        }

        for (structDef.fields) |field| {
            switch (field) {
                .StructProperty => |property_ptr| {
                    const property = property_ptr.*;
                    var found = false;

                    for (structInitStmt.fields) |initField| {
                        if (std.mem.eql(u8, initField.name, property.name)) {
                            found = true;
                            break;
                        }
                    }

                    if (!found) {
                        return SemanticError.StructFieldUnIntialized;
                    }
                },
                else => {},
            }
        }
    }
};
