const std = @import("std");

const Type = @import("../../semantic/types.zig").Type;

pub const LLVMTypeMapper = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LLVMTypeMapper {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LLVMTypeMapper) void {
        _ = self;
    }

    pub fn mapType(self: *LLVMTypeMapper, ir_type: Type) ![]const u8 {
        _ = self;

        if (ir_type.isArray) {
            return "ptr";
        }

        return switch (ir_type.kind) {
            .INT => "i64",
            .BOOL => "i1",
            .FLOAT => "double",
            .VOID => "void",
            .STRING, .STRUCT => "ptr",
            .FUNCTION, .EMPTY => error.UnsupportedType,
        };
    }
};
