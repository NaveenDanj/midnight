const std = @import("std");
const Instruction = @import("./ir.zig").Instruction;
const Value = @import("./ir.zig").Value;

pub const InstructionBuilder = struct {
    allocator: std.mem.Allocator,
    instructions: std.ArrayList(Instruction),
    tempCounter: u32,

    pub fn init(allocator: std.mem.Allocator) InstructionBuilder {
        return InstructionBuilder{
            .allocator = allocator,
            .instructions = std.ArrayList(Instruction).empty,
            .tempCounter = 0,
        };
    }

    pub fn emit(self: *InstructionBuilder, instruction: Instruction) !void {
        try self.instructions.append(self.allocator, instruction);
    }

    pub fn newTemp(self: *InstructionBuilder) u32 {
        const tempId = self.tempCounter;
        self.tempCounter += 1;
        return tempId;
    }

    pub fn free(self: *InstructionBuilder) void {
        self.instructions.deinit(self.allocator);
    }

    pub fn printIR(self: *InstructionBuilder) void {
        for (self.instructions.items) |instr| {
            std.debug.print("IR Instruction: {any}\n", .{instr});
        }
    }
};
