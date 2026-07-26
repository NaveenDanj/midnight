const LLVMBackend = @import("../llvm_backend.zig").LLVMBackend;
const LLVMBackendError = @import("../llvm_backend.zig").LLVMBackendError;
const c = @import("../../../llvm.zig").c;
const Instruction = @import("../../../ir/ir.zig").Instruction;
const Value = @import("../../../ir/ir.zig").Value;
const Type = @import("../../../semantic/types.zig").Type;
const std = @import("std");

pub fn lowerAllocArray(self: *LLVMBackend, inst: @FieldType(Instruction, "AllocArray")) !void {
    const array_type = inst.resolvedType orelse return LLVMBackendError.MissingResolvedType;

    if (!array_type.isArray) {
        return LLVMBackendError.UnsupportedType;
    }

    const element_type = arrayElementType(array_type);
    const allocation = try buildArrayAllocation(self, array_type, element_type, inst.length);

    try self.putTemp(inst.dest, allocation, array_type);
}

pub fn lowerStoreIndex(self: *LLVMBackend, inst: @FieldType(Instruction, "StoreIndex")) !void {
    const element_type = inst.resolvedType orelse return LLVMBackendError.MissingResolvedType;
    const array_type = self.valueType(inst.array) orelse return LLVMBackendError.UnsupportedValue;
    if (!array_type.isArray) {
        return LLVMBackendError.UnsupportedType;
    }

    const value = try self.valueRef(inst.value, element_type);
    var index_value = try self.valueRef(inst.index, Type{ .kind = .INT });
    try emitArrayBoundsCheck(self, inst.array, array_type, index_value);
    const llvm_element_type = try self.llvmType(element_type);
    const array_ptr = try arrayDataPointer(self, inst.array, array_type, llvm_element_type);

    const ptr = c.LLVMBuildGEP2(
        self.builder,
        llvm_element_type,
        array_ptr,
        &index_value,
        1,
        try self.nextName("store_index_tmp"),
    );

    _ = c.LLVMBuildStore(self.builder, value, ptr);
}

pub fn lowerLoadIndex(self: *LLVMBackend, inst: @FieldType(Instruction, "LoadIndex")) !void {
    const element_type = inst.resolvedType orelse return LLVMBackendError.MissingResolvedType;
    const array_type = self.valueType(inst.array) orelse return LLVMBackendError.UnsupportedValue;
    if (!array_type.isArray) {
        return LLVMBackendError.UnsupportedType;
    }

    var index_value = try self.valueRef(inst.index, Type{ .kind = .INT });
    try emitArrayBoundsCheck(self, inst.array, array_type, index_value);
    const llvm_element_type = try self.llvmType(element_type);
    const array_ptr = try arrayDataPointer(self, inst.array, array_type, llvm_element_type);

    const ptr = c.LLVMBuildGEP2(
        self.builder,
        llvm_element_type,
        array_ptr,
        &index_value,
        1,
        try self.nextName("load_index_tmp"),
    );

    const value = c.LLVMBuildLoad2(
        self.builder,
        llvm_element_type,
        ptr,
        try self.nextName("load_index_value"),
    );

    try self.putTemp(inst.dest, value, element_type);
}

fn arrayElementType(array_type: Type) Type {
    return .{
        .kind = array_type.kind,
        .isArray = false,
        .struct_name = array_type.struct_name,
    };
}

fn emitArrayBoundsCheck(
    self: *LLVMBackend,
    array: Value,
    array_type: Type,
    index_value: c.LLVMValueRef,
) !void {
    const i32_type = c.LLVMInt32TypeInContext(self.context);
    const zero = c.LLVMConstInt(i32_type, 0, 0);
    const array_length = try arrayLengthValue(self, array, array_type);

    const non_negative = c.LLVMBuildICmp(
        self.builder,
        c.LLVMIntSGE,
        index_value,
        zero,
        try self.nextName("array_index_non_negative"),
    );
    const within_length = c.LLVMBuildICmp(
        self.builder,
        c.LLVMIntSLT,
        index_value,
        array_length,
        try self.nextName("array_index_within_length"),
    );
    const in_bounds = c.LLVMBuildAnd(
        self.builder,
        non_negative,
        within_length,
        try self.nextName("array_index_in_bounds"),
    );

    const ok_block = c.LLVMAppendBasicBlockInContext(self.context, self.current_function, try self.nextName("array.bounds.ok"));
    const fail_block = c.LLVMAppendBasicBlockInContext(self.context, self.current_function, try self.nextName("array.bounds.fail"));
    _ = c.LLVMBuildCondBr(self.builder, in_bounds, ok_block, fail_block);

    c.LLVMPositionBuilderAtEnd(self.builder, fail_block);
    const message = c.LLVMBuildGlobalStringPtr(
        self.builder,
        try self.toZ("runtime error: array index out of bounds"),
        try self.nextName("array_bounds_msg"),
    );
    var puts_args = [_]c.LLVMValueRef{message};
    _ = c.LLVMBuildCall2(
        self.builder,
        self.puts_type,
        self.puts_function,
        &puts_args,
        puts_args.len,
        try self.nextName("array_bounds_puts"),
    );
    _ = c.LLVMBuildCall2(
        self.builder,
        self.abort_type,
        self.abort_function,
        null,
        0,
        "",
    );
    _ = c.LLVMBuildUnreachable(self.builder);

    c.LLVMPositionBuilderAtEnd(self.builder, ok_block);
}

pub fn buildArrayAllocation(
    self: *LLVMBackend,
    array_type: Type,
    element_type: Type,
    length: u32,
) !c.LLVMValueRef {
    if (array_type.dynamicArray) {
        return try buildDynamicArray(self, element_type, length);
    }
    return try buildStaticArray(self, element_type, array_type.staticLength orelse length);
}

fn buildStaticArray(self: *LLVMBackend, element_type: Type, length: u32) !c.LLVMValueRef {
    const llvm_element_type = try self.llvmType(element_type);
    const llvm_array_type = c.LLVMArrayType2(llvm_element_type, length);
    const array_slot = c.LLVMBuildAlloca(self.builder, llvm_array_type, try self.nextName("array_stack"));
    return c.LLVMBuildBitCast(
        self.builder,
        array_slot,
        c.LLVMPointerType(llvm_element_type, 0),
        try self.nextName("array_data_ptr"),
    );
}

fn buildDynamicArray(self: *LLVMBackend, element_type: Type, length: u32) !c.LLVMValueRef {
    const llvm_element_type = try self.llvmType(element_type);
    const header_type = arrayHeaderType(self.context);
    const header_size = c.LLVMSizeOf(header_type);
    const header_ptr = try mallocAsType(self, header_size, c.LLVMPointerType(header_type, 0), "array_header");
    const data_ptr = try allocateArrayElements(self, llvm_element_type, length);
    const i32_type = c.LLVMInt32TypeInContext(self.context);
    const length_value = c.LLVMConstInt(i32_type, length, 0);

    try storeHeaderField(self, header_type, header_ptr, 0, length_value, "array_length_ptr");
    try storeHeaderField(self, header_type, header_ptr, 1, length_value, "array_capacity_ptr");
    try storeHeaderField(self, header_type, header_ptr, 2, data_ptr, "array_data_field_ptr");

    return header_ptr;
}

fn arrayDataPointer(
    self: *LLVMBackend,
    array: Value,
    array_type: Type,
    llvm_element_type: c.LLVMTypeRef,
) !c.LLVMValueRef {
    const array_value = try self.valueRef(array, array_type);
    if (!array_type.dynamicArray) {
        return array_value;
    }

    const header_type = arrayHeaderType(self.context);
    const data_field_ptr = c.LLVMBuildStructGEP2(
        self.builder,
        header_type,
        array_value,
        2,
        try self.nextName("array_data_ptr_slot"),
    );

    return c.LLVMBuildLoad2(
        self.builder,
        c.LLVMPointerType(llvm_element_type, 0),
        data_field_ptr,
        try self.nextName("array_data_ptr"),
    );
}

fn arrayLengthValue(self: *LLVMBackend, array: Value, array_type: Type) !c.LLVMValueRef {
    const i32_type = c.LLVMInt32TypeInContext(self.context);
    if (!array_type.dynamicArray) {
        const static_length = array_type.staticLength orelse return LLVMBackendError.UnsupportedType;
        return c.LLVMConstInt(i32_type, static_length, 0);
    }

    const array_value = try self.valueRef(array, array_type);
    const header_type = arrayHeaderType(self.context);
    const length_ptr = c.LLVMBuildStructGEP2(
        self.builder,
        header_type,
        array_value,
        0,
        try self.nextName("array_length_ptr"),
    );
    return c.LLVMBuildLoad2(
        self.builder,
        i32_type,
        length_ptr,
        try self.nextName("array_length"),
    );
}

fn allocateArrayElements(self: *LLVMBackend, llvm_element_type: c.LLVMTypeRef, length: u32) !c.LLVMValueRef {
    const i64_type = c.LLVMInt64TypeInContext(self.context);
    const element_size = c.LLVMSizeOf(llvm_element_type);
    const element_count = c.LLVMConstInt(i64_type, length, 0);
    const byte_count = c.LLVMBuildMul(
        self.builder,
        element_size,
        element_count,
        try self.nextName("array_bytes"),
    );
    return try mallocAsType(self, byte_count, c.LLVMPointerType(llvm_element_type, 0), "array_data");
}

fn mallocAsType(
    self: *LLVMBackend,
    byte_count: c.LLVMValueRef,
    target_type: c.LLVMTypeRef,
    name_prefix: []const u8,
) !c.LLVMValueRef {
    var malloc_args = [_]c.LLVMValueRef{byte_count};
    const raw_ptr = c.LLVMBuildCall2(
        self.builder,
        self.malloc_type,
        self.malloc_function,
        &malloc_args,
        malloc_args.len,
        try self.nextName(name_prefix),
    );

    return c.LLVMBuildBitCast(
        self.builder,
        raw_ptr,
        target_type,
        try self.nextName("array_ptr"),
    );
}

fn arrayHeaderType(context: c.LLVMContextRef) c.LLVMTypeRef {
    var fields = [_]c.LLVMTypeRef{
        c.LLVMInt32TypeInContext(context),
        c.LLVMInt32TypeInContext(context),
        c.LLVMPointerTypeInContext(context, 0),
    };
    return c.LLVMStructTypeInContext(context, &fields, fields.len, 0);
}

fn storeHeaderField(
    self: *LLVMBackend,
    header_type: c.LLVMTypeRef,
    header_ptr: c.LLVMValueRef,
    field_index: c_uint,
    value: c.LLVMValueRef,
    name_prefix: []const u8,
) !void {
    const field_ptr = c.LLVMBuildStructGEP2(
        self.builder,
        header_type,
        header_ptr,
        field_index,
        try self.nextName(name_prefix),
    );
    _ = c.LLVMBuildStore(self.builder, value, field_ptr);
}
