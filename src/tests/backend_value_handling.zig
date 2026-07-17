const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;

const AsmBuilder = @import("../backend/asm_builder.zig").AsmBuilder;
const BackendError = @import("../backend/x86_64/x86_64_backend.zig").BackendError;
const X86_64Backend = @import("../backend/x86_64/x86_64_backend.zig").X86_64Backend;
const Instruction = @import("../ir/ir.zig").Instruction;

fn lowerOne(allocator: std.mem.Allocator, instruction: *const Instruction) ![]const u8 {
    var backend = X86_64Backend.init(allocator);
    var asmBuilder = try AsmBuilder.init(allocator);
    defer asmBuilder.deinit();

    try backend.lowerInstruction(&asmBuilder, instruction);
    return try allocator.dupe(u8, asmBuilder.buffer.items);
}

test "backend StoreVar loads constant values through value helper" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const instruction = Instruction{ .StoreVar = .{
        .name = "count",
        .value = .{ .constantInt = 42 },
        .resolvedType = .{ .kind = .INT },
    } };

    const assembly = try lowerOne(allocator, &instruction);

    try expect(std.mem.indexOf(u8, assembly, "mov rax, 42") != null);
    try expect(std.mem.indexOf(u8, assembly, "mov qword [rbp-") != null);
}

test "backend integer binary operations load immediate values through value helper" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const instruction = Instruction{ .BinaryOp = .{
        .op = .Add,
        .left = .{ .constantInt = 7 },
        .right = .{ .constantBool = true },
        .dest = 0,
        .resolvedType = .{ .kind = .INT },
    } };

    const assembly = try lowerOne(allocator, &instruction);

    try expect(std.mem.indexOf(u8, assembly, "mov rax, 7") != null);
    try expect(std.mem.indexOf(u8, assembly, "mov rbx, 1") != null);
    try expect(std.mem.indexOf(u8, assembly, "add rax, rbx") != null);
}

test "backend float binary operations load float constants through xmm helper" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const instruction = Instruction{ .BinaryOp = .{
        .op = .Multiply,
        .left = .{ .constantFloat = 1.5 },
        .right = .{ .constantFloat = 2.0 },
        .dest = 0,
        .resolvedType = .{ .kind = .FLOAT },
    } };

    const assembly = try lowerOne(allocator, &instruction);

    try expect(std.mem.indexOf(u8, assembly, "movsd xmm0, qword [LCF0]") != null);
    try expect(std.mem.indexOf(u8, assembly, "movsd xmm1, qword [LCF1]") != null);
    try expect(std.mem.indexOf(u8, assembly, "mulsd xmm0, xmm1") != null);
}

test "backend print call loads strings through value helper" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const instruction = Instruction{ .PrintCall = .{
        .value = .{ .string = "hello" },
        .resolvedType = .{ .kind = .STRING },
    } };

    const assembly = try lowerOne(allocator, &instruction);

    try expect(std.mem.indexOf(u8, assembly, "mov rdi, LCS0") != null);
    try expect(std.mem.indexOf(u8, assembly, "call puts") != null);
}

test "backend returns unsupported value for invalid register load variant" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var backend = X86_64Backend.init(allocator);
    var asmBuilder = try AsmBuilder.init(allocator);
    defer asmBuilder.deinit();

    var instruction = Instruction{ .StoreVar = .{
        .name = "bad",
        .value = .{ .constantFloat = 1.5 },
        .resolvedType = .{ .kind = .FLOAT },
    } };

    try expectError(BackendError.UnsupportedValue, backend.lowerInstruction(&asmBuilder, &instruction));
}
