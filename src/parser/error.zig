const std = @import("std");

pub const ParserError = error{
    UnexpectedEndOfFile,
    UnExpectedToken,
    UnExpectedEndOfLine,
    TokenNotFound,
    OutOfMemory,
    UnknownCharacter,
    UnterminatedString,
};
