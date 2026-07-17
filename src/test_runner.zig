test {
    _ = @import("tests/basic.zig");
    _ = @import("tests/arrays.zig");
    _ = @import("tests/ir.zig");
    _ = @import("tests/type_compatibility.zig");
    _ = @import("tests/expr_type_checker.zig");
    _ = @import("tests/semantic_checkers.zig");
    _ = @import("tests/phase7_errors.zig");
    _ = @import("tests/backend_value_handling.zig");
    _ = @import("tests/pipeline.zig");
}
