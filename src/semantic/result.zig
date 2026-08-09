const std = @import("std");

const expr_ast = @import("../ast/expr.zig");
const stmt_ast = @import("../ast/stmt.zig");
const Type = @import("types.zig").Type;

pub const SemanticResult = struct {
    allocator: std.mem.Allocator,
    expr_types: std.AutoHashMap(*const expr_ast.Expr, Type),
    var_decl_types: std.AutoHashMap(*const stmt_ast.VarDecl, Type),
    var_assign_types: std.AutoHashMap(*const stmt_ast.VarAssign, Type),
    return_types: std.AutoHashMap(*const stmt_ast.ReturnStatement, Type),
    print_types: std.AutoHashMap(*const stmt_ast.PrintStatement, Type),
    function_return_types: std.AutoHashMap(*const stmt_ast.FunctionDecl, Type),
    param_types: std.AutoHashMap(*const stmt_ast.Param, Type),
    struct_property_types: std.AutoHashMap(*const stmt_ast.StructPropertyField, Type),
    struct_method_return_types: std.AutoHashMap(*const stmt_ast.StructMethodField, Type),
    receiver_member_exprs: std.AutoHashMap(*const expr_ast.Expr, void),

    pub fn init(allocator: std.mem.Allocator) SemanticResult {
        return .{
            .allocator = allocator,
            .expr_types = std.AutoHashMap(*const expr_ast.Expr, Type).init(allocator),
            .var_decl_types = std.AutoHashMap(*const stmt_ast.VarDecl, Type).init(allocator),
            .var_assign_types = std.AutoHashMap(*const stmt_ast.VarAssign, Type).init(allocator),
            .return_types = std.AutoHashMap(*const stmt_ast.ReturnStatement, Type).init(allocator),
            .print_types = std.AutoHashMap(*const stmt_ast.PrintStatement, Type).init(allocator),
            .function_return_types = std.AutoHashMap(*const stmt_ast.FunctionDecl, Type).init(allocator),
            .param_types = std.AutoHashMap(*const stmt_ast.Param, Type).init(allocator),
            .struct_property_types = std.AutoHashMap(*const stmt_ast.StructPropertyField, Type).init(allocator),
            .struct_method_return_types = std.AutoHashMap(*const stmt_ast.StructMethodField, Type).init(allocator),
            .receiver_member_exprs = std.AutoHashMap(*const expr_ast.Expr, void).init(allocator),
        };
    }

    pub fn deinit(self: *SemanticResult) void {
        self.expr_types.deinit();
        self.var_decl_types.deinit();
        self.var_assign_types.deinit();
        self.return_types.deinit();
        self.print_types.deinit();
        self.function_return_types.deinit();
        self.param_types.deinit();
        self.struct_property_types.deinit();
        self.struct_method_return_types.deinit();
        self.receiver_member_exprs.deinit();
    }
};
