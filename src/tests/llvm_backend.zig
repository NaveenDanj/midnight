const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;

const LLVMBackendError = @import("../backend/llvm/llvm_backend.zig").LLVMBackendError;
const LLVMContext = @import("../backend/llvm/llvm_context.zig").LLVMContext;
const LLVMEmitter = @import("../backend/llvm/llvm_emitter.zig").LLVMEmitter;
const LLVMTypeMapper = @import("../backend/llvm/llvm_type_mapper.zig").LLVMTypeMapper;
const emitLLVMIR = @import("../backend/llvm/llvm_backend.zig").emitLLVMIR;
const Instruction = @import("../ir/ir.zig").Instruction;

test "LLVM backend emits constants variables and integer arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const instructions = [_]Instruction{
        .{ .StoreVar = .{
            .name = "left",
            .value = .{ .constantInt = 2 },
            .resolvedType = .{ .kind = .INT },
        } },
        .{ .StoreVar = .{
            .name = "right",
            .value = .{ .constantInt = 3 },
            .resolvedType = .{ .kind = .INT },
        } },
        .{ .LoadVar = .{
            .name = "left",
            .dest = 0,
            .resolvedType = .{ .kind = .INT },
        } },
        .{ .LoadVar = .{
            .name = "right",
            .dest = 1,
            .resolvedType = .{ .kind = .INT },
        } },
        .{ .LoadConstInt = .{
            .value = 0,
            .dest = 99,
            .resolvedType = .{ .kind = .INT },
        } },
        .{ .BinaryOp = .{
            .op = .Add,
            .left = .{ .temp = 0 },
            .right = .{ .temp = 1 },
            .dest = 2,
            .resolvedType = .{ .kind = .INT },
        } },
        .{ .StoreVar = .{
            .name = "total",
            .value = .{ .temp = 2 },
            .resolvedType = .{ .kind = .INT },
        } },
    };

    const llvm_ir = try emitLLVMIR(allocator, &instructions);

    try expect(std.mem.indexOf(u8, llvm_ir, "define i32 @main()") != null);
    try expect(std.mem.indexOf(u8, llvm_ir, "add i64") != null);
    try expect(std.mem.indexOf(u8, llvm_ir, "alloca i64") != null);
    try expect(std.mem.indexOf(u8, llvm_ir, "store i64") != null);
}

test "LLVM backend emits string constants and print calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const instructions = [_]Instruction{
        .{ .LoadConstString = .{
            .value = "hello",
            .dest = 0,
            .resolvedType = .{ .kind = .STRING },
        } },
        .{ .PrintCall = .{
            .value = .{ .temp = 0 },
            .resolvedType = .{ .kind = .STRING },
        } },
    };

    const llvm_ir = try emitLLVMIR(allocator, &instructions);

    try expect(std.mem.indexOf(u8, llvm_ir, "c\"hello\\00\"") != null);
    try expect(std.mem.indexOf(u8, llvm_ir, "call i32 @puts") != null);
}

test "LLVM backend reports missing type information for typed IR operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const instructions = [_]Instruction{
        .{ .StoreVar = .{
            .name = "x",
            .value = .{ .constantInt = 1 },
            .resolvedType = null,
        } },
    };

    try expectError(LLVMBackendError.MissingResolvedType, emitLLVMIR(allocator, &instructions));
}

test "LLVM emitter wrapper delegates to backend" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var context = LLVMContext.init(allocator, "test");
    defer context.deinit();

    var type_mapper = LLVMTypeMapper.init(allocator);
    defer type_mapper.deinit();

    var emitter = try LLVMEmitter.Init(allocator, &context, &type_mapper);
    defer emitter.deinit();

    const instructions = [_]Instruction{
        .{ .LoadConstBool = .{
            .value = true,
            .dest = 0,
            .resolvedType = .{ .kind = .BOOL },
        } },
    };

    const llvm_ir = try emitter.emitInstructions(&instructions);

    try expect(std.mem.indexOf(u8, llvm_ir, "define i32 @main()") != null);
}
