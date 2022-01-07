const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

const application_name = "dircolors";

const help_message =
    \\Usage: dircolors [OPTION]... [FILE]
    \\Output commands to set the LS_COLORS environment variable.
    \\
    \\Determine format of output:
    \\  -b, --sh, --bourne-shell    output Bourne shell code to set LS_COLORS
    \\  -c, --csh, --c-shell        output C shell code to set LS_COLORS
    \\  -p, --print-database        output defaults
    \\      --help     display this help and exit
    \\      --version  output version information and exit
    \\
    \\If FILE is specified, read it to determine which colors to use for which
    \\file types and extensions.  Otherwise, a precompiled database is used.
    \\For details on the format of these files, run 'dircolors --print-database'.
    \\
    \\
;

const env_name: []const u8 = "LS_COLORS";

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("-b, --sh") catch unreachable,
        clap.parseParam("--bourne-shell") catch unreachable,
        clap.parseParam("-c, --csh") catch unreachable,
        clap.parseParam("-p, --print-database") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.os.exit(0);
    }

    const env = os.getenv(env_name);
    if (env != null) {
        std.debug.print("LS_COLORS='{s}';\nexport LS_COLORS\n", .{env});
    }
}
