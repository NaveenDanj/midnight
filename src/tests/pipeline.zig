const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const pipeline = @import("../compiler/pipeline.zig");
const toolchain = @import("../backend/toolchain.zig");

test "pipeline compiles in-memory source without invoking toolchain" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\var int x = 5;
        \\print(x);
    ;

    var result = try pipeline.compileSource(allocator, source, .{
        .emit_asm = true,
        .link = false,
        .run = false,
    });
    defer result.deinit();

    try expect(result.statements.len == 2);
    try expect(result.instructions.len > 0);
    try expect(result.asm_text != null);
    try expect(result.artifact == null);
    try expect(std.mem.indexOf(u8, result.asm_text.?, "global main") != null);
}

test "pipeline can stop after IR without emitting assembly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var result = try pipeline.compileSource(allocator, "var int x = 1;", .{
        .emit_asm = false,
        .link = false,
        .run = false,
    });
    defer result.deinit();

    try expectEqual(@as(usize, 2), result.instructions.len);
    try expect(result.asm_text == null);
    try expect(result.artifact == null);
}

test "toolchain writes assembly without assembling or running" {
    const path = "/tmp/midnight-pipeline-tests/output.asm";
    const io = std.Io.Threaded.global_single_threaded.io();
    std.Io.Dir.cwd().deleteFile(io, path) catch {};

    try toolchain.writeAssembly("global main\n", path);

    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var buffer: [64]u8 = undefined;
    var reader = file.reader(io, &buffer);
    const text = try reader.interface.allocRemaining(std.testing.allocator, .limited64(64));
    defer std.testing.allocator.free(text);

    try expect(std.mem.eql(u8, text, "global main\n"));
}
