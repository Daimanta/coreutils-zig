const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const mem = std.mem;

const clap = @import("clap.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const default_allocator = std.heap.page_allocator;

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
    const arguments = try std.process.argsAlloc(default_allocator);

    if (arguments.len == 1) {
        return;
    }

    const options = arguments[1];
    var print_newline = true;
    var flag_e = false;
    var flag_E = false;
    var ignore_first_argument = true;

    if (options[0] == '-' and options.len > 1) {
        if (options.len == 1) {
            if (mem.eql(u8, options, "--help")) {
                std.debug.print(help_message, .{});
                std.os.exit(0);
            } else if (mem.eql(u8, options, "--version")) {
                version.printVersionInfo(application_name);
                std.os.exit(0);
            }
        }
        if (options[1] != '-') {
            var i: usize = 1;
            while (i < options.len): (i += 1) {
                const byte = options[i];
                if (byte != 'e' and byte != 'E' and byte != 'n') {
                    ignore_first_argument = false;
                }
            }
            if (ignore_first_argument) {
                i = 1;
                while (i < options.len): (i += 1) {
                    const byte = options[i];
                    switch (byte) {
                        'e' => flag_e = true,
                        'E' => flag_E = true,
                        'n' => print_newline = false,
                        else => unreachable
                    }
                }
            }
        }
    }

    if (flag_e and flag_E) {
        std.debug.print("Cannot combine -e and -E. Exiting\n",.{});
        std.os.exit(1);
    }

    if (flag_e) {
        var i: usize = 1;
        if (ignore_first_argument) i += 1;
        while (i < arguments.len - 1): (i += 1) {
            printEscapedString(arguments[i], true);
        }

        if (arguments.len > 1) {
            printEscapedString(arguments[arguments.len - 1], false);
        }
    } else {
        var i: usize = 1;
        if (ignore_first_argument) i += 1;
        while (i < arguments.len - 1): (i += 1) {
            std.debug.print("{s} ", .{arguments[i]});
        }

        if (arguments.len > 1) {
            std.debug.print("{s}", .{arguments[arguments.len - 1]});
        }
    }
    if (print_newline) std.debug.print("\n", .{});
}

fn printEscapedString(string: []const u8, space: bool) void {
    var found_backslash = false;
    for (string) |byte, i| {
        if (i != string.len - 1 and byte == '\\') {
            found_backslash = true;
            break;
        }
    }

    if (found_backslash) {
        var i: usize = 0;
        while (i < string.len) {
            var j = i;
            while (j < string.len) {
                if (string[j] == '\\') {
                    std.debug.print("{s}", .{string[i..j]});
                    i += 1;
                    break;
                }
                j += 1;
            }
            i += 1;
        }
    } else {
        std.debug.print("{s}", .{string});
        if (space) std.debug.print(" ", .{});
    }

}