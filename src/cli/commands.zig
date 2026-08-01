const std = @import("std");
const pipeline = @import("../compiler/pipeline.zig");
const options = @import("options.zig");

pub const CliError = error{
    MissingCommand,
    UnknownCommand,
    MissingSourcePath,
    MissingOptionValue,
    UnknownOption,
    InvalidBackend,
};

pub const Command = union(enum) {
    run: options.RunOptions,
    build: options.BuildOptions,
    help,
    version,
};

pub fn parseArgs(_: std.mem.Allocator, args: []const []const u8) !Command {
    var arg_index: usize = 1;

    const command_name = if (arg_index < args.len) args[arg_index] else return .help;
    arg_index += 1;

    if (std.mem.eql(u8, command_name, "help") or std.mem.eql(u8, command_name, "--help") or std.mem.eql(u8, command_name, "-h")) {
        return .help;
    }

    if (std.mem.eql(u8, command_name, "run")) {
        return .{ .run = try parseCommonOptions(args, &arg_index) };
    }

    if (std.mem.eql(u8, command_name, "build")) {
        return .{ .build = try parseCommonOptions(args, &arg_index) };
    }

    if (std.mem.eql(u8, command_name, "version")) {
        return .version;
    }

    return CliError.UnknownCommand;
}

fn parseCommonOptions(args: []const []const u8, arg_index: *usize) !options.CommonOptions {
    var source_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var backend: pipeline.BackendKind = .llvm;
    var emit_ir = false;
    var emit_asm = false;
    var emit_llvm_ir = false;

    while (arg_index.* < args.len) {
        const arg = args[arg_index.*];
        arg_index.* += 1;

        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            if (arg_index.* >= args.len) return CliError.MissingOptionValue;
            output_path = args[arg_index.*];
            arg_index.* += 1;
        } else if (std.mem.eql(u8, arg, "--backend")) {
            if (arg_index.* >= args.len) return CliError.MissingOptionValue;
            const backend_name = args[arg_index.*];
            arg_index.* += 1;
            backend = parseBackend(backend_name) orelse return CliError.InvalidBackend;
        } else if (std.mem.eql(u8, arg, "--emit-ir")) {
            emit_ir = true;
        } else if (std.mem.eql(u8, arg, "--emit-asm")) {
            emit_asm = true;
        } else if (std.mem.eql(u8, arg, "--emit-llvm-ir")) {
            emit_llvm_ir = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return CliError.UnknownOption;
        } else if (source_path == null) {
            source_path = arg;
        } else {
            return CliError.UnknownOption;
        }
    }

    return .{
        .source_path = source_path orelse return CliError.MissingSourcePath,
        .output_path = output_path,
        .backend = backend,
        .emit_ir = emit_ir,
        .emit_asm = emit_asm,
        .emit_llvm_ir = emit_llvm_ir,
    };
}

fn parseBackend(name: []const u8) ?pipeline.BackendKind {
    if (std.mem.eql(u8, name, "llvm")) return .llvm;
    if (std.mem.eql(u8, name, "x86_64")) return .x86_64;
    if (std.mem.eql(u8, name, "x86-64")) return .x86_64;
    return null;
}

pub fn printHelp() void {
    std.debug.print(
        \\Usage:
        \\  midnight run <file.mn> [--backend llvm|x86_64] [--emit-ir] [--emit-asm] [--emit-llvm-ir]
        \\  midnight build <file.mn> [-o output] [--backend llvm|x86_64] [--emit-ir] [--emit-asm] [--emit-llvm-ir]
        \\
        \\Examples:
        \\  midnight run src/data/test3.mn
        \\  midnight build src/data/test3.mn -o /tmp/midnight-build/app
        \\
    , .{});
}
