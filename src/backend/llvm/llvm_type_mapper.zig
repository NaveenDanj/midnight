const std = @import("std");
const Type = @import("../semantic/types.zig").Type;
const Instruction = @import("../ir/ir.zig").Instruction;

pub const LLVMTypeMapper = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LLVMTypeMapper {
        return LLVMTypeMapper{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LLVMTypeMapper) void {
        _ = self;
    }

    pub fn mapType(self: *LLVMTypeMapper, ir_type: Type) !*const u8 {
        _ = self;
        return switch (ir_type) {
            .Int => "i32",
            .Float => "float",
            .Double => "double",
            .Void => "void",
            else => return error.UnsupportedType,
        };
    }
};
