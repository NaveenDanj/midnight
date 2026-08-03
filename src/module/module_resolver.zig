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
};

pub const ModuleResolver = struct {
    allocator: std.mem.Allocator,
    resolved: std.StringHashMap(*Module),
    in_progress: std.StringHashMap(u8),

    pub fn init(allocator: std.mem.Allocator) ModuleResolver {
        return .{
            .allocator = allocator,
            .resolved = std.StringHashMap(*Module).init(allocator),
            .in_progress = std.StringHashMap(u8).init(allocator),
        };
    }

    pub fn deinit(self: *ModuleResolver) void {
        self.resolved.deinit();
        self.in_progress.deinit();
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

        const module = try self.loadModule(canonicalPath);
        const moduleDir = std.fs.path.dirname(canonicalPath) orelse ".";

        for (module.imports) |importStmt| {
            _ = try self.resolveModule(importStmt.path, moduleDir);
        }

        _ = try self.resolved.put(canonicalPath, module);
        _ = self.in_progress.remove(canonicalPath);

        return module;
    }

    pub fn loadModule(self: *ModuleResolver, path: []const u8) !*Module {
        const source = try readFile(self.allocator, path);

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
};
