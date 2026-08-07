const std = @import("std");
const FunctionDecl = @import("../ast/stmt.zig").FunctionDecl;
const stmt = @import("../ast/stmt.zig");
const VariableDecl = @import("../ast/stmt.zig").VarDecl;
const ImportStatement = @import("../ast/stmt.zig").ImportStatement;
const readFile = @import("../compiler/parser.zig").readFile;
const parseFromSource = @import("../compiler/parser.zig").parseFromSource;

pub const Module = struct {
    name: []const u8,
    imports: []*ImportStatement,

    functions: []*FunctionDecl,
    structs: []*stmt.StructStmt,
    variables: []*VariableDecl,
    allocator: std.mem.Allocator,

    pub fn getAllStatements(self: *Module) ![]const *stmt.Statement {
        var all = std.ArrayList(*stmt.Statement){};
        errdefer all.deinit(self.allocator);

        for (self.functions) |function_decl| {
            const module_stmt = try self.allocator.create(stmt.Statement);
            module_stmt.* = .{ .FunctionDecl = function_decl };
            try all.append(self.allocator, module_stmt);
        }

        for (self.structs) |struct_decl| {
            const module_stmt = try self.allocator.create(stmt.Statement);
            module_stmt.* = .{ .StructDecl = struct_decl };
            try all.append(self.allocator, module_stmt);
        }

        for (self.variables) |variable_decl| {
            const module_stmt = try self.allocator.create(stmt.Statement);
            module_stmt.* = .{ .VariableDecl = variable_decl };
            try all.append(self.allocator, module_stmt);
        }

        return try all.toOwnedSlice(self.allocator);
    }
};

pub const ModuleResolver = struct {
    allocator: std.mem.Allocator,
    resolved: std.StringHashMap(*Module),
    in_progress: std.StringHashMap(u8),
    order: std.ArrayList(*Module),
    std_lib_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, std_lib_path: []const u8) ModuleResolver {
        return .{
            .allocator = allocator,
            .resolved = std.StringHashMap(*Module).init(allocator),
            .in_progress = std.StringHashMap(u8).init(allocator),
            .order = std.ArrayList(*Module){},
            .std_lib_path = std_lib_path,
        };
    }

    pub fn deinit(self: *ModuleResolver) void {
        self.resolved.deinit();
        self.in_progress.deinit();
        self.order.deinit(self.allocator);
    }

    pub fn resolveModule(self: *ModuleResolver, importPath: []const u8, baseDir: []const u8) !*Module {
        const canonicalPath = try std.fs.path.resolve(self.allocator, &.{ baseDir, importPath });

        if (self.in_progress.get(canonicalPath)) |_| {
            return error.CircularDependency;
        }

        if (self.resolved.get(canonicalPath)) |resolvedModule| {
            return resolvedModule;
        }

        _ = try self.in_progress.put(canonicalPath, 1);

        const module = try self.loadModule(canonicalPath, importPath);
        const moduleDir = std.fs.path.dirname(canonicalPath) orelse ".";

        for (module.imports) |importStmt| {
            _ = try self.resolveModule(importStmt.path, moduleDir);
        }

        _ = try self.resolved.put(canonicalPath, module);
        try self.order.append(self.allocator, module);
        _ = self.in_progress.remove(canonicalPath);

        return module;
    }

    pub fn loadModule(self: *ModuleResolver, path: []const u8, import_path: []const u8) !*Module {
        const source = readFile(self.allocator, path) catch |err| switch (err) {
            error.FileNotFound => blk: {
                const std_path = try self.resolveStdModule(import_path);
                break :blk try readFile(self.allocator, std_path);
            },
            else => return err,
        };

        const statements = try parseFromSource(self.allocator, source);

        var imports = try std.ArrayList(*ImportStatement).initCapacity(self.allocator, 0);
        var functions = try std.ArrayList(*FunctionDecl).initCapacity(self.allocator, 0);
        var structs = try std.ArrayList(*stmt.StructStmt).initCapacity(self.allocator, 0);
        var variables = try std.ArrayList(*VariableDecl).initCapacity(self.allocator, 0);

        for (statements) |_stmt| {
            switch (_stmt.*) {
                .ImportStatement => |importStmt| {
                    try imports.append(self.allocator, importStmt);
                },
                .FunctionDecl => |funcDecl| {
                    try functions.append(self.allocator, funcDecl);
                },
                .StructDecl => |structDecl| {
                    try structs.append(self.allocator, structDecl);
                },
                .VariableDecl => |varDecl| {
                    try variables.append(self.allocator, varDecl);
                },
                else => {},
            }
        }

        const module = try self.allocator.create(Module);
        module.* = .{
            .name = try self.resolveModuleName(path),
            .imports = try imports.toOwnedSlice(self.allocator),
            .functions = try functions.toOwnedSlice(self.allocator),
            .structs = try structs.toOwnedSlice(self.allocator),
            .variables = try variables.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
        };
        return module;
    }

    pub fn handleImportStatements(self: *ModuleResolver, statements: []const *stmt.Statement, baseDir: []const u8) !void {
        for (statements) |statement| {
            switch (statement.*) {
                .ImportStatement => |importStmt| {
                    _ = try self.resolveModule(importStmt.path, baseDir);
                },
                else => {},
            }
        }
    }

    pub fn collectStatements(self: *ModuleResolver, statements: []const *stmt.Statement) ![]*stmt.Statement {
        var all = try std.ArrayList(*stmt.Statement).initCapacity(self.allocator, 0);
        defer all.deinit(self.allocator);

        var it = self.resolved.valueIterator();
        while (it.next()) |module_ptr| {
            const module = module_ptr.*;

            for (module.functions) |function_decl| {
                const module_stmt = try self.allocator.create(stmt.Statement);
                module_stmt.* = .{ .FunctionDecl = function_decl };
                try all.append(self.allocator, module_stmt);
            }

            for (module.structs) |struct_decl| {
                const module_stmt = try self.allocator.create(stmt.Statement);
                module_stmt.* = .{ .StructDecl = struct_decl };
                try all.append(self.allocator, module_stmt);
            }

            for (module.variables) |variable_decl| {
                const module_stmt = try self.allocator.create(stmt.Statement);
                module_stmt.* = .{ .VariableDecl = variable_decl };
                try all.append(self.allocator, module_stmt);
            }
        }

        try all.appendSlice(self.allocator, statements);

        return try all.toOwnedSlice(self.allocator);
    }

    fn resolveModuleName(self: *ModuleResolver, modulePath: []const u8) ![]const u8 {
        _ = self;
        return std.fs.path.basename(modulePath);
    }

    fn resolveStdModule(self: *ModuleResolver, module_path: []const u8) ![]const u8 {
        var path = std.ArrayList(u8){};
        errdefer path.deinit(self.allocator);

        try path.appendSlice(self.allocator, self.std_lib_path);
        try path.append(self.allocator, std.fs.path.sep);

        var it = std.mem.splitScalar(u8, module_path, '.');

        while (it.next()) |part| {
            try path.appendSlice(self.allocator, part);

            if (it.peek() != null) {
                try path.append(self.allocator, std.fs.path.sep);
            }
        }

        try path.appendSlice(self.allocator, ".mn");
        return path.toOwnedSlice(self.allocator);
    }

    // Returns modules in dependency-first order (a module's imports always
    // precede it), matching the DFS post-order built up in resolveModule.
    pub fn getResolvedModules(self: *ModuleResolver) []const *Module {
        return self.order.items;
    }
};
