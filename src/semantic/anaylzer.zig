const std = @import("std");
const ScopeStack = @import("scope.zig").ScopeStack;
const SemanticContext = @import("./context.zig").SemanticContext;

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
const StructStmt = @import("../parser/lib/parseStruct.zig").StructStmt;
const StructInitExpr = @import("../parser/lib/parseStruct.zig").StructInitExpr;

pub const SemanticAnalyzer = struct {
    allocator: std.mem.Allocator,
    scopeStack: ScopeStack,
    context: SemanticContext,

    pub fn init(allocator: std.mem.Allocator) !SemanticAnalyzer {
        const scopeStack = try ScopeStack.init(allocator);
        const context = try SemanticContext.init(allocator);
        return .{ .allocator = allocator, .scopeStack = scopeStack, .context = context };
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
                .StructDecl => {
                    try self.analyzeStructStatement(stmt.StructDecl);
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

        for (funcDecl.params) |param| {
            try self.scopeStack.declareSymbol(param.name, .parameter, param.dataType, false, &[_]types.Type{});
        }

        try self.analyzeBlock(funcDecl.body);

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
                    if (!self.areTypesCompatible(expectedRetType, retStmt.resolvedType orelse return SemanticError.TypeMismatch)) {
                        return SemanticError.TypeMismatch;
                    }
                    hasReturnWithValue = true;
                }
            }

            if (!hasReturnWithValue) {
                return SemanticError.MissingReturnStatement;
            }
        }
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
                .ReturnStatement => {
                    const retStmt = stmt.ReturnStatement;
                    const actualType = try self.evaluateExprType(retStmt.expression);
                    retStmt.resolvedType = actualType;
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

        if (varType.isArray and initType.kind == .EMPTY) {
            // Allow empty arrays to be assigned to any array type
            return;
        } else {
            if (!self.areTypesCompatible(varType, initType)) {
                return SemanticError.TypeMismatch;
            }
        }

        if (varType.kind == .STRUCT) {
            const structDef = self.context.structs.get(varType.struct_name orelse return SemanticError.TypeMismatch) orelse return SemanticError.TypeMismatch;
            try self.analyzeStructFields(structDef, &varDecl.initializer.StructInit);
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
        // const structDef = self.context.structs.get(expected.name) orelse return SemanticError.StructAlreadyDeclared

        if (expected.kind == .STRUCT) {
            if (actual.kind != .STRUCT) {
                return false;
            }

            if (expected.struct_name) |expected_name| {
                if (actual.struct_name) |actual_name| {
                    return std.mem.eql(u8, expected_name, actual_name);
                } else {
                    std.debug.print("Expected struct name {s}, but actual has no struct name\n", .{expected_name});
                    return false;
                }
            } else {
                return false;
            }
        }

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
            .StructInit => {
                const structInit = expr.StructInit;
                var symbol = self.scopeStack.lookupSymbol(structInit.structName) orelse return SemanticError.UndefinedVariable;
                if (symbol.kind != .structure) {
                    return SemanticError.TypeMismatch;
                }
                symbol.symbolType.struct_name = structInit.structName;
                return symbol.symbolType;
            },

            .ExpressionStmt => {
                std.debug.print("Evaluating expression statement: {any}\n", .{expr.ExpressionStmt});
                return try self.evaluateExprType(expr.ExpressionStmt);
            },

            .MemberAccess => {
                const object = expr.MemberAccess;
                const memberName = object.memberName;
                const objectType = try self.evaluateExprType(object.object orelse return SemanticError.TypeMismatch);

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
                                found = true;
                                return property.fieldType;
                            }
                        },
                        .StructMethod => |method_ptr| {
                            const method = method_ptr.*;
                            if (std.mem.eql(u8, method.name, memberName)) {
                                found = true;
                                return method.returnType;
                            }
                        },
                    }
                }

                if (!found) {
                    return SemanticError.UndefinedVariable;
                }
            },
            .Unary => {
                const unary = expr.Unary;
                const operandType = try self.evaluateExprType(unary.operand);

                if (std.mem.eql(u8, unary.operator, "-")) {
                    if (operandType.isNumeric()) {
                        return operandType;
                    } else {
                        return SemanticError.TypeMismatch;
                    }
                }

                if (std.mem.eql(u8, unary.operator, "!")) {
                    if (operandType.kind == .BOOL) {
                        return types.BOOL;
                    } else {
                        return SemanticError.TypeMismatch;
                    }
                }

                return SemanticError.TypeMismatch;
            },
            .ArrayLiteral => {
                const arrayExpr = expr.ArrayLiteral;

                if (arrayExpr.elements.len == 0) {
                    return types.Type{ .kind = .EMPTY, .isArray = true, .struct_name = null };
                }

                const firstElemType = try self.evaluateExprType(arrayExpr.elements[0]);

                for (arrayExpr.elements) |elem| {
                    const elemType = try self.evaluateExprType(elem);
                    if (!self.areTypesCompatible(firstElemType, elemType)) {
                        return SemanticError.TypeMismatch;
                    }
                }

                return types.Type{ .kind = firstElemType.kind, .isArray = true, .struct_name = firstElemType.struct_name };
            },
            .ArrayAccess => {
                const arrayAccess = expr.ArrayAccess;
                const arrayType = try self.evaluateExprType(arrayAccess.array);

                if (!arrayType.isArray) {
                    return SemanticError.TypeMismatch;
                }

                const indexType = try self.evaluateExprType(arrayAccess.index);
                if (indexType.kind != .INT) {
                    return SemanticError.TypeMismatch;
                }

                return types.Type{ .kind = arrayType.kind, .isArray = true, .struct_name = arrayType.struct_name };
            },
        }

        return types.Type{ .kind = .VOID };
    }

    pub fn analyzeVarAssignment(self: *SemanticAnalyzer, varAssign: *VarAssign) SemanticError!void {
        switch (varAssign.target.*) {
            .Identifier => {
                const symbol = self.scopeStack.lookupSymbol(varAssign.target.Identifier.name) orelse return SemanticError.UndefinedVariable;

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
            },

            .MemberAccess => {
                const object = varAssign.target.MemberAccess.object orelse return SemanticError.TypeMismatch;
                const objectType = try self.evaluateExprType(object);
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
                                const exprType = try self.evaluateExprType(varAssign.value);
                                if (!self.areTypesCompatible(property.fieldType, exprType)) {
                                    return SemanticError.TypeMismatch;
                                }
                                found = true;
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
                const arrayType = try self.evaluateExprType(arrayAccess.array);

                std.debug.print("Array type: {any}\n", .{arrayType});
                std.debug.print("Array access expression: {s}\n", .{arrayAccess.array.*.ArrayAccess.array.*.Identifier.name});

                if (!arrayType.isArray) {
                    return SemanticError.TypeMismatch;
                }

                const indexType = try self.evaluateExprType(arrayAccess.index);
                if (indexType.kind != .INT) {
                    return SemanticError.TypeMismatch;
                }

                const exprType = try self.evaluateExprType(varAssign.value);
                if (!self.areTypesCompatible(types.Type{ .kind = arrayType.kind, .isArray = false, .struct_name = arrayType.struct_name }, exprType)) {
                    return SemanticError.TypeMismatch;
                }
            },

            else => {
                return SemanticError.TypeMismatch;
            },
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

    pub fn analyzeStructStatement(self: *SemanticAnalyzer, structStmt: *StructStmt) SemanticError!void {
        try self.scopeStack.declareSymbol(structStmt.name, .structure, types.STRUCT, true, &[_]types.Type{});
        try self.context.addStruct(structStmt);
    }

    pub fn analyzeStructFields(self: *SemanticAnalyzer, structDef: *StructStmt, structInitStmt: *StructInitExpr) SemanticError!void {
        var hashMap = std.StringHashMap(types.Type).init(self.allocator);
        defer hashMap.deinit();

        for (structDef.fields) |field| {
            switch (field) {
                .StructProperty => {
                    const property = field.StructProperty;
                    _ = try hashMap.put(property.name, property.fieldType);
                },
                .StructMethod => {
                    // For now, we won't analyze method bodies during struct initialization.
                },
            }
        }

        for (structInitStmt.fields) |field| {
            const expectedType = hashMap.get(field.name) orelse return SemanticError.StructFieldMismatch;
            const actualType = try self.evaluateExprType(field.value);

            if (!self.areTypesCompatible(expectedType, actualType)) {
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
