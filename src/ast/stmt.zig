const Type = @import("../semantic/types.zig").Type;
const expr_ast = @import("expr.zig");

pub const Expr = expr_ast.Expr;
pub const FunctionCallStmt = expr_ast.FunctionCallStmt;

pub const Statement = union(enum) {
    PrintStatement: *PrintStatement,
    FunctionDecl: *FunctionDecl,
    Block: *BlockStmt,
    VariableDecl: *VarDecl,
    ReturnStatement: *ReturnStatement,
    IfStatement: *IfStatement,
    WhileStatement: *WhileStatement,
    StructDecl: *StructStmt,
    VarAssignment: *VarAssign,
    FunctionCallStatement: *FunctionCallStmt,
    ExpressionStmt: *Expr,
};

pub const BlockStmt = struct {
    statements: []*Statement,
};

pub const FunctionDecl = struct {
    name: []const u8,
    params: []*Param,
    body: *BlockStmt,
    returnType: Type,
};

pub const ReturnStatement = struct {
    expression: *Expr,
    resolvedType: ?Type = null,
};

pub const Param = struct {
    dataType: Type,
    name: []const u8,
};

pub const VarDecl = struct {
    immutable: bool,
    name: []const u8,
    varType: Type,
    initializer: *Expr,
};

pub const VarAssign = struct {
    target: *Expr,
    value: *Expr,
    resolvedType: ?Type,
};

pub const IfStatement = struct {
    expression: *Expr,
    thenBlock: *BlockStmt,
    elseBlock: ?*BlockStmt = null,
};

pub const WhileStatement = struct {
    expression: *Expr,
    body: *BlockStmt,
};

pub const StructField = union(enum) {
    StructProperty: *StructPropertyField,
    StructMethod: *StructMethodField,
};

pub const StructStmt = struct {
    name: []const u8,
    fields: []StructField,
};

pub const StructPropertyField = struct {
    name: []const u8,
    fieldType: Type,
    isImmutable: bool,
};

pub const StructMethodParameter = struct {
    name: []const u8,
    paramType: Type,
};

pub const StructMethodField = struct {
    name: []const u8,
    parameters: []*Param,
    body: *BlockStmt,
    returnType: Type,
};

pub const PrintStatement = struct {
    value: *Expr,
    resolvedType: ?Type = null,
};
