const std = @import("std");
const Type = @import("../../semantic/types.zig").Type;
const Instruction = @import("../../ir/ir.zig").Instruction;
const SemanticContext = @import("../../semantic/context.zig").SemanticContext;

pub const LLVMBackend = struct {
    allocator: std.mem.Allocator,
    type_context: *const SemanticContext,

    pub fn init(allocator: std.mem.Allocator, type_context: *const SemanticContext) LLVMBackend {
        return LLVMBackend{ .allocator = allocator, .type_context = type_context };
    }

    pub fn deinit(self: *LLVMBackend) void {
        self.allocator.free(self.instructions);
    }

    pub fn compile(self: *LLVMBackend, IRModule: std.ArrayList(Instruction)) !void {
        _ = self;
        _ = IRModule;
    }
};
