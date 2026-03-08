const std = @import("std");

pub const INT = Type{ .kind = .INT };

pub const FLOAT = Type{ .kind = .FLOAT };

pub const BOOL = Type{ .kind = .BOOL };

pub const VOID = Type{ .kind = .VOID };

pub const STRING = Type{ .kind = .STRING };

pub const TypeError = error{
    TypeMismatch,
    InvalidType,
    NotAFunction,
    NotAVariable,
};

pub const TypeKind = enum {
    INT,
    BOOL,
    FLOAT,
    VOID,
    STRING,
};

pub const Type = struct {
    kind: TypeKind,

    pub fn isNumeric(self: Type) bool {
        return self.kind == .INT or self.kind == .FLOAT;
    }

    pub fn equals(a: Type, b: Type) bool {
        return a.kind == b.kind;
    }
};

pub const IntLiteral = struct {
    value: i64,
    resolvedType: ?Type = null,
};

pub const FloatLiteral = struct {
    value: f64,
    resolvedType: ?Type = null,
};

pub const BooleanLiteral = struct {
    value: bool,
    resolvedType: ?Type = null,
};

pub const StringLiteral = struct {
    value: []const u8,
    resolvedType: ?Type = null,
};
