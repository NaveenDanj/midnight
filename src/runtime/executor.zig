const std = @import("std");
const Instruction = @import("../ir/ir.zig").Instruction;
const BinaryOp = @import("../ir/ir.zig").BinaryOp;
const IRValue = @import("../ir/ir.zig").Value;

pub const RuntimeValue = union(enum) {
    int: i64,
    float: f64,
    boolean: bool,
    string: []const u8,
    array: std.ArrayList(RuntimeValue),
    null: void,
};

pub const Executor = struct {
    allocator: std.mem.Allocator,
    registers: std.AutoHashMap(u32, RuntimeValue),
    variables: std.StringHashMap(RuntimeValue), // named variables
    labels: std.AutoHashMap(u32, usize), // label -> instruction index
    return_value: ?RuntimeValue = null,
    pc: usize = 0, // program counter

    pub fn init(allocator: std.mem.Allocator) Executor {
        return .{
            .allocator = allocator,
            .registers = std.AutoHashMap(u32, RuntimeValue).init(allocator),
            .variables = std.StringHashMap(RuntimeValue).init(allocator),
            .labels = std.AutoHashMap(u32, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Executor) void {
        self.registers.deinit();
        self.variables.deinit();
        self.labels.deinit();
    }

    /// Build a map of labels to instruction indices for control flow
    pub fn buildLabelMap(self: *Executor, instructions: []const Instruction) !void {
        for (instructions, 0..) |instr, i| {
            if (instr == .Label) {
                try self.labels.put(instr.Label.id, i);
            }
        }
    }

    /// Get runtime value from an IR value reference
    pub fn resolveValue(self: *Executor, val: IRValue) RuntimeValue {
        switch (val) {
            .constantInt => |v| return RuntimeValue{ .int = v },
            .constantFloat => |v| return RuntimeValue{ .float = v },
            .constantBool => |v| return RuntimeValue{ .boolean = v },
            .string => |s| return RuntimeValue{ .string = s },
            .temp => |t| {
                return self.registers.get(t) orelse RuntimeValue{ .null = {} };
            },
            .variable => |name| {
                return self.variables.get(name) orelse RuntimeValue{ .null = {} };
            },
            .paramIndex => |idx| {
                // For now, treat as temp register with index
                return self.registers.get(@intCast(idx)) orelse RuntimeValue{ .null = {} };
            },
            .arrayIndex => |idx| {
                return RuntimeValue{ .int = @intCast(idx) };
            },
        }
    }

    pub fn executeInstruction(self: *Executor, instr: Instruction) !bool {
        switch (instr) {
            .LoadConstInt => |inst| {
                try self.registers.put(inst.dest, .{ .int = inst.value });
            },
            .LoadConstFloat => |inst| {
                try self.registers.put(inst.dest, .{ .float = inst.value });
            },
            .LoadConstBool => |inst| {
                try self.registers.put(inst.dest, .{ .boolean = inst.value });
            },
            .LoadConstString => |inst| {
                try self.registers.put(inst.dest, .{ .string = inst.value });
            },
            .LoadVar => |inst| {
                const val = self.variables.get(inst.name) orelse RuntimeValue{ .null = {} };
                try self.registers.put(inst.dest, val);
            },
            .StoreVar => |inst| {
                const val = self.resolveValue(inst.value);
                try self.variables.put(inst.name, val);
            },
            .BinaryOp => |inst| {
                const left = self.resolveValue(inst.left);
                const right = self.resolveValue(inst.right);
                const result = try self.executeBinaryOp(inst.op, left, right);
                try self.registers.put(inst.dest, result);
            },
            .Label => {
                // Labels are just markers, nothing to do
            },
            .Jump => |inst| {
                if (self.labels.get(inst.label)) |target| {
                    self.pc = target;
                    return false;
                }
            },
            .JumpIfFalse => |inst| {
                const cond = self.resolveValue(inst.condition);
                const is_false = switch (cond) {
                    .boolean => |b| !b,
                    .int => |i| i == 0,
                    .null => true,
                    else => false,
                };
                if (is_false) {
                    if (self.labels.get(inst.label)) |target| {
                        self.pc = target;
                        return false;
                    }
                }
            },
            .Return => |inst| {
                self.return_value = self.resolveValue(inst.value);
                return true;
            },
            .FunctionCall => |inst| {
                if (std.mem.eql(u8, inst.name, "print")) {
                    if (inst.args.len > 0) {
                        const value = self.resolveValue(inst.args[0]);
                        self.printValue(value);
                    } else {
                        std.debug.print("\n", .{});
                    }

                    try self.registers.put(inst.dest, .{ .null = {} });
                    return false;
                }

                std.debug.print("Function call: {s}\n", .{inst.name});
                try self.registers.put(inst.dest, .{ .null = {} });
            },
            else => {
                // Other instructions not yet implemented
            },
        }
        return false;
    }

    pub fn executeBinaryOp(self: *Executor, op: BinaryOp, left: RuntimeValue, right: RuntimeValue) !RuntimeValue {
        switch (op) {
            .Add => {
                switch (left) {
                    .int => |l| {
                        if (right == .int) return RuntimeValue{ .int = l + right.int };
                    },
                    .float => |l| {
                        if (right == .float) return RuntimeValue{ .float = l + right.float };
                    },
                    .string => |l| {
                        if (right == .string) {
                            var result = try self.allocator.alloc(u8, l.len + right.string.len);
                            std.mem.copyForwards(u8, result[0..l.len], l);
                            std.mem.copyForwards(u8, result[l.len..], right.string);
                            return RuntimeValue{ .string = result };
                        }
                    },
                    else => {},
                }
            },
            .Subtract => {
                if (left == .int and right == .int) {
                    return RuntimeValue{ .int = left.int - right.int };
                } else if (left == .float and right == .float) {
                    return RuntimeValue{ .float = left.float - right.float };
                }
            },
            .Multiply => {
                if (left == .int and right == .int) {
                    return RuntimeValue{ .int = left.int * right.int };
                } else if (left == .float and right == .float) {
                    return RuntimeValue{ .float = left.float * right.float };
                }
            },
            .Divide => {
                if (left == .int and right == .int and right.int != 0) {
                    return RuntimeValue{ .int = @divTrunc(left.int, right.int) };
                } else if (left == .float and right == .float and right.float != 0) {
                    return RuntimeValue{ .float = left.float / right.float };
                }
            },
            .Equal => {
                const eq = switch (left) {
                    .int => |l| l == right.int,
                    .float => |l| l == right.float,
                    .boolean => |l| l == right.boolean,
                    .string => |l| std.mem.eql(u8, l, right.string),
                    else => false,
                };
                return RuntimeValue{ .boolean = eq };
            },
            .NotEqual => {
                const neq = switch (left) {
                    .int => |l| l != right.int,
                    .float => |l| l != right.float,
                    .boolean => |l| l != right.boolean,
                    .string => |l| !std.mem.eql(u8, l, right.string),
                    else => true,
                };
                return RuntimeValue{ .boolean = neq };
            },
            .LessThan => {
                const lt = switch (left) {
                    .int => |l| l < right.int,
                    .float => |l| l < right.float,
                    else => false,
                };
                return RuntimeValue{ .boolean = lt };
            },
            .LessThanOrEqual => {
                const le = switch (left) {
                    .int => |l| l <= right.int,
                    .float => |l| l <= right.float,
                    else => false,
                };
                return RuntimeValue{ .boolean = le };
            },
            .GreaterThan => {
                const gt = switch (left) {
                    .int => |l| l > right.int,
                    .float => |l| l > right.float,
                    else => false,
                };
                return RuntimeValue{ .boolean = gt };
            },
            .GreaterThanOrEqual => {
                const ge = switch (left) {
                    .int => |l| l >= right.int,
                    .float => |l| l >= right.float,
                    else => false,
                };
                return RuntimeValue{ .boolean = ge };
            },
            .And => {
                if (left == .boolean and right == .boolean) {
                    return RuntimeValue{ .boolean = left.boolean and right.boolean };
                }
            },
            .Or => {
                if (left == .boolean and right == .boolean) {
                    return RuntimeValue{ .boolean = left.boolean or right.boolean };
                }
            },
            .Modulo => {
                if (left == .int and right == .int and right.int != 0) {
                    return RuntimeValue{ .int = @mod(left.int, right.int) };
                }
            },
        }
        return RuntimeValue{ .null = {} };
    }

    pub fn run(self: *Executor, instructions: []const Instruction) !void {
        try self.buildLabelMap(instructions);

        while (self.pc < instructions.len) {
            const pc = self.pc;
            self.pc += 1;

            std.debug.print("[exec] pc={d} instr={any}\n", .{ pc, instructions[pc] });

            const should_break = try self.executeInstruction(instructions[pc]);
            if (should_break) break;
        }
    }

    pub fn printResult(self: *Executor) void {
        if (self.return_value) |val| {
            self.printValue(val);
        }
    }

    pub fn printValue(self: *Executor, val: RuntimeValue) void {
        _ = self;
        switch (val) {
            .int => |i| std.debug.print("Result: {d}\n", .{i}),
            .float => |f| std.debug.print("Result: {d}\n", .{f}),
            .boolean => |b| std.debug.print("Result: {}\n", .{b}),
            .string => |s| std.debug.print("Result: {s}\n", .{s}),
            .null => std.debug.print("Result: null\n", .{}),
            else => std.debug.print("Result: <complex value>\n", .{}),
        }
    }
};
