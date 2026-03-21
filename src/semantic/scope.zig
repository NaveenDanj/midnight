const std = @import("std");
const Symbol = @import("./symbol.zig").Symbol;
const SymbolKind = @import("./symbol.zig").SymbolKind;
const Type = @import("./types.zig").Type;
const SemanticError = @import("./semantic_error.zig").SemanticError;
const Statement = @import("../parser/lib/parseStatement.zig").Statement;

pub const Scope = struct {
    symbols: std.StringHashMap(Symbol),
};

pub const ScopeStack = struct {
    allocator: std.mem.Allocator,
    scopeStack: std.ArrayList(Scope),

    pub fn init(allocator: std.mem.Allocator) !ScopeStack {
        return .{ .allocator = allocator, .scopeStack = try std.ArrayList(Scope).initCapacity(allocator, 0) };
    }

    pub fn pushScope(self: *ScopeStack) !void {
        const scope = Scope{ .symbols = std.StringHashMap(Symbol).init(self.allocator) };
        try self.scopeStack.append(self.allocator, scope);
    }

    pub fn popScope(self: *ScopeStack) void {
        _ = self.scopeStack.pop();
    }

    pub fn declareSymbol(self: *ScopeStack, symbolName: []const u8, kind: SymbolKind, symbolType: Type, isImmutable: bool, params: []Type) !void {
        var currentScope = &self.scopeStack.items[self.scopeStack.items.len - 1];

        if (currentScope.symbols.contains(symbolName)) {
            return SemanticError.SymbolAlreadyDeclared;
        }

        const symbol = Symbol{ .name = symbolName, .kind = kind, .symbolType = symbolType, .isImmutable = isImmutable, .params = params };
        _ = try currentScope.symbols.put(symbolName, symbol);
    }

    pub fn lookupSymbol(self: *ScopeStack, symbolName: []const u8) ?Symbol {
        var i: usize = self.scopeStack.items.len;
        while (i > 0) : (i -= 1) {
            const currentScope = &self.scopeStack.items[i - 1];
            if (currentScope.symbols.get(symbolName)) |symbol| {
                return symbol;
            }
        }
        return null;
    }
};
