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
const ModuleResolver = @import("../module/module_resolver.zig").ModuleResolver;
const ModuleCompiler = @import("../module/module_compiler.zig").ModuleCompiler;
const writeObject = @import("../backend/toolchain.zig").writeObject;

pub const BackendKind = enum {
    x86_64,
    llvm,
};

pub const CompileOptions = struct {
    source_path: []const u8 = "",
    output_dir: []const u8 = "/tmp/midnight-build",
    asm_path: []const u8 = "/tmp/midnight-build/output.asm",
    object_path: []const u8 = "/tmp/midnight-build/out.o",
    std_lib_path: []const u8 = "/run/media/naveendanj/STORAGE/projects/midnight/src/",
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
    const normalized_path = try normalizePath(allocator, options.source_path);
    defer if (normalized_path) |path| allocator.free(path);

    var file = try std.fs.cwd().openFile(normalized_path orelse options.source_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
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

    // handle module resolution for import statements
    var moduleResolver = ModuleResolver.init(allocator, options.std_lib_path);
    defer moduleResolver.deinit();

    const base_dir = std.fs.path.dirname(options.source_path) orelse ".";
    try moduleResolver.handleImportStatements(statements, base_dir);

    var semanticAnalyzer = try SemanticAnalyzer.init(allocator);
    defer semanticAnalyzer.deinit();

    // Every module this file (transitively) imports, plus this file's own
    // top-level statements, are analyzed into one shared top-level scope so
    // that declarations made while analyzing one module stay visible while
    // analyzing modules/the main file that import it - without merging their
    // ASTs together. See module_compiler.zig for how each module is then
    // separately lowered/emitted into its own object file.
    try semanticAnalyzer.beginSharedScope();
    defer semanticAnalyzer.endSharedScope();

    var module_objects: []const []const u8 = try allocator.alloc([]const u8, 0);

    var moduleCompiler: ?ModuleCompiler = null;
    defer if (moduleCompiler) |*mc| mc.deinit();

    if (options.backend == .llvm) {
        moduleCompiler = ModuleCompiler.init(allocator);

        try moduleCompiler.?.registerStatements(statements);
        module_objects = try moduleCompiler.?.compileModules(&moduleResolver, &semanticAnalyzer, options.output_dir);
    }

    try semanticAnalyzer.analyzeStatements(statements);

    var irBuilder = InstructionBuilder.init(allocator);
    defer {
        irBuilder.var_map.deinit();
        irBuilder.version_map.deinit();
    }

    try generateIRWithSemantics(&irBuilder, statements, &semanticAnalyzer.result);

    // The entry file's own instructions can reference functions/structs
    // defined in an imported module (which now lives in a separate object),
    // so it needs the same extern declarations synthesized for it as any
    // other module - see module_compiler.zig.
    if (moduleCompiler) |*mc| {
        try mc.augmentInstructions(&irBuilder.instructions, &semanticAnalyzer);
    }

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

    if (options.emit_ir) {
        std.debug.print("=== Generated IR ===\n", .{});
        for (instructions) |instruction| {
            std.debug.print("{any}\n", .{instruction});
        }
    }

    if (options.emit_llvm_ir) if (llvm_ir_text) |text| {
        std.debug.print("=== Generated LLVM IR ===\n", .{});
        std.debug.print("{s}\n", .{text});
    };

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

                try writeObject(object_bytes, options.object_path);

                var all_object_paths = try std.ArrayList([]const u8).initCapacity(allocator, module_objects.len + 1);
                defer all_object_paths.deinit(allocator);
                try all_object_paths.appendSlice(allocator, module_objects);
                try all_object_paths.append(allocator, options.object_path);

                break :blk try toolchain.linkObjects(allocator, .{
                    .object_paths = all_object_paths.items,
                    .output_dir = options.output_dir,
                    .executable_name = options.executable_name,
                });
            },
        };
    }

    for (module_objects) |path| allocator.free(path);
    allocator.free(module_objects);

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

// Rewrites backslashes to forward slashes. Returns null (no allocation) when
// the path has no backslashes, which covers all normal Linux/macOS paths.
fn normalizePath(allocator: std.mem.Allocator, path: []const u8) !?[]const u8 {
    if (std.mem.indexOfScalar(u8, path, '\\') == null) return null;

    const normalized = try allocator.alloc(u8, path.len);
    for (path, 0..) |char, i| {
        normalized[i] = if (char == '\\') '/' else char;
    }
    return normalized;
}
