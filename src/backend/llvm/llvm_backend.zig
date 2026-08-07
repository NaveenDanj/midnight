const std = @import("std");

const c = @import("../../llvm.zig").c;
const BinaryOp = @import("../../ir/ir.zig").BinaryOp;
const Instruction = @import("../../ir/ir.zig").Instruction;
const Type = @import("../../semantic/types.zig").Type;
const Value = @import("../../ir/ir.zig").Value;
const FunctionRef = @import("./lib//function_emitter.zig").FunctionRef;
const StructStmt = @import("../../ast/stmt.zig").StructStmt;

const realPredicate = @import("./lib/predicates.zig").realPredicate;
const intPredicate = @import("./lib/predicates.zig").intPredicate;
const lowerBinaryOp = @import("./lib/bin_op_emitter.zig").lowerBinaryOp;
const lowerPrintCall = @import("./lib/print_emitter.zig").lowerPrintCall;
const lowerFunction = @import("./lib/function_emitter.zig").lowerFunction;
const lowerFunctionCall = @import("./lib/function_emitter.zig").lowerFunctionCall;
const lowerUnaryOp = @import("./lib/unary_op.zig").lowerUnaryOp;
const lowerAllocArray = @import("./lib/arr_emitter.zig").lowerAllocArray;
const lowerLoadIndex = @import("./lib/arr_emitter.zig").lowerLoadIndex;
const lowerStoreIndex = @import("./lib/arr_emitter.zig").lowerStoreIndex;
const lowerStoreField = @import("./lib/struct_emitter.zig").lowerStoreField;
const lowerAllocStruct = @import("./lib/struct_emitter.zig").lowerAllocStruct;
const lowerLoadField = @import("./lib/struct_emitter.zig").lowerLoadField;

pub const LLVMBackendError = error{
    ArgumentCountMismatch,
    FunctionNotFound,
    MissingResolvedType,
    OutOfMemory,
    UnsupportedBinaryOperation,
    UnsupportedUnaryOperation,
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

// Like emitLLVMObject, but names the synthetic top-level entry function
// `entry_name` (instead of "main") and gives it internal linkage. Used when
// compiling a single module (translation unit) of a multi-object build to its
// own .o file: only the program's actual entry object should export "main",
// so every other object needs a non-colliding, non-exported stand-in to hold
// any top-level instructions (struct/function registration has no such
// instructions today, but this keeps module objects link-safe regardless).
pub fn emitLLVMObjectNamed(allocator: std.mem.Allocator, instructions: []const Instruction, entry_name: []const u8) ![]const u8 {
    var backend = try LLVMBackend.initEntry(allocator, entry_name, true);
    defer backend.deinit();
    return try backend.generateObject(instructions);
}

pub const LLVMBackend = struct {
    allocator: std.mem.Allocator,
    context: c.LLVMContextRef,
    module: c.LLVMModuleRef,
    builder: c.LLVMBuilderRef,
    main_function: c.LLVMValueRef,
    current_function: c.LLVMValueRef,
    printf_function: c.LLVMValueRef,
    printf_type: c.LLVMTypeRef,
    puts_function: c.LLVMValueRef,
    puts_type: c.LLVMTypeRef,
    malloc_function: c.LLVMValueRef,
    malloc_type: c.LLVMTypeRef,
    abort_function: c.LLVMValueRef,
    abort_type: c.LLVMTypeRef,
    temp_values: std.AutoHashMap(u32, c.LLVMValueRef),
    temp_types: std.AutoHashMap(u32, Type),
    variables: std.StringHashMap(VariableRef),
    global_variables: std.StringHashMap(VariableRef),
    functions: std.StringHashMap(FunctionRef),
    struct_defs: std.StringHashMap(*StructStmt),
    struct_types: std.StringHashMap(c.LLVMTypeRef),
    label_blocks: std.AutoHashMap(u32, c.LLVMBasicBlockRef),
    next_name_id: u32,
    current_block_terminated: bool,

    const VariableRef = struct {
        pointer: c.LLVMValueRef,
        typ: Type,
    };

    pub fn init(allocator: std.mem.Allocator) !LLVMBackend {
        return initEntry(allocator, "main", false);
    }

    pub fn initEntry(allocator: std.mem.Allocator, entry_name: []const u8, internal_linkage: bool) !LLVMBackend {
        const context = c.LLVMContextCreate();
        const module = c.LLVMModuleCreateWithNameInContext("midnight", context);
        const builder = c.LLVMCreateBuilderInContext(context);

        const i32_type = c.LLVMInt32TypeInContext(context);
        const main_type = c.LLVMFunctionType(i32_type, null, 0, 0);
        const entry_name_z = try allocator.dupeZ(u8, entry_name);
        defer allocator.free(entry_name_z);
        const main_function = c.LLVMAddFunction(module, entry_name_z, main_type);
        if (internal_linkage) {
            c.LLVMSetLinkage(main_function, c.LLVMInternalLinkage);
        }
        const entry = c.LLVMAppendBasicBlockInContext(context, main_function, "entry");
        c.LLVMPositionBuilderAtEnd(builder, entry);

        var backend = LLVMBackend{
            .allocator = allocator,
            .context = context,
            .module = module,
            .builder = builder,
            .main_function = main_function,
            .current_function = main_function,
            .printf_function = undefined,
            .printf_type = undefined,
            .puts_function = undefined,
            .puts_type = undefined,
            .malloc_function = undefined,
            .malloc_type = undefined,
            .abort_function = undefined,
            .abort_type = undefined,
            .temp_values = std.AutoHashMap(u32, c.LLVMValueRef).init(allocator),
            .temp_types = std.AutoHashMap(u32, Type).init(allocator),
            .variables = std.StringHashMap(VariableRef).init(allocator),
            .global_variables = std.StringHashMap(VariableRef).init(allocator),
            .functions = std.StringHashMap(FunctionRef).init(allocator),
            .struct_defs = std.StringHashMap(*StructStmt).init(allocator),
            .struct_types = std.StringHashMap(c.LLVMTypeRef).init(allocator),
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
        self.global_variables.deinit();
        var function_it = self.functions.iterator();
        while (function_it.next()) |entry| {
            self.allocator.free(entry.value_ptr.param_types);
        }
        self.functions.deinit();
        self.struct_defs.deinit();
        self.struct_types.deinit();
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
            .AllocArray => |inst| try lowerAllocArray(self, inst),
            .LoadVar => |inst| {
                const typ = inst.resolvedType orelse self.lookupVariableType(inst.name) orelse return LLVMBackendError.MissingResolvedType;
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
            .UnaryOp => |inst| try lowerUnaryOp(self, inst),
            .JumpIfFalse => |inst| {
                const condition = try self.valueRef(inst.condition, Type{ .kind = .BOOL });
                const false_block = try self.labelBlock(inst.label);
                const continue_block = c.LLVMAppendBasicBlockInContext(self.context, self.current_function, try self.nextName("if.cont"));
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
            .PrintCall => |inst| try lowerPrintCall(self, inst.value, inst.resolvedType orelse return LLVMBackendError.MissingResolvedType),
            .FunctionIR => |inst| try lowerFunction(self, inst),
            .StructDeclIR => |inst| try self.registerStructDefinition(inst.definition),
            .FunctionCall => |inst| try lowerFunctionCall(self, inst),
            .LoadIndex => |inst| try lowerLoadIndex(self, inst),
            .StoreIndex => |inst| try lowerStoreIndex(self, inst),
            .StoreField => |inst| try lowerStoreField(self, inst),
            .AllocStruct => |inst| try lowerAllocStruct(self, inst),
            .LoadField => |inst| try lowerLoadField(self, inst),
            .ParamBind,
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

        var malloc_params = [_]c.LLVMTypeRef{c.LLVMInt64TypeInContext(self.context)};
        self.malloc_type = c.LLVMFunctionType(ptr_type, &malloc_params, malloc_params.len, 0);
        self.malloc_function = c.LLVMAddFunction(self.module, "malloc", self.malloc_type);

        self.abort_type = c.LLVMFunctionType(c.LLVMVoidTypeInContext(self.context), null, 0, 0);
        self.abort_function = c.LLVMAddFunction(self.module, "abort", self.abort_type);
    }

    fn ensureVariable(self: *LLVMBackend, name: []const u8, typ: Type) !VariableRef {
        if (self.variables.get(name)) |variable| {
            return variable;
        }

        if (self.global_variables.get(name)) |variable| {
            return variable;
        }

        if (self.current_function == self.main_function) {
            return try self.ensureGlobalVariable(name, typ);
        }

        const pointer = c.LLVMBuildAlloca(self.builder, try self.llvmType(typ), try self.toZ(name));
        const variable = VariableRef{ .pointer = pointer, .typ = typ };
        try self.variables.put(name, variable);
        return variable;
    }

    fn ensureGlobalVariable(self: *LLVMBackend, name: []const u8, typ: Type) !VariableRef {
        if (self.global_variables.get(name)) |variable| {
            return variable;
        }

        const llvm_type = try self.llvmType(typ);
        const pointer = c.LLVMAddGlobal(self.module, llvm_type, try self.toZ(name));
        c.LLVMSetLinkage(pointer, c.LLVMInternalLinkage);
        c.LLVMSetInitializer(pointer, c.LLVMConstNull(llvm_type));

        const variable = VariableRef{ .pointer = pointer, .typ = typ };
        try self.global_variables.put(name, variable);
        return variable;
    }

    fn labelBlock(self: *LLVMBackend, id: u32) !c.LLVMBasicBlockRef {
        if (self.label_blocks.get(id)) |block| {
            return block;
        }

        const block = c.LLVMAppendBasicBlockInContext(self.context, self.current_function, try self.nextName("label"));
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
            .variable => |name| self.lookupVariableType(name),
            .paramIndex => null,
        };
    }

    fn lookupVariableType(self: *LLVMBackend, name: []const u8) ?Type {
        if (self.variables.get(name)) |variable| {
            return variable.typ;
        }

        if (self.global_variables.get(name)) |variable| {
            return variable.typ;
        }

        return null;
    }

    pub fn inferBinaryType(self: *LLVMBackend, left: Value, right: Value) ?Type {
        const left_type = self.valueType(left);
        const right_type = self.valueType(right);

        if (left_type) |typ| {
            if (typ.kind == .FLOAT) return typ;
        }
        if (right_type) |typ| {
            if (typ.kind == .FLOAT) return typ;
        }

        return left_type orelse right_type;
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
                const variable = self.variables.get(name) orelse self.global_variables.get(name) orelse return LLVMBackendError.UnsupportedValue;
                const loaded = c.LLVMBuildLoad2(self.builder, try self.llvmType(variable.typ), variable.pointer, try self.nextName("loadtmp"));
                break :blk try self.coerceValue(loaded, variable.typ, expected_type);
            },
            .paramIndex => return LLVMBackendError.UnsupportedValue,
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

    pub fn llvmType(self: *LLVMBackend, typ: Type) LLVMBackendError!c.LLVMTypeRef {
        if (typ.isArray) {
            return c.LLVMPointerTypeInContext(self.context, 0);
        }

        return switch (typ.kind) {
            .INT => c.LLVMInt32TypeInContext(self.context),
            .BOOL => c.LLVMInt1TypeInContext(self.context),
            .FLOAT => c.LLVMDoubleTypeInContext(self.context),
            .VOID => c.LLVMVoidTypeInContext(self.context),
            .STRING => c.LLVMPointerTypeInContext(self.context, 0),
            .STRUCT => c.LLVMPointerType(try self.structBodyType(typ.struct_name orelse return LLVMBackendError.UnsupportedType), 0),
            .FUNCTION, .EMPTY => LLVMBackendError.UnsupportedType,
        };
    }

    pub fn registerStructDefinition(self: *LLVMBackend, definition: *StructStmt) !void {
        try self.struct_defs.put(definition.name, definition);
        _ = try self.structBodyType(definition.name);
    }

    pub fn structDefinition(self: *LLVMBackend, name: []const u8) !*StructStmt {
        return self.struct_defs.get(name) orelse return LLVMBackendError.UnsupportedType;
    }

    pub fn structBodyType(self: *LLVMBackend, name: []const u8) !c.LLVMTypeRef {
        if (self.struct_types.get(name)) |typ| {
            return typ;
        }

        const definition = try self.structDefinition(name);
        const struct_handle = c.LLVMStructCreateNamed(self.context, try self.toZ(name));
        try self.struct_types.put(name, struct_handle);

        var property_count: usize = 0;
        for (definition.fields) |field| {
            switch (field) {
                .StructProperty => property_count += 1,
                .StructMethod => {},
            }
        }

        var field_types = try self.allocator.alloc(c.LLVMTypeRef, property_count);
        defer self.allocator.free(field_types);

        var index: usize = 0;
        for (definition.fields) |field| {
            switch (field) {
                .StructProperty => |property| {
                    const resolved = @import("../../semantic/type_resolver.zig").resolveTypeRefUnchecked(property.fieldType);
                    field_types[index] = try self.llvmType(resolved);
                    index += 1;
                },
                .StructMethod => {},
            }
        }

        c.LLVMStructSetBody(struct_handle, if (field_types.len == 0) null else field_types.ptr, @intCast(field_types.len), 0);
        return struct_handle;
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
        std.debug.print("LLVM IR:\n{s}\n", .{llvm_text});
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

    pub fn getStringConcatFunction(self: *LLVMBackend) !FunctionRef {
        const function_name = "midnight_string_concat";

        if (self.functions.get(function_name)) |function_ref| {
            return function_ref;
        }

        const i8_ptr_type = c.LLVMPointerTypeInContext(self.context, 0);

        var llvm_param_types = [_]c.LLVMTypeRef{
            i8_ptr_type,
            i8_ptr_type,
        };

        var param_types = [_]Type{
            .{ .kind = .STRING },
            .{ .kind = .STRING },
        };

        const function_type = c.LLVMFunctionType(
            i8_ptr_type,
            &llvm_param_types,
            llvm_param_types.len,
            0,
        );

        const function = c.LLVMAddFunction(
            self.module,
            function_name,
            function_type,
        );

        const function_ref = FunctionRef{
            .value = function,
            .func_type = function_type,
            .return_type = Type{ .kind = .STRING },
            .param_types = try self.allocator.dupe(Type, param_types[0..]),
        };

        try self.functions.put(function_name, function_ref);

        return function_ref;
    }

    pub fn toZ(self: *LLVMBackend, value: []const u8) ![:0]const u8 {
        return try self.allocator.dupeZ(u8, value);
    }
};
