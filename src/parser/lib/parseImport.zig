const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const ParserError = @import("../error.zig").ParserError;
const stmt_ast = @import("../../ast/stmt.zig");
const ImportStatement = stmt_ast.ImportStatement;
const parseFromSource = @import("../../compiler/parser.zig").parseFromSource;
const ExportStatement = stmt_ast.ExportStatement;
const readFile = @import("../../compiler/parser.zig").readFile;

pub fn parseImportStatement(self: *Parser) ParserError!*ImportStatement {
    _ = try self.expect(.KwImport);

    const pathToken = try self.expect(.StringLiteral);
    const path = pathToken.lexeme[1 .. pathToken.lexeme.len - 1];
    _ = try self.expect(.Semicolon);
    const source = try readFile(self.allocator, path);

    const statements = try parseFromSource(self.allocator, source);
    var exportStatements = try std.ArrayList(*ExportStatement).initCapacity(self.allocator, 0);

    for (statements) |stmt| {
        switch (stmt.*) {
            .ExportStatement => {
                try exportStatements.append(self.allocator, stmt.ExportStatement);
            },
            .FunctionDecl => {
                const export_stmt = try self.allocator.create(ExportStatement);
                export_stmt.* = .{ .FunctionDecl = stmt.FunctionDecl };
                try exportStatements.append(self.allocator, export_stmt);
            },
            .StructDecl => {
                const export_stmt = try self.allocator.create(ExportStatement);
                export_stmt.* = .{ .StructDecl = stmt.StructDecl };
                try exportStatements.append(self.allocator, export_stmt);
            },
            .VariableDecl => {
                const export_stmt = try self.allocator.create(ExportStatement);
                export_stmt.* = .{ .VariableDecl = stmt.VariableDecl };
                try exportStatements.append(self.allocator, export_stmt);
            },
            else => {},
        }
    }

    const imported_statements = try exportStatements.toOwnedSlice(self.allocator);

    const stmt = try self.allocator.create(ImportStatement);

    stmt.* = .{
        .path = path,
        .importedStatements = imported_statements,
        .isLocal = true,
    };

    return stmt;
}
