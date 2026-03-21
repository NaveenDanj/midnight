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
const VarAssign = @import("../parser/lib/parseVarDec.zig").VarAssign;
const FunctionCallStmt = @import("../parser/lib/parseFunctionDecl.zig").FunctionCallStmt;
const IfStatement = @import("../parser/lib/parseIf.zig").IfStatement;

pub const SemanticAnalyzer = struct {
    allocator: std.mem.Allocator,
    scopeStack: ScopeStack,

    pub fn init(allocator: std.mem.Allocator) !SemanticAnalyzer {
        const scopeStack = try ScopeStack.init(allocator);
        return .{ .allocator = allocator, .scopeStack = scopeStack };
    }

    pub fn analyzeProgram(self: *SemanticAnalyzer, statements: []*Statement) SemanticError!void {
        try self.scopeStack.pushScope();
        defer self.scopeStack.popScope();
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
                .VarAssignment => {
                    try self.analyzeVarAssignment(stmt.VarAssignment);
                },
                .FunctionCallStatement => {
                    try self.analyzeFunctionCall(stmt.FunctionCallStatement);
                },
                .IfStatement => {
                    try self.analyzeIfStatement(stmt.IfStatement);
                },
                else => {
                    // Handle other statement types.
                },
            }
        }
    }

    pub fn analyzeFunctionDecl(self: *SemanticAnalyzer, funcDecl: *FunctionDecl) SemanticError!void {
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .FunctionDecl = funcDecl };

        var paramTypes = try std.ArrayList(types.Type).initCapacity(self.allocator, 0);
        for (funcDecl.params) |param| {
            try paramTypes.append(self.allocator, param.dataType);
        }

        try self.scopeStack.declareSymbol(funcDecl.name, .function, funcDecl.returnType, true, paramTypes.items);

        try self.scopeStack.pushScope();
        defer self.scopeStack.popScope();

        const expectedRetType = funcDecl.returnType;

        if (expectedRetType.kind == .VOID) {
            for (funcDecl.body.statements) |stmt| {
                if (stmt.* == .ReturnStatement) {
                    return SemanticError.TypeMismatch;
                }
            }
        } else {
            var hasReturnWithValue = false;
            for (funcDecl.body.statements) |stmt| {
                if (stmt.* == .ReturnStatement) {
                    const retStmt = stmt.ReturnStatement;
                    const actualRetType = try self.evaluateExprType(retStmt.expression);
                    if (!self.areTypesCompatible(expectedRetType, actualRetType)) {
                        return SemanticError.TypeMismatch;
                    }
                    hasReturnWithValue = true;
                }
            }

            if (!hasReturnWithValue) {
                return SemanticError.MissingReturnStatement;
            }
        }

        for (funcDecl.params) |param| {
            try self.scopeStack.declareSymbol(param.name, .parameter, param.dataType, false, &[_]types.Type{});
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
                .IfStatement => {
                    try self.analyzeIfStatement(stmt.IfStatement);
                },

                .WhileStatement => {
                    try self.analyzeWhileLoop(stmt.WhileStatement);
                },

                .VarAssignment => {
                    try self.analyzeVarAssignment(stmt.VarAssignment);
                },
                .FunctionCallStatement => {
                    try self.analyzeFunctionCall(stmt.FunctionCallStatement);
                },
                else => {
                    // Handle other statement types.
                },
            }
        }
    }

    pub fn analyzeVarDecl(self: *SemanticAnalyzer, varDecl: *VarDecl) SemanticError!void {
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .VariableDecl = varDecl };

        try self.scopeStack.declareSymbol(varDecl.name, .variable, varDecl.varType, varDecl.immutable, &[_]types.Type{});
        const varType = varDecl.varType;
        const initType = try self.evaluateExprType(varDecl.initializer);

        if (!self.areTypesCompatible(varType, initType)) {
            return SemanticError.TypeMismatch;
        }
    }

    pub fn analyzeWhileLoop(self: *SemanticAnalyzer, whileStmt: *WhileStatement) SemanticError!void {
        const condType = try self.evaluateExprType(whileStmt.expression);

        if (condType.kind != .BOOL) {
            return SemanticError.TypeMismatch;
        }

        try self.analyzeBlock(whileStmt.body);
    }

    pub fn analyzeIfStatement(self: *SemanticAnalyzer, ifStmt: *IfStatement) SemanticError!void {
        const condType = try self.evaluateExprType(ifStmt.expression);

        if (condType.kind != .BOOL) {
            return SemanticError.TypeMismatch;
        }

        try self.analyzeBlock(ifStmt.thenBlock);
        if (ifStmt.elseBlock) |elseBranch| {
            try self.analyzeBlock(elseBranch);
        }
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
            .FunctionCall => {
                const funcExpr = expr.FunctionCall;
                const symbol = self.scopeStack.lookupSymbol(funcExpr.name) orelse return SemanticError.UndefinedVariable;
                if (symbol.kind != .function) {
                    return SemanticError.TypeMismatch;
                }
                return symbol.symbolType;
            },
        }

        return types.Type{ .kind = .VOID };
    }

    pub fn analyzeVarAssignment(self: *SemanticAnalyzer, varAssign: *VarAssign) SemanticError!void {
        const symbol = self.scopeStack.lookupSymbol(varAssign.name) orelse return SemanticError.UndefinedVariable;

        if (symbol.kind != .variable) {
            return SemanticError.TypeMismatch;
        }

        if (symbol.isImmutable) {
            return SemanticError.SymbolImmutable;
        }

        const symbolType = symbol.symbolType;
        const exprKind = try self.evaluateExprType(varAssign.value);

        if (!self.areTypesCompatible(symbolType, exprKind)) {
            return SemanticError.TypeMismatch;
        }
    }

    pub fn analyzeFunctionCall(self: *SemanticAnalyzer, funcCall: *FunctionCallStmt) SemanticError!void {
        const symbol = self.scopeStack.lookupSymbol(funcCall.name) orelse return SemanticError.UndefinedVariable;
        const params = symbol.params;

        if (symbol.kind != .function) {
            return SemanticError.TypeMismatch;
        }

        if (params.len != funcCall.args.len) {
            return SemanticError.ArgumentCountMismatch;
        }

        for (params, 0..) |expectedParam, i| {
            const argType = try self.evaluateExprType(funcCall.args[i]);
            if (!self.areTypesCompatible(expectedParam, argType)) {
                return SemanticError.TypeMismatch;
            }
        }
    }
};
