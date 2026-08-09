const std = @import("std");

pub const INT = Type{ .kind = .INT };

pub const FLOAT = Type{ .kind = .FLOAT };

pub const BOOL = Type{ .kind = .BOOL };

pub const VOID = Type{ .kind = .VOID };

pub const STRING = Type{ .kind = .STRING };

pub const FUNCTION = Type{ .kind = .FUNCTION };

pub const STRUCT = Type{ .kind = .STRUCT };

pub const EMPTY = Type{ .kind = .EMPTY };

pub const NULL = Type{ .kind = .EMPTY, .is_nullable = true };

pub const TypeError = error{
    TypeMismatch,
    InvalidType,
    NotAFunction,
    NotAVariable,
};

pub const TypeKind = enum { INT, BOOL, FLOAT, VOID, STRING, FUNCTION, STRUCT, EMPTY };

pub const Type = struct {
    kind: TypeKind,
    struct_name: ?[]const u8 = null,
    isArray: bool = false,
    dynamicArray: bool = false,
    staticLength: ?u32 = null,
    is_nullable: bool = false,

    pub fn isNumeric(self: Type) bool {
        return self.kind == .INT or self.kind == .FLOAT;
    }

    pub fn equals(a: Type, b: Type) bool {
        return @import("type_compatibility.zig").equals(a, b);
    }
};
