const std = @import("std");
const Type = @import("../semantic/types.zig").Type;
const Param = @import("../parser/lib//parseFunctionDecl.zig").Param;

pub const Value = union(enum) { temp: u32, constantInt: i64, constantFloat: f64, constantBool: bool, string: []const u8, variable: []const u8, paramIndex: i64, arrayIndex: u32 };

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

pub const Instruction = union(enum) { BinaryOp: struct {
    op: BinaryOp,
    left: Value,
    right: Value,
    dest: u32,
    resolvedType: ?Type,
}, LoadConstInt: struct {
    value: i64,
    dest: u32,
    resolvedType: ?Type,
}, LoadConstFloat: struct {
    value: f64,
    dest: u32,
    resolvedType: ?Type,
}, LoadConstBool: struct {
    value: bool,
    dest: u32,
    resolvedType: ?Type,
}, LoadConstString: struct {
    value: []const u8,
    dest: u32,
    resolvedType: ?Type,
}, LoadVar: struct {
    name: []const u8,
    dest: u32,
    resolvedType: ?Type,
}, StoreVar: struct {
    name: []const u8,
    value: Value,
    resolvedType: ?Type,
}, JumpIfFalse: struct {
    condition: Value,
    label: u32,
}, Jump: struct {
    label: u32,
}, Label: struct {
    id: u32,
}, Return: struct {
    value: Value,
}, StoreField: struct {
    object: Value,
    fieldName: []const u8,
    value: Value,
}, LoadField: struct {
    object: Value,
    fieldName: []const u8,
    dest: u32,
}, LoadIndex: struct {
    array: Value,
    index: Value,
    dest: u32,
}, StoreIndex: struct {
    array: Value,
    index: Value,
    value: Value,
}, JumpWhileTrue: struct {
    condition: Value,
    label: u32,
}, FunctionIR: struct {
    name: []const u8,
    params: []*Param,
    body: []Instruction,
    returnType: Type,
}, FunctionCall: struct {
    name: []const u8,
    args: []Value,
    dest: u32,
}, ParamBind: struct {
    name: []const u8,
    index: u32,
}, AllocStruct: struct {
    structType: []const u8,
    dest: u32,
}, PrintCall: struct {
    value: Value,
    resolvedType: ?Type,
} };
