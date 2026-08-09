const std = @import("std");

pub const TypeRef = struct {
    name: []const u8,
    is_array: bool = false,
    dynamic_array: bool = false,
    static_length: ?u32 = null,
    is_nullable: bool = false,

    pub fn isNamed(self: TypeRef, name: []const u8) bool {
        return std.mem.eql(u8, self.name, name);
    }
};

pub const INT = TypeRef{ .name = "int" };
pub const FLOAT = TypeRef{ .name = "float" };
pub const BOOL = TypeRef{ .name = "bool" };
pub const VOID = TypeRef{ .name = "void" };
pub const STRING = TypeRef{ .name = "string" };
pub const NULL = TypeRef{ .name = "null", .is_nullable = true };
