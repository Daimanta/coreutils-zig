const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

const clap = @import("clap.zig");
const version = @import("util/version.zig");
const strings = @import("util/strings.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;
const print = @import("util/print_tools.zig").print;
const exit = std.posix.exit;

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
pub extern fn getlogin_r(buf: [*:0]u8, bufsize: usize) callconv(.C) c_int;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    if (args.flag("--help")) {
        print(help_message, .{});
        std.posix.exit(0);
    } else if (args.flag("--version")) {
        version.printVersionInfo(application_name);
        std.posix.exit(0);
    }

    printLoginNameMessage();
}

fn printLoginNameMessage() void {
    const stringPointer: [*:0]u8 = undefined;
    const err: c_int = getlogin_r(stringPointer, 1 << 8);
    if (err != 0) {
        std.debug.print("{s}\n", .{"logname: no login name"});
        exit(1);
    } else {
        print("{s}\n", .{strings.convertOptionalSentinelString(stringPointer).?});
        exit(0);
    }
}
