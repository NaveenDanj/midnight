const std = @import("std");
const Type = @import("../semantic/types.zig").Type;
const Instruction = @import("../ir/ir.zig").Instruction;
const LLVMBuilder = @import("LLVMBuilder.zig").LLVMBuilder;
const LLVMModuleRef = @import("LLVMModule.zig").LLVMModuleRef;

pub const LLVMContext = struct {
    allocator: std.mem.Allocator,
    builder: LLVMBuilder,
    module: LLVMModuleRef,
};
