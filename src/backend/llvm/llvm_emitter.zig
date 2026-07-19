const std = @import("std");
const LLVMContext = @import("llvm_context.zig").LLVMContext;
const LLVMTypeMapper = @import("llvm_type_mapper.zig").LLVMTypeMapper;
const Instruction = @import("../../ir/ir.zig").Instruction;

pub const LLVMEmitter = struct {
    allocator: std.mem.Allocator,
    llvm: LLVMContext,
    type_mapper: LLVMTypeMapper,

    pub fn Init(allocator: std.mem.Allocator, llvm: *LLVMContext, type_mapper: *LLVMTypeMapper) !LLVMEmitter {
        return LLVMEmitter{
            .allocator = allocator,
            .llvm = llvm.*,
            .type_mapper = type_mapper.*,
        };
    }

    pub fn deinit(self: *LLVMEmitter) void {
        _ = self;
    }

    pub fn emitInstructions(self: *LLVMEmitter, instructions: std.ArrayList(Instruction)) !void {
        _ = self;
        for (instructions.items) |instruction| {
            std.debug.print("Emitting instruction: {any}\n", .{instruction});
        }
    }
};
