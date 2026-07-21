const std = @import("std");
const LLVMBackend = @import("../llvm_backend.zig").LLVMBackend;
const LLVMBackendError = @import("../llvm_backend.zig").LLVMBackendError;
const c = @import("../../../llvm.zig").c;
const Type = @import("../../../semantic/types.zig").Type;
const realPredicate = @import("./predicates.zig").realPredicate;
const intPredicate = @import("./predicates.zig").intPredicate;
const Value = @import("../../../ir/ir.zig").Value;

pub fn lowerPrintCall(self: *LLVMBackend, value: Value, typ: Type) !void {
    switch (typ.kind) {
        .INT => {
            const format = c.LLVMBuildGlobalStringPtr(self.builder, "%lld", try self.nextName("fmt.int"));
            var args = [_]c.LLVMValueRef{ format, try self.valueRef(value, typ) };
            _ = c.LLVMBuildCall2(self.builder, self.printf_type, self.printf_function, &args, args.len, "");
        },
        .BOOL => {
            const format = c.LLVMBuildGlobalStringPtr(self.builder, "%lld", try self.nextName("fmt.bool"));
            const bool_as_int = c.LLVMBuildZExt(
                self.builder,
                try self.valueRef(value, typ),
                c.LLVMInt64TypeInContext(self.context),
                try self.nextName("bool.print"),
            );
            var args = [_]c.LLVMValueRef{ format, bool_as_int };
            _ = c.LLVMBuildCall2(self.builder, self.printf_type, self.printf_function, &args, args.len, "");
        },
        .FLOAT => {
            const format = c.LLVMBuildGlobalStringPtr(self.builder, "%f", try self.nextName("fmt.float"));
            var args = [_]c.LLVMValueRef{ format, try self.valueRef(value, typ) };
            _ = c.LLVMBuildCall2(self.builder, self.printf_type, self.printf_function, &args, args.len, "");
        },
        .STRING => {
            var args = [_]c.LLVMValueRef{try self.valueRef(value, typ)};
            _ = c.LLVMBuildCall2(self.builder, self.puts_type, self.puts_function, &args, args.len, "");
        },
        else => return LLVMBackendError.UnsupportedType,
    }
}
