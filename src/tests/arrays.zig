const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;

const Lexer = @import("../lexer/lexer.zig").Lexer;
const Parser = @import("../parser/parser.zig").Parser;
const SemanticAnalyzer = @import("../semantic/anaylzer.zig").SemanticAnalyzer;
const SemanticError = @import("../semantic/semantic_error.zig").SemanticError;

test "parse array literal expression" {
	var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

	const source =
		\\func main() int {
		\\    var int[] values = [1, 2, 3];
		\\    return 0;
		\\}
	;

	var lexer = Lexer.init(source);
	var token_list = try lexer.lexAll(std.testing.allocator);
	defer token_list.deinit(std.testing.allocator);

	var parser = Parser.init(allocator, token_list.items);
	const statements = try parser.parseProgram();

	try expect(statements.len == 1);
	try expect(statements[0].* == .FunctionDecl);

	const body = statements[0].FunctionDecl.body.statements;
	try expect(body.len == 2);
	try expect(body[0].* == .VariableDecl);
	try expect(body[0].VariableDecl.varType.isArray);
	try expect(body[0].VariableDecl.initializer.* == .ArrayLiteral);
	try expect(body[0].VariableDecl.initializer.ArrayLiteral.elements.len == 3);
	try expect(body[0].VariableDecl.initializer.ArrayLiteral.elements[0].* == .IntLiteral);
	try expect(body[0].VariableDecl.initializer.ArrayLiteral.elements[0].IntLiteral.value == 1);
}

test "semantic analysis accepts homogeneous array literal" {
	var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

	const source =
		\\func main() int {
		\\    var int[] values = [1, 2, 3];
		\\    return 0;
		\\}
	;

	var lexer = Lexer.init(source);
	var token_list = try lexer.lexAll(std.testing.allocator);
	defer token_list.deinit(std.testing.allocator);

	var parser = Parser.init(allocator, token_list.items);
	const statements = try parser.parseProgram();

	var semantic = try SemanticAnalyzer.init(allocator);
	try semantic.analyzeProgram(statements);
}

test "semantic analysis rejects mixed array literal" {
	var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

	const source =
		\\func main() int {
		\\    var int[] values = [1, true];
		\\    return 0;
		\\}
	;

	var lexer = Lexer.init(source);
	var token_list = try lexer.lexAll(std.testing.allocator);
	defer token_list.deinit(std.testing.allocator);

	var parser = Parser.init(allocator, token_list.items);
	const statements = try parser.parseProgram();

	var semantic = try SemanticAnalyzer.init(allocator);
	try expectError(SemanticError.TypeMismatch, semantic.analyzeProgram(statements));
}
