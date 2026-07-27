const std = @import("std");
const LLVMBackend = @import("../llvm_backend.zig").LLVMBackend;
const LLVMBackendError = @import("../llvm_backend.zig").LLVMBackendError;
const Instruction = @import("../../../ir/ir.zig").Instruction;
const Value = @import("../../../ir/ir.zig").Value;
const c = @import("../../../llvm.zig").c;
const Type = @import("../../../semantic/types.zig").Type;

pub fn lowerStoreField(self: *LLVMBackend, inst: @FieldType(Instruction, "StoreField")) !void {
    const object_type = self.valueType(inst.object) orelse return LLVMBackendError.UnsupportedValue;
    if (object_type.kind != .STRUCT) return LLVMBackendError.UnsupportedType;

    const field_index = try fieldIndex(self, object_type, inst.fieldName);
    const field_type = try fieldType(self, object_type, inst.fieldName);
    const field_ptr = try fieldPointer(self, inst.object, object_type, inst.fieldName, field_index);
    const value = try self.valueRef(inst.value, field_type);
    _ = c.LLVMBuildStore(self.builder, value, field_ptr);
}

pub fn lowerAllocStruct(self: *LLVMBackend, inst: @FieldType(Instruction, "AllocStruct")) !void {
    const struct_type = inst.resolvedType orelse Type{ .kind = .STRUCT, .struct_name = inst.structType };
    const struct_body = try self.structBodyType(inst.structType);
    const byte_count = c.LLVMSizeOf(struct_body);

    var malloc_args = [_]c.LLVMValueRef{byte_count};
    const raw_ptr = c.LLVMBuildCall2(
        self.builder,
        self.malloc_type,
        self.malloc_function,
        &malloc_args,
        malloc_args.len,
        try self.nextName("struct_malloc"),
    );
    const ptr = c.LLVMBuildBitCast(
        self.builder,
        raw_ptr,
        c.LLVMPointerType(struct_body, 0),
        try self.nextName("struct_ptr"),
    );
    try self.putTemp(inst.dest, ptr, struct_type);
}

pub fn lowerLoadField(self: *LLVMBackend, inst: @FieldType(Instruction, "LoadField")) !void {
    const object_type = self.valueType(inst.object) orelse return LLVMBackendError.UnsupportedValue;
    if (object_type.kind != .STRUCT) return LLVMBackendError.UnsupportedType;

    const field_index = try fieldIndex(self, object_type, inst.fieldName);
    const field_type = try fieldType(self, object_type, inst.fieldName);
    const field_ptr = try fieldPointer(self, inst.object, object_type, inst.fieldName, field_index);
    const loaded = c.LLVMBuildLoad2(
        self.builder,
        try self.llvmType(field_type),
        field_ptr,
        try self.nextName("field_load"),
    );
    try self.putTemp(inst.dest, loaded, field_type);
}

fn fieldPointer(
    self: *LLVMBackend,
    object: Value,
    object_type: Type,
    field_name: []const u8,
    index: u32,
) !c.LLVMValueRef {
    const struct_body = try self.structBodyType(object_type.struct_name orelse return LLVMBackendError.UnsupportedType);
    const object_ptr = try self.valueRef(object, object_type);
    return c.LLVMBuildStructGEP2(
        self.builder,
        struct_body,
        object_ptr,
        index,
        try self.nextName(field_name),
    );
}

fn fieldIndex(self: *LLVMBackend, object_type: Type, field_name: []const u8) !u32 {
    const definition = try self.structDefinition(object_type.struct_name orelse return LLVMBackendError.UnsupportedType);
    var index: u32 = 0;
    for (definition.fields) |field| {
        switch (field) {
            .StructProperty => |property| {
                if (std.mem.eql(u8, property.name, field_name)) {
                    return index;
                }
                index += 1;
            },
            .StructMethod => {},
        }
    }
    return LLVMBackendError.UnsupportedValue;
}

fn fieldType(self: *LLVMBackend, object_type: Type, field_name: []const u8) !Type {
    const definition = try self.structDefinition(object_type.struct_name orelse return LLVMBackendError.UnsupportedType);
    for (definition.fields) |field| {
        switch (field) {
            .StructProperty => |property| {
                if (std.mem.eql(u8, property.name, field_name)) {
                    return @import("../../../semantic/type_resolver.zig").resolveTypeRefUnchecked(property.fieldType);
                }
            },
            .StructMethod => {},
        }
    }
    return LLVMBackendError.UnsupportedValue;
}
