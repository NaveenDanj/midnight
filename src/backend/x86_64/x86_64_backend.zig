const std = @import("std");
const AsmBuilder = @import("../asm_builder.zig").AsmBuilder;
const Instruction = @import("../../ir/ir.zig").Instruction;

pub const X86_64Backend = struct {
    allocator: std.mem.Allocator,
    temp_slots: std.AutoHashMap(u32, i32),
    variable_slots: std.StringHashMap(i32),
    float_constants: std.AutoHashMap(u64, []const u8),
    next_offset: i32,
    next_float_id: u32,

    pub fn init(allocator: std.mem.Allocator) X86_64Backend {
        return .{ .allocator = allocator, .temp_slots = std.AutoHashMap(u32, i32).init(allocator), .variable_slots = std.StringHashMap(i32).init(allocator), .float_constants = std.AutoHashMap(u64, []const u8).init(allocator), .next_offset = 8, .next_float_id = 0 };
    }

    pub fn deinit(self: *X86_64Backend) void {
        self.temp_slots.deinit();
        self.variable_slots.deinit();
        self.float_constants.deinit();
    }

    fn getTempSlot(self: *X86_64Backend, temp: u32) !i32 {
        if (self.temp_slots.get(temp)) |offset| {
            return offset;
        }

        const offset = self.next_offset;
        self.next_offset += 8;

        try self.temp_slots.put(temp, offset);
        return offset;
    }

    fn getVariableSlot(self: *X86_64Backend, name: []const u8) !i32 {
        if (self.variable_slots.get(name)) |offset| {
            return offset;
        }

        const slot = self.next_offset;
        self.next_offset += 8;

        try self.variable_slots.put(name, slot);
        return slot;
    }

    fn getFloatConstantLabel(self: *X86_64Backend, value: f64) ![]const u8 {
        const bits: u64 = @bitCast(value);
        if (self.float_constants.get(bits)) |label| {
            return label;
        }

        const label = try std.fmt.allocPrint(self.allocator, "LCF{d}", .{self.next_float_id});
        self.next_float_id += 1;

        try self.float_constants.put(bits, label);
        return label;
    }

    fn loadTempInto(self: *X86_64Backend, asmBuilder: *AsmBuilder, temp: u32, reg: []const u8) !void {
        const slot = try self.getTempSlot(temp);
        try asmBuilder.emit("    mov {s}, qword [rbp-{d}]", .{ reg, slot });
    }

    pub fn generate(self: *X86_64Backend, instructions: []Instruction) ![]const u8 {
        var asmBuilder = try AsmBuilder.init(self.allocator);
        try asmBuilder.LoadInstructions(instructions);
        defer asmBuilder.deinit();

        try asmBuilder.emit("default rel", .{});
        try asmBuilder.emit("global main", .{});
        try asmBuilder.emit("section .text", .{});
        try asmBuilder.emit("", .{});
        try asmBuilder.emit("main:", .{});

        try asmBuilder.emit("    push rbp", .{});
        try asmBuilder.emit("    mov rbp, rsp", .{});
        try asmBuilder.emit("    sub rsp, 4096", .{});

        for (asmBuilder.instructions.items) |instruction| {
            try self.lowerInstruction(&asmBuilder, &instruction);
        }

        try asmBuilder.emit("    mov rax, 0", .{});
        try asmBuilder.emit("    leave", .{});
        try asmBuilder.emit("    ret", .{});

        try asmBuilder.emit("", .{});
        try asmBuilder.emit("section .data", .{});

        var it = self.float_constants.iterator();
        while (it.next()) |entry| {
            const bits = entry.key_ptr.*;
            const label = entry.value_ptr.*;

            try asmBuilder.emit("{s}:", .{label});
            try asmBuilder.emit("   dq {d}", .{bits});
        }

        return try asmBuilder.toOwnedSlice();
    }

    pub fn lowerInstruction(self: *X86_64Backend, asmBuilder: *AsmBuilder, instruction: *const Instruction) !void {
        switch (instruction.*) {
            .LoadConstInt => |inst| {
                const slot = try self.getTempSlot(inst.dest);
                try asmBuilder.emit("    mov qword [rbp-{d}], {d}", .{ slot, inst.value });
            },

            .LoadConstBool => |inst| {
                const slot = try self.getTempSlot(inst.dest);
                const boolValue: i64 = if (inst.value) @as(i64, 1) else @as(i64, 0);
                try asmBuilder.emit("    mov qword [rbp-{d}], {d}", .{ slot, boolValue });
            },

            .LoadConstFloat => |inst| {
                const slot = try self.getTempSlot(inst.dest);
                const bits: u64 = @bitCast(inst.value);
                const label = try self.getFloatConstantLabel(inst.value);
                try asmBuilder.emit("    movsd xmm0, qword [{s}]", .{label});
                try asmBuilder.emit("    movsd qword [rbp-{d}], xmm0", .{slot});
                _ = bits;
            },

            .StoreVar => |inst| {
                const temp_slot = try self.getTempSlot(inst.value.temp);
                const variable_slot = try self.getVariableSlot(inst.name);
                try asmBuilder.emit("    mov rax, qword [rbp-{d}]", .{temp_slot});
                try asmBuilder.emit("    mov qword [rbp-{d}], rax", .{variable_slot});
            },

            .LoadVar => |inst| {
                const variable_slot = try self.getVariableSlot(inst.name);
                const temp_slot = try self.getTempSlot(inst.dest);
                try asmBuilder.emit("    mov rax, qword [rbp-{d}]", .{variable_slot});
                try asmBuilder.emit("    mov qword [rbp-{d}], rax", .{temp_slot});
            },

            .BinaryOp => |inst| {
                const left_slot = try self.getTempSlot(inst.left.temp);
                const right_slot = try self.getTempSlot(inst.right.temp);
                const dest_slot = try self.getTempSlot(inst.dest);

                try asmBuilder.emit("    mov rax, qword [rbp-{d}]", .{left_slot});
                try asmBuilder.emit("    mov rbx, qword [rbp-{d}]", .{right_slot});

                switch (inst.op) {
                    .Add => {
                        try asmBuilder.emit("    add rax, rbx", .{});
                    },
                    .Subtract => {
                        try asmBuilder.emit("    sub rax, rbx", .{});
                    },
                    .Multiply => {
                        try asmBuilder.emit("    imul rax, rbx", .{});
                    },
                    .Divide => {
                        try asmBuilder.emit("    cqo", .{});
                        try asmBuilder.emit("    idiv rbx", .{});
                    },
                    else => {
                        @panic("Unsupported binary operation");
                    },
                }

                try asmBuilder.emit("    mov qword [rbp-{d}], rax", .{dest_slot});
            },

            else => {
                @panic("Unsupported instruction");
            },
        }
    }

    pub fn toOwnedSlice(self: *AsmBuilder) ![]const u8 {
        return try self.buffer.toOwnedSlice(self.allocator);
    }

    pub fn writeAsm(
        self: *X86_64Backend,
        asm_string: []const u8,
        path: []const u8,
    ) !void {
        _ = self;

        const dirname = std.fs.path.dirname(path);

        if (dirname) |dir| {
            try std.fs.cwd().makePath(dir);
        }

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(asm_string);
    }

    fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) !void {
        var child = std.process.Child.init(argv, allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        const term = try child.spawnAndWait();
        if (term != .Exited or term.Exited != 0) {
            return error.CommandFailed;
        }
    }

    pub fn build(self: *X86_64Backend, path: []const u8, asm_string: []const u8) !void {
        self.writeAsm(asm_string, path) catch |err| {
            std.debug.print("Error writing assembly file: {any}\n", .{err});
            return err;
        };

        try runCommand(self.allocator, &.{
            "nasm",
            "-f",
            "win64",
            "./build/output.asm",
            "-o",
            "./build/out.o",
        });

        try runCommand(self.allocator, &.{
            "gcc",
            "./build/out.o",
            "-o",
            "./build/out",
        });

        // Cleanup intermediate files
        try std.fs.cwd().deleteFile("./build/out.o");
        // try std.fs.cwd().deleteFile("./build/output.asm");
    }
};
