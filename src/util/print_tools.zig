// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const mem = std.mem;

const Allocator = std.mem.Allocator;

const writer = std.io.getStdOut().writer();

pub fn print(comptime format_string: []const u8, args: anytype) void {
    writer.print(format_string, args) catch return;
}

pub fn println(comptime format_string: []const u8, args: anytype) void {
    writer.print(format_string, args) catch return;
    writer.print("\n", .{}) catch return;
}

pub fn pprint(comptime format_string: []const u8) void {
    writer.print(format_string, .{}) catch return;
}

pub fn pprintln(comptime format_string: []const u8) void {
    writer.print(format_string, .{}) catch return;
    writer.print("\n", .{}) catch return;
}
