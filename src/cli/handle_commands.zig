const std = @import("std");
const Command = @import("../cli/commands.zig").Command;
const cli = @import("../cli/commands.zig");
const pipeline = @import("../compiler/pipeline.zig");
const makeCompileOptions = @import("../cli/compiler_options.zig").makeCompileOptions;

pub fn handle_cli_commands(allocator: std.mem.Allocator, command: *const Command) !void {
    switch (command.*) {
        .help => cli.printHelp(),
        .run => |options| {
            var result = try pipeline.compileFile(allocator, makeCompileOptions(allocator, options, true));
            defer result.deinit();
        },
        .build => |options| {
            var result = try pipeline.compileFile(allocator, makeCompileOptions(allocator, options, false));
            defer result.deinit();

            if (result.artifact) |artifact| {
                std.debug.print("Built {s}\n", .{artifact.executable_path});
            }
        },
        .version => {
            std.debug.print("Midnight Compiler version 0.1.0-alpha.1\n", .{});
        },
    }
}
