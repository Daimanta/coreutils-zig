// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const mem = std.mem;

const Allocator = std.mem.Allocator;

pub fn print(comptime format_string: []const u8, args: anytype) void {
    std.io.getStdOut().writer().print(format_string, args) catch return;
}
