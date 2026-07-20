const std = @import("std");

const c = @import("../../llvm.zig").c;
const BinaryOp = @import("../../ir/ir.zig").BinaryOp;
const Instruction = @import("../../ir/ir.zig").Instruction;
const Type = @import("../../semantic/types.zig").Type;
const Value = @import("../../ir/ir.zig").Value;
const realPredicate = @import("./lib/predicates.zig").realPredicate;
const intPredicate = @import("./lib/predicates.zig").intPredicate;
const lowerBinaryOp = @import("./lib/bin_op_emitter.zig").lowerBinaryOp;
const lowerPrintCall = @import("./lib/print_emitter.zig").lowerPrintCall;

pub const LLVMBackendError = error{
    MissingResolvedType,
    UnsupportedBinaryOperation,
    UnsupportedInstruction,
    UnsupportedType,
    UnsupportedValue,
    LLVMModuleVerificationFailed,
    LLVMTargetInitializationFailed,
    LLVMTargetLookupFailed,
    LLVMTargetMachineCreationFailed,
    LLVMTargetEmissionFailed,
};

pub fn emitLLVMIR(allocator: std.mem.Allocator, instructions: []const Instruction) ![]const u8 {
    var backend = try LLVMBackend.init(allocator);
    defer backend.deinit();
    return try backend.generate(instructions);
}

pub fn emitLLVMAssembly(allocator: std.mem.Allocator, instructions: []const Instruction) ![]const u8 {
    var backend = try LLVMBackend.init(allocator);
    defer backend.deinit();
    return try backend.generateAssembly(instructions);
}

pub fn emitLLVMObject(allocator: std.mem.Allocator, instructions: []const Instruction) ![]const u8 {
    var backend = try LLVMBackend.init(allocator);
    defer backend.deinit();
    return try backend.generateObject(instructions);
}

pub const LLVMBackend = struct {
    allocator: std.mem.Allocator,
    context: c.LLVMContextRef,
    module: c.LLVMModuleRef,
    builder: c.LLVMBuilderRef,
    main_function: c.LLVMValueRef,
    printf_function: c.LLVMValueRef,
    printf_type: c.LLVMTypeRef,
    puts_function: c.LLVMValueRef,
    puts_type: c.LLVMTypeRef,
    temp_values: std.AutoHashMap(u32, c.LLVMValueRef),
    temp_types: std.AutoHashMap(u32, Type),
    variables: std.StringHashMap(VariableRef),
    label_blocks: std.AutoHashMap(u32, c.LLVMBasicBlockRef),
    next_name_id: u32,
    current_block_terminated: bool,

    const VariableRef = struct {
        pointer: c.LLVMValueRef,
        typ: Type,
    };

    pub fn init(allocator: std.mem.Allocator) !LLVMBackend {
        const context = c.LLVMContextCreate();
        const module = c.LLVMModuleCreateWithNameInContext("midnight", context);
        const builder = c.LLVMCreateBuilderInContext(context);

        const i32_type = c.LLVMInt32TypeInContext(context);
        const main_type = c.LLVMFunctionType(i32_type, null, 0, 0);
        const main_function = c.LLVMAddFunction(module, "main", main_type);
        const entry = c.LLVMAppendBasicBlockInContext(context, main_function, "entry");
        c.LLVMPositionBuilderAtEnd(builder, entry);

        var backend = LLVMBackend{
            .allocator = allocator,
            .context = context,
            .module = module,
            .builder = builder,
            .main_function = main_function,
            .printf_function = undefined,
            .printf_type = undefined,
            .puts_function = undefined,
            .puts_type = undefined,
            .temp_values = std.AutoHashMap(u32, c.LLVMValueRef).init(allocator),
            .temp_types = std.AutoHashMap(u32, Type).init(allocator),
            .variables = std.StringHashMap(VariableRef).init(allocator),
            .label_blocks = std.AutoHashMap(u32, c.LLVMBasicBlockRef).init(allocator),
            .next_name_id = 0,
            .current_block_terminated = false,
        };
        try backend.declareRuntimeFunctions();
        return backend;
    }

    pub fn deinit(self: *LLVMBackend) void {
        self.temp_values.deinit();
        self.temp_types.deinit();
        self.variables.deinit();
        self.label_blocks.deinit();
        c.LLVMDisposeBuilder(self.builder);
        c.LLVMDisposeModule(self.module);
        c.LLVMContextDispose(self.context);
    }

    pub fn generate(self: *LLVMBackend, instructions: []const Instruction) ![]const u8 {
        try self.buildModule(instructions);
        return try self.printModule();
    }

    pub fn generateAssembly(self: *LLVMBackend, instructions: []const Instruction) ![]const u8 {
        try self.buildModule(instructions);
        return try self.emitTargetBuffer(c.LLVMAssemblyFile);
    }

    pub fn generateObject(self: *LLVMBackend, instructions: []const Instruction) ![]const u8 {
        try self.buildModule(instructions);
        return try self.emitTargetBuffer(c.LLVMObjectFile);
    }

    fn buildModule(self: *LLVMBackend, instructions: []const Instruction) !void {
        for (instructions) |instruction| {
            try self.lowerInstruction(&instruction);
        }

        if (!self.current_block_terminated) {
            _ = c.LLVMBuildRet(self.builder, c.LLVMConstInt(c.LLVMInt32TypeInContext(self.context), 0, 0));
            self.current_block_terminated = true;
        }

        try self.verifyModule();
    }

    pub fn lowerInstruction(self: *LLVMBackend, instruction: *const Instruction) !void {
        switch (instruction.*) {
            .LoadConstInt => |inst| {
                const typ = inst.resolvedType orelse Type{ .kind = .INT };
                const value = c.LLVMConstInt(try self.llvmType(typ), @as(u64, @bitCast(inst.value)), 1);
                try self.putTemp(inst.dest, value, typ);
            },
            .LoadConstFloat => |inst| {
                const typ = inst.resolvedType orelse Type{ .kind = .FLOAT };
                const value = c.LLVMConstReal(try self.llvmType(typ), inst.value);
                try self.putTemp(inst.dest, value, typ);
            },
            .LoadConstBool => |inst| {
                const typ = inst.resolvedType orelse Type{ .kind = .BOOL };
                const value = c.LLVMConstInt(try self.llvmType(typ), if (inst.value) 1 else 0, 0);
                try self.putTemp(inst.dest, value, typ);
            },
            .LoadConstString => |inst| {
                const typ = inst.resolvedType orelse Type{ .kind = .STRING };
                const name = try self.nextName("strtmp");
                const value = c.LLVMBuildGlobalStringPtr(self.builder, try self.toZ(inst.value), name);
                try self.putTemp(inst.dest, value, typ);
            },
            .LoadVar => |inst| {
                const typ = inst.resolvedType orelse return LLVMBackendError.MissingResolvedType;
                const variable = try self.ensureVariable(inst.name, typ);
                const value = c.LLVMBuildLoad2(self.builder, try self.llvmType(typ), variable.pointer, try self.nextName("loadtmp"));
                try self.putTemp(inst.dest, value, typ);
            },
            .StoreVar => |inst| {
                const typ = inst.resolvedType orelse return LLVMBackendError.MissingResolvedType;
                const variable = try self.ensureVariable(inst.name, typ);
                _ = c.LLVMBuildStore(self.builder, try self.valueRef(inst.value, typ), variable.pointer);
            },
            .BinaryOp => |inst| try lowerBinaryOp(self, inst),
            .JumpIfFalse => |inst| {
                const condition = try self.valueRef(inst.condition, Type{ .kind = .BOOL });
                const false_block = try self.labelBlock(inst.label);
                const continue_block = c.LLVMAppendBasicBlockInContext(self.context, self.main_function, try self.nextName("if.cont"));
                _ = c.LLVMBuildCondBr(self.builder, condition, continue_block, false_block);
                self.current_block_terminated = true;
                c.LLVMPositionBuilderAtEnd(self.builder, continue_block);
                self.current_block_terminated = false;
            },
            .Jump => |inst| {
                _ = c.LLVMBuildBr(self.builder, try self.labelBlock(inst.label));
                self.current_block_terminated = true;
            },
            .Label => |inst| {
                const block = try self.labelBlock(inst.id);
                if (!self.current_block_terminated) {
                    _ = c.LLVMBuildBr(self.builder, block);
                }
                c.LLVMPositionBuilderAtEnd(self.builder, block);
                self.current_block_terminated = false;
            },
            .Return => |inst| {
                const typ = self.valueType(inst.value) orelse Type{ .kind = .INT };
                _ = c.LLVMBuildRet(self.builder, try self.valueRef(inst.value, typ));
                self.current_block_terminated = true;
            },
            .PrintCall => |inst| try lowerPrintCall(inst.value, inst.resolvedType orelse return LLVMBackendError.MissingResolvedType),
            .FunctionIR,
            .FunctionCall,
            .ParamBind,
            .AllocStruct,
            .StoreField,
            .LoadField,
            .LoadIndex,
            .StoreIndex,
            .JumpWhileTrue,
            => return LLVMBackendError.UnsupportedInstruction,
        }
    }

    fn declareRuntimeFunctions(self: *LLVMBackend) !void {
        const i32_type = c.LLVMInt32TypeInContext(self.context);
        const ptr_type = c.LLVMPointerTypeInContext(self.context, 0);

        var printf_params = [_]c.LLVMTypeRef{ptr_type};
        self.printf_type = c.LLVMFunctionType(i32_type, &printf_params, printf_params.len, 1);
        self.printf_function = c.LLVMAddFunction(self.module, "printf", self.printf_type);

        var puts_params = [_]c.LLVMTypeRef{ptr_type};
        self.puts_type = c.LLVMFunctionType(i32_type, &puts_params, puts_params.len, 0);
        self.puts_function = c.LLVMAddFunction(self.module, "puts", self.puts_type);
    }

    fn ensureVariable(self: *LLVMBackend, name: []const u8, typ: Type) !VariableRef {
        if (self.variables.get(name)) |variable| {
            return variable;
        }

        const pointer = c.LLVMBuildAlloca(self.builder, try self.llvmType(typ), try self.toZ(name));
        const variable = VariableRef{ .pointer = pointer, .typ = typ };
        try self.variables.put(name, variable);
        return variable;
    }

    fn labelBlock(self: *LLVMBackend, id: u32) !c.LLVMBasicBlockRef {
        if (self.label_blocks.get(id)) |block| {
            return block;
        }

        const block = c.LLVMAppendBasicBlockInContext(self.context, self.main_function, try self.nextName("label"));
        try self.label_blocks.put(id, block);
        return block;
    }

    pub fn putTemp(self: *LLVMBackend, dest: u32, value: c.LLVMValueRef, typ: Type) !void {
        try self.temp_values.put(dest, value);
        try self.temp_types.put(dest, typ);
    }

    pub fn valueType(self: *LLVMBackend, value: Value) ?Type {
        return switch (value) {
            .temp => |temp| self.temp_types.get(temp),
            .constantInt => Type{ .kind = .INT },
            .constantFloat => Type{ .kind = .FLOAT },
            .constantBool => Type{ .kind = .BOOL },
            .string => Type{ .kind = .STRING },
            .variable => |name| if (self.variables.get(name)) |variable| variable.typ else null,
            .arrayIndex => Type{ .kind = .INT },
            .paramIndex => null,
        };
    }

    pub fn valueRef(self: *LLVMBackend, value: Value, expected_type: Type) !c.LLVMValueRef {
        return switch (value) {
            .temp => |temp| blk: {
                const temp_value = self.temp_values.get(temp) orelse return LLVMBackendError.UnsupportedValue;
                const temp_type = self.temp_types.get(temp) orelse return LLVMBackendError.UnsupportedValue;
                break :blk try self.coerceValue(temp_value, temp_type, expected_type);
            },
            .constantInt => |int_value| switch (expected_type.kind) {
                .FLOAT => c.LLVMConstReal(try self.llvmType(expected_type), @floatFromInt(int_value)),
                else => c.LLVMConstInt(try self.llvmType(expected_type), @as(u64, @bitCast(int_value)), 1),
            },
            .constantFloat => |float_value| switch (expected_type.kind) {
                .FLOAT => c.LLVMConstReal(try self.llvmType(expected_type), float_value),
                else => c.LLVMConstInt(try self.llvmType(expected_type), @intFromFloat(float_value), 1),
            },
            .constantBool => |bool_value| c.LLVMConstInt(try self.llvmType(expected_type), if (bool_value) 1 else 0, 0),
            .string => |string_value| c.LLVMBuildGlobalStringPtr(self.builder, try self.toZ(string_value), try self.nextName("str")),
            .variable => |name| blk: {
                const variable = self.variables.get(name) orelse return LLVMBackendError.UnsupportedValue;
                const loaded = c.LLVMBuildLoad2(self.builder, try self.llvmType(variable.typ), variable.pointer, try self.nextName("loadtmp"));
                break :blk try self.coerceValue(loaded, variable.typ, expected_type);
            },
            .arrayIndex, .paramIndex => return LLVMBackendError.UnsupportedValue,
        };
    }

    fn coerceValue(self: *LLVMBackend, value: c.LLVMValueRef, actual_type: Type, expected_type: Type) !c.LLVMValueRef {
        if (actual_type.kind == expected_type.kind and actual_type.isArray == expected_type.isArray) {
            return value;
        }

        if (expected_type.kind == .FLOAT and actual_type.kind == .INT) {
            return c.LLVMBuildSIToFP(self.builder, value, try self.llvmType(expected_type), try self.nextName("sitofp"));
        }

        if (expected_type.kind == .FLOAT and actual_type.kind == .BOOL) {
            return c.LLVMBuildUIToFP(self.builder, value, try self.llvmType(expected_type), try self.nextName("uitofp"));
        }

        if (expected_type.kind == .INT and actual_type.kind == .BOOL) {
            return c.LLVMBuildZExt(self.builder, value, try self.llvmType(expected_type), try self.nextName("zext"));
        }

        return value;
    }

    fn llvmType(self: *LLVMBackend, typ: Type) LLVMBackendError!c.LLVMTypeRef {
        if (typ.isArray) {
            return c.LLVMPointerTypeInContext(self.context, 0);
        }

        return switch (typ.kind) {
            .INT => c.LLVMInt64TypeInContext(self.context),
            .BOOL => c.LLVMInt1TypeInContext(self.context),
            .FLOAT => c.LLVMDoubleTypeInContext(self.context),
            .VOID => c.LLVMVoidTypeInContext(self.context),
            .STRING, .STRUCT => c.LLVMPointerTypeInContext(self.context, 0),
            .FUNCTION, .EMPTY => LLVMBackendError.UnsupportedType,
        };
    }

    fn verifyModule(self: *LLVMBackend) !void {
        var error_message: [*c]u8 = null;
        const failed = c.LLVMVerifyModule(self.module, c.LLVMReturnStatusAction, &error_message);
        if (failed != 0) {
            if (error_message != null) {
                std.debug.print("LLVM Module Verification Error: {s}\n", .{error_message});
                c.LLVMDisposeMessage(error_message);
            }
            return LLVMBackendError.LLVMModuleVerificationFailed;
        }
    }

    fn printModule(self: *LLVMBackend) ![]const u8 {
        const llvm_text = c.LLVMPrintModuleToString(self.module);
        defer c.LLVMDisposeMessage(llvm_text);
        return try self.allocator.dupe(u8, std.mem.span(llvm_text));
    }

    fn emitTargetBuffer(self: *LLVMBackend, file_type: c.LLVMCodeGenFileType) ![]const u8 {
        c.LLVMInitializeAllTargetInfos();
        c.LLVMInitializeAllTargets();
        c.LLVMInitializeAllTargetMCs();
        c.LLVMInitializeAllAsmPrinters();

        const triple = c.LLVMGetDefaultTargetTriple();
        defer c.LLVMDisposeMessage(triple);

        var target: c.LLVMTargetRef = null;
        var target_error: [*c]u8 = null;
        if (c.LLVMGetTargetFromTriple(triple, &target, &target_error) != 0) {
            if (target_error != null) {
                c.LLVMDisposeMessage(target_error);
            }
            return LLVMBackendError.LLVMTargetLookupFailed;
        }

        const cpu = c.LLVMGetHostCPUName();
        defer c.LLVMDisposeMessage(cpu);
        const features = c.LLVMGetHostCPUFeatures();
        defer c.LLVMDisposeMessage(features);

        const target_machine = c.LLVMCreateTargetMachine(
            target,
            triple,
            cpu,
            features,
            c.LLVMCodeGenLevelDefault,
            c.LLVMRelocPIC,
            c.LLVMCodeModelDefault,
        ) orelse return LLVMBackendError.LLVMTargetMachineCreationFailed;
        defer c.LLVMDisposeTargetMachine(target_machine);

        c.LLVMSetTarget(self.module, triple);

        const target_data = c.LLVMCreateTargetDataLayout(target_machine);
        defer c.LLVMDisposeTargetData(target_data);
        const data_layout = c.LLVMCopyStringRepOfTargetData(target_data);
        defer c.LLVMDisposeMessage(data_layout);
        c.LLVMSetDataLayout(self.module, data_layout);

        var emit_error: [*c]u8 = null;
        var memory_buffer: c.LLVMMemoryBufferRef = null;
        if (c.LLVMTargetMachineEmitToMemoryBuffer(target_machine, self.module, file_type, &emit_error, &memory_buffer) != 0) {
            if (emit_error != null) {
                c.LLVMDisposeMessage(emit_error);
            }
            return LLVMBackendError.LLVMTargetEmissionFailed;
        }
        defer c.LLVMDisposeMemoryBuffer(memory_buffer);

        const start = c.LLVMGetBufferStart(memory_buffer);
        const size = c.LLVMGetBufferSize(memory_buffer);
        return try self.allocator.dupe(u8, start[0..size]);
    }

    pub fn nextName(self: *LLVMBackend, prefix: []const u8) ![:0]const u8 {
        const raw_name = try std.fmt.allocPrint(self.allocator, "{s}.{d}", .{ prefix, self.next_name_id });
        defer self.allocator.free(raw_name);
        self.next_name_id += 1;
        return try self.allocator.dupeZ(u8, raw_name);
    }

    pub fn toZ(self: *LLVMBackend, value: []const u8) ![:0]const u8 {
        return try self.allocator.dupeZ(u8, value);
    }
};
