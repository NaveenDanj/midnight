const std = @import("std");
const Type = @import("types.zig").Type;

pub fn equals(a: Type, b: Type) bool {
    if (a.kind != b.kind) return false;
    if (a.isArray != b.isArray) return false;

    if (a.kind == .STRUCT) {
        const a_name = a.struct_name orelse return false;
        const b_name = b.struct_name orelse return false;
        return std.mem.eql(u8, a_name, b_name);
    }

    return true;
}

pub fn isAssignable(expected: Type, actual: Type) bool {
    if (expected.kind == .VOID) return false;

    if (expected.kind == .STRUCT) {
        return equals(expected, actual);
    }

    if (expected.isArray or actual.isArray) {
        return expected.isArray == actual.isArray and expected.kind == actual.kind and structNamesEqual(expected, actual);
    }

    if (expected.kind == .STRING) {
        return actual.kind == .STRING;
    }

    if (expected.isNumeric()) {
        return actual.isNumeric();
    }

    return expected.kind == actual.kind;
}

pub fn commonNumericType(left: Type, right: Type) ?Type {
    if (!left.isNumeric() or !right.isNumeric()) return null;
    if (left.kind == .FLOAT or right.kind == .FLOAT) return Type{ .kind = .FLOAT };
    return Type{ .kind = .INT };
}

fn structNamesEqual(a: Type, b: Type) bool {
    if (a.kind != .STRUCT and b.kind != .STRUCT) return true;
    const a_name = a.struct_name orelse return false;
    const b_name = b.struct_name orelse return false;
    return std.mem.eql(u8, a_name, b_name);
}
