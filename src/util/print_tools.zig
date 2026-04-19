// BSD 3-clause licensed. Copyright Léon van der Kaap 2021

const std = @import("std");
const Io = std.Io;

var threaded: Io.Threaded = .init_single_threaded;
const io = threaded.io();

pub fn print(comptime format_string: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buffer);
    const stdout = &stdout_writer.interface;
    stdout.print(format_string, args) catch return;
    stdout.flush() catch return;
}

pub fn println(comptime format_string: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buffer);
    const stdout = &stdout_writer.interface;
    stdout.print(format_string ++ "\n", args) catch return;
    stdout.flush() catch return;
}

pub fn pprint(comptime format_string: []const u8) void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buffer);
    const stdout = &stdout_writer.interface;
    stdout.print(format_string, .{}) catch return;
    stdout.flush() catch return;
}

pub fn pprintln(comptime format_string: []const u8) void {
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buffer);
    const stdout = &stdout_writer.interface;
    stdout.print(format_string ++ "\n", .{}) catch return;
    stdout.flush() catch return;
}
