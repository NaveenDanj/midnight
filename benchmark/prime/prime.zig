const std = @import("std");

fn isPrime(n: i32) bool {
    if (n < 2)
        return false;

    var i: i32 = 2;

    while (i * i <= n) : (i += 1) {
        if (@mod(n, i) == 0)
            return false;
    }

    return true;
}

pub fn main() !void {
    var count: i32 = 0;
    var n: i32 = 2;

    while (n <= 1_000_000) : (n += 1) {
        if (isPrime(n)) {
            count += 1;
        }
    }

    std.debug.print("{}\n", .{count});
}
