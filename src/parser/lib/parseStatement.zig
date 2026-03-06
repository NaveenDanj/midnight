const Parser = @import("../parser.zig").Parser;
const Statement = @import("./commTypes.zig").Statement;
const parseVarDecl = @import("./parseVarDec.zig").parseVarDecl;

pub fn parseStatement(self: *Parser) !*Statement {
    if (self.check(.KwVar)) {
        const varDecl = try parseVarDecl(self);
        const statement = try self.allocator.create(Statement);
        statement.* = .{ .VariableDecl = varDecl };
        return statement;
    } else {
        return error.UnExpectedToken;
    }
}
