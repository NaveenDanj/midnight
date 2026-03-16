const std = @import("std");
const ScopeStack = @import("scope.zig").ScopeStack;
const FunctionDecl = @import("../parser/lib/parseFunctionDecl.zig").FunctionDecl;
const VarDecl = @import("../parser/lib/parseVarDec.zig").VarDecl;
const WhileStatement = @import("../parser/lib/parseWhile.zig").WhileStatement;
const SemanticError = @import("./semantic_error.zig").SemanticError;
const types = @import("./types.zig");
const BlockStmt = @import("../parser/lib/parseBlock.zig").BlockStmt;
const BinaryExpr = @import("../parser/lib/parseExpr.zig").BinaryExpr;
const Expr = @import("../parser/lib/parseExpr.zig").Expr;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;

pub const SemanticAnalyzer = struct {
    allocator: std.mem.Allocator,
    scopeStack: ScopeStack,

    pub fn init(allocator: std.mem.Allocator) !SemanticAnalyzer {
        const scopeStack = try ScopeStack.init(allocator);
        return .{ .allocator = allocator, .scopeStack = scopeStack };
    }

    pub fn analyzeProgram(self: *SemanticAnalyzer, statements: []*Statement) SemanticError!void {
        for (statements) |stmt| {
            switch (stmt.*) {
                .FunctionDecl => {
                    try self.analyzeFunctionDecl(stmt.FunctionDecl);
                },
                .Block => {
                    try self.analyzeBlock(stmt.Block);
                },
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

    pub fn analyzeFunctionDecl(self: *SemanticAnalyzer, funcDecl: *FunctionDecl) SemanticError!void {
        try self.scopeStack.pushScope();
        defer self.scopeStack.popScope();

        for (funcDecl.params) |param| {
            try self.scopeStack.declareSymbol(param.name, .function, param.dataType);
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
        try self.scopeStack.declareSymbol(varDecl.name, .variable, varDecl.varType);
        const varType = varDecl.varType;
        const initType = try self.evaluateExprType(varDecl.initializer);

        if (!self.areTypesCompatible(varType, initType)) {
            return SemanticError.TypeMismatch;
        }
    }

    pub fn analyzeWhileLoop(self: *SemanticAnalyzer, whileStmt: *WhileStatement) SemanticError!void {
        try self.analyzeBlock(whileStmt.body);
    }

    pub fn areTypesCompatible(_: *SemanticAnalyzer, expected: types.Type, actual: types.Type) bool {
        if (expected.kind == .VOID) {
            return false;
        }

        if (expected.kind == .STRING) {
            return actual.kind == .STRING;
        }

        if (expected.isNumeric()) {
            return actual.isNumeric();
        }

        return expected.kind == actual.kind;
    }

    pub fn evaluateExprType(self: *SemanticAnalyzer, expr: *Expr) SemanticError!types.Type {
        switch (expr.*) {
            .Binary => {
                const binary = expr.Binary;
                const leftType = try self.evaluateExprType(binary.left);
                const rightType = try self.evaluateExprType(binary.right);

                if (!self.areTypesCompatible(leftType, rightType)) {
                    return SemanticError.TypeMismatch;
                }

                if (std.mem.eql(u8, binary.operator, "+") or std.mem.eql(u8, binary.operator, "-") or std.mem.eql(u8, binary.operator, "*") or std.mem.eql(u8, binary.operator, "/")) {
                    if (leftType.isNumeric()) {
                        return leftType;
                    } else if (leftType.kind == .STRING and std.mem.eql(u8, binary.operator, "+")) {
                        return types.STRING;
                    }
                }

                if (std.mem.eql(u8, binary.operator, "==") or std.mem.eql(u8, binary.operator, "!=")) {
                    return types.Type{ .kind = .BOOL };
                }

                return SemanticError.TypeMismatch;
            },

            .IntLiteral => {
                expr.IntLiteral.resolvedType = types.INT;
                return types.INT;
            },
            .FloatLiteral => {
                expr.FloatLiteral.resolvedType = types.FLOAT;
                return types.FLOAT;
            },
            .BoolLiteral => {
                expr.BoolLiteral.resolvedType = types.BOOL;
                return types.BOOL;
            },
            .StringLiteral => {
                expr.StringLiteral.resolvedType = types.STRING;
                return types.STRING;
            },
            .Identifier => {
                const idExpr = expr.Identifier;
                const symbol = self.scopeStack.lookupSymbol(idExpr.name) orelse return SemanticError.UndefinedVariable;
                return symbol.symbolType;
            },
        }

        return types.Type{ .kind = .VOID };
    }
};
