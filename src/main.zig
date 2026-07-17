const std = @import("std");
const pipeline = @import("compiler/pipeline.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var result = try pipeline.compileFile(allocator, .{
        .source_path = "./src/data/simple.mn",
        .output_dir = "/tmp/midnight-build",
        .asm_path = "/tmp/midnight-build/output.asm",
        .emit_ir = true,
        .emit_asm = true,
        .link = true,
        .run = true,
    });
    defer result.deinit();
}
