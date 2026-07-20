const std = @import("std");

const LLVMContext = @import("llvm_context.zig").LLVMContext;
const LLVMTypeMapper = @import("llvm_type_mapper.zig").LLVMTypeMapper;
const emitLLVMIR = @import("llvm_backend.zig").emitLLVMIR;
const Instruction = @import("../../ir/ir.zig").Instruction;

pub const LLVMEmitter = struct {
    allocator: std.mem.Allocator,
    context: LLVMContext,
    type_mapper: LLVMTypeMapper,

    pub fn init(allocator: std.mem.Allocator, context: LLVMContext, type_mapper: LLVMTypeMapper) LLVMEmitter {
        return .{
            .allocator = allocator,
            .context = context,
            .type_mapper = type_mapper,
        };
    }

    pub fn Init(allocator: std.mem.Allocator, context: *LLVMContext, type_mapper: *LLVMTypeMapper) !LLVMEmitter {
        return init(allocator, context.*, type_mapper.*);
    }

    pub fn deinit(self: *LLVMEmitter) void {
        _ = self;
    }

    pub fn emitInstructions(self: *LLVMEmitter, instructions: []const Instruction) ![]const u8 {
        _ = self.context;
        _ = self.type_mapper;
        return try emitLLVMIR(self.allocator, instructions);
    }

    pub fn emitInstructionList(self: *LLVMEmitter, instructions: std.ArrayList(Instruction)) ![]const u8 {
        return try self.emitInstructions(instructions.items);
    }
};
