const std = @import("std");

const ModuleResolverError = error{
    CircularDependency,
    ModuleNotFound,
} || std.Io.File.OpenError || std.Io.Reader.LimitedAllocError;
