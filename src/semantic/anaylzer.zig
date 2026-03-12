const std = @import("std");
const ScopeStack = @import("scope.zig").ScopeStack;
const FunctionDecl = @import("../parser/lib/parseFunctionDecl.zig").FunctionDecl;
const VarDecl = @import("../parser/lib/parseVarDec.zig").VarDecl;
const WhileStatement = @import("../parser/lib/parseWhile.zig").WhileStatement;
const SemanticError = @import("./semantic_error.zig").SemanticError;
const types = @import("./types.zig");
const BlockStmt = @import("../parser/lib/parseBlock.zig").BlockStmt;

pub const SemanticAnalyzer = struct {
    allocator: std.mem.Allocator,
    scopeStack: ScopeStack,

    pub fn init(allocator: std.mem.Allocator) !SemanticAnalyzer {
        const scopeStack = try ScopeStack.init(allocator);
        return .{ .allocator = allocator, .scopeStack = scopeStack };
    }

    pub fn analyzeFunctionDecl(self: *SemanticAnalyzer, funcDecl: *FunctionDecl) SemanticError!void {
        try self.scopeStack.pushScope();
        defer self.scopeStack.popScope();

        for (funcDecl.params) |param| {
            try self.scopeStack.declareSymbol(param.name, .function, types.INT);
        }
        try self.analyzeBlock(funcDecl.body);
    }

    pub fn analyzeBlock(self: *SemanticAnalyzer, block: *BlockStmt) SemanticError!void {
        try self.scopeStack.pushScope();
        defer self.scopeStack.popScope();

        for (block.statements) |stmt| {
            switch (stmt.*) {
                .VariableDecl => {
                    try self.analyzeVarDecl(stmt.VariableDecl);
                },

                .WhileStatement => {
                    try self.analyzeWhileLoop(stmt.WhileStatement);
                },

                else => {
                    // Handle other statement types.
                },
            }
        }
    }

    pub fn analyzeVarDecl(self: *SemanticAnalyzer, varDecl: *VarDecl) SemanticError!void {
        try self.scopeStack.declareSymbol(varDecl.name, .variable, types.INT);
    }

    pub fn analyzeWhileLoop(self: *SemanticAnalyzer, whileStmt: *WhileStatement) SemanticError!void {
        try self.analyzeBlock(whileStmt.body);
    }
};
