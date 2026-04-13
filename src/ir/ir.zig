const std = @import("std");

pub const Value = union(enum) {
    temp: u32,
    constantInt: i64,
    constantFloat: f64,
    constantBool: bool,
    string: []const u8,
    variable: []const u8,
};

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
}, LoadConstInt: struct {
    value: i64,
    dest: u32,
}, LoadConstFloat: struct {
    value: f64,
    dest: u32,
}, LoadConstBool: struct {
    value: bool,
    dest: u32,
}, LoadConstString: struct {
    value: []const u8,
    dest: u32,
}, LoadVar: struct {
    name: []const u8,
    dest: u32,
}, StoreVar: struct {
    name: []const u8,
    value: Value,
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
} };
