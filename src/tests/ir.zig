const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const Lexer = @import("../lexer/lexer.zig").Lexer;
const Parser = @import("../parser/parser.zig").Parser;
const Expr = @import("../parser/lib/parseExpr.zig").Expr;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;
const VarDecl = @import("../parser/lib/parseVarDec.zig").VarDecl;
const FunctionCallStmt = @import("../parser/lib/parseFunctionDecl.zig").FunctionCallStmt;
const Instruction = @import("../ir/ir.zig").Instruction;
const BinaryOp = @import("../ir/ir.zig").BinaryOp;
const Value = @import("../ir/ir.zig").Value;
const InstructionBuilder = @import("../ir/builder.zig").InstructionBuilder;
const lowerExpression = @import("../ir/lib/lowerExpr.zig").lowerExpression;
const lowerLValue = @import("../ir/lib/lowerExpr.zig").lowerLValue;
const lowerVarAssignment = @import("../ir/lib/lowerVar.zig").lowerVarAssignment;
const lowerVarDeclaration = @import("../ir/lib/lowerVar.zig").lowerVarDeclaration;
const generateIR = @import("../ir/lower.zig").generateIR;
const lowerStatement = @import("../ir/lower.zig").lowerStatement;

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

test "IR lowerExpression lowers float bool and string literals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const float_expr = try allocator.create(Expr);
    float_expr.* = .{ .FloatLiteral = .{ .value = 3.5, .resolvedType = null } };

    const bool_expr = try allocator.create(Expr);
    bool_expr.* = .{ .BoolLiteral = .{ .value = false, .resolvedType = null } };

    const string_expr = try allocator.create(Expr);
    string_expr.* = .{ .StringLiteral = .{ .value = "hello", .resolvedType = null } };

    try assertTemp(try lowerExpression(&builder, float_expr), 0);
    try assertTemp(try lowerExpression(&builder, bool_expr), 1);
    try assertTemp(try lowerExpression(&builder, string_expr), 2);

    try expectEqual(@as(usize, 3), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .LoadConstFloat);
    try expectEqual(@as(f64, 3.5), builder.instructions.items[0].LoadConstFloat.value);
    try expect(builder.instructions.items[1] == .LoadConstBool);
    try expectEqual(false, builder.instructions.items[1].LoadConstBool.value);
    try expect(builder.instructions.items[2] == .LoadConstString);
    try expect(std.mem.eql(u8, builder.instructions.items[2].LoadConstString.value, "hello"));
}

test "IR lowerExpression lowers array literal including empty array" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder_non_empty = InstructionBuilder.init(allocator);

    const e1 = try allocator.create(Expr);
    e1.* = .{ .IntLiteral = .{ .value = 7, .resolvedType = null } };

    const e2 = try allocator.create(Expr);
    e2.* = .{ .IntLiteral = .{ .value = 9, .resolvedType = null } };

    const elements = try allocator.alloc(*Expr, 2);
    elements[0] = e1;
    elements[1] = e2;

    const arr_expr = try allocator.create(Expr);
    arr_expr.* = .{ .ArrayLiteral = .{ .elements = elements, .resolvedType = null } };

    const arr_result = try lowerExpression(&builder_non_empty, arr_expr);
    try assertTemp(arr_result, 0);
    try expectEqual(@as(usize, 4), builder_non_empty.instructions.items.len);
    try expect(builder_non_empty.instructions.items[0] == .LoadConstInt);
    try expect(builder_non_empty.instructions.items[1] == .StoreIndex);
    try expect(builder_non_empty.instructions.items[2] == .LoadConstInt);
    try expect(builder_non_empty.instructions.items[3] == .StoreIndex);

    switch (builder_non_empty.instructions.items[1].StoreIndex.index) {
        .arrayIndex => |idx| try expectEqual(@as(u32, 0), idx),
        else => try expect(false),
    }

    switch (builder_non_empty.instructions.items[3].StoreIndex.index) {
        .arrayIndex => |idx| try expectEqual(@as(u32, 1), idx),
        else => try expect(false),
    }

    var builder_empty = InstructionBuilder.init(allocator);
    const empty_elements = try allocator.alloc(*Expr, 0);
    const empty_arr_expr = try allocator.create(Expr);
    empty_arr_expr.* = .{ .ArrayLiteral = .{ .elements = empty_elements, .resolvedType = null } };

    const empty_result = try lowerExpression(&builder_empty, empty_arr_expr);
    try assertTemp(empty_result, 0);
    try expectEqual(@as(usize, 0), builder_empty.instructions.items.len);
}

test "IR lowerExpression maps every supported binary operator" {
    const cases = [_]struct {
        operator: []const u8,
        expected: BinaryOp,
    }{
        .{ .operator = "+", .expected = .Add },
        .{ .operator = "-", .expected = .Subtract },
        .{ .operator = "*", .expected = .Multiply },
        .{ .operator = "/", .expected = .Divide },
        .{ .operator = "%", .expected = .Modulo },
        .{ .operator = "==", .expected = .Equal },
        .{ .operator = "!=", .expected = .NotEqual },
        .{ .operator = "<", .expected = .LessThan },
        .{ .operator = "<=", .expected = .LessThanOrEqual },
        .{ .operator = ">", .expected = .GreaterThan },
        .{ .operator = ">=", .expected = .GreaterThanOrEqual },
        .{ .operator = "&&", .expected = .And },
        .{ .operator = "||", .expected = .Or },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    for (cases) |case| {
        var builder = InstructionBuilder.init(allocator);

        const left = try allocator.create(Expr);
        left.* = .{ .IntLiteral = .{ .value = 10, .resolvedType = null } };

        const right = try allocator.create(Expr);
        right.* = .{ .IntLiteral = .{ .value = 3, .resolvedType = null } };

        const binary = try allocator.create(Expr);
        binary.* = .{ .Binary = .{
            .left = left,
            .operator = case.operator,
            .right = right,
            .resolvedType = null,
        } };

        _ = try lowerExpression(&builder, binary);
        try expectEqual(@as(usize, 3), builder.instructions.items.len);
        try expect(builder.instructions.items[2] == .BinaryOp);
        try expectEqual(case.expected, builder.instructions.items[2].BinaryOp.op);
    }
}

test "IR lowerExpression lowers function call with argument order and empty args" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder_with_args = InstructionBuilder.init(allocator);

    const arg1 = try allocator.create(Expr);
    arg1.* = .{ .IntLiteral = .{ .value = 1, .resolvedType = null } };

    const arg2 = try allocator.create(Expr);
    arg2.* = .{ .IntLiteral = .{ .value = 2, .resolvedType = null } };

    const args = try allocator.alloc(*Expr, 2);
    args[0] = arg1;
    args[1] = arg2;

    const call_with_args = try allocator.create(Expr);
    call_with_args.* = .{ .FunctionCall = .{
        .callee = null,
        .name = "sum",
        .args = args,
        .resolvedType = null,
    } };

    const result_with_args = try lowerExpression(&builder_with_args, call_with_args);
    try assertTemp(result_with_args, 2);
    try expectEqual(@as(usize, 3), builder_with_args.instructions.items.len);
    try expect(builder_with_args.instructions.items[0] == .LoadConstInt);
    try expect(builder_with_args.instructions.items[1] == .LoadConstInt);
    try expect(builder_with_args.instructions.items[2] == .FunctionCall);
    try expect(std.mem.eql(u8, builder_with_args.instructions.items[2].FunctionCall.name, "sum"));
    try expectEqual(@as(usize, 2), builder_with_args.instructions.items[2].FunctionCall.args.len);

    switch (builder_with_args.instructions.items[2].FunctionCall.args[0]) {
        .temp => |t| try expectEqual(@as(u32, 0), t),
        else => try expect(false),
    }

    switch (builder_with_args.instructions.items[2].FunctionCall.args[1]) {
        .temp => |t| try expectEqual(@as(u32, 1), t),
        else => try expect(false),
    }

    var builder_no_args = InstructionBuilder.init(allocator);
    const empty_args = try allocator.alloc(*Expr, 0);
    const call_no_args = try allocator.create(Expr);
    call_no_args.* = .{ .FunctionCall = .{
        .callee = null,
        .name = "noop",
        .args = empty_args,
        .resolvedType = null,
    } };

    const result_no_args = try lowerExpression(&builder_no_args, call_no_args);
    try assertTemp(result_no_args, 0);
    try expectEqual(@as(usize, 1), builder_no_args.instructions.items.len);
    try expect(builder_no_args.instructions.items[0] == .FunctionCall);
    try expectEqual(@as(usize, 0), builder_no_args.instructions.items[0].FunctionCall.args.len);
}

test "IR lowerVarDeclaration stores and updates var map" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const init_expr = try allocator.create(Expr);
    init_expr.* = .{ .IntLiteral = .{ .value = 55, .resolvedType = null } };

    const var_decl = try allocator.create(VarDecl);
    var_decl.* = .{
        .immutable = false,
        .name = "y",
        .varType = .{ .kind = .INT },
        .initializer = init_expr,
    };

    try lowerVarDeclaration(&builder, var_decl);
    try expectEqual(@as(usize, 2), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .LoadConstInt);
    try expect(builder.instructions.items[1] == .StoreVar);

    const saved = builder.getVariable("y") orelse return error.TestExpectedEqual;
    switch (saved) {
        .temp => |t| try expectEqual(@as(u32, 0), t),
        else => try expect(false),
    }
}

test "IR generateIR lowers if without else and while loop" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\var bool cond = true;
        \\if (cond) {
        \\    var int x = 1;
        \\}
        \\while (cond) {
        \\    var int y = 2;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var builder = InstructionBuilder.init(allocator);
    try generateIR(&builder, statements);

    try expectEqual(@as(usize, 16), builder.instructions.items.len);
    try expect(builder.instructions.items[3] == .JumpIfFalse);
    try expect(builder.instructions.items[6] == .Jump);
    try expect(builder.instructions.items[7] == .Label);
    try expect(builder.instructions.items[8] == .Label);

    try expect(builder.instructions.items[10] == .JumpWhileTrue);
    try expect(builder.instructions.items[11] == .Label);
    try expect(builder.instructions.items[14] == .Jump);
    try expect(builder.instructions.items[15] == .Label);

    try expectEqual(@as(u32, 0), builder.instructions.items[3].JumpIfFalse.label);
    try expectEqual(@as(u32, 1), builder.instructions.items[6].Jump.label);
    try expectEqual(@as(u32, 0), builder.instructions.items[7].Label.id);
    try expectEqual(@as(u32, 1), builder.instructions.items[8].Label.id);
    try expectEqual(@as(u32, 2), builder.instructions.items[10].JumpWhileTrue.label);
    try expectEqual(@as(u32, 2), builder.instructions.items[11].Label.id);
    try expectEqual(@as(u32, 2), builder.instructions.items[14].Jump.label);
    try expectEqual(@as(u32, 3), builder.instructions.items[15].Label.id);
}

test "IR generateIR lowers function declaration with params and body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\func sum(int a, int b) int {
        \\    var int c = a + b;
        \\    print(c);
        \\    return c;
        \\}
    ;

    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(std.testing.allocator);
    defer token_list.deinit(std.testing.allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var builder = InstructionBuilder.init(allocator);
    try generateIR(&builder, statements);

    try expectEqual(@as(usize, 1), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .FunctionIR);
    try expect(std.mem.eql(u8, builder.instructions.items[0].FunctionIR.name, "sum"));
    try expectEqual(@as(usize, 2), builder.instructions.items[0].FunctionIR.params.len);
    try expectEqual(@as(usize, 8), builder.instructions.items[0].FunctionIR.body.len);

    const body = builder.instructions.items[0].FunctionIR.body;
    try expect(body[0] == .ParamBind);
    try expectEqual(@as(u32, 0), body[0].ParamBind.index);
    try expect(body[1] == .ParamBind);
    try expectEqual(@as(u32, 1), body[1].ParamBind.index);
    try expect(body[2] == .LoadVar);
    try expect(body[3] == .LoadVar);
    try expect(body[4] == .BinaryOp);
    try expect(body[5] == .StoreVar);
    try expect(body[6] == .LoadVar);
    try expect(body[7] == .FunctionCall);
}

test "IR lowerStatement handles expression statement and direct function call statement branches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var builder = InstructionBuilder.init(allocator);

    const int_expr = try allocator.create(Expr);
    int_expr.* = .{ .IntLiteral = .{ .value = 12, .resolvedType = null } };

    const expr_stmt = try allocator.create(Statement);
    expr_stmt.* = .{ .ExpressionStmt = int_expr };

    try lowerStatement(&builder, expr_stmt);
    try expectEqual(@as(usize, 0), builder.instructions.items.len);

    const call_args = try allocator.alloc(*Expr, 1);
    const call_arg = try allocator.create(Expr);
    call_arg.* = .{ .IntLiteral = .{ .value = 5, .resolvedType = null } };
    call_args[0] = call_arg;

    const call_stmt = try allocator.create(FunctionCallStmt);
    call_stmt.* = .{ .callee = null, .name = "print", .args = call_args, .resolvedType = null };

    const function_stmt = try allocator.create(Statement);
    function_stmt.* = .{ .FunctionCallStatement = call_stmt };

    try lowerStatement(&builder, function_stmt);
    try expectEqual(@as(usize, 2), builder.instructions.items.len);
    try expect(builder.instructions.items[0] == .LoadConstInt);
    try expect(builder.instructions.items[1] == .FunctionCall);
    try expect(std.mem.eql(u8, builder.instructions.items[1].FunctionCall.name, "print"));
    try expectEqual(@as(usize, 1), builder.instructions.items[1].FunctionCall.args.len);
}
