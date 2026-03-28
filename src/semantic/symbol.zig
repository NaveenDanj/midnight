const Type = @import("./types.zig").Type;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;

pub const SymbolKind = enum {
    variable,
    function,
    parameter,
    structure,
};

pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    symbolType: Type,
    isImmutable: bool,
    params: []Type,
};
