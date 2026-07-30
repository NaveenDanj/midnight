const std = @import("std");

pub const ParserError = error{
    UnexpectedEndOfFile,
    UnExpectedToken,
    UnExpectedEndOfLine,
    TokenNotFound,
    OutOfMemory,
    UnknownCharacter,
    UnterminatedString,
} || std.Io.File.OpenError || std.Io.Reader.LimitedAllocError;
