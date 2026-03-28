const std = @import("std");
const StructStmt = @import("../parser/lib/parseStruct.zig").StructStmt;
const FunctionDecl = @import("../parser/lib/parseFunctionDecl.zig").FunctionDecl;
const SemanticError = @import("./semantic_error.zig").SemanticError;

pub const SemanticContext = struct {
    allocator: std.mem.Allocator,
    structs: std.StringHashMap(*StructStmt),
    functions: std.StringHashMap(*FunctionDecl),

    pub fn init(allocator: std.mem.Allocator) !SemanticContext {
        return .{ .allocator = allocator, .structs = std.StringHashMap(*StructStmt).init(allocator), .functions = std.StringHashMap(*FunctionDecl).init(allocator) };
    }

    pub fn deinit(self: *SemanticContext) void {
        self.structs.deinit();
        self.functions.deinit();
    }

    pub fn addStruct(self: *SemanticContext, structDef: *StructStmt) !void {
        if (self.structs.contains(structDef.name)) {
            return SemanticError.StructAlreadyDeclared;
        }
        _ = try self.structs.put(structDef.name, structDef);
    }

    pub fn addFunction(self: *SemanticContext, funcDef: *FunctionDecl) !void {
        if (self.functions.contains(funcDef.name)) {
            return SemanticError.FunctionAlreadyDeclared;
        }
        _ = try self.functions.put(funcDef.name, funcDef);
    }
};
