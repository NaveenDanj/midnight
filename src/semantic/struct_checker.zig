const std = @import("std");

const expr_ast = @import("../ast/expr.zig");
const stmt_ast = @import("../ast/stmt.zig");
const ExprTypeChecker = @import("expr_type_checker.zig").ExprTypeChecker;
const SemanticContext = @import("context.zig").SemanticContext;
const SemanticError = @import("semantic_error.zig").SemanticError;
const ScopeStack = @import("scope.zig").ScopeStack;
const types = @import("types.zig");
const typeCompatibility = @import("type_compatibility.zig");

const StructInitExpr = expr_ast.StructInitExpr;
const StructStmt = stmt_ast.StructStmt;

pub const StructChecker = struct {
    allocator: std.mem.Allocator,
    context: *SemanticContext,
    scopeStack: *ScopeStack,

    pub fn init(allocator: std.mem.Allocator, context: *SemanticContext, scopeStack: *ScopeStack) StructChecker {
        return .{ .allocator = allocator, .context = context, .scopeStack = scopeStack };
    }

    pub fn analyzeStructStatement(self: *StructChecker, structStmt: *StructStmt) SemanticError!void {
        try self.scopeStack.declareSymbol(structStmt.name, .structure, types.STRUCT, true, &[_]types.Type{});
        try self.context.addStruct(structStmt);
    }

    pub fn analyzeStructFields(self: *StructChecker, structDef: *StructStmt, structInitStmt: *StructInitExpr) SemanticError!void {
        var hashMap = std.StringHashMap(types.Type).init(self.allocator);
        defer hashMap.deinit();

        for (structDef.fields) |field| {
            switch (field) {
                .StructProperty => {
                    const property = field.StructProperty;
                    _ = try hashMap.put(property.name, property.fieldType);
                },
                .StructMethod => {},
            }
        }

        var exprChecker = ExprTypeChecker.init(self.context, self.scopeStack);
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
