const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap2 = @import("clap2/clap2.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;

const application_name = "printenv";

const help_message =
\\Usage: /usr/bin/printenv [OPTION]... [VARIABLE]...
\\Print the values of the specified environment VARIABLE(s).
\\If no VARIABLE is specified, print name and value pairs for them all.
\\
\\  -0, --null     end each output line with NUL, not newline
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
\\NOTE: your shell may have its own version of printenv, which usually supersedes
\\the version described here.  Please refer to your shell's documentation
\\for details about the options it supports.
\\
;

pub fn main() !void {
    const args: []const clap2.Argument = &[_]clap2.Argument{
        clap2.Argument.FlagArgument(null, &[_][]const u8{"help"}),
        clap2.Argument.FlagArgument(null, &[_][]const u8{"version"}),
        clap2.Argument.FlagArgument("0", &[_][]const u8{"null"}),
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

    var separator = "\n";
    const useNullEnd = parser.flag("0");

    if (useNullEnd) {
        separator = "\x00";
    }

    const vals = parser.positionals();
    if (vals.len > 0) {
        for (vals) |arg| {
            const env = std.posix.getenv(arg);
            if (env != null) {
                print("{s}{s}", .{env.?, separator});
            }
        }
    } else {
        const environment = std.c.environ;
        var iterator: usize = 0;
        while (environment[iterator] != null): (iterator += 1) {
            print("{s}\n", .{environment[iterator].?});
        }
    }

}
