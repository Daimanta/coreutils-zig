const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "tty";

const help_message =
\\Usage: tty [OPTION]...
\\Print the file name of the terminal connected to standard input.
\\
\\  -s, --silent, --quiet   print nothing, only return an exit status
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

pub extern fn ttyname(fd: c_int) callconv(.c) [*:0]u8;

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("s", &[_][]const u8{"quiet", "silent"}),
    };

    var parser = clap2.Parser.init(args, .{});
    defer parser.deinit();

    if (parser.flag("help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (parser.flag("version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    const silent = parser.flag("s");

    if (!silent) {
        const stdin = std.posix.STDIN_FILENO;
        const check_tty = std.posix.isatty(stdin);
        if (!check_tty) {
            print("not a tty. Exiting", .{});
            std.posix.exit(1);
        }
        print("{s}\n", .{ttyname(stdin)});
    }

}
