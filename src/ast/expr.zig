const Type = @import("../semantic/types.zig").Type;
const Types = @import("../semantic/types.zig");

pub const Expr = union(enum) {
    Binary: BinaryExpr,
    IntLiteral: Types.IntLiteral,
    FloatLiteral: Types.FloatLiteral,
    BoolLiteral: Types.BooleanLiteral,
    StringLiteral: Types.StringLiteral,
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
    resolvedType: ?Type = null,
};

pub const IdentifierExpr = struct {
    name: []const u8,
    resolvedType: ?Type = null,
};

pub const UnaryExpr = struct {
    operator: []const u8,
    operand: *Expr,
    resolvedType: ?Type = null,
};

pub const ArrayExpression = struct {
    elements: []*Expr,
    resolvedType: ?Type = null,
};

pub const ArrayAccess = struct {
    array: *Expr,
    index: *Expr,
    resolvedType: ?Type = null,
};

pub const FunctionCallStmt = struct {
    callee: ?*Expr = null,
    name: []const u8,
    args: []*Expr,
    resolvedType: ?Type = null,
};

pub const MemberAccessExpr = struct {
    object: ?*Expr = null,
    memberName: []const u8,
    resolvedType: ?Type = null,
};

pub const StructInitExpr = struct {
    structName: []const u8,
    fields: []StructInitField,
    resolvedType: ?Type = null,
};

pub const StructInitField = struct {
    name: []const u8,
    value: *Expr,
};
