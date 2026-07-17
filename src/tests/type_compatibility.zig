const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const Type = @import("../semantic/types.zig").Type;
const compatibility = @import("../semantic/type_compatibility.zig");

test "strict type equality compares kind array flag and struct names" {
    try expect(compatibility.equals(.{ .kind = .INT }, .{ .kind = .INT }));
    try expect(!compatibility.equals(.{ .kind = .INT }, .{ .kind = .FLOAT }));
    try expect(!compatibility.equals(.{ .kind = .INT }, .{ .kind = .INT, .isArray = true }));

    const person_a = Type{ .kind = .STRUCT, .struct_name = "Person" };
    const person_b = Type{ .kind = .STRUCT, .struct_name = "Person" };
    const account = Type{ .kind = .STRUCT, .struct_name = "Account" };

    try expect(compatibility.equals(person_a, person_b));
    try expect(!compatibility.equals(person_a, account));
    try expect(!compatibility.equals(.{ .kind = .STRUCT }, person_a));
}

test "assignability keeps current numeric and primitive compatibility rules" {
    try expect(compatibility.isAssignable(.{ .kind = .INT }, .{ .kind = .INT }));
    try expect(compatibility.isAssignable(.{ .kind = .INT }, .{ .kind = .FLOAT }));
    try expect(compatibility.isAssignable(.{ .kind = .FLOAT }, .{ .kind = .INT }));

    try expect(compatibility.isAssignable(.{ .kind = .STRING }, .{ .kind = .STRING }));
    try expect(!compatibility.isAssignable(.{ .kind = .STRING }, .{ .kind = .INT }));
    try expect(!compatibility.isAssignable(.{ .kind = .VOID }, .{ .kind = .VOID }));
}

test "assignability validates arrays and struct names" {
    try expect(compatibility.isAssignable(.{ .kind = .INT, .isArray = true }, .{ .kind = .INT, .isArray = true }));
    try expect(!compatibility.isAssignable(.{ .kind = .INT, .isArray = true }, .{ .kind = .INT }));
    try expect(!compatibility.isAssignable(.{ .kind = .INT, .isArray = true }, .{ .kind = .FLOAT, .isArray = true }));

    const expected_person = Type{ .kind = .STRUCT, .struct_name = "Person" };
    const actual_person = Type{ .kind = .STRUCT, .struct_name = "Person" };
    const actual_account = Type{ .kind = .STRUCT, .struct_name = "Account" };

    try expect(compatibility.isAssignable(expected_person, actual_person));
    try expect(!compatibility.isAssignable(expected_person, actual_account));
}

test "common numeric type returns promoted numeric type only for numeric operands" {
    try expectEqual(Type{ .kind = .INT }, compatibility.commonNumericType(.{ .kind = .INT }, .{ .kind = .INT }).?);
    try expectEqual(Type{ .kind = .FLOAT }, compatibility.commonNumericType(.{ .kind = .INT }, .{ .kind = .FLOAT }).?);
    try expectEqual(Type{ .kind = .FLOAT }, compatibility.commonNumericType(.{ .kind = .FLOAT }, .{ .kind = .INT }).?);
    try expect(compatibility.commonNumericType(.{ .kind = .STRING }, .{ .kind = .INT }) == null);
}
