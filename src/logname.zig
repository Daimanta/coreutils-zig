const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

const application_name = "logname";

const help_message =
\\Usage: logname [OPTION]
\\Print the name of the current user.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

pub extern fn getlogin() callconv(.C) [*:0]u8;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
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

    const login = getLoginName();
    if (login == null) {
        std.debug.print("{s}: no login name\n", .{application_name});
        std.os.exit(1);
    } else {
        std.debug.print("{s}\n", .{login});
        std.os.exit(0);
    }

}

fn getLoginName() ?[]u8 {
    return strings.convertOptionalSentinelString(getlogin());
}