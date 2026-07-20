const std = @import("std");
const pipeline = @import("compiler/pipeline.zig");
const c = @cImport({
    @cInclude("llvm-c/Core.h");
});

pub fn main() !void {
    const context = c.LLVMContextCreate();

    defer c.LLVMContextDispose(context);

    std.debug.print(
        "LLVM context created\n",
        .{},
    );

    const allocator = std.heap.page_allocator;
    var result = try pipeline.compileFile(allocator, .{
        .source_path = "./src/data/simple.mn",
        .output_dir = "/tmp/midnight-llvm-build",
        .asm_path = "/tmp/midnight-llvm-build/output.s",
        .object_path = "/tmp/midnight-llvm-build/out.o",
        .emit_ir = true,
        .emit_asm = true,
        .emit_llvm_ir = true,
        .backend = .llvm,
        .link = true,
        .run = true,
    });
    defer result.deinit();
}
