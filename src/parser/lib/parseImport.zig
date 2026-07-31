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

    const stmt = try self.allocator.create(ImportStatement);

    stmt.* = .{
        .path = path,
        .isLocal = true,
    };

    return stmt;
}
