const std = @import("std");
const Instruction = @import("./ir.zig").Instruction;
const Value = @import("./ir.zig").Value;

pub const InstructionBuilder = struct {
    allocator: std.mem.Allocator,
    instructions: std.ArrayList(Instruction),
    tempCounter: u32,
    labelCounter: u32,
    var_map: std.StringHashMap(Value),

    pub fn init(allocator: std.mem.Allocator) InstructionBuilder {
        return InstructionBuilder{
            .allocator = allocator,
            .instructions = std.ArrayList(Instruction).empty,
            .tempCounter = 0,
            .labelCounter = 0,
            .var_map = std.StringHashMap(Value).init(allocator),
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

    pub fn newLabel(self: *InstructionBuilder) u32 {
        const labelId = self.labelCounter;
        self.labelCounter += 1;
        return labelId;
    }

    pub fn declareVariable(self: *InstructionBuilder, name: []const u8, value: Value) !void {
        try self.var_map.put(name, value);
    }

    pub fn getVariable(self: *InstructionBuilder, name: []const u8) ?Value {
        return self.var_map.get(name);
    }

    pub fn free(self: *InstructionBuilder) void {
        self.instructions.deinit(self.allocator);
        self.var_map.deinit();
    }

    pub fn printIR(self: *InstructionBuilder) void {
        for (self.instructions.items) |instr| {
            std.debug.print("IR Instruction: {any}\n", .{instr});
        }
    }
};
