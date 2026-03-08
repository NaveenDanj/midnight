const Type = @import("./types.zig").Type;

pub const SymbolKind = enum {
    variable,
    function,
    parameter,
};

pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    symbolType: Type,
};
