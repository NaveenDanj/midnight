const std = @import("std");
const cli = @import("cli/commands.zig");
const cli_handler = @import("cli/handle_commands.zig");
const cli_options = @import("cli/options.zig");
const pipeline = @import("compiler/pipeline.zig");
const makeCompileOptions = @import("cli/compiler_options.zig").makeCompileOptions;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const command = cli.parseArgs(allocator, args) catch |err| {
        std.debug.print("error: {s}\n\n", .{@errorName(err)});
        cli.printHelp();
        return err;
    };

    try cli_handler.handle_cli_commands(allocator, &command);
}
