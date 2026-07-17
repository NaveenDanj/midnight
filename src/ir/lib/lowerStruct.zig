const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const StructDecl = @import("../../ast/stmt.zig").StructStmt;

pub fn lowerStructDecl(builder: *InstructionBuilder, structDecl: *StructDecl) anyerror!void {}
