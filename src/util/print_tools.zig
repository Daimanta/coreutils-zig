// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const mem = std.mem;

const Allocator = std.mem.Allocator;


pub fn print(comptime format_string: []const u8, args: anytype) void {
    std.io.getStdOut().writer().print(format_string, args) catch return;
}

pub fn println(comptime format_string: []const u8, args: anytype) void {
    std.io.getStdOut().writer().print(format_string ++ "\n", args) catch return;
}

pub fn pprint(comptime format_string: []const u8) void {
    std.io.getStdOut().writer().print(format_string, .{}) catch return;
}

pub fn pprintln(comptime format_string: []const u8) void {
    std.io.getStdOut().writer().print(format_string ++ "\n", .{}) catch return;
}
