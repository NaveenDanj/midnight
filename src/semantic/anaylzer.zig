const std = @import("std");
const ScopeStack = @import("scope.zig").ScopeStack;
const FunctionDecl = @import("../parser/lib/parseFunctionDecl.zig").FunctionDecl;
const types = @import("./types.zig");

pub const SemanticAnalyzer = struct {
    allocator: std.mem.Allocator,
    scopeStack: ScopeStack,

    pub fn init(allocator: std.mem.Allocator) !SemanticAnalyzer {
        const scopeStack = try ScopeStack.init(allocator);
        return .{ .allocator = allocator, .scopeStack = scopeStack };
    }

    pub fn analyzeFunctionDecl(self: *SemanticAnalyzer, funcDecl: *FunctionDecl) !void {
        try self.scopeStack.pushScope();
        defer self.scopeStack.popScope();

        for (funcDecl.params) |param| {
            try self.scopeStack.declareSymbol(param.name, .function, types.INT);
        }
    }
};
