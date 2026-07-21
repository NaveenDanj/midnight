const std = @import("std");
const cli = @import("../cli/commands.zig");
const cli_options = @import("../cli/options.zig");
const pipeline = @import("../compiler/pipeline.zig");

pub fn makeCompileOptions(
    allocator: std.mem.Allocator,
    options: cli_options.CommonOptions,
    run: bool,
) pipeline.CompileOptions {
    const default_output_dir = defaultOutputDir(allocator);

    const output_dir = if (options.output_path) |path|
        std.fs.path.dirname(path) orelse default_output_dir
    else
        default_output_dir;

    const executable_name = if (options.output_path) |path|
        std.fs.path.basename(path)
    else
        "out";

    const asm_path = std.fmt.allocPrint(allocator, "{s}/output.s", .{output_dir}) catch @panic("OOM");
    const object_path = std.fmt.allocPrint(allocator, "{s}/out.o", .{output_dir}) catch @panic("OOM");

    return .{
        .source_path = options.source_path,
        .output_dir = output_dir,
        .asm_path = asm_path,
        .object_path = object_path,
        .executable_name = executable_name,
        .backend = options.backend,
        .emit_ir = options.emit_ir,
        .emit_asm = options.emit_asm,
        .emit_llvm_ir = options.emit_llvm_ir,
        .link = true,
        .run = run,
    };
}

fn defaultOutputDir(allocator: std.mem.Allocator) []const u8 {
    return std.fmt.allocPrint(allocator, "/tmp/midnight-build-{d}", .{std.os.linux.getpid()}) catch @panic("OOM");
}
