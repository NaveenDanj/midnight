const std = @import("std");

const toolchain = @import("../backend/toolchain.zig");
const llvm_backend = @import("../backend/llvm/llvm_backend.zig");
const emitAssembly = @import("../backend/x86_64/x86_64_backend.zig").emitAssembly;
const Instruction = @import("../ir/ir.zig").Instruction;
const InstructionBuilder = @import("../ir/builder.zig").InstructionBuilder;
const generateIRWithSemantics = @import("../ir/lower.zig").generateIRWithSemantics;
const Lexer = @import("../lexer/lexer.zig").Lexer;
const Parser = @import("../parser/parser.zig").Parser;
const SemanticAnalyzer = @import("../semantic/anaylzer.zig").SemanticAnalyzer;
const Statement = @import("../ast/stmt.zig").Statement;

pub const BackendKind = enum {
    x86_64,
    llvm,
};

pub const CompileOptions = struct {
    source_path: []const u8 = "",
    output_dir: []const u8 = "/tmp/midnight-build",
    asm_path: []const u8 = "/tmp/midnight-build/output.asm",
    object_path: []const u8 = "/tmp/midnight-build/out.o",
    executable_name: []const u8 = "out.exe",
    backend: BackendKind = .x86_64,
    emit_ir: bool = false,
    emit_asm: bool = true,
    emit_llvm_ir: bool = false,
    link: bool = false,
    run: bool = false,
};

pub const CompileResult = struct {
    allocator: std.mem.Allocator,
    source_text: ?[]const u8 = null,
    statements: []*Statement,
    instructions: []Instruction,
    asm_text: ?[]const u8 = null,
    llvm_ir_text: ?[]const u8 = null,
    artifact: ?toolchain.BuildArtifact = null,

    pub fn deinit(self: *CompileResult) void {
        if (self.source_text) |source_text| {
            self.allocator.free(source_text);
        }
        self.allocator.free(self.instructions);
        if (self.asm_text) |asm_text| {
            self.allocator.free(asm_text);
        }
        if (self.llvm_ir_text) |llvm_ir_text| {
            self.allocator.free(llvm_ir_text);
        }
        if (self.artifact) |*artifact| {
            artifact.deinit();
        }
    }
};

pub fn compileFile(allocator: std.mem.Allocator, options: CompileOptions) !CompileResult {
    const io = std.Io.Threaded.global_single_threaded.io();
    const file = try std.Io.Dir.cwd().openFile(io, options.source_path, .{});
    defer file.close(io);

    var file_buffer: [4096]u8 = undefined;
    var file_reader = file.reader(io, &file_buffer);
    const source = try file_reader.interface.allocRemaining(allocator, .limited64(1024 * 1024));
    errdefer allocator.free(source);

    var result = try compileSource(allocator, source, options);
    result.source_text = source;
    return result;
}

pub fn compileSource(allocator: std.mem.Allocator, source: []const u8, options: CompileOptions) !CompileResult {
    var lexer = Lexer.init(source);
    var token_list = try lexer.lexAll(allocator);
    defer token_list.deinit(allocator);

    var parser = Parser.init(allocator, token_list.items);
    const statements = try parser.parseProgram();

    var semanticAnalyzer = try SemanticAnalyzer.init(allocator);
    defer semanticAnalyzer.deinit();
    try semanticAnalyzer.analyzeProgram(statements);

    var irBuilder = InstructionBuilder.init(allocator);
    defer {
        irBuilder.var_map.deinit();
        irBuilder.version_map.deinit();
    }
    try generateIRWithSemantics(&irBuilder, statements, &semanticAnalyzer.result);

    const instructions = try irBuilder.instructions.toOwnedSlice(allocator);
    errdefer allocator.free(instructions);

    var asm_text: ?[]const u8 = null;
    errdefer if (asm_text) |text| allocator.free(text);

    if (options.emit_asm or options.link or options.run) {
        asm_text = switch (options.backend) {
            .x86_64 => try emitAssembly(allocator, instructions),
            .llvm => try llvm_backend.emitLLVMAssembly(allocator, instructions),
        };
    }

    var llvm_ir_text: ?[]const u8 = null;
    errdefer if (llvm_ir_text) |text| allocator.free(text);

    if (options.emit_llvm_ir) {
        llvm_ir_text = try llvm_backend.emitLLVMIR(allocator, instructions);
    }

    // if (options.emit_ir) {
    //     std.debug.print("=== Generated IR ===\n", .{});
    //     for (instructions) |instruction| {
    //         std.debug.print("{any}\n", .{instruction});
    //     }
    // }

    std.debug.print("=== Generated LLVM IR ===\n", .{});
    if (llvm_ir_text) |text| {
        std.debug.print("{s}\n", .{text});
    }

    var artifact: ?toolchain.BuildArtifact = null;
    errdefer if (artifact) |*build_artifact| build_artifact.deinit();

    if (options.link or options.run) {
        artifact = switch (options.backend) {
            .x86_64 => try toolchain.assembleAndLink(allocator, .{
                .asm_text = asm_text orelse return error.MissingAssembly,
                .asm_path = options.asm_path,
                .output_dir = options.output_dir,
                .executable_name = options.executable_name,
            }),
            .llvm => blk: {
                const object_bytes = try llvm_backend.emitLLVMObject(allocator, instructions);
                defer allocator.free(object_bytes);

                break :blk try toolchain.linkObject(allocator, .{
                    .object_bytes = object_bytes,
                    .object_path = options.object_path,
                    .output_dir = options.output_dir,
                    .executable_name = options.executable_name,
                });
            },
        };
    }

    if (options.run) {
        try toolchain.runArtifact(allocator, artifact orelse return error.MissingBuildArtifact);
    }

    return .{
        .allocator = allocator,
        .statements = statements,
        .instructions = instructions,
        .asm_text = asm_text,
        .llvm_ir_text = llvm_ir_text,
        .artifact = artifact,
    };
}
