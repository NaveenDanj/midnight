const std = @import("std");
const Type = @import("../semantic/types.zig").Type;
const Param = @import("../ast/stmt.zig").Param;
const StructInitExpr = @import("../ast/expr.zig").StructInitExpr;
const StructStmt = @import("../ast/stmt.zig").StructStmt;

pub const Value = union(enum) { temp: u32, constantInt: i64, constantFloat: f64, constantBool: bool, string: []const u8, variable: []const u8, paramIndex: i64 };

pub const BinaryOp = enum {
    Add,
    Subtract,
    Multiply,
    Divide,
    Modulo,
    Equal,
    NotEqual,
    LessThan,
    LessThanOrEqual,
    GreaterThan,
    GreaterThanOrEqual,
    And,
    Or,
};

pub const UnaryOperator = enum {
    Negate,
    Not,
};

pub const Instruction = union(enum) {
    BinaryOp: struct {
        op: BinaryOp,
        left: Value,
        right: Value,
        dest: u32,
        resolvedType: ?Type,
    },
    LoadConstInt: struct {
        value: i64,
        dest: u32,
        resolvedType: ?Type,
    },
    LoadConstFloat: struct {
        value: f64,
        dest: u32,
        resolvedType: ?Type,
    },
    LoadConstBool: struct {
        value: bool,
        dest: u32,
        resolvedType: ?Type,
    },
    LoadConstString: struct {
        value: []const u8,
        dest: u32,
        resolvedType: ?Type,
    },
    AllocArray: struct {
        length: u32,
        dest: u32,
        resolvedType: ?Type,
    },
    LoadVar: struct {
        name: []const u8,
        dest: u32,
        resolvedType: ?Type,
    },
    StoreVar: struct {
        name: []const u8,
        value: Value,
        resolvedType: ?Type,
    },
    JumpIfFalse: struct {
        condition: Value,
        label: u32,
    },
    Jump: struct {
        label: u32,
    },
    Label: struct {
        id: u32,
    },
    Return: struct {
        value: Value,
    },
    StoreField: struct {
        object: Value,
        fieldName: []const u8,
        value: Value,
        fieldIndex: u32,
        resolvedType: ?Type,
    },
    LoadField: struct {
        object: Value,
        fieldName: []const u8,
        dest: u32,
    },
    LoadIndex: struct {
        array: Value,
        index: Value,
        dest: u32,
        resolvedType: ?Type,
    },
    StoreIndex: struct {
        array: Value,
        index: Value,
        value: Value,
        resolvedType: ?Type,
    },
    JumpWhileTrue: struct {
        condition: Value,
        label: u32,
    },
    FunctionIR: struct {
        name: []const u8,
        params: []*Param,
        body: []Instruction,
        returnType: Type,
    },
    StructDeclIR: struct {
        definition: *StructStmt,
    },
    FunctionCall: struct {
        name: []const u8,
        args: []Value,
        dest: u32,
    },
    ParamBind: struct {
        name: []const u8,
        index: u32,
    },
    AllocStruct: struct {
        structType: []const u8,
        definition: StructInitExpr,
        dest: u32,
        resolvedType: ?Type,
    },
    PrintCall: struct {
        value: Value,
        resolvedType: ?Type,
    },
    UnaryOp: struct {
        op: UnaryOperator,
        operand: Value,
        dest: u32,
        resolvedType: ?Type,
    },
};
