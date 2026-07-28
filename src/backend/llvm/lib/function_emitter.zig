const Type = @import("../../../semantic/types.zig").Type;
const typeResolver = @import("../../../semantic/type_resolver.zig");
const c = @import("../../../llvm.zig").c;
const Instruction = @import("../../../ir/ir.zig").Instruction;
const LLVMBackend = @import("../llvm_backend.zig").LLVMBackend;
const LLVMBackendError = @import("../llvm_backend.zig").LLVMBackendError;

pub const FunctionRef = struct {
    value: c.LLVMValueRef,
    func_type: c.LLVMTypeRef,
    return_type: Type,
    param_types: []Type,
    isExtern: bool = false,
};

pub fn lowerFunction(self: *LLVMBackend, inst: @FieldType(Instruction, "FunctionIR")) anyerror!void {
    var param_types = try self.allocator.alloc(c.LLVMTypeRef, inst.params.len);
    defer self.allocator.free(param_types);

    for (inst.params, 0..) |param, index| {
        const param_type = typeResolver.resolveTypeRefUnchecked(param.dataType);
        param_types[index] = try self.llvmType(param_type);
    }

    var semantic_param_types = try self.allocator.alloc(Type, inst.params.len);
    errdefer self.allocator.free(semantic_param_types);

    for (inst.params, 0..) |param, index| {
        semantic_param_types[index] = typeResolver.resolveTypeRefUnchecked(param.dataType);
    }

    const return_type = inst.returnType;
    const func_type = c.LLVMFunctionType(
        try self.llvmType(return_type),
        if (param_types.len == 0) null else param_types.ptr,
        @intCast(param_types.len),
        0,
    );
    const function = c.LLVMAddFunction(self.module, try self.toZ(inst.name), func_type);

    try self.functions.put(inst.name, .{ .value = function, .func_type = func_type, .return_type = return_type, .param_types = semantic_param_types, .isExtern = inst.isExtern });

    if (inst.isExtern) {
        return;
    }

    const old_block = c.LLVMGetInsertBlock(self.builder);
    const old_function = self.current_function;
    const old_terminated = self.current_block_terminated;
    const old_variables = self.variables;
    const old_temp_values = self.temp_values;
    const old_temp_types = self.temp_types;
    const old_label_blocks = self.label_blocks;

    self.variables = @TypeOf(self.variables).init(self.allocator);
    self.temp_values = @TypeOf(self.temp_values).init(self.allocator);
    self.temp_types = @TypeOf(self.temp_types).init(self.allocator);
    self.label_blocks = @TypeOf(self.label_blocks).init(self.allocator);

    self.current_function = function;
    self.current_block_terminated = false;

    var restored = false;
    defer if (!restored) {
        self.variables.deinit();
        self.temp_values.deinit();
        self.temp_types.deinit();
        self.label_blocks.deinit();
        self.variables = old_variables;
        self.temp_values = old_temp_values;
        self.temp_types = old_temp_types;
        self.label_blocks = old_label_blocks;
        self.current_function = old_function;
        self.current_block_terminated = old_terminated;
        c.LLVMPositionBuilderAtEnd(self.builder, old_block);
    };

    const entry = c.LLVMAppendBasicBlockInContext(self.context, function, "entry");
    c.LLVMPositionBuilderAtEnd(self.builder, entry);

    for (inst.params, 0..) |param, index| {
        const param_type = typeResolver.resolveTypeRefUnchecked(param.dataType);
        const llvm_param = c.LLVMGetParam(function, @intCast(index));
        const slot = c.LLVMBuildAlloca(self.builder, try self.llvmType(param_type), try self.toZ(param.name));
        _ = c.LLVMBuildStore(self.builder, llvm_param, slot);
        try self.variables.put(param.name, .{ .pointer = slot, .typ = param_type });
    }

    for (inst.body) |body_inst| {
        switch (body_inst) {
            .ParamBind => {},
            else => try self.lowerInstruction(&body_inst),
        }
    }

    if (!self.current_block_terminated) {
        try emitDefaultReturn(self, return_type);
    }

    self.variables.deinit();
    self.temp_values.deinit();
    self.temp_types.deinit();
    self.label_blocks.deinit();
    self.variables = old_variables;
    self.temp_values = old_temp_values;
    self.temp_types = old_temp_types;
    self.label_blocks = old_label_blocks;
    self.current_function = old_function;
    self.current_block_terminated = old_terminated;
    c.LLVMPositionBuilderAtEnd(self.builder, old_block);
    restored = true;
}

pub fn lowerFunctionCall(self: *LLVMBackend, inst: @FieldType(Instruction, "FunctionCall")) anyerror!void {
    const function_ref = self.functions.get(inst.name) orelse return LLVMBackendError.FunctionNotFound;
    const function = function_ref.value;
    const func_type = function_ref.func_type;
    const return_type = function_ref.return_type;

    var arg_values = try self.allocator.alloc(c.LLVMValueRef, inst.args.len);
    defer self.allocator.free(arg_values);

    if (inst.args.len != function_ref.param_types.len) {
        return LLVMBackendError.ArgumentCountMismatch;
    }

    for (inst.args, 0..) |arg, index| {
        const arg_type = function_ref.param_types[index];
        arg_values[index] = try self.valueRef(arg, arg_type);
    }

    const call_name = if (return_type.kind == .VOID) "" else try self.nextName("calltmp");
    const result = c.LLVMBuildCall2(self.builder, func_type, function, arg_values.ptr, @intCast(arg_values.len), call_name);
    if (return_type.kind != .VOID) {
        try self.putTemp(inst.dest, result, return_type);
    }
}

fn emitDefaultReturn(self: *LLVMBackend, return_type: Type) anyerror!void {
    switch (return_type.kind) {
        .VOID => _ = c.LLVMBuildRetVoid(self.builder),
        .INT => _ = c.LLVMBuildRet(self.builder, c.LLVMConstInt(try self.llvmType(return_type), 0, 0)),
        .BOOL => _ = c.LLVMBuildRet(self.builder, c.LLVMConstInt(try self.llvmType(return_type), 0, 0)),
        .FLOAT => _ = c.LLVMBuildRet(self.builder, c.LLVMConstReal(try self.llvmType(return_type), 0)),
        else => return LLVMBackendError.UnsupportedType,
    }
    self.current_block_terminated = true;
}
