const std = @import("std");

pub const ToolchainOptions = struct {
    asm_text: []const u8,
    asm_path: []const u8 = "/tmp/midnight-build/output.asm",
    output_dir: []const u8 = "/tmp/midnight-build",
    executable_name: []const u8 = "out.exe",
    cleanup_object: bool = true,
};

pub const ObjectLinkOptions = struct {
    object_bytes: []const u8,
    object_path: []const u8 = "/tmp/midnight-build/out.o",
    output_dir: []const u8 = "/tmp/midnight-build",
    executable_name: []const u8 = "out.exe",
    cleanup_object: bool = true,
};

pub const BuildArtifact = struct {
    allocator: std.mem.Allocator,
    asm_path: []const u8,
    object_path: []const u8,
    executable_path: []const u8,

    pub fn deinit(self: *BuildArtifact) void {
        self.allocator.free(self.asm_path);
        self.allocator.free(self.object_path);
        self.allocator.free(self.executable_path);
    }
};

pub fn writeAssembly(asm_text: []const u8, path: []const u8) !void {
    const io = std.Io.Threaded.global_single_threaded.io();

    if (std.fs.path.dirname(path)) |dir| {
        try std.Io.Dir.cwd().createDirPath(io, dir);
    }

    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = path,
        .data = asm_text,
    });
}

pub fn writeObject(object_bytes: []const u8, path: []const u8) !void {
    const io = std.Io.Threaded.global_single_threaded.io();

    if (std.fs.path.dirname(path)) |dir| {
        try std.Io.Dir.cwd().createDirPath(io, dir);
    }

    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = path,
        .data = object_bytes,
    });
}

pub fn assembleAndLink(allocator: std.mem.Allocator, options: ToolchainOptions) !BuildArtifact {
    const io = std.Io.Threaded.global_single_threaded.io();
    try std.Io.Dir.cwd().createDirPath(io, options.output_dir);

    try writeAssembly(options.asm_text, options.asm_path);

    const object_path = try std.fmt.allocPrint(allocator, "{s}/out.o", .{options.output_dir});
    errdefer allocator.free(object_path);

    const executable_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ options.output_dir, options.executable_name });
    errdefer allocator.free(executable_path);

    const asm_path = try allocator.dupe(u8, options.asm_path);
    errdefer allocator.free(asm_path);

    const zig_global_cache = try std.fmt.allocPrint(allocator, "ZIG_GLOBAL_CACHE_DIR={s}/zig-global-cache", .{options.output_dir});
    defer allocator.free(zig_global_cache);
    const zig_local_cache = try std.fmt.allocPrint(allocator, "ZIG_LOCAL_CACHE_DIR={s}/zig-local-cache", .{options.output_dir});
    defer allocator.free(zig_local_cache);

    try runCommand(allocator, &.{
        "nasm",
        "-f",
        "elf64",
        asm_path,
        "-o",
        object_path,
    });

    try runCommand(allocator, &.{
        "env",
        zig_global_cache,
        zig_local_cache,
        "zig",
        "cc",
        object_path,
        "-o",
        executable_path,
    });

    if (options.cleanup_object) {
        std.Io.Dir.cwd().deleteFile(io, object_path) catch {};
    }

    return .{
        .allocator = allocator,
        .asm_path = asm_path,
        .object_path = object_path,
        .executable_path = executable_path,
    };
}

pub fn linkObject(allocator: std.mem.Allocator, options: ObjectLinkOptions) !BuildArtifact {
    const io = std.Io.Threaded.global_single_threaded.io();
    try std.Io.Dir.cwd().createDirPath(io, options.output_dir);

    try writeObject(options.object_bytes, options.object_path);

    const object_path = try allocator.dupe(u8, options.object_path);
    errdefer allocator.free(object_path);

    const executable_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ options.output_dir, options.executable_name });
    errdefer allocator.free(executable_path);

    const asm_path = try allocator.dupe(u8, "");
    errdefer allocator.free(asm_path);

    const zig_global_cache = try std.fmt.allocPrint(allocator, "ZIG_GLOBAL_CACHE_DIR={s}/zig-global-cache", .{options.output_dir});
    defer allocator.free(zig_global_cache);
    const zig_local_cache = try std.fmt.allocPrint(allocator, "ZIG_LOCAL_CACHE_DIR={s}/zig-local-cache", .{options.output_dir});
    defer allocator.free(zig_local_cache);

    try runCommand(allocator, &.{
        "env",
        zig_global_cache,
        zig_local_cache,
        "zig",
        "cc",
        object_path,
        "runtime/string.o",
        "runtime/file.o",
        "runtime/input.o",
        "-o",
        executable_path,
    });

    if (options.cleanup_object) {
        std.Io.Dir.cwd().deleteFile(io, object_path) catch {};
    }

    return .{
        .allocator = allocator,
        .asm_path = asm_path,
        .object_path = object_path,
        .executable_path = executable_path,
    };
}

pub fn runArtifact(allocator: std.mem.Allocator, artifact: BuildArtifact) !void {
    try runCommand(allocator, &.{artifact.executable_path});
}

fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    var threaded_io = std.Io.Threaded.init(allocator, .{});
    defer threaded_io.deinit();
    const io = threaded_io.io();
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    });

    const term = try child.wait(io);
    switch (term) {
        .exited => |code| if (code != 0) return error.CommandFailed,
        else => return error.CommandFailed,
    }
}
