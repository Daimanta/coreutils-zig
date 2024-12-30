const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const mem = std.mem;

const clap = @import("clap.zig");
const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const default_allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "echo";

const help_message =
\\Usage: /usr/bin/echo [SHORT-OPTION]... [STRING]...
\\  or:  /usr/bin/echo LONG-OPTION
\\Echo the STRING(s) to standard output.
\\
\\  -n             do not output the trailing newline
\\  -e             enable interpretation of backslash escapes
\\  -E             disable interpretation of backslash escapes (default)
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\If -e is in effect, the following sequences are recognized:
\\
\\  \\      backslash
\\  \a      alert (BEL)
\\  \b      backspace
\\  \c      produce no further output
\\  \e      escape
\\  \f      form feed
\\  \n      new line
\\  \r      carriage return
\\  \t      horizontal tab
\\  \v      vertical tab
\\  \0NNN   byte with octal value NNN (1 to 3 digits)
\\  \xHH    byte with hexadecimal value HH (1 to 2 digits)
\\
\\NOTE: your shell may have its own version of echo, which usually supersedes
\\the version described here.  Please refer to your shell's documentation
\\for details about the options it supports.
\\
;

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("n", null),
        clap2.Argument.FlagArgument("e", null),
        clap2.Argument.FlagArgument("E", null),
    };

    var parser = clap2.Parser.init(args);
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    const print_newline = !parser.flag("n");
    const escape_characters = parser.flag("e");
    const disable_escape_characters = parser.flag("E");
    const positionals = parser.positionals();
    const positionals_string = try std.mem.join(default_allocator, " ", positionals);

    if (escape_characters and disable_escape_characters) {
        print("Cannot combine -e and -E. Exiting\n",.{});
        std.posix.exit(1);
    }

    if (escape_characters) {
        const result = printEscapedString(positionals_string, true);
        if (result) return;
    } else {
        print("{s} ", .{positionals_string});
    }
    if (print_newline) print("\n", .{});
}

fn printEscapedString(string: []const u8, space: bool) bool {
    var found_backslash = false;
    for (string, 0..) |byte, i| {
        if (i != string.len - 1 and byte == '\\') {
            found_backslash = true;
            break;
        }
    }

    if (found_backslash) {
        var i: usize = 0;
        var old_begin: usize = 0;
        while (i < string.len): (i += 1) {
            if (string[i] == 92 and i < string.len - 1) {
                print("{s}", .{string[old_begin..i]});
                if (string[i + 1] == 92) {
                    print("\\", .{});
                    old_begin = i + 2;
                    i += 2;
                } else if (string [i + 1] == 'a') {
                    print("\x07", .{});
                    old_begin = i + 2;
                    i += 2;
                } else if (string [i + 1] == 'b') {
                    print("\x08", .{});
                    old_begin = i + 2;
                    i += 2;
                } else if (string [i + 1] == 'c') {
                    return true;
                } else if (string [i + 1] == 'e') {
                    print("\x1B", .{});
                    old_begin = i + 2;
                    i += 2;
                } else if (string [i + 1] == 'f') {
                    print("\x0C", .{});
                    old_begin = i + 2;
                    i += 2;
                } else if (string [i + 1] == 'n') {
                    print("\n", .{});
                    old_begin = i + 2;
                    i += 2;
                } else if (string [i + 1] == 'r') {
                    print("\r", .{});
                    old_begin = i + 2;
                    i += 2;
                } else if (string [i + 1] == 't') {
                    print("\t", .{});
                    old_begin = i + 2;
                    i += 2;
                } else if (string [i + 1] == 'v') {
                    print("\x0B", .{});
                    old_begin = i + 2;
                    i += 2;
                } else if (string [i + 1] == '0') {
                    if (i + 4 < string.len and byteIsOct(string[i + 2]) and byteIsOct(string[i + 3]) and byteIsOct(string[i + 4])) {
                        const byte = std.fmt.parseInt(u8, string[i+1..i+5], 8) catch unreachable;
                        const byte_string: [1]u8 = .{byte};
                        print("{s}", .{byte_string});
                        old_begin = i + 5;
                        i += 5;
                    } else if (i + 3 < string.len and byteIsOct(string[i + 2]) and byteIsOct(string[i + 3])) {
                        const byte = std.fmt.parseInt(u8, string[i+1..i+4], 8) catch unreachable;
                        const byte_string: [1]u8 = .{byte};
                        print("{s}", .{byte_string});
                        old_begin = i + 4;
                        i += 4;
                    } else if (i + 2 < string.len and byteIsOct(string[i + 2])) {
                        const byte = std.fmt.parseInt(u8, string[i+1..i+3], 8) catch unreachable;
                        const byte_string: [1]u8 = .{byte};
                        print("{s}", .{byte_string});
                        old_begin = i + 3;
                        i += 3;
                    } else {
                        old_begin = i;
                    }
                } else if (string [i + 1] == 'x') {
                    if (i + 3 < string.len and byteIsHex(string[i + 2]) and byteIsHex(string[i + 3])) {
                        const byte = std.fmt.parseInt(u8, string[i+2..i+4], 16) catch unreachable;
                        const byte_string: [1]u8 = .{byte};
                        print("{s}", .{byte_string});
                        old_begin = i + 4;
                        i += 4;
                    } else if (i + 2 < string.len and byteIsHex(string[i + 2])) {
                        const byte = std.fmt.parseInt(u8, string[i+2..i+3], 16) catch unreachable;
                        const byte_string: [1]u8 = .{byte};
                        print("{s}", .{byte_string});
                        old_begin = i + 3;
                        i += 3;
                    } else {
                        old_begin = i;
                    }
                }
                else {
                    old_begin = i;
                }
            }
        }
        if (old_begin < string.len) {
            print("{s}", .{string[old_begin..string.len]});
        }
    } else {
        print("{s}", .{string});
        if (space) print(" ", .{});
    }
    return false;
}

fn byteIsOct(byte: u8) bool {
    return byte >= '0' and byte <= '7';
}

fn byteIsHex(byte: u8) bool {
    return (byte >= '0' and byte <= '9') or (byte >= 'a' and byte <= 'f') or (byte >= 'A' and byte <= 'F');
}
