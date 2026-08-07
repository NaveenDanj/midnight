const std = @import("std");
const Module = @import("module_resolver.zig").Module;
const ModuleResolver = @import("module_resolver.zig").ModuleResolver;
const SemanticAnalyzer = @import("../semantic/anaylzer.zig").SemanticAnalyzer;
const InstructionBuilder = @import("../ir/builder.zig").InstructionBuilder;
const generateIRWithSemantics = @import("../ir/lower.zig").generateIRWithSemantics;
const llvm_backend = @import("../backend/llvm/llvm_backend.zig");
const Instruction = @import("../ir/ir.zig").Instruction;
const typeResolver = @import("../semantic/type_resolver.zig");
const stmt_ast = @import("../ast/stmt.zig");
const TypeRef = @import("../ast/type_ref.zig").TypeRef;
const FunctionDecl = stmt_ast.FunctionDecl;
const StructStmt = stmt_ast.StructStmt;
const Statement = stmt_ast.Statement;
const Param = stmt_ast.Param;

const FnSig = struct {
    params: []*Param,
    returnType: TypeRef,
};

// Compiles resolved modules (see module_resolver.zig) into independent
// object files, one per module, so they can be linked together instead of
// being flattened into a single translation unit. A module's own object
// contains only the functions/structs it defines itself; any function or
// struct it uses but doesn't define is emitted as an extern (declaration
// only) so the symbol is resolved at final link time against the object
// that actually defines it - the same mechanism already used for `extern
// func` declarations that bind to the C runtime.
pub const ModuleCompiler = struct {
    allocator: std.mem.Allocator,
    // Registry of every function/method signature seen across all modules
    // and the main file, keyed by the exact name used at IR call sites
    // (plain function name, or "StructName__methodName" for methods). Built
    // up-front (registerModule/registerStatements) before any module is
    // compiled, so cross-module references resolve regardless of dependency
    // order.
    function_signatures: std.StringHashMap(FnSig),

    pub fn init(allocator: std.mem.Allocator) ModuleCompiler {
        return .{
            .allocator = allocator,
            .function_signatures = std.StringHashMap(FnSig).init(allocator),
        };
    }

    pub fn deinit(self: *ModuleCompiler) void {
        self.function_signatures.deinit();
    }

    pub fn registerModule(self: *ModuleCompiler, module: *Module) !void {
        for (module.functions) |function_decl| {
            try self.registerFunction(function_decl);
        }
        for (module.structs) |struct_decl| {
            try self.registerStruct(struct_decl);
        }
    }

    pub fn registerStatements(self: *ModuleCompiler, statements: []const *Statement) !void {
        for (statements) |statement| {
            switch (statement.*) {
                .FunctionDecl => |function_decl| try self.registerFunction(function_decl),
                .StructDecl => |struct_decl| try self.registerStruct(struct_decl),
                else => {},
            }
        }
    }

    fn registerFunction(self: *ModuleCompiler, function_decl: *FunctionDecl) !void {
        if (self.function_signatures.contains(function_decl.name)) return;
        try self.function_signatures.put(function_decl.name, .{ .params = function_decl.params, .returnType = function_decl.returnType });
    }

    fn registerStruct(self: *ModuleCompiler, struct_decl: *StructStmt) !void {
        for (struct_decl.fields) |field| {
            switch (field) {
                .StructMethod => |method| {
                    const mangled_name = try std.fmt.allocPrint(self.allocator, "{s}__{s}", .{ struct_decl.name, method.name });
                    if (self.function_signatures.contains(mangled_name)) continue;

                    const params = try self.allocator.alloc(*Param, method.parameters.len + 1);
                    const self_param = try self.allocator.create(Param);
                    self_param.* = .{ .dataType = .{ .name = struct_decl.name }, .name = "self" };
                    params[0] = self_param;
                    for (method.parameters, 0..) |param, index| {
                        params[index + 1] = param;
                    }

                    try self.function_signatures.put(mangled_name, .{ .params = params, .returnType = method.returnType });
                },
                .StructProperty => {},
            }
        }
    }

    // Compiles every resolved module (in dependency order) into its own
    // object file under output_dir, returning the written paths in the same
    // order. Assumes the caller has already called
    // semanticAnalyzer.beginSharedScope() so declarations accumulate across
    // modules instead of being discarded between them.
    pub fn compileModules(self: *ModuleCompiler, moduleResolver: *ModuleResolver, semanticAnalyzer: *SemanticAnalyzer, output_dir: []const u8) ![]const []const u8 {
        const modules = moduleResolver.getResolvedModules();

        for (modules) |module| {
            try self.registerModule(module);
        }

        var object_paths = try std.ArrayList([]const u8).initCapacity(self.allocator, modules.len);
        errdefer object_paths.deinit(self.allocator);

        for (modules, 0..) |module, index| {
            const object_path = try self.compileModule(module, semanticAnalyzer, output_dir, index);
            try object_paths.append(self.allocator, object_path);
        }

        return try object_paths.toOwnedSlice(self.allocator);
    }

    fn compileModule(self: *ModuleCompiler, module: *Module, semanticAnalyzer: *SemanticAnalyzer, output_dir: []const u8, index: usize) ![]const u8 {
        const statements = try module.getAllStatements();

        try semanticAnalyzer.analyzeStatements(statements);

        var irBuilder = InstructionBuilder.init(self.allocator);
        defer irBuilder.free();

        try generateIRWithSemantics(&irBuilder, statements, &semanticAnalyzer.result);

        var instructions = std.ArrayList(Instruction){};
        defer instructions.deinit(self.allocator);
        try instructions.appendSlice(self.allocator, irBuilder.instructions.items);

        try self.augmentInstructions(&instructions, semanticAnalyzer);

        const entry_name = try std.fmt.allocPrint(self.allocator, "__mn_mod_init_{d}", .{index});
        defer self.allocator.free(entry_name);

        const object_bytes = try llvm_backend.emitLLVMObjectNamed(self.allocator, instructions.items, entry_name);
        defer self.allocator.free(object_bytes);

        try std.fs.cwd().makePath(output_dir);
        const object_path = try std.fmt.allocPrint(self.allocator, "{s}/mod_{d}.o", .{ output_dir, index });

        const file = try std.fs.cwd().createFile(object_path, .{});
        defer file.close();
        try file.writeAll(object_bytes);

        return object_path;
    }

    // Prepends extern (declaration-only) FunctionIR/StructDeclIR entries for
    // every function call and struct instantiation this instruction list
    // references but doesn't itself define, so the LLVM backend can emit the
    // prototype/type layout needed to reference them, leaving the actual
    // symbol resolution to the linker.
    // Public so callers can also augment a translation unit that isn't one of
    // the resolved modules (namely: the entry file's own top-level
    // instructions), which needs the same extern declarations for any
    // module-defined function/struct it references.
    pub fn augmentInstructions(self: *ModuleCompiler, instructions: *std.ArrayList(Instruction), semanticAnalyzer: *SemanticAnalyzer) !void {
        var defined_functions = std.StringHashMap(void).init(self.allocator);
        defer defined_functions.deinit();
        var defined_structs = std.StringHashMap(void).init(self.allocator);
        defer defined_structs.deinit();
        collectDefined(instructions.items, &defined_functions, &defined_structs);

        var used_functions = std.StringHashMap(void).init(self.allocator);
        defer used_functions.deinit();
        var used_structs = std.StringHashMap(void).init(self.allocator);
        defer used_structs.deinit();
        try collectUsages(instructions.items, &defined_functions, &defined_structs, &used_functions, &used_structs);

        var extern_decls = std.ArrayList(Instruction){};
        defer extern_decls.deinit(self.allocator);

        var struct_it = used_structs.keyIterator();
        while (struct_it.next()) |name| {
            const definition = semanticAnalyzer.context.structs.get(name.*) orelse continue;
            try extern_decls.append(self.allocator, .{ .StructDeclIR = .{ .definition = definition } });
        }

        var function_it = used_functions.keyIterator();
        while (function_it.next()) |name| {
            const signature = self.function_signatures.get(name.*) orelse continue;
            try extern_decls.append(self.allocator, .{ .FunctionIR = .{
                .name = name.*,
                .params = signature.params,
                .body = &.{},
                .returnType = typeResolver.resolveTypeRefUnchecked(signature.returnType),
                .isExtern = true,
            } });
        }

        try instructions.insertSlice(self.allocator, 0, extern_decls.items);
    }

    fn collectDefined(instructions: []const Instruction, defined_functions: *std.StringHashMap(void), defined_structs: *std.StringHashMap(void)) void {
        for (instructions) |instruction| {
            switch (instruction) {
                .FunctionIR => |function_ir| defined_functions.put(function_ir.name, {}) catch {},
                .StructDeclIR => |struct_decl_ir| defined_structs.put(struct_decl_ir.definition.name, {}) catch {},
                else => {},
            }
        }
    }

    fn collectUsages(
        instructions: []const Instruction,
        defined_functions: *std.StringHashMap(void),
        defined_structs: *std.StringHashMap(void),
        used_functions: *std.StringHashMap(void),
        used_structs: *std.StringHashMap(void),
    ) !void {
        for (instructions) |instruction| {
            switch (instruction) {
                .FunctionCall => |function_call| {
                    if (!defined_functions.contains(function_call.name)) {
                        try used_functions.put(function_call.name, {});
                    }
                },
                .AllocStruct => |alloc_struct| {
                    if (!defined_structs.contains(alloc_struct.structType)) {
                        try used_structs.put(alloc_struct.structType, {});
                    }
                },
                .FunctionIR => |function_ir| {
                    try collectUsages(function_ir.body, defined_functions, defined_structs, used_functions, used_structs);
                },
                else => {},
            }
        }
    }
};
