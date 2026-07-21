const pipeline = @import("../compiler/pipeline.zig");

pub const CommonOptions = struct {
    source_path: []const u8,
    output_path: ?[]const u8 = null,
    backend: pipeline.BackendKind = .llvm,
    emit_ir: bool = false,
    emit_asm: bool = false,
    emit_llvm_ir: bool = false,
};

pub const RunOptions = CommonOptions;
pub const BuildOptions = CommonOptions;
