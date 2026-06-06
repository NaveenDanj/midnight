const std = @import("std");
const Instruction = @import("../ir/ir.zig").Instruction;

pub const AsmBuilder = struct {
    allocator: std.mem.Allocator,
    instructions: std.ArrayList(Instruction),
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) AsmBuilder {
        return .{ .allocator = allocator, .instructions = std.ArrayList(Instruction).init(allocator), .buffer = std.ArrayList(u8).initCapacity(allocator, 0) };
    }

    pub fn deinit(self: *AsmBuilder) void {
        self.instructions.deinit();
        self.buffer.deinit();
    }

    pub fn loadInstruction(self: *AsmBuilder, instructions: []Instruction) !void {
        for (instructions) |instruction| {
            try self.instructions.append(self.allocator, instruction);
        }
    }

    pub fn emit(self: *AsmBuilder, fmt: []const u8, args: anytype) !void {
        try self.buffer.writer().print(fmt, args);
        try self.buffer.append(self.allocator, "\n");
    }

    pub fn toOwnedSlice(self: *AsmBuilder) []const u8 {
        return self.buffer.toOwnedSlice();
    }
};
