const std = @import("std");
const LLVMBackend = @import("../llvm_backend.zig").LLVMBackend;
const LLVMBackendError = @import("../llvm_backend.zig").LLVMBackendError;
const c = @import("../../../llvm.zig").c;
const Type = @import("../../../semantic/types.zig").Type;
const UnaryOperator = @import("../../../ir/ir.zig").UnaryOperator;

pub fn lowerUnaryOp(self: *LLVMBackend, inst: *UnaryOperator) !void {
    switch (inst.op) {
        .Negate => {
            const typ = inst.resolvedType orelse return LLVMBackendError.MissingResolvedType;
            const operand_value = try self.valueRef(inst.operand, typ);
            const result_value = c.LLVMBuildFNeg(self.builder, operand_value, try self.nextName("negtmp"));
            try self.putTemp(inst.dest, result_value, typ);
        },
        .Not => {
            const typ = inst.resolvedType orelse return LLVMBackendError.MissingResolvedType;
            const operand_value = try self.valueRef(inst.operand, typ);
            const result_value = c.LLVMBuildNot(self.builder, operand_value, try self.nextName("nottmp"));
            try self.putTemp(inst.dest, result_value, typ);
        },
    }
}
