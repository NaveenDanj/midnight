const std = @import("std");
const Instruction = @import("../ir/ir.zig").Instruction;

pub const AsmBuilder = struct {
    allocator: std.mem.Allocator,
    instructions: std.ArrayList(Instruction),
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) !AsmBuilder {
        return .{ .allocator = allocator, .instructions = try std.ArrayList(Instruction).initCapacity(allocator, 0), .buffer = try std.ArrayList(u8).initCapacity(allocator, 0) };
    }

    pub fn deinit(self: *AsmBuilder) void {
        self.instructions.deinit(self.allocator);
        self.buffer.deinit(self.allocator);
    }

    pub fn LoadInstructions(self: *AsmBuilder, instructions: []Instruction) !void {
        for (instructions) |instruction| {
            try self.instructions.append(self.allocator, instruction);
        }
    }

    pub fn emit(self: *AsmBuilder, comptime fmt: []const u8, args: anytype) !void {
        const line = try std.fmt.allocPrint(self.allocator, fmt, args);
        defer self.allocator.free(line);

        try self.buffer.appendSlice(self.allocator, line);
        try self.buffer.append(self.allocator, '\n');
    }

    pub fn toOwnedSlice(self: *AsmBuilder) ![]const u8 {
        const result = try self.buffer.toOwnedSlice(self.allocator);
        return result;
    }
};
