const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const StructDecl = @import("../../ast/stmt.zig").StructStmt;

pub fn lowerStructDecl(_: *InstructionBuilder, structDecl: *StructDecl) anyerror!void {
    for (structDecl.fields) |field| {
        std.debug.print("  Field: {s}\n", .{field.StructProperty.name});
    }
}
