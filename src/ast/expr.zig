const UnaryOperator = @import("../ir/ir.zig").UnaryOperator;

pub const Expr = union(enum) {
    Binary: BinaryExpr,
    IntLiteral: IntLiteral,
    FloatLiteral: FloatLiteral,
    BoolLiteral: BooleanLiteral,
    StringLiteral: StringLiteral,
    Identifier: IdentifierExpr,
    ArrayLiteral: ArrayExpression,
    ArrayAccess: ArrayAccess,
    FunctionCall: FunctionCallStmt,
    MemberAccess: MemberAccessExpr,
    StructInit: StructInitExpr,
    ExpressionStmt: *Expr,
    Unary: UnaryExpr,
};

pub const BinaryExpr = struct {
    left: *Expr,
    operator: []const u8,
    right: *Expr,
};

pub const IdentifierExpr = struct {
    name: []const u8,
};

pub const UnaryExpr = struct {
    operator: UnaryOperator,
    operand: *Expr,
};

pub const ArrayExpression = struct {
    elements: []*Expr,
};

pub const ArrayAccess = struct {
    array: *Expr,
    index: *Expr,
};

pub const FunctionCallStmt = struct {
    callee: ?*Expr = null,
    name: []const u8,
    args: []*Expr,
};

pub const MemberAccessExpr = struct {
    object: ?*Expr = null,
    memberName: []const u8,
};

pub const StructInitExpr = struct {
    structName: []const u8,
    fields: []StructInitField,
};

pub const StructInitField = struct {
    name: []const u8,
    value: *Expr,
};

pub const IntLiteral = struct {
    value: i64,
};

pub const FloatLiteral = struct {
    value: f64,
};

pub const BooleanLiteral = struct {
    value: bool,
};

pub const StringLiteral = struct {
    value: []const u8,
};
