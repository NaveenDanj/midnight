const std = @import("std");

pub const LLVMContext = struct {
    allocator: std.mem.Allocator,
    module_name: []const u8,

    pub fn init(allocator: std.mem.Allocator, module_name: []const u8) LLVMContext {
        return .{
            .allocator = allocator,
            .module_name = module_name,
        };
    }

    pub fn deinit(self: *LLVMContext) void {
        _ = self;
    }
};
