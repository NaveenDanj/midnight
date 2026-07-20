const BinaryOp = @import("../../../ir/ir.zig").BinaryOp;
const LLVMBackendError = @import("../llvm_backend.zig").LLVMBackendError;
const c = @import("../../../llvm.zig").c;

pub fn intPredicate(op: BinaryOp) LLVMBackendError!c.LLVMIntPredicate {
    return switch (op) {
        .Equal => c.LLVMIntEQ,
        .NotEqual => c.LLVMIntNE,
        .LessThan => c.LLVMIntSLT,
        .LessThanOrEqual => c.LLVMIntSLE,
        .GreaterThan => c.LLVMIntSGT,
        .GreaterThanOrEqual => c.LLVMIntSGE,
        else => LLVMBackendError.UnsupportedBinaryOperation,
    };
}

pub fn realPredicate(op: BinaryOp) LLVMBackendError!c.LLVMRealPredicate {
    return switch (op) {
        .Equal => c.LLVMRealOEQ,
        .NotEqual => c.LLVMRealONE,
        .LessThan => c.LLVMRealOLT,
        .LessThanOrEqual => c.LLVMRealOLE,
        .GreaterThan => c.LLVMRealOGT,
        .GreaterThanOrEqual => c.LLVMRealOGE,
        else => LLVMBackendError.UnsupportedBinaryOperation,
    };
}
