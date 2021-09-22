const std = @import("std");
const os = std.os;
const mem = std.mem;

const clap = @import("clap.zig");
const version = @import("util/version.zig");

const Allocator = std.mem.Allocator;

const allocator = std.heap.page_allocator;

const application_name = "hostid";
const help_message =
\\Usage: hostid [OPTION]
\\Print the numeric identifier (in hexadecimal) for the current host.
\\
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
;

extern fn gethostid() callconv(.C) c_long;

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("--help") catch unreachable,
        clap.parseParam("--version") catch unreachable,
        clap.parseParam("<STRING>") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parseAndHandleErrors(clap.Help, &params, .{ .diagnostic = &diag }, application_name, 1);
    defer args.deinit();

    if (args.flag("--help")) {
        std.debug.print(help_message, .{});
        std.os.exit(0);
    } else if (args.flag("--version")) {
        version.print_version_info(application_name);
        std.os.exit(0);
    }

    const arguments = try std.process.argsAlloc(allocator);

    const c_hostid = gethostid();
    const hostid = @intCast(u32, c_hostid);
    std.debug.print("{x:0>8}\n", .{hostid});

}
