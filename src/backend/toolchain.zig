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
    if (std.fs.path.dirname(path)) |dir| {
        try std.fs.cwd().makePath(dir);
    }

    try std.fs.cwd().writeFile(.{
        .sub_path = path,
        .data = asm_text,
    });
}

pub fn writeObject(object_bytes: []const u8, path: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir| {
        try std.fs.cwd().makePath(dir);
    }

    try std.fs.cwd().writeFile(.{
        .sub_path = path,
        .data = object_bytes,
    });
}

pub fn assembleAndLink(allocator: std.mem.Allocator, options: ToolchainOptions) !BuildArtifact {
    try std.fs.cwd().makePath(options.output_dir);

    try writeAssembly(options.asm_text, options.asm_path);

    const object_path = try std.fmt.allocPrint(allocator, "{s}/out.o", .{options.output_dir});
    errdefer allocator.free(object_path);

    const executable_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ options.output_dir, options.executable_name });
    errdefer allocator.free(executable_path);

    const asm_path = try allocator.dupe(u8, options.asm_path);
    errdefer allocator.free(asm_path);

    try runCommand(allocator, &.{
        "nasm",
        "-f",
        "elf64",
        asm_path,
        "-o",
        object_path,
    });

    try runZigCC(allocator, options.output_dir, &.{
        object_path,
        "-o",
        executable_path,
    });

    if (options.cleanup_object) {
        std.fs.cwd().deleteFile(object_path) catch {};
    }

    return .{
        .allocator = allocator,
        .asm_path = asm_path,
        .object_path = object_path,
        .executable_path = executable_path,
    };
}

pub fn linkObject(allocator: std.mem.Allocator, options: ObjectLinkOptions) !BuildArtifact {
    try std.fs.cwd().makePath(options.output_dir);

    try writeObject(options.object_bytes, options.object_path);

    const artifact = try linkObjects(allocator, .{
        .object_paths = &.{options.object_path},
        .output_dir = options.output_dir,
        .executable_name = options.executable_name,
        .cleanup_objects = options.cleanup_object,
    });
    allocator.free(artifact.asm_path);
    allocator.free(artifact.object_path);

    return .{
        .allocator = allocator,
        .asm_path = try allocator.dupe(u8, ""),
        .object_path = try allocator.dupe(u8, options.object_path),
        .executable_path = artifact.executable_path,
    };
}

pub const ObjectsLinkOptions = struct {
    object_paths: []const []const u8,
    output_dir: []const u8 = "/tmp/midnight-build",
    executable_name: []const u8 = "out.exe",
    cleanup_objects: bool = true,
};

// Links any number of already-written object files together (e.g. one per
// compiled module plus the entry object) alongside the runtime C sources,
// producing a single executable. This is what makes separate compilation
// (module_compiler.zig) work: each module/entry object only needs to declare
// externs for symbols it doesn't define itself, and this final step is what
// actually resolves them against whichever object defines them.
pub fn linkObjects(allocator: std.mem.Allocator, options: ObjectsLinkOptions) !BuildArtifact {
    try std.fs.cwd().makePath(options.output_dir);

    const executable_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ options.output_dir, options.executable_name });
    errdefer allocator.free(executable_path);

    var cc_args = try std.ArrayList([]const u8).initCapacity(allocator, options.object_paths.len + 5);
    defer cc_args.deinit(allocator);
    try cc_args.appendSlice(allocator, options.object_paths);
    try cc_args.appendSlice(allocator, &.{
        "src/runtime/string.c",
        "src/runtime/file.c",
        "src/runtime/input.c",
        "-o",
        executable_path,
    });

    try runZigCC(allocator, options.output_dir, cc_args.items);

    if (options.cleanup_objects) {
        for (options.object_paths) |object_path| {
            std.fs.cwd().deleteFile(object_path) catch {};
        }
    }

    return .{
        .allocator = allocator,
        .asm_path = try allocator.dupe(u8, ""),
        .object_path = try allocator.dupe(u8, options.object_paths[options.object_paths.len - 1]),
        .executable_path = executable_path,
    };
}

pub fn runArtifact(allocator: std.mem.Allocator, artifact: BuildArtifact) !void {
    try runCommand(allocator, &.{artifact.executable_path});
}

fn runZigCC(allocator: std.mem.Allocator, output_dir: []const u8, cc_args: []const []const u8) !void {
    const argv = try allocator.alloc([]const u8, cc_args.len + 2);
    defer allocator.free(argv);
    argv[0] = "zig";
    argv[1] = "cc";
    @memcpy(argv[2..], cc_args);

    const global_cache_dir = try std.fmt.allocPrint(allocator, "{s}/zig-global-cache", .{output_dir});
    defer allocator.free(global_cache_dir);
    const local_cache_dir = try std.fmt.allocPrint(allocator, "{s}/zig-local-cache", .{output_dir});
    defer allocator.free(local_cache_dir);

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();
    try env_map.put("ZIG_GLOBAL_CACHE_DIR", global_cache_dir);
    try env_map.put("ZIG_LOCAL_CACHE_DIR", local_cache_dir);

    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    child.env_map = &env_map;

    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) return error.CommandFailed,
        else => return error.CommandFailed,
    }
}

fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) return error.CommandFailed,
        else => return error.CommandFailed,
    }
}
