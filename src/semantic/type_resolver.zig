const std = @import("std");

const TypeRef = @import("../ast/type_ref.zig").TypeRef;
const SemanticContext = @import("context.zig").SemanticContext;
const SemanticError = @import("semantic_error.zig").SemanticError;
const types = @import("types.zig");

pub fn resolveTypeRef(context: *SemanticContext, type_ref: TypeRef) SemanticError!types.Type {
    var resolved = if (std.mem.eql(u8, type_ref.name, "int"))
        types.Type{ .kind = .INT }
    else if (std.mem.eql(u8, type_ref.name, "float"))
        types.Type{ .kind = .FLOAT }
    else if (std.mem.eql(u8, type_ref.name, "bool"))
        types.Type{ .kind = .BOOL }
    else if (std.mem.eql(u8, type_ref.name, "void"))
        types.Type{ .kind = .VOID }
    else if (std.mem.eql(u8, type_ref.name, "string"))
        types.Type{ .kind = .STRING }
    else blk: {
        if (!context.structs.contains(type_ref.name)) {
            return SemanticError.UndefinedVariable;
        }
        break :blk types.Type{ .kind = .STRUCT, .struct_name = type_ref.name };
    };

    resolved.isArray = type_ref.is_array;
    resolved.dynamicArray = type_ref.dynamic_array;
    resolved.staticLength = type_ref.static_length;
    return resolved;
}

// Inverse of resolveTypeRefUnchecked: turns a resolved semantic Type back into
// AST-level type syntax. Used to synthesize parameter declarations for extern
// (cross-module) function signatures, where only the resolved Type is known
// (from a Symbol looked up in scope), not the original TypeRef.
pub fn typeToTypeRef(typ: types.Type) TypeRef {
    const name = switch (typ.kind) {
        .INT => "int",
        .FLOAT => "float",
        .BOOL => "bool",
        .VOID => "void",
        .STRING => "string",
        .STRUCT => typ.struct_name orelse "void",
        .FUNCTION, .EMPTY => "void",
    };

    return .{
        .name = name,
        .is_array = typ.isArray,
        .dynamic_array = typ.dynamicArray,
        .static_length = typ.staticLength,
    };
}

pub fn resolveTypeRefUnchecked(type_ref: TypeRef) types.Type {
    var resolved = if (std.mem.eql(u8, type_ref.name, "int"))
        types.Type{ .kind = .INT }
    else if (std.mem.eql(u8, type_ref.name, "float"))
        types.Type{ .kind = .FLOAT }
    else if (std.mem.eql(u8, type_ref.name, "bool"))
        types.Type{ .kind = .BOOL }
    else if (std.mem.eql(u8, type_ref.name, "void"))
        types.Type{ .kind = .VOID }
    else if (std.mem.eql(u8, type_ref.name, "string"))
        types.Type{ .kind = .STRING }
    else
        types.Type{ .kind = .STRUCT, .struct_name = type_ref.name };

    resolved.isArray = type_ref.is_array;
    resolved.dynamicArray = type_ref.dynamic_array;
    resolved.staticLength = type_ref.static_length;
    return resolved;
}
