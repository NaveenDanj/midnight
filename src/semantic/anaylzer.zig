const std = @import("std");

const expr_ast = @import("../ast/expr.zig");
const stmt_ast = @import("../ast/stmt.zig");
const AssignmentChecker = @import("./assignment_checker.zig").AssignmentChecker;
const ExprTypeChecker = @import("./expr_type_checker.zig").ExprTypeChecker;
const FunctionChecker = @import("./function_checker.zig").FunctionChecker;
const SemanticResult = @import("./result.zig").SemanticResult;
const ScopeStack = @import("scope.zig").ScopeStack;
const SemanticContext = @import("./context.zig").SemanticContext;
const SemanticError = @import("./semantic_error.zig").SemanticError;
const StructChecker = @import("./struct_checker.zig").StructChecker;
const types = @import("./types.zig");

const BlockStmt = stmt_ast.BlockStmt;
const Expr = expr_ast.Expr;
const FunctionDecl = stmt_ast.FunctionDecl;
const IfStatement = stmt_ast.IfStatement;
const PrintStatement = stmt_ast.PrintStatement;
const Statement = stmt_ast.Statement;
const WhileStatement = stmt_ast.WhileStatement;

pub const SemanticAnalyzer = struct {
    allocator: std.mem.Allocator,
    scopeStack: ScopeStack,
    context: SemanticContext,
    result: SemanticResult,

    pub fn init(allocator: std.mem.Allocator) !SemanticAnalyzer {
        const scopeStack = try ScopeStack.init(allocator);
        const context = try SemanticContext.init(allocator);
        const result = SemanticResult.init(allocator);
        return .{ .allocator = allocator, .scopeStack = scopeStack, .context = context, .result = result };
    }

    pub fn deinit(self: *SemanticAnalyzer) void {
        self.result.deinit();
        self.context.deinit();
    }

    pub fn analyzeProgram(self: *SemanticAnalyzer, statements: []*Statement) SemanticError!void {
        try self.scopeStack.pushScope();
        defer self.scopeStack.popScope();

        for (statements) |stmt| {
            try self.analyzeStatement(stmt);
        }
    }

    pub fn analyzeFunctionDecl(self: *SemanticAnalyzer, funcDecl: *FunctionDecl) SemanticError!void {
        var checker = self.functionChecker();
        try checker.declareFunction(funcDecl);

        try self.scopeStack.pushScope();
        defer self.scopeStack.popScope();

        try checker.declareParams(funcDecl);
        try self.analyzeBlock(funcDecl.body);
        try checker.validateReturns(funcDecl);
    }

    pub fn analyzeBlock(self: *SemanticAnalyzer, block: *BlockStmt) SemanticError!void {
        try self.scopeStack.pushScope();
        defer self.scopeStack.popScope();

        for (block.statements) |stmt| {
            try self.analyzeStatement(stmt);
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

    pub fn evaluateExprType(self: *SemanticAnalyzer, expr: *Expr) SemanticError!types.Type {
        var checker = ExprTypeChecker.init(&self.context, &self.scopeStack, &self.result);
        return checker.evaluate(expr);
    }

    pub fn analyzePrintStatement(self: *SemanticAnalyzer, printStmt: *PrintStatement) SemanticError!void {
        const printValueType = try self.evaluateExprType(printStmt.value);
        try self.result.print_types.put(printStmt, printValueType);

        if (printValueType.kind == .STRUCT) {
            return SemanticError.TypeMismatch;
        }
    }

    fn analyzeStatement(self: *SemanticAnalyzer, stmt: *Statement) SemanticError!void {
        switch (stmt.*) {
            .FunctionDecl => {
                try self.analyzeFunctionDecl(stmt.FunctionDecl);
            },
            .Block => {
                try self.analyzeBlock(stmt.Block);
            },
            .VariableDecl => {
                var checker = self.assignmentChecker();
                try checker.analyzeVarDecl(stmt.VariableDecl);
            },
            .WhileStatement => {
                try self.analyzeWhileLoop(stmt.WhileStatement);
            },
            .VarAssignment => {
                var checker = self.assignmentChecker();
                try checker.analyzeVarAssignment(stmt.VarAssignment);
            },
            .FunctionCallStatement => {
                var checker = self.functionChecker();
                try checker.analyzeFunctionCall(stmt.FunctionCallStatement);
            },
            .ExpressionStmt => {
                switch (stmt.ExpressionStmt.*) {
                    .FunctionCall => {
                        var checker = self.functionChecker();
                        try checker.analyzeFunctionCall(&stmt.ExpressionStmt.FunctionCall);
                    },
                    else => return SemanticError.UnsupportedStatement,
                }
            },
            .IfStatement => {
                try self.analyzeIfStatement(stmt.IfStatement);
            },
            .StructDecl => {
                var checker = self.structChecker();
                try checker.analyzeStructStatement(stmt.StructDecl);
            },
            .ReturnStatement => {
                var checker = self.functionChecker();
                try checker.analyzeReturn(stmt.ReturnStatement);
            },
            .PrintStatement => {
                try self.analyzePrintStatement(stmt.PrintStatement);
            },
        }
    }

    fn assignmentChecker(self: *SemanticAnalyzer) AssignmentChecker {
        return AssignmentChecker.init(self.allocator, &self.context, &self.scopeStack, &self.result);
    }

    fn functionChecker(self: *SemanticAnalyzer) FunctionChecker {
        return FunctionChecker.init(self.allocator, &self.context, &self.scopeStack, &self.result);
    }

    fn structChecker(self: *SemanticAnalyzer) StructChecker {
        return StructChecker.init(self.allocator, &self.context, &self.scopeStack, &self.result);
    }
};
