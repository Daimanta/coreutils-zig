const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

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
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-0, --null") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    var separator = "\n";

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    if (args.flag("-0") or args.flag("--null")) {
        separator = "\x00";
    }

    const vals = args.positionals();
    if (vals.len > 0) {
        for (vals) |arg| {
            const env = os.getenv(arg);
            if (env != null) {
                std.debug.print("{s}{s}", .{env, separator});
            }
        }
    } else {
        const environment = std.c.environ;
        var walker = environment;
        while(walker.*) |param| {
            std.debug.print("{s}\n", .{param});
            walker += 1;
        }
    }

}
