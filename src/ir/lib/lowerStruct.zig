const InstructionBuilder = @import("../builder.zig").InstructionBuilder;
const StructDecl = @import("../../ast/stmt.zig").StructStmt;
const lower_function = @import("./lowerFunction.zig");
const SemanticResult = @import("../../semantic/result.zig").SemanticResult;

pub fn lowerStructDecl(builder: *InstructionBuilder, structDecl: *StructDecl) anyerror!void {
    try lowerStructDeclWithSemantics(builder, structDecl, null);
}

pub fn lowerStructDeclWithSemantics(builder: *InstructionBuilder, structDecl: *StructDecl, semantic: ?*const SemanticResult) anyerror!void {
    try builder.emit(.{ .StructDeclIR = .{ .definition = structDecl } });

    for (structDecl.fields) |field| {
        switch (field) {
            .StructMethod => |method_ptr| {
                const method_ir = try lower_function.lowerStructMethodWithSemantics(builder, structDecl, method_ptr, semantic);
                try builder.emit(method_ir);
            },
            .StructProperty => {},
        }
    }
}
