const std = @import("std");
const LLVMBackend = @import("../llvm_backend.zig").LLVMBackend;
const LLVMBackendError = @import("../llvm_backend.zig").LLVMBackendError;
const c = @import("../../../llvm.zig").c;
const Type = @import("../../../semantic/types.zig").Type;
const realPredicate = @import("./predicates.zig").realPredicate;
const intPredicate = @import("./predicates.zig").intPredicate;

pub fn lowerBinaryOp(self: *LLVMBackend, inst: anytype) !void {
    const resolved_type = inst.resolvedType orelse self.inferBinaryType(inst.left, inst.right) orelse return LLVMBackendError.MissingResolvedType;
    const name = try self.nextName("bintmp");

    switch (inst.op) {
        .Add, .Subtract, .Multiply, .Divide, .Modulo => {
            const left = try self.valueRef(inst.left, resolved_type);
            const right = try self.valueRef(inst.right, resolved_type);

            const result = switch (resolved_type.kind) {
                .INT, .BOOL => switch (inst.op) {
                    .Add => c.LLVMBuildAdd(self.builder, left, right, name),
                    .Subtract => c.LLVMBuildSub(self.builder, left, right, name),
                    .Multiply => c.LLVMBuildMul(self.builder, left, right, name),
                    .Divide => c.LLVMBuildSDiv(self.builder, left, right, name),
                    .Modulo => c.LLVMBuildSRem(self.builder, left, right, name),
                    else => return LLVMBackendError.UnsupportedBinaryOperation,
                },
                .FLOAT => switch (inst.op) {
                    .Add => c.LLVMBuildFAdd(self.builder, left, right, name),
                    .Subtract => c.LLVMBuildFSub(self.builder, left, right, name),
                    .Multiply => c.LLVMBuildFMul(self.builder, left, right, name),
                    .Divide => c.LLVMBuildFDiv(self.builder, left, right, name),
                    else => return LLVMBackendError.UnsupportedBinaryOperation,
                },
                .STRING => switch (inst.op) {
                    .Add => blk: {
                        const concat = try self.getStringConcatFunction();

                        var args = [_]c.LLVMValueRef{
                            left,
                            right,
                        };

                        break :blk c.LLVMBuildCall2(
                            self.builder,
                            concat.func_type,
                            concat.value,
                            &args,
                            args.len,
                            name,
                        );
                    },
                    else => return LLVMBackendError.UnsupportedBinaryOperation,
                },
                else => return LLVMBackendError.UnsupportedBinaryOperation,
            };
            try self.putTemp(inst.dest, result, resolved_type);
        },
        .Equal, .NotEqual, .LessThan, .LessThanOrEqual, .GreaterThan, .GreaterThanOrEqual => {
            const operand_type = self.valueType(inst.left) orelse self.valueType(inst.right) orelse Type{ .kind = .INT };
            const left = try self.valueRef(inst.left, operand_type);
            const right = try self.valueRef(inst.right, operand_type);
            const result = switch (operand_type.kind) {
                .FLOAT => c.LLVMBuildFCmp(self.builder, try realPredicate(inst.op), left, right, name),
                .INT, .BOOL => c.LLVMBuildICmp(self.builder, try intPredicate(inst.op), left, right, name),
                else => return LLVMBackendError.UnsupportedBinaryOperation,
            };
            try self.putTemp(inst.dest, result, Type{ .kind = .BOOL });
        },
        .And, .Or => {
            const bool_type = Type{ .kind = .BOOL };
            const left = try self.valueRef(inst.left, bool_type);
            const right = try self.valueRef(inst.right, bool_type);
            const result = if (inst.op == .And)
                c.LLVMBuildAnd(self.builder, left, right, name)
            else
                c.LLVMBuildOr(self.builder, left, right, name);
            try self.putTemp(inst.dest, result, bool_type);
        },
    }
}
