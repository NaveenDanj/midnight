const std = @import("std");
const cli = @import("cli/commands.zig");
const cli_handler = @import("cli/handle_commands.zig");
const cli_options = @import("cli/options.zig");
const pipeline = @import("compiler/pipeline.zig");
const makeCompileOptions = @import("cli/compiler_options.zig").makeCompileOptions;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    const command = cli.parseArgs(allocator, init.minimal.args) catch |err| {
        std.debug.print("error: {s}\n\n", .{@errorName(err)});
        cli.printHelp();
        return err;
    };

    try cli_handler.handle_cli_commands(allocator, &command);
}
