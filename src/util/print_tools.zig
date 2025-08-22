// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");

pub fn print(comptime format_string: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;
    stdout.print(format_string, args) catch return;
    stdout.flush() catch return;
}

pub fn println(comptime format_string: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;
    stdout.print(format_string ++ "\n", args) catch return;
    stdout.flush() catch return;
}

pub fn pprint(comptime format_string: []const u8) void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;
    stdout.print(format_string, .{}) catch return;
    stdout.flush() catch return;
}

pub fn pprintln(comptime format_string: []const u8) void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;
    stdout.print(format_string ++ "\n", .{}) catch return;
    stdout.flush() catch return;
}
