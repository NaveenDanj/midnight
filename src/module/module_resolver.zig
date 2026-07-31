const std = @import("std");
const FunctionDecl = @import("../ast/stmt.zig").FunctionDecl;
const stmt = @import("../ast/stmt.zig");
const VariableDecl = @import("../ast/stmt.zig").VarDecl;
const ImportStatement = @import("../ast/stmt.zig").ImportStatement;
const readFile = @import("../compiler/parser.zig").readFile;
const parseFromSource = @import("../compiler/parser.zig").parseFromSource;
const ExportStatement = stmt.ExportStatement;

pub const Module = struct {
    name: []const u8,
    imports: []*ImportStatement,

    functions: []*FunctionDecl,
    structs: []*stmt.StructStmt,
    variables: []*VariableDecl,
};

pub const ModuleResolver = struct {
    allocator: *std.mem.Allocator,
    resolved: std.StringHashMap(*Module),
    in_progress: std.StringHashMap(u8),

    pub fn init(self: *ModuleResolver, allocator: *std.mem.Allocator) void {
        self.allocator = allocator;
        self.resolved = std.StringHashMap(*Module).init(allocator);
        self.in_progress = std.StringHashMap(u8).init(allocator);
    }

    pub fn resolveModule(self: *ModuleResolver, moduleName: []const u8) !*Module {
        if (self.in_progress.get(moduleName)) |_| {
            return error.CircularDependency;
        }

        if (self.resolved.get(moduleName)) |resolvedModule| {
            return resolvedModule;
        }

        _ = try self.in_progress.put(moduleName, 1);

        const module = try self.loadModule(moduleName);

        for (module.imports) |importStmt| {
            const importedModuleName = importStmt.path;
            const importedModule = try self.resolveModule(importedModuleName);
            _ = try self.resolved.put(importedModuleName, importedModule);
        }

        _ = try self.resolved.put(moduleName, module);
        _ = try self.in_progress.remove(moduleName);

        return module;
    }

    pub fn loadModule(self: *ModuleResolver, moduleName: []const u8) !*Module {
        const source = try readFile(self.allocator, moduleName);

        const statements = try parseFromSource(self.allocator, source);
        var exportStatements = try std.ArrayList(*ExportStatement).initCapacity(self.allocator, 0);
        const module = try self.allocator.create(Module);

        for (statements) |_stmt| {
            switch (_stmt.*) {
                .ImportStatement => {
                    try exportStatements.append(self.allocator, _stmt.ImportStatement);
                },

                .ExportStatement => {
                    try exportStatements.append(self.allocator, _stmt.ExportStatement);
                },
                .FunctionDecl => {
                    const export_stmt = try self.allocator.create(ExportStatement);
                    export_stmt.* = .{ .FunctionDecl = _stmt.FunctionDecl };
                    try exportStatements.append(self.allocator, export_stmt);
                },
                .StructDecl => {
                    const export_stmt = try self.allocator.create(ExportStatement);
                    export_stmt.* = .{ .StructDecl = _stmt.StructDecl };
                    try exportStatements.append(self.allocator, export_stmt);
                },
                .VariableDecl => {
                    const export_stmt = try self.allocator.create(ExportStatement);
                    export_stmt.* = .{ .VariableDecl = _stmt.VariableDecl };
                    try exportStatements.append(self.allocator, export_stmt);
                },
                else => {},
            }
        }

        module.* = .{
            .name = self.resolveModuleName(moduleName),
            .imports = try std.ArrayList(*ImportStatement).initCapacity(self.allocator, 0),
            .functions = try std.ArrayList(*FunctionDecl).initCapacity(self.allocator, 0),
            .structs = try std.ArrayList(*stmt.StructStmt).initCapacity(self.allocator, 0),
            .variables = try std.ArrayList(*VariableDecl).initCapacity(self.allocator, 0),
        };
        return module;
    }

    fn resolveModuleName(self: *ModuleResolver, modulePath: []const u8) !*Module {
        _ = self;
        var moduleName = "";

        const parts = std.mem.split(modulePath, "/");
        if (parts.len > 0) {
            moduleName = parts[parts.len - 1];
        } else {
            moduleName = modulePath;
        }
        return modulePath;
    }
};
