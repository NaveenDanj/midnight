const std = @import("std");
const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const StructDecl = @import("../../parser/lib/parseStruct.zig").StructDecl;

pub fn lowerStructDecl(builder: *InstructionBuilder, structDecl: *StructDecl) anyerror!void {}
