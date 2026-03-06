const FunctionDecl = @import("./parseFunctionDecl.zig").FunctionDecl;
const BlockStmt = @import("./parseBlock.zig").BlockStmt;
const VariableDecl = @import("./parseVarDec.zig").VarDecl;

pub const Statement = union(enum) {
    FunctionDecl: *FunctionDecl,
    Block: *BlockStmt,
    VariableDecl: *VariableDecl,
};

pub const Literal = union(enum) {
    Integer: i64,
    Float: f64,
    String: []const u8,
    Boolean: bool,
};

pub const DataType = struct {
    DataTypeKind: []u8,
};
