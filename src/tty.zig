const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

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

pub extern fn ttyname(fd: c_int) callconv(.C) [*:0]u8;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("--silent") catch unreachable,
        clap.parseParam("-s") catch unreachable,
        clap.parseParam("--quiet") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    var silent = false;

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    } else if (args.flag("--silent") or args.flag("--quiet") or args.flag("-s")) {
        silent = true;
    }

    if (!silent) {
        const stdin = os.STDIN_FILENO;
        const check_tty = os.isatty(stdin);
        if (!check_tty) {
            std.debug.print("not a tty. Exiting", .{});
            std.os.exit(1);
        }
        std.debug.print("{s}\n", .{ttyname(stdin)});
    }

}