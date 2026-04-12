const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const Lexer = @import("../lexer/lexer.zig").Lexer;
const Parser = @import("../parser/parser.zig").Parser;
const Expr = @import("../parser/lib/parseExpr.zig").Expr;
const Instruction = @import("../ir/ir.zig").Instruction;
const BinaryOp = @import("../ir/ir.zig").BinaryOp;
const Value = @import("../ir/ir.zig").Value;
const InstructionBuilder = @import("../ir/builder.zig").InstructionBuilder;
const lowerExpression = @import("../ir/lib/lowerExpr.zig").lowerExpression;
const lowerLValue = @import("../ir/lib/lowerExpr.zig").lowerLValue;
const lowerVarAssignment = @import("../ir/lib/lowerVar.zig").lowerVarAssignment;
const generateIR = @import("../ir/lower.zig").generateIR;

fn assertTemp(value: Value, expected: u32) !void {
    switch (value) {
        .temp => |t| try expectEqual(expected, t),
        else => try expect(false),
    }
}

test "IR lowerExpression lowers int literal" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const expr = try allocator.create(Expr);
    expr.* = .{ .IntLiteral = .{ .value = 42, .resolvedType = null } };

    const result = try lowerExpression(&builder, expr);
    try assertTemp(result, 0);
    try expectEqual(@as(usize, 1), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .LoadConstInt);
    try expectEqual(@as(i64, 42), builder.instructions.items[0].LoadConstInt.value);
    try expectEqual(@as(u32, 0), builder.instructions.items[0].LoadConstInt.dest);
}

test "IR lowerExpression lowers binary expression in evaluation order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const left = try allocator.create(Expr);
    left.* = .{ .IntLiteral = .{ .value = 1, .resolvedType = null } };

    const right = try allocator.create(Expr);
    right.* = .{ .IntLiteral = .{ .value = 2, .resolvedType = null } };

    const binary = try allocator.create(Expr);
    binary.* = .{ .Binary = .{
        .left = left,
        .operator = "+",
        .right = right,
        .resolvedType = null,
    } };

    const result = try lowerExpression(&builder, binary);
    try assertTemp(result, 2);
    try expectEqual(@as(usize, 3), builder.instructions.items.len);

    try expect(builder.instructions.items[0] == .LoadConstInt);
    try expectEqual(@as(i64, 1), builder.instructions.items[0].LoadConstInt.value);
    try expectEqual(@as(u32, 0), builder.instructions.items[0].LoadConstInt.dest);

    try expect(builder.instructions.items[1] == .LoadConstInt);
    try expectEqual(@as(i64, 2), builder.instructions.items[1].LoadConstInt.value);
    try expectEqual(@as(u32, 1), builder.instructions.items[1].LoadConstInt.dest);

    try expect(builder.instructions.items[2] == .BinaryOp);
    try expectEqual(BinaryOp.Add, builder.instructions.items[2].BinaryOp.op);
    try expectEqual(@as(u32, 2), builder.instructions.items[2].BinaryOp.dest);
}

test "IR lowerExpression lowers member access" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const obj = try allocator.create(Expr);
    obj.* = .{ .Identifier = .{ .name = "person", .resolvedType = null } };

    const access = try allocator.create(Expr);
    access.* = .{ .MemberAccess = .{
        .object = obj,
        .memberName = "age",
        .resolvedType = null,
    } };

    const result = try lowerExpression(&builder, access);
    try assertTemp(result, 1);
    try expectEqual(@as(usize, 2), builder.instructions.items.len);

    try expect(builder.instructions.items[0] == .LoadVar);
    try expect(std.mem.eql(u8, builder.instructions.items[0].LoadVar.name, "person"));
    try expectEqual(@as(u32, 0), builder.instructions.items[0].LoadVar.dest);

    try expect(builder.instructions.items[1] == .LoadField);
    try expect(std.mem.eql(u8, builder.instructions.items[1].LoadField.fieldName, "age"));
    try expectEqual(@as(u32, 1), builder.instructions.items[1].LoadField.dest);
}

test "IR lowerExpression lowers array index access" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const arr = try allocator.create(Expr);
    arr.* = .{ .Identifier = .{ .name = "values", .resolvedType = null } };

    const index = try allocator.create(Expr);
    index.* = .{ .IntLiteral = .{ .value = 3, .resolvedType = null } };

    const access = try allocator.create(Expr);
    access.* = .{ .ArrayAccess = .{
        .array = arr,
        .index = index,
        .resolvedType = null,
    } };

    const result = try lowerExpression(&builder, access);
    try assertTemp(result, 2);
    try expectEqual(@as(usize, 3), builder.instructions.items.len);

    try expect(builder.instructions.items[0] == .LoadVar);
    try expect(std.mem.eql(u8, builder.instructions.items[0].LoadVar.name, "values"));
    try expectEqual(@as(u32, 0), builder.instructions.items[0].LoadVar.dest);

    try expect(builder.instructions.items[1] == .LoadConstInt);
    try expectEqual(@as(i64, 3), builder.instructions.items[1].LoadConstInt.value);
    try expectEqual(@as(u32, 1), builder.instructions.items[1].LoadConstInt.dest);

    try expect(builder.instructions.items[2] == .LoadIndex);
    try expectEqual(@as(u32, 2), builder.instructions.items[2].LoadIndex.dest);
}

test "IR lowerExpression falls back for unsupported expression kind" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const inner = try allocator.create(Expr);
    inner.* = .{ .IntLiteral = .{ .value = 9, .resolvedType = null } };

    const unsupported = try allocator.create(Expr);
    unsupported.* = .{ .ExpressionStmt = inner };

    const result = try lowerExpression(&builder, unsupported);
    try assertTemp(result, 0);
    try expectEqual(@as(usize, 0), builder.instructions.items.len);
}

test "IR lowerLValue stores into identifier" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const target = try allocator.create(Expr);
    target.* = .{ .Identifier = .{ .name = "x", .resolvedType = null } };

    try lowerLValue(&builder, target, .{ .temp = 99 });
    try expectEqual(@as(usize, 1), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .StoreVar);
    try expect(std.mem.eql(u8, builder.instructions.items[0].StoreVar.name, "x"));

    switch (builder.instructions.items[0].StoreVar.value) {
        .temp => |t| try expectEqual(@as(u32, 99), t),
        else => try expect(false),
    }
}

test "IR lowerLValue stores into member access" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const obj = try allocator.create(Expr);
    obj.* = .{ .Identifier = .{ .name = "person", .resolvedType = null } };

    const target = try allocator.create(Expr);
    target.* = .{ .MemberAccess = .{
        .object = obj,
        .memberName = "age",
        .resolvedType = null,
    } };

    try lowerLValue(&builder, target, .{ .temp = 7 });
    try expectEqual(@as(usize, 2), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .LoadVar);
    try expect(builder.instructions.items[1] == .StoreField);
    try expect(std.mem.eql(u8, builder.instructions.items[1].StoreField.fieldName, "age"));

    switch (builder.instructions.items[1].StoreField.value) {
        .temp => |t| try expectEqual(@as(u32, 7), t),
        else => try expect(false),
    }
}

test "IR lowerLValue stores into array index" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const arr = try allocator.create(Expr);
    arr.* = .{ .Identifier = .{ .name = "values", .resolvedType = null } };

    const index = try allocator.create(Expr);
    index.* = .{ .IntLiteral = .{ .value = 1, .resolvedType = null } };

    const target = try allocator.create(Expr);
    target.* = .{ .ArrayAccess = .{
        .array = arr,
        .index = index,
        .resolvedType = null,
    } };

    try lowerLValue(&builder, target, .{ .temp = 5 });
    try expectEqual(@as(usize, 3), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .LoadVar);
    try expect(builder.instructions.items[1] == .LoadConstInt);
    try expect(builder.instructions.items[2] == .StoreIndex);

    switch (builder.instructions.items[2].StoreIndex.value) {
        .temp => |t| try expectEqual(@as(u32, 5), t),
        else => try expect(false),
    }
}

test "IR lowerVarAssignment lowers RHS before storing into array index" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const arr = try allocator.create(Expr);
    arr.* = .{ .Identifier = .{ .name = "arr", .resolvedType = null } };

    const index = try allocator.create(Expr);
    index.* = .{ .IntLiteral = .{ .value = 2, .resolvedType = null } };

    const target = try allocator.create(Expr);
    target.* = .{ .ArrayAccess = .{
        .array = arr,
        .index = index,
        .resolvedType = null,
    } };

    const value = try allocator.create(Expr);
    value.* = .{ .IntLiteral = .{ .value = 99, .resolvedType = null } };

    const var_assign = try allocator.create(@import("../parser/lib/parseVarDec.zig").VarAssign);
    var_assign.* = .{ .target = target, .value = value };

    try lowerVarAssignment(&builder, var_assign);
    try expectEqual(@as(usize, 4), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .LoadConstInt);
    try expect(builder.instructions.items[1] == .LoadVar);
    try expect(builder.instructions.items[2] == .LoadConstInt);
    try expect(builder.instructions.items[3] == .StoreIndex);
}

test "IR generateIR lowers var declarations and assignments at top level" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\var int x = 10;
        \\x = x + 1;
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var builder = InstructionBuilder.init(allocator);
    try generateIR(&builder, statements);

    try expectEqual(@as(usize, 6), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .LoadConstInt);
    try expect(builder.instructions.items[1] == .StoreVar);
    try expect(builder.instructions.items[2] == .LoadVar);
    try expect(builder.instructions.items[3] == .LoadConstInt);
    try expect(builder.instructions.items[4] == .BinaryOp);
    try expect(builder.instructions.items[5] == .StoreVar);
}

test "IR generateIR lowers if else statements with labels and jumps" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\var bool cond = true;
        \\if (cond) {
        \\    var int x = 1;
        \\} else {
        \\    var int x = 2;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var builder = InstructionBuilder.init(allocator);
    try generateIR(&builder, statements);

    try expectEqual(@as(usize, 11), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .LoadConstBool);
    try expect(builder.instructions.items[1] == .StoreVar);
    try expect(builder.instructions.items[2] == .LoadVar);
    try expect(builder.instructions.items[3] == .JumpIfFalse);
    try expect(builder.instructions.items[4] == .LoadConstInt);
    try expect(builder.instructions.items[5] == .StoreVar);
    try expect(builder.instructions.items[6] == .Jump);
    try expect(builder.instructions.items[7] == .Label);
    try expect(builder.instructions.items[8] == .LoadConstInt);
    try expect(builder.instructions.items[9] == .StoreVar);
    try expect(builder.instructions.items[10] == .Label);

    try expectEqual(@as(u32, 0), builder.instructions.items[3].JumpIfFalse.label);
    try expectEqual(@as(u32, 1), builder.instructions.items[6].Jump.label);
    try expectEqual(@as(u32, 0), builder.instructions.items[7].Label.id);
    try expectEqual(@as(u32, 1), builder.instructions.items[10].Label.id);
}
