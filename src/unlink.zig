const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

const application_name = "unlink";

const help_message =
\\Usage: unlink FILE
\\  or:  unlink OPTION
\\Call the unlink function to remove the specified FILE.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
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
    }

    const positionals = args.positionals();

    if (positionals.len > 2) {
        std.debug.print("Too many arguments. Exiting\n", .{});
        std.os.exit(1);
    } else if (positionals.len == 0) {
        std.debug.print("No file specified. Exiting\n", .{});
        std.os.exit(1);
    }

    const file_target = positionals[0];
    try os.unlink(file_target);
}