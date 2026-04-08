const std = @import("std");
const InstructionBuilder = @import("./builder.zig").InstructionBuilder;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;

pub fn generateIR(_: *InstructionBuilder, statements: []*Statement) !void {
    for (statements) |stmt| {
        std.debug.print("Generating IR for statement: {any}\n", .{stmt});
    }
}
